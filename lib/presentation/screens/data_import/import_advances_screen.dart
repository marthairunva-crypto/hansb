import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

class ImportAdvancesScreen extends StatefulWidget {
  const ImportAdvancesScreen({Key? key}) : super(key: key);

  @override
  State<ImportAdvancesScreen> createState() => _ImportAdvancesScreenState();
}

class _ImportAdvancesScreenState extends State<ImportAdvancesScreen> {
  final _firestore = FirebaseFirestore.instance;
  bool _isLoading = false;
  String? _selectedBranchId;
  String? _selectedBranchName;
  List<Map<String, dynamic>> _parsedData = [];
  List<String> _errors = [];
  int _importedCount = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Import Previous Advances'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 800),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInfoCard(),
                const SizedBox(height: 24),
                _buildBranchSelector(),
                const SizedBox(height: 24),
                _buildFilePickerSection(),
                if (_parsedData.isNotEmpty) ...[
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
                  'CSV Format Instructions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Your file should have the following columns (in order):',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            _buildFormatRow('1', 'Farmer Name', 'e.g., John Doe'),
            _buildFormatRow('2', 'Farmer Phone', 'e.g., 0700123456 (optional)'),
            _buildFormatRow('3', 'Amount', 'e.g., 50000'),
            _buildFormatRow('4', 'Date', 'e.g., 2024-01-15 or 15/01/2024'),
            _buildFormatRow('5', 'Notes', 'e.g., Seed advance (optional)'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.amber[800]),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Make sure farmers exist in the system before importing advances. Unknown farmers will be skipped.',
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

  Widget _buildFormatRow(String num, String label, String example) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              num,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  example,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
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
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
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
              'Upload File',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
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
                    strokeAlign: BorderSide.strokeAlignInside,
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
                          : 'Click to select CSV file',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _selectedBranchId == null
                            ? Colors.grey[600]
                            : const Color(0xFF2E7D32),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Supported formats: Excel (.xlsx) or CSV (.csv)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
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
                  'Preview (${_parsedData.length} records)',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
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
                    DataColumn(label: Text('Phone')),
                    DataColumn(label: Text('Amount')),
                    DataColumn(label: Text('Date')),
                    DataColumn(label: Text('Notes')),
                  ],
                  rows: _parsedData.take(10).map((row) {
                    return DataRow(
                      cells: [
                        DataCell(Text(row['farmerName'] ?? '')),
                        DataCell(Text(row['phone'] ?? '-')),
                        DataCell(Text(
                          NumberFormat('#,##0').format(row['amount'] ?? 0),
                        )),
                        DataCell(Text(
                          row['date'] != null
                              ? DateFormat('dd/MM/yyyy').format(row['date'])
                              : '-',
                        )),
                        DataCell(Text(row['notes'] ?? '-')),
                      ],
                    );
                  }).toList(),
                ),
              ),
            if (_parsedData.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '... and ${_parsedData.length - 10} more records',
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ..._errors.map((error) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '• $error',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red[900],
                    ),
                  ),
                )),
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
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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
        allowedExtensions: ['csv', 'xlsx'],
      );

      if (result != null && result.files.single.bytes != null) {
        final bytes = result.files.single.bytes!;
        final extension = result.files.single.extension?.toLowerCase();
        
        if (extension == 'xlsx') {
          await _parseExcel(bytes);
        } else {
          final csvString = utf8.decode(bytes);
          await _parseCSV(csvString);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  Future<void> _parseExcel(List<int> bytes) async {
    setState(() {
      _parsedData = [];
      _errors = [];
      _importedCount = 0;
    });

    try {
      final excel = Excel.decodeBytes(bytes);
      
      // Get first sheet
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null) {
        setState(() {
          _errors.add('No data found in Excel file');
        });
        return;
      }

      // Skip header row (first row)
      final dataRows = sheet.rows.skip(1);

      for (var i = 0; i < dataRows.length; i++) {
        final row = dataRows.elementAt(i);
        
        if (row.isEmpty || row.length < 3) {
          _errors.add('Row ${i + 2}: Not enough columns');
          continue;
        }

        try {
          final farmerName = row[0]?.value?.toString().trim() ?? '';
          final phone = row.length > 1 ? (row[1]?.value?.toString().trim() ?? '') : '';
          final amountStr = row.length > 2 ? (row[2]?.value?.toString().trim() ?? '0') : '0';
          final dateValue = row.length > 3 ? row[3]?.value : null;
          final notes = row.length > 4 ? (row[4]?.value?.toString().trim() ?? '') : '';

          if (farmerName.isEmpty) {
            continue; // Skip empty rows
          }

          // Parse amount
          double amount = 0;
          try {
            amount = double.parse(amountStr.replaceAll(',', ''));
          } catch (e) {
            _errors.add('Row ${i + 2}: Invalid amount "$amountStr"');
            continue;
          }

          // Parse date
          DateTime? date;
          if (dateValue != null) {
            try {
              if (dateValue is DateTime) {
                date = dateValue;
              } else if (dateValue is DateCellValue) {
                date = DateTime(
                  dateValue.year,
                  dateValue.month,
                  dateValue.day,
                );
              } else {
                final dateStr = dateValue.toString();
                if (dateStr.contains('-')) {
                  date = DateTime.parse(dateStr);
                } else if (dateStr.contains('/')) {
                  final parts = dateStr.split('/');
                  if (parts.length == 3) {
                    date = DateTime(
                      int.parse(parts[2]),
                      int.parse(parts[1]),
                      int.parse(parts[0]),
                    );
                  }
                }
              }
            } catch (e) {
              _errors.add('Row ${i + 2}: Invalid date format');
            }
          }

          _parsedData.add({
            'farmerName': farmerName,
            'phone': phone.isEmpty ? null : phone,
            'amount': amount,
            'date': date,
            'notes': notes.isEmpty ? null : notes,
          });
        } catch (e) {
          _errors.add('Row ${i + 2}: Error parsing - $e');
        }
      }

      setState(() {});
    } catch (e) {
      setState(() {
        _errors.add('Error parsing Excel: $e');
      });
    }
  }

  Future<void> _parseCSV(String csvString) async {
    setState(() {
      _parsedData = [];
      _errors = [];
      _importedCount = 0;
    });

    try {
      final rows = const CsvToListConverter().convert(csvString);
      
      // Skip header row if it exists
      final dataRows = rows.length > 0 && rows[0][0].toString().toLowerCase().contains('name')
          ? rows.skip(1)
          : rows;

      for (var i = 0; i < dataRows.length; i++) {
        final row = dataRows.elementAt(i);
        
        if (row.length < 3) {
          _errors.add('Row ${i + 1}: Not enough columns');
          continue;
        }

        try {
          final farmerName = row[0].toString().trim();
          final phone = row.length > 1 ? row[1].toString().trim() : '';
          final amountStr = row.length > 2 ? row[2].toString().trim() : '0';
          final dateStr = row.length > 3 ? row[3].toString().trim() : '';
          final notes = row.length > 4 ? row[4].toString().trim() : '';

          // Parse amount
          double amount = 0;
          try {
            amount = double.parse(amountStr.replaceAll(',', ''));
          } catch (e) {
            _errors.add('Row ${i + 1}: Invalid amount "$amountStr"');
            continue;
          }

          // Parse date
          DateTime? date;
          if (dateStr.isNotEmpty) {
            try {
              // Try multiple date formats
              if (dateStr.contains('-')) {
                date = DateTime.parse(dateStr);
              } else if (dateStr.contains('/')) {
                final parts = dateStr.split('/');
                if (parts.length == 3) {
                  date = DateTime(
                    int.parse(parts[2]),
                    int.parse(parts[1]),
                    int.parse(parts[0]),
                  );
                }
              }
            } catch (e) {
              _errors.add('Row ${i + 1}: Invalid date format "$dateStr"');
            }
          }

          _parsedData.add({
            'farmerName': farmerName,
            'phone': phone.isEmpty ? null : phone,
            'amount': amount,
            'date': date,
            'notes': notes.isEmpty ? null : notes,
          });
        } catch (e) {
          _errors.add('Row ${i + 1}: Error parsing - $e');
        }
      }

      setState(() {});
    } catch (e) {
      setState(() {
        _errors.add('Error parsing CSV: $e');
      });
    }
  }

  Future<void> _importData() async {
    if (_selectedBranchId == null || _parsedData.isEmpty) return;

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
      for (var i = 0; i < _parsedData.length; i++) {
        final row = _parsedData[i];
        final farmerName = row['farmerName'].toString().toLowerCase().trim();
        
        final farmerId = farmersByName[farmerName];
        if (farmerId == null) {
          _errors.add('Farmer "${row['farmerName']}" not found in $_selectedBranchName');
          continue;
        }

        // Create advance record
        await _firestore.collection('advances').add({
          'farmerId': farmerId,
          'farmerName': row['farmerName'],
          'branchId': _selectedBranchId,
          'branchName': _selectedBranchName,
          'amount': row['amount'],
          'balance': row['amount'], // Initial balance equals amount
          'date': row['date'] ?? DateTime.now(),
          'notes': row['notes'] ?? '',
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
              'advanceBalance': currentAdvance + row['amount'],
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
