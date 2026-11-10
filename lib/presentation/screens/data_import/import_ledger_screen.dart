import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:excel/excel.dart';
import '../home/dashboard_home_new.dart' show DashPalette;

/// Specialized importer for advance ledger format
/// Handles multiple advances per farmer in ledger layout
class ImportLedgerScreen extends StatefulWidget {
  const ImportLedgerScreen({Key? key}) : super(key: key);

  @override
  State<ImportLedgerScreen> createState() => _ImportLedgerScreenState();
}

class _ImportLedgerScreenState extends State<ImportLedgerScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String? _selectedBranchId;
  String? _selectedBranchName;
  List<Map<String, dynamic>> _parsedAdvances = [];
  List<String> _errors = [];
  int _importedCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Import Advance Ledger'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInfoCard(),
                const SizedBox(height: 24),
                _buildBranchSelector(),
                const SizedBox(height: 24),
                _buildFilePickerSection(),
                if (_parsedAdvances.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildPreviewSection(),
                ],
                if (_errors.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildErrorsSection(),
                ],
                if (_importedCount > 0) ...[
                  const SizedBox(height: 24),
                  _buildSuccessMessage(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue[700], size: 24),
                const SizedBox(width: 12),
                const Text(
                  'Advance Ledger Format',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'This tool imports your advance ledger Excel file automatically.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your Excel should have columns like:',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            _buildBullet('Column with farmer names'),
            _buildBullet('Column with dates (can be multiple dates per farmer)'),
            _buildBullet('Column with advance amounts'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.green[700]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'The tool will automatically detect and parse your ledger format!',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(fontSize: 16)),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
        ],
      ),
    );
  }

  Widget _buildBranchSelector() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select Branch',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('branches').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const CircularProgressIndicator();
                }
                final branches = snapshot.data!.docs;
                return DropdownButtonFormField<String>(
                  value: _selectedBranchId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  hint: const Text('Choose a branch'),
                  items: branches.map((doc) {
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text(doc['name'] ?? 'Unknown'),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedBranchId = value;
                      _selectedBranchName = branches
                          .firstWhere((doc) => doc.id == value)['name'];
                    });
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilePickerSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Upload Ledger File',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _selectedBranchId == null ? null : _pickFile,
              child: Container(
                padding: const EdgeInsets.all(40),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _selectedBranchId == null
                        ? Colors.grey[300]!
                        : const Color(0xFF2E7D32),
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: _selectedBranchId == null
                      ? Colors.grey[100]
                      : const Color(0xFF2E7D32).withOpacity(0.05),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 64,
                      color: _selectedBranchId == null
                          ? Colors.grey[400]
                          : const Color(0xFF2E7D32),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _selectedBranchId == null
                          ? 'Select a branch first'
                          : 'Click to select Excel file',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _selectedBranchId == null
                            ? Colors.grey[600]
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Preview (${_parsedAdvances.length} advances)',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                if (!_isLoading)
                  ElevatedButton.icon(
                    onPressed: _importData,
                    icon: const Icon(Icons.upload),
                    label: const Text('Import All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: CircularProgressIndicator(),
                ),
              )
            else
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateProperty.all(
                    const Color(0xFF2E7D32).withOpacity(0.1),
                  ),
                  columns: const [
                    DataColumn(label: Text('Farmer')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Date')),
                  ],
                  rows: _parsedAdvances.take(20).map((adv) {
                    return DataRow(
                      cells: [
                        DataCell(Text(adv['farmerName'] ?? '')),
                        DataCell(Text(
                          NumberFormat('#,##0').format(adv['amount'] ?? 0),
                        )),
                        DataCell(Text(
                          adv['date'] != null
                              ? DateFormat('dd/MM/yyyy').format(adv['date'])
                              : '-',
                        )),
                      ],
                    );
                  }).toList(),
                ),
              ),
            if (_parsedAdvances.length > 20)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '... and ${_parsedAdvances.length - 20} more advances',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorsSection() {
    return Card(
      color: Colors.red[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red[700]),
                const SizedBox(width: 12),
                const Text(
                  'Errors',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._errors.take(10).map((error) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text('• $error',
                      style: TextStyle(fontSize: 13, color: Colors.red[900])),
                )),
            if (_errors.length > 10)
              Text(
                '... and ${_errors.length - 10} more errors',
                style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: Colors.green[700], size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Import Successful!',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Successfully imported $_importedCount advances to $_selectedBranchName',
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        await _parseLedgerExcel(bytes);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  Future<void> _parseLedgerExcel(List<int> bytes) async {
    setState(() {
      _parsedAdvances = [];
      _errors = [];
      _importedCount = 0;
    });

    try {
      final excel = Excel.decodeBytes(bytes);
      final sheet = excel.tables[excel.tables.keys.first];
      
      if (sheet == null) {
        setState(() {
          _errors.add('No data found in Excel file');
        });
        return;
      }

      String? currentFarmer;
      int rowNum = 0;

      for (final row in sheet.rows) {
        rowNum++;
        
        // Skip empty rows and header rows
        if (row.isEmpty || row.every((cell) => cell?.value == null)) continue;
        
        // Try to find farmer name (usually in first non-empty cell)
        String? farmerName;
        DateTime? date;
        double? amount;

        for (var i = 0; i < row.length; i++) {
          final cellValue = row[i]?.value;
          if (cellValue == null) continue;

          final cellText = cellValue.toString().trim();
          
          // Skip totals and balance rows
          if (cellText.toUpperCase().contains('TOTAL') ||
              cellText.toUpperCase().contains('BALANCE') ||
              cellText.toUpperCase().contains('ADVANCE LEDGER') ||
              cellText.toUpperCase().contains('RECOVERY') ||
              cellText.toUpperCase().contains('PAYMENTS')) {
            break;
          }

          // Check if it's a farmer name (starts with letter, not a number or date)
          if (farmerName == null && 
              cellText.isNotEmpty &&
              !cellText.startsWith(RegExp(r'[\d\$\[]')) &&
              cellText.length > 3 &&
              !cellText.contains('/')) {
            farmerName = cellText;
            currentFarmer = farmerName;
            continue;
          }

          // Check if it's a date (contains /)
          if (date == null && cellText.contains('/')) {
            try {
              final parts = cellText.replaceAll('//', '/').split('/');
              if (parts.length >= 2) {
                int day = int.parse(parts[0]);
                int month = int.parse(parts[1]);
                int year = parts.length > 2 
                    ? int.parse(parts[2])
                    : DateTime.now().year;
                
                // Handle 2-digit years
                if (year < 100) {
                  year += 2000;
                }
                
                date = DateTime(year, month, day);
              }
            } catch (e) {
              // Skip invalid dates
            }
            continue;
          }

          // Check if it's an amount (contains number or currency symbol)
          if (amount == null) {
            try {
              // Remove currency symbols and commas
              String cleanAmount = cellText
                  .replaceAll(RegExp(r'[\$\[\]UGX,\s]'), '')
                  .trim();
              
              if (cleanAmount.isNotEmpty) {
                amount = double.tryParse(cleanAmount);
              }
            } catch (e) {
              // Skip invalid amounts
            }
          }
        }

        // If we have date and amount, create an advance record
        if (date != null && amount != null && amount > 0) {
          final farmer = farmerName ?? currentFarmer;
          
          if (farmer != null && farmer.isNotEmpty) {
            _parsedAdvances.add({
              'farmerName': farmer,
              'amount': amount,
              'date': date,
            });
          }
        }
      }

      if (_parsedAdvances.isEmpty) {
        _errors.add('No valid advances found in file');
      }

      setState(() {});
    } catch (e) {
      setState(() {
        _errors.add('Error parsing Excel: $e');
      });
    }
  }

  Future<void> _importData() async {
    if (_selectedBranchId == null || _parsedAdvances.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errors = [];
      _importedCount = 0;
    });

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _errors.add('Not logged in');
        _isLoading = false;
      });
      return;
    }

    // Get all farmers from this branch
    final farmersSnapshot = await _firestore
        .collection('farmers')
        .where('branchId', isEqualTo: _selectedBranchId)
        .get();

    final farmersByName = <String, String>{};
    for (var doc in farmersSnapshot.docs) {
      final name = (doc.data()['name'] ?? '').toString().toLowerCase().trim();
      farmersByName[name] = doc.id;
    }

    try {
      for (var adv in _parsedAdvances) {
        final farmerName = adv['farmerName'].toString().toLowerCase().trim();
        
        final farmerId = farmersByName[farmerName];
        if (farmerId == null) {
          _errors.add('Farmer "${adv['farmerName']}" not found');
          continue;
        }

        // Create advance record
        await _firestore.collection('advances').add({
          'farmerId': farmerId,
          'farmerName': adv['farmerName'],
          'branchId': _selectedBranchId,
          'branchName': _selectedBranchName,
          'amount': adv['amount'],
          'balance': adv['amount'],
          'date': adv['date'],
          'notes': 'Imported from ledger',
          'isActive': true,
          'createdBy': currentUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update farmer's advance balance
        final farmerDoc = _firestore.collection('farmers').doc(farmerId);
        await _firestore.runTransaction((transaction) async {
          final farmerSnapshot = await transaction.get(farmerDoc);
          if (farmerSnapshot.exists) {
            final currentAdvance = (farmerSnapshot.data()?['advanceBalance'] ?? 0.0);
            transaction.update(farmerDoc, {
              'advanceBalance': currentAdvance + adv['amount'],
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        });

        _importedCount++;
      }

      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully imported $_importedCount advances'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errors.add('Import error: $e');
        _isLoading = false;
      });
    }
  }
}
