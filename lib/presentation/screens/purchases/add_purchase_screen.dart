import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/services/receipt_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../domain/services/coffee_calculation_service.dart';

/// Add New Purchase Screen
class AddPurchaseScreen extends StatefulWidget {
  const AddPurchaseScreen({Key? key}) : super(key: key);

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _grossWeightController = TextEditingController();
  final _deductionController = TextEditingController();
  // NEW: Multiple deduction fields
  final _transportDeductionController = TextEditingController(text: '0');
  final _qualityDeductionController = TextEditingController(text: '0');
  final _otherDeductionController = TextEditingController(text: '0');
  
  final _pricePerKgController = TextEditingController();
  final _advanceController = TextEditingController();
  final _millingChargePerKgController = TextEditingController(text: '300');
  final _farmerSearchController = TextEditingController();
  final _walkInNameController = TextEditingController(); // For walk-in customer name
  
  // NEW: Partial payment field
  final _amountPaidController = TextEditingController();
  
  String? _selectedFarmerId;
  String? _selectedFarmerName;
  String? _selectedFarmerPhone;
  bool _isLoading = false;
  String _farmerSearchQuery = '';
  bool _isWalkInCustomer = false; // Toggle for walk-in customer
  
  // Calculated values
  double _payableWeight = 0;
  double _totalAmount = 0;
  double _millingCharge = 0;
  double _netPayment = 0;
  double _balance = 0; // NEW: Balance to track pending amount
  
  // Store last purchase data for receipt
  double _lastGrossWeight = 0;
  double _lastDeduction = 0;
  double _lastPricePerKg = 0;

  @override
  void dispose() {
    _grossWeightController.dispose();
    _deductionController.dispose();
    _transportDeductionController.dispose();
    _qualityDeductionController.dispose();
    _otherDeductionController.dispose();
    _pricePerKgController.dispose();
    _advanceController.dispose();
    _millingChargePerKgController.dispose();
    _farmerSearchController.dispose();
    _walkInNameController.dispose();
    _amountPaidController.dispose();
    super.dispose();
  }

  void _calculateAmounts() {
    final grossWeight = double.tryParse(_grossWeightController.text) ?? 0;
    final deduction = double.tryParse(_deductionController.text) ?? 0;
    
    // NEW: Calculate total deductions from multiple sources
    final transportDeduction = double.tryParse(_transportDeductionController.text) ?? 0;
    final qualityDeduction = double.tryParse(_qualityDeductionController.text) ?? 0;
    final otherDeduction = double.tryParse(_otherDeductionController.text) ?? 0;
    final totalMoneyDeduction = transportDeduction + qualityDeduction + otherDeduction;
    
    final pricePerKg = double.tryParse(_pricePerKgController.text) ?? 0;
    final advance = double.tryParse(_advanceController.text) ?? 0;
    final millingChargePerKg = double.tryParse(_millingChargePerKgController.text) ?? 300;
    
    // NEW: Amount actually paid
    final amountPaid = double.tryParse(_amountPaidController.text) ?? 0;

    // Only calculate if we have valid positive values
    if (grossWeight > 0 && pricePerKg > 0) {
      final result = CoffeeCalculationService.calculatePurchase(
        grossWeight: grossWeight,
        qualityDeduction: deduction,
        buyingPricePerKg: pricePerKg,
        advanceRecovery: advance,
        millingRatePerKg: millingChargePerKg,
      );

      // Calculate net payment with money deductions
      final netPaymentBeforeDeductions = result.netPayment;
      final finalNetPayment = netPaymentBeforeDeductions - totalMoneyDeduction;
      
      // Calculate balance (what farmer is still owed)
      final balance = amountPaid > 0 ? (finalNetPayment - amountPaid) : 0;

      setState(() {
        _payableWeight = result.payableWeight;
        _totalAmount = result.coffeeValue;
        _millingCharge = result.millingCharge;
        _netPayment = finalNetPayment;
        _balance = balance.toDouble(); // Convert to double
      });
    } else {
      // Reset calculations if invalid input
      setState(() {
        _payableWeight = 0;
        _totalAmount = 0;
        _millingCharge = 0;
        _netPayment = 0;
        _balance = 0;
      });
    }
  }

  Future<void> _loadFarmerAdvances(String farmerId) async {
    try {
      // Get farmer's total active advances (using single where to avoid index requirement)
      final advancesSnapshot = await FirebaseFirestore.instance
          .collection(AppConstants.advancesCollection)
          .where('farmerId', isEqualTo: farmerId)
          .get();

      double totalAvailableAdvance = 0;
      for (var doc in advancesSnapshot.docs) {
        final data = doc.data();
        // Filter active advances in code instead of query
        if (data['status'] == 'active') {
          totalAvailableAdvance += (data['remainingAmount'] ?? 0.0);
        }
      }

      // Auto-fill the advance field
      if (totalAvailableAdvance > 0) {
        setState(() {
          _advanceController.text = totalAvailableAdvance.toStringAsFixed(0);
        });
        _calculateAmounts();
        
        // Show info to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Available advance: UGX ${totalAvailableAdvance.toStringAsFixed(0)} loaded'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      } else {
        setState(() {
          _advanceController.text = '0';
        });
      }
    } catch (e) {
      // Silently fail, user can enter manually
      setState(() {
        _advanceController.text = '0';
      });
    }
  }

  Future<void> _savePurchase() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // For walk-in customers, no farmer selection needed
    if (!_isWalkInCustomer && _selectedFarmerId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a farmer or enable walk-in customer'),
          backgroundColor: AppTheme.errorRed,
        ),
      );
      return;
    }

    // Prevent duplicate submissions
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final grossWeight = double.parse(_grossWeightController.text);
      final deduction = double.parse(_deductionController.text);
      final pricePerKg = double.parse(_pricePerKgController.text);
      final manualAdvance = double.parse(_advanceController.text.isEmpty ? '0' : _advanceController.text);
      
      // NEW: Get deduction amounts
      final transportDeduction = double.parse(_transportDeductionController.text.isEmpty ? '0' : _transportDeductionController.text);
      final qualityDeduction = double.parse(_qualityDeductionController.text.isEmpty ? '0' : _qualityDeductionController.text);
      final otherDeduction = double.parse(_otherDeductionController.text.isEmpty ? '0' : _otherDeductionController.text);
      
      // NEW: Get amount paid
      final amountPaid = double.parse(_amountPaidController.text.isEmpty ? '0' : _amountPaidController.text);
      
      // Calculate payment status
      String paymentStatus = 'paid';
      if (amountPaid > 0) {
        if (_balance > 0) {
          paymentStatus = 'partial';
        } else if (_balance == 0 && amountPaid >= _netPayment) {
          paymentStatus = 'paid';
        }
      } else {
        // No payment made means full amount pending
        paymentStatus = _netPayment > 0 ? 'pending' : 'paid';
      }

      final batch = FirebaseFirestore.instance.batch();
      double totalAdvanceToDeduct = 0;

      // Only process advances if NOT a walk-in customer and farmer selected
      if (!_isWalkInCustomer && _selectedFarmerId != null && manualAdvance > 0) {
        // Get farmer's active advances (simplified query to avoid index requirement)
        final advancesSnapshot = await FirebaseFirestore.instance
            .collection(AppConstants.advancesCollection)
            .where('farmerId', isEqualTo: _selectedFarmerId)
            .get();

        double remainingToDeduct = manualAdvance;

        // Filter active advances and sort in code
        final activeAdvances = advancesSnapshot.docs.where((doc) {
          final data = doc.data();
          return data['status'] == 'active';
        }).toList();

        // Sort by createdAt in code (oldest first)
        activeAdvances.sort((a, b) {
          final aTime = a.data()['createdAt'] as Timestamp?;
          final bTime = b.data()['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return aTime.compareTo(bTime);
        });

        // Deduct ONLY the manual advance amount
        for (var advDoc in activeAdvances) {
          if (remainingToDeduct <= 0) break;

          final advData = advDoc.data();
          final remainingAmount = (advData['remainingAmount'] ?? 0.0);

          if (remainingAmount > 0) {
            final deductAmount = remainingAmount <= remainingToDeduct
                ? remainingAmount
                : remainingToDeduct;

            totalAdvanceToDeduct += deductAmount;
            remainingToDeduct -= deductAmount;

            final newRemaining = remainingAmount - deductAmount;
            batch.update(advDoc.reference, {
              'remainingAmount': newRemaining,
              'status': newRemaining <= 0 ? 'fully_recovered' : 'active',
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      // Net payment is already calculated with the manual advance
      final finalNetPayment = _netPayment;

      // Determine customer name
      final customerName = _isWalkInCustomer 
          ? (_walkInNameController.text.trim().isEmpty ? 'Walk-in Customer' : _walkInNameController.text.trim())
          : _selectedFarmerName ?? 'Unknown';

      // Save purchase
      final currentUser = AuthService.instance.currentUser;
      final purchaseRef = FirebaseFirestore.instance.collection(AppConstants.purchasesCollection).doc();
      batch.set(purchaseRef, {
        'farmerId': _isWalkInCustomer ? null : _selectedFarmerId,
        'farmerName': customerName,
        'isWalkIn': _isWalkInCustomer,
        'grossWeight': grossWeight,
        'deduction': deduction,
        'payableWeight': _payableWeight,
        'pricePerKg': pricePerKg,
        'totalAmount': _totalAmount,
        'millingCharge': _millingCharge,
        'advanceAmount': totalAdvanceToDeduct,
        // NEW: Additional deductions
        'transportDeduction': transportDeduction,
        'qualityDeduction': qualityDeduction,
        'otherDeduction': otherDeduction,
        'totalMoneyDeduction': transportDeduction + qualityDeduction + otherDeduction,
        // NEW: Payment tracking
        'netPayment': finalNetPayment,
        'amountPaid': amountPaid > 0 ? amountPaid : finalNetPayment, // If no amount entered, assume full payment
        'balance': _balance,
        'paymentStatus': paymentStatus, // paid, partial, pending
        'branch_id': currentUser?.branchId,
        'branch_name': currentUser?.branchName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update farmer's total advances (only if we actually deducted something and it's not walk-in)
      if (!_isWalkInCustomer && totalAdvanceToDeduct > 0 && _selectedFarmerId != null) {
        final farmerRef = FirebaseFirestore.instance.collection(AppConstants.farmersCollection).doc(_selectedFarmerId);
        batch.update(farmerRef, {
          'totalAdvances': FieldValue.increment(-totalAdvanceToDeduct),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // Send notification to branch users
      if (currentUser?.branchId != null) {
        NotificationService.instance.notifyPurchaseCreated(
          farmerName: customerName,
          netPayment: finalNetPayment,
          branchId: currentUser!.branchId!,
        );
      }

      if (mounted) {
        // Show success with receipt option
        _showSuccessWithReceipt(
          context,
          purchaseRef.id,
          totalAdvanceToDeduct,
          finalNetPayment,
          amountPaid > 0 ? amountPaid : finalNetPayment,
          _balance,
          paymentStatus,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: AppTheme.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'New Coffee Purchase',
          style: TextStyle(
            color: AppTheme.textDark,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(
            color: AppTheme.borderLight,
            height: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Section Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isWalkInCustomer ? 'Walk-in Customer' : 'Select Farmer',
                        style: TextStyle(
                          color: AppTheme.textDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        _isWalkInCustomer 
                            ? 'Customer without registration' 
                            : 'Choose the farmer for this purchase',
                        style: TextStyle(
                          color: AppTheme.textGrey,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  // Toggle button
                  InkWell(
                    onTap: () {
                      setState(() {
                        _isWalkInCustomer = !_isWalkInCustomer;
                        if (_isWalkInCustomer) {
                          // Clear farmer selection when switching to walk-in
                          _selectedFarmerId = null;
                          _selectedFarmerName = null;
                          _selectedFarmerPhone = null;
                          _advanceController.text = '0';
                        } else {
                          // Clear walk-in name when switching to farmer
                          _walkInNameController.clear();
                        }
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _isWalkInCustomer ? AppTheme.primaryGreen.withOpacity(0.1) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _isWalkInCustomer ? AppTheme.primaryGreen : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _isWalkInCustomer ? Icons.person : Icons.people,
                            size: 18,
                            color: _isWalkInCustomer ? AppTheme.primaryGreen : AppTheme.textGrey,
                          ),
                          SizedBox(width: 6),
                          Text(
                            _isWalkInCustomer ? 'Walk-in' : 'Farmer',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: _isWalkInCustomer ? AppTheme.primaryGreen : AppTheme.textGrey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12),
              
              // Farmer Selection Card OR Walk-in Name Field
              if (_isWalkInCustomer) ...[
                // Walk-in customer name field (optional)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: TextFormField(
                    controller: _walkInNameController,
                    style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.textDark,
                    ),
                    decoration: InputDecoration(
                      prefixIcon: Icon(Icons.person_outline, color: AppTheme.textGrey),
                      labelText: 'Customer Name (Optional)',
                      hintText: 'Leave blank for anonymous customer',
                      hintStyle: TextStyle(
                        color: AppTheme.textLight,
                        fontSize: 14,
                      ),
                      filled: true,
                      fillColor: AppTheme.backgroundLight,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    ),
                  ),
                ),
              ] else ...[
              // Farmer Selection Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Search field
                    TextField(
                      controller: _farmerSearchController,
                      style: TextStyle(
                        fontSize: 15,
                        color: AppTheme.textDark,
                      ),
                      decoration: InputDecoration(
                        prefixIcon: Icon(Icons.search, color: AppTheme.textGrey, size: 20),
                        hintText: 'Search farmer by name or phone',
                        hintStyle: TextStyle(
                          color: AppTheme.textLight,
                          fontSize: 14,
                        ),
                        filled: true,
                        fillColor: AppTheme.backgroundLight,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        suffixIcon: _farmerSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 18, color: AppTheme.textGrey),
                                onPressed: () {
                                  setState(() {
                                    _farmerSearchController.clear();
                                    _farmerSearchQuery = '';
                                  });
                                },
                              )
                            : null,
                      ),
                      onChanged: (value) {
                        setState(() {
                          _farmerSearchQuery = value.toLowerCase();
                        });
                      },
                    ),
                    
                    const SizedBox(height: 12),
                    
                    StreamBuilder<QuerySnapshot>(
                      stream: AuthService.instance
                          .applyBranchFilterToCollection(AppConstants.farmersCollection)
                          .where('isActive', isEqualTo: true)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (!snapshot.hasData) {
                          return Center(
                            child: Padding(
                              padding: EdgeInsets.all(20.0),
                              child: CircularProgressIndicator(
                                color: AppTheme.primaryGreen,
                                strokeWidth: 2,
                              ),
                            ),
                          );
                        }
                        
                        // Filter farmers based on search query
                        final allFarmers = snapshot.data!.docs;
                        final filteredFarmers = allFarmers.where((doc) {
                          if (_farmerSearchQuery.isEmpty) return true;
                          final data = doc.data() as Map<String, dynamic>;
                          final name = (data['name'] ?? '').toString().toLowerCase();
                          final phone = (data['phone'] ?? '').toString().toLowerCase();
                          return name.contains(_farmerSearchQuery) || 
                                 phone.contains(_farmerSearchQuery);
                        }).toList();
                        
                        if (filteredFarmers.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                              _farmerSearchQuery.isEmpty 
                                  ? 'No active farmers available'
                                  : 'No farmers found for "$_farmerSearchQuery"',
                              style: TextStyle(
                                color: AppTheme.textGrey,
                                fontSize: 14,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          );
                        }
                        
                        return DropdownButtonFormField<String>(
                          value: _selectedFarmerId,
                          style: TextStyle(
                            color: AppTheme.textDark,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                          dropdownColor: Colors.white,
                          decoration: InputDecoration(
                            prefixIcon: Icon(Icons.person_outline, color: AppTheme.textGrey),
                            labelText: 'Farmer *',
                            labelStyle: TextStyle(
                              color: AppTheme.textGrey,
                              fontSize: 14,
                            ),
                            filled: true,
                            fillColor: AppTheme.backgroundLight,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                          ),
                          items: filteredFarmers.map((doc) {
                            final data = doc.data() as Map<String, dynamic>;
                            final name = data['name'] ?? 'Unknown';
                            final phone = data['phone'] ?? '';
                            final displayName = name.length > 25 ? '${name.substring(0, 25)}...' : name;
                            return DropdownMenuItem(
                              value: doc.id,
                              child: Text(
                                displayName,
                                style: TextStyle(
                                  color: AppTheme.textDark,
                                  fontSize: 15,
                                ),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) async {
                            setState(() {
                              _selectedFarmerId = value;
                              final doc = filteredFarmers.firstWhere((d) => d.id == value);
                              final data = doc.data() as Map<String, dynamic>;
                              _selectedFarmerName = data['name'];
                              _selectedFarmerPhone = data['phone'] ?? '';
                            });
                            
                            // Auto-load farmer's total advances
                            await _loadFarmerAdvances(value!);
                          },
                          validator: (value) {
                            if (value == null) {
                              return 'Please select a farmer';
                            }
                            return null;
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              ], // Close else block for farmer selection

              const SizedBox(height: 24),

              // Purchase Details Section
              Text(
                'Purchase Details',
                style: TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Enter coffee weight and pricing information',
                style: TextStyle(
                  color: AppTheme.textGrey,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 12),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  children: [
                    _buildInputField(
                      controller: _grossWeightController,
                      label: 'Gross Weight (kg)',
                      icon: Icons.scale_outlined,
                      hint: 'e.g., 500',
                      required: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      onChanged: (value) => _calculateAmounts(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter gross weight';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    _buildInputField(
                      controller: _deductionController,
                      label: 'Deduction (kg)',
                      icon: Icons.remove_circle_outline,
                      hint: 'e.g., 10',
                      required: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      onChanged: (value) => _calculateAmounts(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter deduction';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    _buildInputField(
                      controller: _pricePerKgController,
                      label: 'Price per Kg (UGX)',
                      icon: Icons.attach_money_outlined,
                      hint: 'e.g., 8000',
                      required: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (value) => _calculateAmounts(),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter price per kg';
                        }
                        return null;
                      },
                    ),
                    
                    SizedBox(height: 16),
                    
                    _buildInputField(
                      controller: _millingChargePerKgController,
                      label: 'Milling Charge per Kg (UGX)',
                      icon: Icons.settings_outlined,
                      hint: '300',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (value) => _calculateAmounts(),
                    ),
                    
                    SizedBox(height: 16),
                    
                    _buildInputField(
                      controller: _advanceController,
                      label: 'Advance Amount (UGX)',
                      icon: Icons.payments_outlined,
                      hint: '0 - Leave blank for normal clients',
                      keyboardType: TextInputType.number,
                      helperText: 'Optional: Auto-loads if farmer has advances, or leave 0 for regular clients',
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (value) => _calculateAmounts(),
                      suffixIcon: _advanceController.text != '0' && _advanceController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.clear, size: 18, color: AppTheme.textGrey),
                              onPressed: () {
                                setState(() {
                                  _advanceController.text = '0';
                                });
                                _calculateAmounts();
                              },
                              tooltip: 'Clear advance',
                            )
                          : null,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),

              // NEW: Money Deductions Section
              Text(
                'Money Deductions (Optional)',
                style: TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Enter any additional deductions in money (UGX)',
                style: TextStyle(
                  color: AppTheme.textGrey,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 12),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  children: [
                    _buildInputField(
                      controller: _transportDeductionController,
                      label: 'Transport Deduction (UGX)',
                      icon: Icons.local_shipping_outlined,
                      hint: '0',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (value) => _calculateAmounts(),
                    ),
                    
                    SizedBox(height: 16),
                    
                    _buildInputField(
                      controller: _qualityDeductionController,
                      label: 'Quality Deduction (UGX)',
                      icon: Icons.star_border_outlined,
                      hint: '0',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (value) => _calculateAmounts(),
                    ),
                    
                    SizedBox(height: 16),
                    
                    _buildInputField(
                      controller: _otherDeductionController,
                      label: 'Other Deduction (UGX)',
                      icon: Icons.more_horiz,
                      hint: '0',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (value) => _calculateAmounts(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // NEW: Payment Section
              Text(
                'Payment Details',
                style: TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Enter amount paid if partial payment',
                style: TextStyle(
                  color: AppTheme.textGrey,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 12),
              
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  children: [
                    _buildInputField(
                      controller: _amountPaidController,
                      label: 'Amount Paid Now (UGX)',
                      icon: Icons.payments,
                      hint: 'Leave blank for full payment',
                      keyboardType: TextInputType.number,
                      helperText: 'Optional: Enter amount if partial payment, leave blank for full payment',
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (value) => _calculateAmounts(),
                    ),
                    
                    if (_balance > 0) ...[
                      SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Balance Due: UGX ${_balance.toStringAsFixed(0)}',
                                style: TextStyle(
                                  color: Colors.orange.shade900,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Calculation Summary
              Text(
                'Calculation Summary',
                style: TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Review the calculated amounts',
                style: TextStyle(
                  color: AppTheme.textGrey,
                  fontSize: 13,
                ),
              ),
              SizedBox(height: 12),
              
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryGreen.withOpacity(0.3), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryGreen.withOpacity(0.08),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSummaryRow('Payable Weight', '${_payableWeight.toStringAsFixed(2)} kg'),
                    Divider(height: 24, color: AppTheme.borderLight),
                    _buildSummaryRow('Total Amount', 'UGX ${_totalAmount.toStringAsFixed(0)}'),
                    Divider(height: 24, color: AppTheme.borderLight),
                    _buildSummaryRow('Milling Charge', '-UGX ${_millingCharge.toStringAsFixed(0)}'),
                    
                    // Show money deductions if any
                    if (double.tryParse(_transportDeductionController.text) != null && double.parse(_transportDeductionController.text) > 0) ...[
                      Divider(height: 24, color: AppTheme.borderLight),
                      _buildSummaryRow(
                        'Transport Deduction', 
                        '-UGX ${double.parse(_transportDeductionController.text).toStringAsFixed(0)}',
                      ),
                    ],
                    if (double.tryParse(_qualityDeductionController.text) != null && double.parse(_qualityDeductionController.text) > 0) ...[
                      Divider(height: 24, color: AppTheme.borderLight),
                      _buildSummaryRow(
                        'Quality Deduction', 
                        '-UGX ${double.parse(_qualityDeductionController.text).toStringAsFixed(0)}',
                      ),
                    ],
                    if (double.tryParse(_otherDeductionController.text) != null && double.parse(_otherDeductionController.text) > 0) ...[
                      Divider(height: 24, color: AppTheme.borderLight),
                      _buildSummaryRow(
                        'Other Deduction', 
                        '-UGX ${double.parse(_otherDeductionController.text).toStringAsFixed(0)}',
                      ),
                    ],
                    
                    if (double.tryParse(_advanceController.text) != null && double.parse(_advanceController.text) > 0) ...[
                      Divider(height: 24, color: AppTheme.borderLight),
                      _buildSummaryRow(
                        'Advance Deducted', 
                        '-UGX ${double.parse(_advanceController.text).toStringAsFixed(0)}',
                        isAdvance: true,
                      ),
                    ],
                    Divider(height: 24, thickness: 2, color: AppTheme.borderLight),
                    _buildSummaryRow('NET PAYMENT', 'UGX ${_netPayment.toStringAsFixed(0)}', isBold: true),
                    
                    // Show payment details if partial payment
                    if (_balance > 0) ...[
                      Divider(height: 24, color: AppTheme.borderLight),
                      _buildSummaryRow(
                        'Amount Paid', 
                        'UGX ${(double.tryParse(_amountPaidController.text) ?? 0).toStringAsFixed(0)}',
                      ),
                      Divider(height: 24, color: AppTheme.borderLight),
                      _buildSummaryRow(
                        'Balance Due', 
                        'UGX ${_balance.toStringAsFixed(0)}',
                        isAdvance: true,
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _savePurchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check_circle_outline, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Record Purchase',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool required = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    Function(String)? onChanged,
    String? Function(String?)? validator,
    String? helperText,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            if (required)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.errorRed,
                ),
              ),
          ],
        ),
        SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          validator: validator,
          style: TextStyle(
            fontSize: 15,
            color: AppTheme.textDark,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: AppTheme.textLight,
              fontSize: 15,
            ),
            prefixIcon: Icon(icon, color: AppTheme.textGrey, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppTheme.backgroundLight,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            helperText: helperText,
            helperStyle: TextStyle(
              color: AppTheme.primaryGreen,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }

  void _showSuccessWithReceipt(
    BuildContext context,
    String purchaseId,
    double totalAdvanceDeducted,
    double finalNetPayment,
    double amountPaid,
    double balance,
    String paymentStatus,
  ) {
    // Store last values for receipt
    _lastGrossWeight = double.parse(_grossWeightController.text);
    _lastDeduction = double.parse(_deductionController.text);
    _lastPricePerKg = double.parse(_pricePerKgController.text);
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check_circle, color: Colors.green, size: 36),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Text(
                'Purchase Recorded',
                style: TextStyle(
                  color: AppTheme.textDark,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (totalAdvanceDeducted > 0)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.accentOrange.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info, color: AppTheme.accentOrange, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'UGX ${totalAdvanceDeducted.toStringAsFixed(0)} deducted from advances',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textDark,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            const Text(
              'Would you like to print a receipt?',
              style: TextStyle(
                fontSize: 16,
                color: AppTheme.textDark,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              Future.delayed(const Duration(milliseconds: 100), () {
                if (context.mounted) {
                  Navigator.of(context).pop(); // Close purchase screen
                  // Show success on dashboard
                  Future.delayed(const Duration(milliseconds: 200), () {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Purchase recorded successfully!',
                                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 3),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  });
                }
              });
            },
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            child: const Text(
              'Later',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.of(context).pop(); // Close dialog
              await _printReceipt(purchaseId, finalNetPayment, totalAdvanceDeducted, amountPaid, balance, paymentStatus);
              await Future.delayed(const Duration(milliseconds: 100));
              if (context.mounted) {
                Navigator.of(context).pop(); // Close purchase screen
                // Show success on dashboard
                Future.delayed(const Duration(milliseconds: 200), () {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Receipt printed successfully!',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green,
                        duration: Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentOrange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              elevation: 2,
            ),
            icon: const Icon(Icons.print, size: 20),
            label: const Text(
              'Print Receipt',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      ),
    );
  }

  Future<void> _printReceipt(String purchaseId, double netPayment, double advanceDeducted, double amountPaid, double balance, String paymentStatus) async {
    try {
      final receiptNumber = '${AppConstants.purchasePrefix}${purchaseId.substring(0, 8).toUpperCase()}';
      final date = DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());
      final currentUser = AuthService.instance.currentUser;
      final deductionWeight = _lastGrossWeight * (_lastDeduction / 100);

      // Fetch branch location if user has a branch assigned
      String? branchLocation;
      if (currentUser?.branchId != null) {
        try {
          final branchDoc = await FirebaseFirestore.instance
              .collection('branches')
              .doc(currentUser!.branchId)
              .get();
          if (branchDoc.exists) {
            final branchData = branchDoc.data() as Map<String, dynamic>;
            branchLocation = branchData['location'] ?? branchData['address'];
          }
        } catch (e) {
          // Silently fail, will use default business location
          print('Error fetching branch location: $e');
        }
      }

      await ReceiptService.generatePurchaseReceipt(
        receiptNumber: receiptNumber,
        farmerName: _isWalkInCustomer 
            ? (_walkInNameController.text.trim().isEmpty 
                ? 'Walk-in Client' 
                : _walkInNameController.text.trim())
            : (_selectedFarmerName ?? 'Walk-in Client'),
        farmerPhone: _selectedFarmerPhone ?? '',
        grossWeight: _lastGrossWeight,
        deductionPercentage: _lastDeduction,
        deductionWeight: deductionWeight,
        payableWeight: _payableWeight,
        pricePerKg: _lastPricePerKg,
        millingCharge: _millingCharge,
        netPayment: netPayment,
        advanceDeducted: advanceDeducted,
        amountPaid: amountPaid,
        balance: balance,
        paymentStatus: paymentStatus,
        date: date,
        branchName: currentUser?.branchName,
        branchLocation: branchLocation,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Receipt error: $e'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
      }
    }
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false, bool isAdvance = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isAdvance ? Colors.orange.shade700 : AppTheme.textDark,
              fontSize: isBold ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: isAdvance ? Colors.orange.shade700 : AppTheme.textDark,
              fontSize: isBold ? 18 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
