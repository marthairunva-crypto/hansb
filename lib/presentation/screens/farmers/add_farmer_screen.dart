import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';

/// Modern Add New Farmer Screen - Multi-Step Form
class AddFarmerScreen extends StatefulWidget {
  const AddFarmerScreen({Key? key}) : super(key: key);

  @override
  State<AddFarmerScreen> createState() => _AddFarmerScreenState();
}

class _AddFarmerScreenState extends State<AddFarmerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _pageController = PageController();
  
  // Controllers
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _districtController = TextEditingController();
  final _subcountyController = TextEditingController();
  final _parishController = TextEditingController();
  final _villageController = TextEditingController();
  final _notesController = TextEditingController();
  
  int _currentStep = 0;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _districtController.dispose();
    _subcountyController.dispose();
    _parishController.dispose();
    _villageController.dispose();
    _notesController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep == 0) {
      // Validate basic info
      if (_nameController.text.trim().isEmpty || _phoneController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please fill in all required fields'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        return;
      }
    } else if (_currentStep == 1) {
      // Validate location - all 4 fields required
      if (_districtController.text.trim().isEmpty || 
          _subcountyController.text.trim().isEmpty ||
          _parishController.text.trim().isEmpty ||
          _villageController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please fill in all location fields (District, Subcounty, Parish, Village)'),
            backgroundColor: AppTheme.errorRed,
          ),
        );
        return;
      }
    }

    if (_currentStep < 2) {
      setState(() {
        _currentStep++;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.animateToPage(
        _currentStep,
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _saveFarmer() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final currentUser = AuthService.instance.currentUser;
      
      await FirebaseFirestore.instance.collection(AppConstants.farmersCollection).add({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'district': _districtController.text.trim(),
        'subcounty': _subcountyController.text.trim(),
        'parish': _parishController.text.trim(),
        'village': _villageController.text.trim(),
        'notes': _notesController.text.trim(),
        'isActive': true,
        'totalAdvances': 0.0,
        'branch_id': currentUser?.branchId,
        'branch_name': currentUser?.branchName,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Farmer added successfully'),
              ],
            ),
            backgroundColor: AppTheme.primaryGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.errorRed,
            behavior: SnackBarBehavior.floating,
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
          'Add New Farmer',
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
      body: Column(
        children: [
          // Progress Indicator
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Row(
              children: [
                _buildStepIndicator(0, 'Basic Info', Icons.person_outline),
                Expanded(child: _buildStepConnector(0)),
                _buildStepIndicator(1, 'Location', Icons.location_on_outlined),
                Expanded(child: _buildStepConnector(1)),
                _buildStepIndicator(2, 'Review', Icons.check_circle_outline),
              ],
            ),
          ),
          
          // Form Content
          Expanded(
            child: Form(
              key: _formKey,
              child: PageView(
                controller: _pageController,
                physics: NeverScrollableScrollPhysics(),
                children: [
                  _buildBasicInfoStep(),
                  _buildLocationStep(),
                  _buildReviewStep(),
                ],
              ),
            ),
          ),
          
          // Bottom Action Bar
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: SafeArea(
              child: Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _previousStep,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: AppTheme.borderLight, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Back',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textGrey,
                          ),
                        ),
                      ),
                    ),
                  if (_currentStep > 0) SizedBox(width: 12),
                  Expanded(
                    flex: _currentStep == 0 ? 1 : 2,
                    child: ElevatedButton(
                      onPressed: _isLoading
                          ? null
                          : (_currentStep == 2 ? _saveFarmer : _nextStep),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryGreen,
                        padding: EdgeInsets.symmetric(vertical: 16),
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
                                Text(
                                  _currentStep == 2 ? 'Add Farmer' : 'Next',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                                if (_currentStep < 2) ...[
                                  SizedBox(width: 8),
                                  Icon(Icons.arrow_forward, size: 18, color: Colors.white),
                                ],
                              ],
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator(int step, String label, IconData icon) {
    final isActive = _currentStep == step;
    final isCompleted = _currentStep > step;

    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isCompleted || isActive
                ? AppTheme.primaryGreen
                : AppTheme.backgroundLight,
            shape: BoxShape.circle,
            border: Border.all(
              color: isCompleted || isActive
                  ? AppTheme.primaryGreen
                  : AppTheme.borderLight,
              width: 2,
            ),
          ),
          child: Icon(
            isCompleted ? Icons.check : icon,
            color: isCompleted || isActive ? Colors.white : AppTheme.textLight,
            size: 20,
          ),
        ),
        SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
            color: isActive ? AppTheme.primaryGreen : AppTheme.textLight,
          ),
        ),
      ],
    );
  }

  Widget _buildStepConnector(int step) {
    final isCompleted = _currentStep > step;
    return Container(
      height: 2,
      margin: EdgeInsets.only(bottom: 18),
      decoration: BoxDecoration(
        color: isCompleted ? AppTheme.primaryGreen : AppTheme.borderLight,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildBasicInfoStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Basic Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Enter the farmer\'s personal details',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textGrey,
            ),
          ),
          SizedBox(height: 24),
          
          // Name Field
          _buildTextField(
            controller: _nameController,
            label: 'Full Name',
            icon: Icons.person_outline,
            hint: 'e.g., John Ssemwanga',
            required: true,
          ),
          
          SizedBox(height: 20),
          
          // Phone Field
          _buildTextField(
            controller: _phoneController,
            label: 'Phone Number',
            icon: Icons.phone_outlined,
            hint: '0700 XXX XXX',
            keyboardType: TextInputType.phone,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d\s+]')),
              LengthLimitingTextInputFormatter(15),
            ],
            required: true,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Location Details',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Enter complete location hierarchy',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textGrey,
            ),
          ),
          SizedBox(height: 24),
          
          // District Field
          _buildTextField(
            controller: _districtController,
            label: 'District',
            icon: Icons.location_city_outlined,
            hint: 'e.g., Wakiso',
            required: true,
          ),
          
          SizedBox(height: 20),
          
          // Subcounty Field
          _buildTextField(
            controller: _subcountyController,
            label: 'Subcounty',
            icon: Icons.map_outlined,
            hint: 'e.g., Nansana',
            required: true,
          ),
          
          SizedBox(height: 20),
          
          // Parish Field
          _buildTextField(
            controller: _parishController,
            label: 'Parish',
            icon: Icons.place_outlined,
            hint: 'e.g., Nabweru',
            required: true,
          ),
          
          SizedBox(height: 20),
          
          // Village Field
          _buildTextField(
            controller: _villageController,
            label: 'Village',
            icon: Icons.home_outlined,
            hint: 'e.g., Kyengera',
            required: true,
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Review & Confirm',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.textDark,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please review the information before adding',
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textGrey,
            ),
          ),
          SizedBox(height: 24),
          
          // Review Card
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              children: [
                _buildReviewItem(
                  Icons.person_outline,
                  'Full Name',
                  _nameController.text.trim().isEmpty
                      ? 'Not provided'
                      : _nameController.text.trim(),
                ),
                Divider(height: 32, color: AppTheme.borderLight),
                _buildReviewItem(
                  Icons.phone_outlined,
                  'Phone Number',
                  _phoneController.text.trim().isEmpty
                      ? 'Not provided'
                      : _phoneController.text.trim(),
                ),
                Divider(height: 32, color: AppTheme.borderLight),
                _buildReviewItem(
                  Icons.location_city_outlined,
                  'District',
                  _districtController.text.trim().isEmpty
                      ? 'Not provided'
                      : _districtController.text.trim(),
                ),
                Divider(height: 32, color: AppTheme.borderLight),
                _buildReviewItem(
                  Icons.map_outlined,
                  'Subcounty',
                  _subcountyController.text.trim().isEmpty
                      ? 'Not provided'
                      : _subcountyController.text.trim(),
                ),
                Divider(height: 32, color: AppTheme.borderLight),
                _buildReviewItem(
                  Icons.place_outlined,
                  'Parish',
                  _parishController.text.trim().isEmpty
                      ? 'Not provided'
                      : _parishController.text.trim(),
                ),
                Divider(height: 32, color: AppTheme.borderLight),
                _buildReviewItem(
                  Icons.home_outlined,
                  'Village',
                  _villageController.text.trim().isEmpty
                      ? 'Not provided'
                      : _villageController.text.trim(),
                ),
              ],
            ),
          ),
          
          SizedBox(height: 24),
          
          // Notes Field (Optional)
          _buildTextField(
            controller: _notesController,
            label: 'Additional Notes (Optional)',
            icon: Icons.note_outlined,
            hint: 'Any additional information about the farmer...',
            maxLines: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool required = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textDark,
              ),
            ),
            if (required)
              Text(
                ' *',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.errorRed,
                ),
              ),
          ],
        ),
        SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderLight),
          ),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLines: maxLines,
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
              prefixIcon: Icon(icon, color: AppTheme.textGrey, size: 22),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primaryGreen.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.primaryGreen, size: 20),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.textGrey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 15,
                  color: AppTheme.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
