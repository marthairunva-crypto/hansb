import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:csv/csv.dart';
// excel exports its own Border / BorderStyle / TextSpan, which clash with Flutter's.
import 'package:excel/excel.dart' hide Border, BorderStyle, TextSpan;
import '../../../core/services/auth_service.dart';

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
  int _createdFarmers = 0;

  /// Your ledger's Excel date cells have day and month swapped
  /// (e.g. 11 Sept was stored as 9 Nov). This corrects them while parsing.
  bool _swapExcelDayMonth = false; // default: dates exactly as Excel shows them

  /// Create farmers that are not found in the selected branch.
  bool _createMissingFarmers = true;

  /// Name of the file the user picked (shown in the upload box).
  String? _fileName;
  int _progress = 0;

  void _showDialog(String title, String message, {bool isError = false}) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              color: isError ? Colors.red[700] : Colors.green[700],
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Design tokens
  // ---------------------------------------------------------------------------

  static const _green = Color(0xFF2E7D32);
  static const _ink = Color(0xFF1F2937);
  static const _muted = Color(0xFF6B7280);
  static const _line = Color(0xFFE5E7EB);
  static const _bad = Color(0xFFC62828);
  static const _info = Color(0xFF1565C0);

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      );

  final _money = NumberFormat('#,##0');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        title: const Text('Import Previous Advances'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 1000;

        final left = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildBranchCard(),
            const SizedBox(height: 20),
            _buildUploadCard(),
            const SizedBox(height: 20),
            _buildFormatCard(),
          ],
        );

        final right = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_importedCount > 0 && !_isLoading) ...[
              _buildSuccessMessage(),
              const SizedBox(height: 20),
            ],
            if (_errors.isNotEmpty) ...[
              _buildMessagesCard(),
              const SizedBox(height: 20),
            ],
            if (_parsedData.isNotEmpty)
              _buildPreviewCard()
            else
              _buildEmptyState(),
          ],
        );

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 48),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1600),
              child: wide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: 400, child: left),
                        const SizedBox(width: 24),
                        Expanded(child: right),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [left, const SizedBox(height: 20), right],
                    ),
            ),
          ),
        );
      }),
    );
  }

  // ---------------------------------------------------------------------------
  // Reusable pieces
  // ---------------------------------------------------------------------------

  Widget _stepCard({
    String? step,
    IconData? icon,
    required String title,
    String? subtitle,
    Widget? trailing,
    bool done = false,
    required Widget child,
  }) {
    final Widget badgeChild;
    if (done) {
      badgeChild = const Icon(Icons.check, size: 16, color: Colors.white);
    } else if (step != null) {
      badgeChild = Text(step,
          style: const TextStyle(
              color: _green, fontWeight: FontWeight.w700, fontSize: 13));
    } else {
      badgeChild = Icon(icon ?? Icons.circle, size: 16, color: _green);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: done ? _green : _green.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: badgeChild,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: _ink)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12.5, color: _muted, height: 1.35)),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing,
              ],
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _kpi({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      width: 230,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(fontSize: 12, color: _muted)),
                const SizedBox(height: 2),
                Text(value,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _ink)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Left column: branch, upload, format guide
  // ---------------------------------------------------------------------------

  Widget _buildBranchCard() {
    return _stepCard(
      step: '1',
      title: 'Select branch',
      subtitle: 'Advances are imported into this branch',
      done: _selectedBranchId != null,
      child: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('branches').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
              ),
            );
          }
          final branches = snapshot.data!.docs;
          String label(QueryDocumentSnapshot doc) {
            final d = doc.data() as Map<String, dynamic>;
            return (d['branch_name'] ?? d['name'] ?? 'Unknown').toString();
          }

          return DropdownButtonFormField<String>(
            value: _selectedBranchId,
            isExpanded: true,
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              prefixIcon: const Icon(Icons.store_outlined, size: 20),
            ),
            hint: const Text('Choose a branch'),
            items: branches
                .map((doc) => DropdownMenuItem(
                      value: doc.id,
                      child: Text(label(doc)),
                    ))
                .toList(),
            onChanged: (value) {
              final selected = branches.firstWhere((doc) => doc.id == value);
              setState(() {
                _selectedBranchId = value;
                _selectedBranchName = label(selected);
              });
            },
          );
        },
      ),
    );
  }

  Widget _buildUploadCard() {
    final enabled = _selectedBranchId != null && !_isLoading;
    final hasFile = _fileName != null;

    final String title = _selectedBranchId == null
        ? 'Select a branch first'
        : (hasFile ? _fileName! : 'Choose Excel or CSV file');
    final String sub = _selectedBranchId == null
        ? 'Pick the branch in step 1 to unlock the upload'
        : (hasFile
            ? 'Click to replace the file'
            : 'Click to browse · .xlsx or .csv');

    return _stepCard(
      step: '2',
      title: 'Upload file',
      subtitle: 'Excel ledger (.xlsx) or a simple CSV',
      done: hasFile && _parsedData.isNotEmpty,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: enabled ? _pickFile : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              decoration: BoxDecoration(
                color: enabled
                    ? _green.withOpacity(0.04)
                    : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: enabled ? _green.withOpacity(0.5) : _line,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    hasFile ? Icons.description_outlined : Icons.upload_file,
                    size: 34,
                    color: enabled ? _green : Colors.grey[400],
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: enabled ? _green : _muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(sub,
                            style: const TextStyle(
                                fontSize: 12.5, color: _muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _line),
            ),
            child: Row(
              children: [
                Switch(
                  value: _swapExcelDayMonth,
                  activeColor: _green,
                  onChanged: (v) => setState(() => _swapExcelDayMonth = v),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Swap day/month in Excel date cells',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: _ink)),
                      SizedBox(height: 2),
                      Text(
                        'OFF (default): dates are imported exactly as Excel shows '
                        'them. Applies when you pick the file.',
                        style: TextStyle(
                            fontSize: 12, color: _muted, height: 1.35),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatCard() {
    Widget col(String n, String label, String example) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _green,
                borderRadius: BorderRadius.circular(5),
              ),
              child: Text(n,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _ink)),
                  Text(example,
                      style: const TextStyle(fontSize: 12, color: _muted)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return _stepCard(
      icon: Icons.info_outline,
      title: 'File format',
      subtitle: 'Simple CSV / Excel columns, in this order',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          col('1', 'Farmer name', 'e.g. John Doe'),
          col('2', 'Farmer phone', 'e.g. 0700123456 (optional)'),
          col('3', 'Amount', 'e.g. 50000'),
          col('4', 'Date', 'e.g. 2024-01-15 or 15/01/2024'),
          col('5', 'Notes', 'e.g. Seed advance (optional)'),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _info.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _info.withOpacity(0.25)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.auto_awesome, size: 18, color: _info),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Ledger-style Excel files (NAME / DATE / ADVANCE AMOUNT / '
                    'RECOVERY) are detected automatically, so you can upload '
                    'them as they are.',
                    style: TextStyle(fontSize: 12.5, color: _ink, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Right column: empty state, preview, messages, success
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 72),
      decoration: _cardDecoration,
      child: Column(
        children: [
          Icon(Icons.table_view_outlined, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No file loaded yet',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 6),
          const Text(
            'Choose a branch and upload your file. A preview of every advance '
            'appears here for you to check before anything is saved.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _muted, height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard() {
    final total = _parsedData.fold<double>(
        0, (s, r) => s + ((r['amount'] as num?)?.toDouble() ?? 0));
    final farmers = _parsedData
        .map((r) => _normName(r['farmerName'].toString()))
        .toSet()
        .length;
    final noDate = _parsedData.where((r) => r['date'] == null).length;

    return _stepCard(
      step: '3',
      title: 'Review & import',
      subtitle: 'Check the numbers against your file, then import',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _kpi(
                icon: Icons.receipt_long_outlined,
                label: 'Advances',
                value: '${_parsedData.length}',
                color: _info,
              ),
              _kpi(
                icon: Icons.groups_outlined,
                label: 'Farmers',
                value: '$farmers',
                color: _info,
              ),
              _kpi(
                icon: Icons.payments_outlined,
                label: 'Total amount',
                value: 'UGX ${_money.format(total)}',
                color: _green,
              ),
              if (noDate > 0)
                _kpi(
                  icon: Icons.event_busy_outlined,
                  label: 'No date (today used)',
                  value: '$noDate',
                  color: const Color(0xFFB26A00),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(8, 6, 16, 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _line),
            ),
            child: Row(
              children: [
                Switch(
                  value: _createMissingFarmers,
                  activeColor: _green,
                  onChanged: _isLoading
                      ? null
                      : (v) => setState(() => _createMissingFarmers = v),
                ),
                const SizedBox(width: 6),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Create missing farmers',
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: _ink)),
                      SizedBox(height: 2),
                      Text(
                        'Farmers not found in this branch are created '
                        'automatically. Turn off to skip them instead.',
                        style: TextStyle(
                            fontSize: 12, color: _muted, height: 1.35),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                if (_isLoading)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                      const SizedBox(width: 12),
                      Text('Importing $_progress of ${_parsedData.length}…',
                          style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                              color: _ink)),
                    ],
                  )
                else
                  ElevatedButton.icon(
                    onPressed: _importData,
                    icon: const Icon(Icons.upload, size: 20),
                    label: Text('Import ${_parsedData.length} advances'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _line),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 520),
                child: SingleChildScrollView(
                  child: LayoutBuilder(
                    builder: (context, c) => SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: c.maxWidth),
                        child: DataTable(
                          columnSpacing: 28,
                          headingRowColor: MaterialStateProperty.all(
                            const Color(0xFFF3F4F6),
                          ),
                          headingTextStyle: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: _muted,
                          ),
                          columns: const [
                            DataColumn(label: Text('#')),
                            DataColumn(label: Text('FARMER')),
                            DataColumn(label: Text('PHONE')),
                            DataColumn(label: Text('AMOUNT'), numeric: true),
                            DataColumn(label: Text('DATE')),
                            DataColumn(label: Text('NOTES')),
                          ],
                          rows: [
                            for (var i = 0; i < _parsedData.length; i++)
                              _buildDataRow(i, _parsedData[i]),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  DataRow _buildDataRow(int index, Map<String, dynamic> row) {
    final DateTime? date = row['date'] as DateTime?;
    final amount = (row['amount'] as num?) ?? 0;
    const cellStyle = TextStyle(fontSize: 13.5, color: _ink);

    return DataRow(
      cells: [
        DataCell(Text('${index + 1}',
            style: const TextStyle(fontSize: 13, color: _muted))),
        DataCell(ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text((row['farmerName'] ?? '').toString(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13.5, color: _ink)),
        )),
        DataCell(Text((row['phone'] ?? '–').toString(), style: cellStyle)),
        DataCell(Text(_money.format(amount), style: cellStyle)),
        DataCell(Text(date != null ? _dateFmt.format(date) : '–',
            style: TextStyle(
                fontSize: 13.5,
                color: date == null ? const Color(0xFFB26A00) : _ink))),
        DataCell(ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Text((row['notes'] ?? '–').toString(),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13, color: _muted)),
        )),
      ],
    );
  }

  Widget _buildMessagesCard() {
    final hasData = _parsedData.isNotEmpty;
    final color = hasData ? Colors.amber[50]! : Colors.red[50]!;
    final iconColor = hasData ? Colors.amber[800]! : _bad;
    final items = _errors;

    return Material(
      color: color,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: iconColor.withOpacity(0.3)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: ValueKey('msgs-${items.length}-$hasData'),
          initiallyExpanded: !hasData,
          leading: Icon(
              hasData ? Icons.warning_amber_rounded : Icons.error_outline,
              color: iconColor),
          title: Text(
              '${hasData ? 'Warnings' : 'Errors'} (${items.length})',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _ink)),
          subtitle: hasData
              ? const Text('Tap to view details',
                  style: TextStyle(fontSize: 12, color: _muted))
              : null,
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ...items.take(30).map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $m',
                      style: const TextStyle(fontSize: 13, color: _ink)),
                )),
            if (items.length > 30)
              Text('… and ${items.length - 30} more',
                  style: const TextStyle(
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      color: _muted)),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessMessage() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green[700], size: 34),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Import finished',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _ink)),
                const SizedBox(height: 4),
                Text(
                  'Imported $_importedCount advances to $_selectedBranchName'
                  '${_createdFarmers > 0 ? ' · $_createdFarmers new farmers created' : ''}',
                  style: const TextStyle(fontSize: 14, color: _ink),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // File picking & parsing
  // ---------------------------------------------------------------------------

  Future<void> _pickFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'xlsx'],
      );

      if (files != null && files.isNotEmpty) {
        final file = files.first;
        if (mounted) setState(() => _fileName = file.name);
        final bytes = await file.readAsBytes();
        final extension = file.extension?.toLowerCase();

        if (extension == 'xlsx') {
          await _parseExcel(bytes);
        } else {
          final csvString = utf8.decode(bytes, allowMalformed: true);
          await _parseCSV(csvString);
        }
      }
    } catch (e) {
      if (mounted) {
        _showDialog('Error', 'Error picking file: $e', isError: true);
      }
    }
  }

  /// Safely converts an Excel cell to plain text.
  String _cellText(Data? cell) {
    final v = cell?.value;
    if (v == null) return '';
    if (v is TextCellValue) {
      // `value` is a String in some excel versions and a TextSpan in others.
      final dynamic t = v.value;
      if (t is String) return t;
      try {
        return t.toPlainText().toString();
      } catch (_) {
        return t.toString();
      }
    }
    if (v is IntCellValue) return v.value.toString();
    if (v is DoubleCellValue) return v.value.toString();
    return v.toString();
  }

  /// Parses yyyy-MM-dd or d/M/yyyy. Tolerates typos like "20/8//2026"
  /// (double slash) and "189/9/2026" (extra digit in the day).
  /// Returns null when the text is not a usable date.
  DateTime? _parseDateString(String dateStr) {
    final s = dateStr.trim();
    if (s.isEmpty) return null;
    if (s.contains('-')) {
      return DateTime.tryParse(s);
    }
    final parts = s.split('/').where((p) => p.trim().isNotEmpty).toList();
    if (parts.length != 3) return null;
    var dayStr = parts[0].trim();
    if (dayStr.length > 2) dayStr = dayStr.substring(0, 2);
    final d = int.tryParse(dayStr);
    final m = int.tryParse(parts[1].trim());
    final y = int.tryParse(parts[2].trim());
    if (d == null || m == null || y == null) return null;
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return DateTime(y, m, d);
  }

  /// Parses a number like "500000" or "1,200,000". Returns null if the text
  /// is not a plain number (e.g. a date or blank).
  double? _parseAmount(String s) {
    final t = s.replaceAll(',', '').trim();
    if (t.isEmpty) return null;
    return double.tryParse(t);
  }

  String _cleanName(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  String _normName(String s) => _cleanName(s).toLowerCase();

  /// Reads a date from a spreadsheet cell (real date cell or text).
  DateTime? _dateFromCell(Data? cell) {
    final v = cell?.value;
    if (v == null) return null;
    if (v is DateCellValue || v is DateTimeCellValue) {
      final dynamic dv = v;
      final int y = dv.year as int;
      final int mo = dv.month as int;
      final int d = dv.day as int;
      // The ledger's real date cells have day/month swapped. Only swap when
      // the stored "day" is a valid month (<= 12).
      if (_swapExcelDayMonth && d <= 12) {
        return DateTime(y, d, mo);
      }
      return DateTime(y, mo, d);
    }
    return _parseDateString(_cellText(cell));
  }

  /// The date exactly as Excel stored it (no day/month correction).
  DateTime? _rawExcelDate(Data? cell) {
    final v = cell?.value;
    if (v is DateCellValue || v is DateTimeCellValue) {
      final dynamic dv = v;
      return DateTime(dv.year as int, dv.month as int, dv.day as int);
    }
    return null;
  }

  Data? _at(List<Data?> row, int i) => i < row.length ? row[i] : null;

  /// True if this sheet looks like the "ADVANCE LEDGER" layout:
  /// NAME | DATE | ADVANCE AMOUNT | (total) | DATE | RECOVERY | BALANCE
  bool _isLedgerSheet(Sheet sheet) {
    final rows = sheet.rows;
    for (var i = 0; i < rows.length && i < 5; i++) {
      final firstCell = _cleanName(_cellText(_at(rows[i], 0))).toUpperCase();
      final thirdCell = _cleanName(_cellText(_at(rows[i], 2))).toUpperCase();
      if (firstCell == 'NAME' && thirdCell.contains('ADVANCE')) return true;
      if (firstCell.contains('LEDGER')) return true;
    }
    return false;
  }

  /// Parses the ledger layout where the farmer's name appears only on the
  /// first row of each group, followed by more advance rows and a total row.
  void _parseLedger(Sheet sheet) {
    final rows = sheet.rows;

    var headerIndex = -1;
    for (var i = 0; i < rows.length && i < 10; i++) {
      if (_cleanName(_cellText(_at(rows[i], 0))).toUpperCase() == 'NAME') {
        headerIndex = i;
        break;
      }
    }

    String? currentName;
    DateTime? lastDateForFarmer;

    for (var i = headerIndex + 1; i < rows.length; i++) {
      final row = rows[i];
      final excelRow = i + 1;

      final name = _cleanName(_cellText(_at(row, 0)));
      if (name.isNotEmpty) {
        if (name.toUpperCase() == 'TOTAL') break; // grand total row
        currentName = name;
        lastDateForFarmer = null;
      }
      if (currentName == null) continue;

      // Advance amount lives in column C. Total rows have it empty
      // (their number is in column D), so they are skipped here.
      final amount = _parseAmount(_cellText(_at(row, 2)));
      if (amount == null || amount <= 0) continue;

      // Date (column B)
      final dateCell = _at(row, 1);
      final dateText = _cellText(dateCell).trim();
      DateTime? date = _dateFromCell(dateCell);
      final noteParts = <String>[];

      if (date == null) {
        if (dateText.isEmpty) {
          // blank date: use the farmer's previous advance date
          date = lastDateForFarmer;
          noteParts.add('Date missing in ledger');
        } else {
          noteParts.add('Original date: $dateText');
        }
        _errors.add(
            'Warning, row $excelRow ($currentName): no valid date'
            '${dateText.isNotEmpty ? ' ("$dateText")' : ''}. '
            '${date != null ? 'Used the previous date.' : 'Today\'s date will be used.'}');
      } else if (dateText.contains('//') ||
          RegExp(r'^\d{3,}/').hasMatch(dateText)) {
        noteParts.add('Original date: $dateText');
        _errors.add(
            'Warning, row $excelRow ($currentName): date "$dateText" looked '
            'mistyped, read as ${DateFormat('dd/MM/yyyy').format(date)}.');
      }
      if (date != null) lastDateForFarmer = date;

      // Show what Excel displayed when the date had to be corrected.
      final rawDate = _rawExcelDate(dateCell);
      if (rawDate != null &&
          date != null &&
          (rawDate.day != date.day || rawDate.month != date.month)) {
        noteParts.add(
            'Date corrected (Excel showed ${DateFormat('dd/MM/yyyy').format(rawDate)})');
      }

      // Recovery in the same row (columns E = date, F = amount)
      final recovery = _parseAmount(_cellText(_at(row, 5))) ?? 0;
      if (recovery > 0) {
        final recDate = _cellText(_at(row, 4)).trim();
        noteParts.add(
            'Recovered ${NumberFormat('#,##0').format(recovery)}'
            '${recDate.isNotEmpty ? ' on $recDate' : ''}');
      }
      final balance = (amount - recovery) < 0 ? 0.0 : (amount - recovery);

      _parsedData.add({
        'farmerName': currentName,
        'phone': null,
        'amount': amount,
        'balance': balance,
        'date': date,
        'notes': noteParts.isEmpty ? null : noteParts.join('. '),
      });
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

      if (excel.tables.isEmpty) {
        setState(() {
          _errors.add('No data found in Excel file');
        });
        return;
      }

      // Get first sheet
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null) {
        setState(() {
          _errors.add('No data found in Excel file');
        });
        return;
      }

      // Ledger layout (NAME / DATE / ADVANCE AMOUNT / RECOVERY / BALANCE)
      if (_isLedgerSheet(sheet)) {
        _parseLedger(sheet);
        if (_parsedData.isEmpty) {
          _errors.add('No advances found in the ledger sheet');
        }
        setState(() {});
        return;
      }

      // Simple layout: Name | Phone | Amount | Date | Notes
      // Skip header row (first row)
      final dataRows = sheet.rows.skip(1).toList();

      for (var i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];

        if (row.isEmpty) continue;

        try {
          final farmerName = _cellText(row[0]).trim();
          if (farmerName.isEmpty) {
            continue; // Skip empty rows
          }

          if (row.length < 3) {
            _errors.add('Row ${i + 2}: Not enough columns');
            continue;
          }

          final phone = row.length > 1 ? _cellText(row[1]).trim() : '';
          final amountStr = row.length > 2 ? _cellText(row[2]).trim() : '0';
          final dateValue = row.length > 3 ? row[3]?.value : null;
          final notes = row.length > 4 ? _cellText(row[4]).trim() : '';

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
              if (dateValue is DateCellValue) {
                date = DateTime(
                  dateValue.year,
                  dateValue.month,
                  dateValue.day,
                );
              } else if (dateValue is DateTimeCellValue) {
                date = DateTime(
                  dateValue.year,
                  dateValue.month,
                  dateValue.day,
                );
              } else if (dateValue is TextCellValue) {
                date = _parseDateString(dateValue.value.toString());
              } else {
                date = _parseDateString(dateValue.toString());
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
      // Works with the current csv package API (csv.decode)
      final List<List<dynamic>> rows = csv.decode(csvString);

      // Skip header row if it exists
      final hasHeader = rows.isNotEmpty &&
          rows[0].isNotEmpty &&
          rows[0][0].toString().toLowerCase().contains('name');
      final dataRows = (hasHeader ? rows.skip(1) : rows).toList();
      final rowOffset = hasHeader ? 2 : 1;

      for (var i = 0; i < dataRows.length; i++) {
        final row = dataRows[i];

        // Skip completely empty rows
        if (row.isEmpty || row.every((c) => c.toString().trim().isEmpty)) {
          continue;
        }

        if (row.length < 3) {
          _errors.add('Row ${i + rowOffset}: Not enough columns');
          continue;
        }

        try {
          final farmerName = row[0].toString().trim();
          if (farmerName.isEmpty) continue;

          final phone = row.length > 1 ? row[1].toString().trim() : '';
          final amountStr = row.length > 2 ? row[2].toString().trim() : '0';
          final dateStr = row.length > 3 ? row[3].toString().trim() : '';
          final notes = row.length > 4 ? row[4].toString().trim() : '';

          // Parse amount
          double amount = 0;
          try {
            amount = double.parse(amountStr.replaceAll(',', ''));
          } catch (e) {
            _errors.add('Row ${i + rowOffset}: Invalid amount "$amountStr"');
            continue;
          }

          // Parse date
          DateTime? date;
          if (dateStr.isNotEmpty) {
            try {
              date = _parseDateString(dateStr);
            } catch (e) {
              _errors.add(
                  'Row ${i + rowOffset}: Invalid date format "$dateStr"');
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
          _errors.add('Row ${i + rowOffset}: Error parsing - $e');
        }
      }

      setState(() {});
    } catch (e) {
      setState(() {
        _errors.add('Error parsing CSV: $e');
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Import to Firestore
  // ---------------------------------------------------------------------------

  Future<void> _importData() async {
    if (_selectedBranchId == null || _parsedData.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errors = [];
      _importedCount = 0;
      _createdFarmers = 0;
      _progress = 0;
    });

    final currentUser = AuthService.instance.currentUser;
    if (currentUser == null) {
      setState(() {
        _errors.add('Not logged in');
        _isLoading = false;
      });
      _showDialog('Not Logged In', 'Please sign in to import data', isError: true);
      return;
    }

    try {
      // Get all farmers from this branch
      final farmersSnapshot = await _firestore
          .collection('farmers')
          .where('branchId', isEqualTo: _selectedBranchId)
          .get();

      final farmersByName = <String, String>{};
      for (var doc in farmersSnapshot.docs) {
        final name = _normName((doc.data()['name'] ?? '').toString());
        farmersByName[name] = doc.id;
      }

      for (var i = 0; i < _parsedData.length; i++) {
        if (mounted) setState(() => _progress = i); // rows before i are done
        final row = _parsedData[i];
        final farmerKey = _normName(row['farmerName'].toString());

        String? farmerId = farmersByName[farmerKey];
        if (farmerId == null) {
          if (!_createMissingFarmers) {
            final msg =
                'Farmer "${row['farmerName']}" not found in $_selectedBranchName';
            if (!_errors.contains(msg)) _errors.add(msg);
            continue;
          }

          // Create the farmer in this branch
          final newFarmer = _firestore.collection('farmers').doc();
          await newFarmer.set({
            'name': _cleanName(row['farmerName'].toString()),
            'phone': row['phone'] ?? '',
            'branchId': _selectedBranchId,
            'branchName': _selectedBranchName,
            'advanceBalance': 0.0,
            'isActive': true,
            'createdBy': currentUser.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          farmerId = newFarmer.id;
          farmersByName[farmerKey] = farmerId;
          _createdFarmers++;
        }

        final double amount = (row['amount'] as num).toDouble();
        // Outstanding balance (amount minus any recovery already made)
        final double balance =
            ((row['balance'] ?? row['amount']) as num).toDouble();

        // Create advance record
        await _firestore.collection('advances').add({
          'farmerId': farmerId,
          'farmerName': row['farmerName'],
          'branchId': _selectedBranchId,
          'branchName': _selectedBranchName,
          'amount': amount,
          'balance': balance,
          'date': row['date'] ?? DateTime.now(),
          'notes': row['notes'] ?? '',
          'isActive': balance > 0,
          'createdBy': currentUser.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });

        // Update farmer's advance balance
        final farmerDoc = _firestore.collection('farmers').doc(farmerId);
        await _firestore.runTransaction((transaction) async {
          final farmerSnapshot = await transaction.get(farmerDoc);
          if (farmerSnapshot.exists) {
            final currentAdvance =
                ((farmerSnapshot.data()?['advanceBalance'] ?? 0) as num)
                    .toDouble();
            transaction.update(farmerDoc, {
              'advanceBalance': currentAdvance + balance,
              'updatedAt': FieldValue.serverTimestamp(),
            });
          }
        });

        _importedCount++;
      }

      setState(() {
        _isLoading = false;
        // Clear the preview so the same file can't be imported twice by accident
        _parsedData = [];
      });

      _showDialog(
        'Import Successful!',
        'Successfully imported $_importedCount advances to $_selectedBranchName'
        '${_createdFarmers > 0 ? '\n\nCreated $_createdFarmers new farmers' : ''}'
        '${_errors.isNotEmpty ? '\n\n${_errors.length} warnings (check errors section above)' : ''}',
        isError: false,
      );
    } catch (e, st) {
      debugPrint('Import error: $e\n$st');
      setState(() {
        // Rows before _progress were already saved: drop them from the preview
        // so pressing Import again cannot create duplicates.
        if (_progress > 0 && _progress <= _parsedData.length) {
          _parsedData = _parsedData.sublist(_progress);
        }
        _errors.add(
            'Import stopped after $_importedCount advances were saved: $e');
        _isLoading = false;
      });
      _showDialog('Import Failed', 'Import stopped after $_importedCount advances: $e', isError: true);
    }
  }
}