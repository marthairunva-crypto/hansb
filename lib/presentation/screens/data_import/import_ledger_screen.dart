import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
// The excel package exports its own Border / BorderStyle / TextSpan, which
// clash with Flutter's, so they are hidden here.
import 'package:excel/excel.dart' hide Border, BorderStyle, TextSpan;

/// Importer for the "ADVANCE LEDGER" Excel layout:
///
///   NAME | DATE | ADVANCE AMOUNT | (sum) | DATE | RECOVERY/PAYMENTS | BALANCE
///
/// - The farmer name appears only on the first row of each farmer (merged
///   cells); following rows belong to the same farmer.
/// - Only the NAME / DATE / ADVANCE AMOUNT (and recovery) columns are read.
///   Formula cells and subtotal / total rows are ignored.
/// - Dates may be real Excel dates or text (22/7/2026, 20/8//2026 ...).
/// - Every problem (unknown farmer, bad date) is shown in the preview and can
///   be fixed on screen before anything is written to Firestore.
class ImportLedgerScreen extends StatefulWidget {
  const ImportLedgerScreen({Key? key}) : super(key: key);

  @override
  State<ImportLedgerScreen> createState() => _ImportLedgerScreenState();
}

class _AdvRow {
  _AdvRow({
    required this.sheetRow,
    required this.ledgerName,
    required this.amount,
    this.date,
    this.dateIssue,
    this.note,
    this.recovered = 0,
    this.recoveryDate,
  });

  final int sheetRow;
  final String ledgerName;
  final double amount;
  DateTime? date;
  String? dateIssue; // set when the date is missing / unreadable
  String? note; // soft warning, row can still be imported
  final double recovered;
  final DateTime? recoveryDate;
}

class _DateResult {
  _DateResult(this.date, this.issue);
  final DateTime? date;
  final String? issue;
}

class _Farmer {
  _Farmer(this.id, this.name);
  final String id;
  final String name;
}

class _ImportLedgerScreenState extends State<ImportLedgerScreen> {
  static const _green = Color(0xFF2E7D32);

  final _firestore = FirebaseFirestore.instance;
  final _money = NumberFormat('#,##0');
  final _dateFmt = DateFormat('dd/MM/yyyy');

  bool _isLoading = false;
  String? _selectedBranchId;
  String? _selectedBranchName;

  List<int>? _fileBytes;
  String? _fileName;

  /// Excel turns "7/9/2026" typed as day/month into July 9 when the PC is set
  /// to US dates. Real date cells are therefore flipped back by default.
  bool _swapExcelDates = true;
  bool _onlyIssues = false;

  List<_Farmer> _farmers = [];
  List<_AdvRow> _rows = [];
  final Map<String, String?> _mapping = {}; // ledger name -> farmerId
  List<String> _warnings = [];
  List<String> _errors = [];

  int _importedCount = 0;
  int _duplicateCount = 0;

  // ---------------------------------------------------------------------------
  // Derived state
  // ---------------------------------------------------------------------------

  bool _isReady(_AdvRow r) =>
      _mapping[r.ledgerName] != null && r.date != null && r.amount > 0;

  int get _readyCount => _rows.where(_isReady).length;
  double get _readyTotal =>
      _rows.where(_isReady).fold<double>(0, (s, r) => s + r.amount);
  double get _allTotal => _rows.fold<double>(0, (s, r) => s + r.amount);

  List<String> get _ledgerNames {
    final seen = <String>{};
    final out = <String>[];
    for (final r in _rows) {
      if (seen.add(r.ledgerName)) out.add(r.ledgerName);
    }
    return out;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Import Advance Ledger'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInfoCard(),
                const SizedBox(height: 24),
                _buildBranchSelector(),
                const SizedBox(height: 24),
                _buildFilePickerSection(),
                if (_rows.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildSummary(),
                  const SizedBox(height: 24),
                  _buildMatchingSection(),
                  const SizedBox(height: 24),
                  _buildPreviewSection(),
                ],
                if (_warnings.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildMessagesCard(
                    title: 'Warnings',
                    icon: Icons.warning_amber_rounded,
                    color: Colors.amber[50]!,
                    iconColor: Colors.amber[800]!,
                    items: _warnings,
                  ),
                ],
                if (_errors.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _buildMessagesCard(
                    title: 'Errors',
                    icon: Icons.error_outline,
                    color: Colors.red[50]!,
                    iconColor: Colors.red[700]!,
                    items: _errors,
                  ),
                ],
                if (_importedCount > 0 || _duplicateCount > 0) ...[
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              'Upload your ADVANCE LEDGER Excel file (.xlsx). The farmer name '
              'is read from the first row of each farmer; the rows below it '
              '(until the next name) belong to the same farmer.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            _bullet('Subtotal, balance and TOTAL rows are ignored automatically'),
            _bullet('Farmers are matched to the farmers saved in the selected branch'),
            _bullet('Unknown farmers and bad dates can be fixed in the preview before importing'),
            _bullet('Rows that were already imported earlier are skipped (no duplicates)'),
          ],
        ),
      ),
    );
  }

  Widget _bullet(String text) {
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
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  hint: const Text('Choose a branch'),
                  items: branches.map((doc) {
                    return DropdownMenuItem(
                      value: doc.id,
                      child: Text((doc['name'] ?? 'Unknown').toString()),
                    );
                  }).toList(),
                  onChanged: (value) async {
                    final doc = branches.firstWhere((d) => d.id == value);
                    setState(() {
                      _selectedBranchId = value;
                      _selectedBranchName = (doc['name'] ?? '').toString();
                      _importedCount = 0;
                      _duplicateCount = 0;
                    });
                    await _loadFarmers();
                    if (_rows.isNotEmpty) {
                      setState(_buildMapping);
                    }
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
    final enabled = _selectedBranchId != null && !_isLoading;
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
              onTap: enabled ? _pickFile : null,
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: enabled ? _green : Colors.grey[300]!,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: enabled
                      ? _green.withOpacity(0.05)
                      : Colors.grey[100],
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 56,
                      color: enabled ? _green : Colors.grey[400],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedBranchId == null
                          ? 'Select a branch first'
                          : (_fileName ?? 'Click to select Excel file (.xlsx)'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: enabled ? _green : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _swapExcelDates,
              activeColor: _green,
              title: const Text(
                'Fix day/month swapped in real Excel date cells',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'If a date you typed as 7/9/2026 (7 Sept) shows in Excel as '
                '9 July, keep this ON. Dates stored as text are never changed.',
                style: TextStyle(fontSize: 12),
              ),
              onChanged: (v) {
                setState(() => _swapExcelDates = v);
                if (_fileBytes != null) _parseLedger();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final needAttention = _rows.length - _readyCount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _chip('Advances in file', '${_rows.length}', Colors.blue[700]!),
                _chip('Ledger total', 'UGX ${_money.format(_allTotal)}',
                    Colors.blue[700]!),
                _chip('Ready to import', '$_readyCount', _green),
                _chip('Ready amount', 'UGX ${_money.format(_readyTotal)}',
                    _green),
                _chip(
                  'Need attention',
                  '$needAttention',
                  needAttention == 0 ? Colors.grey[600]! : Colors.red[700]!,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Compare "Ledger total" with the TOTAL at the bottom of your Excel sheet.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      onPressed: _readyCount == 0 ? null : _importData,
                      icon: const Icon(Icons.upload),
                      label: Text('Import $_readyCount ready advances'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMatchingSection() {
    final names = _ledgerNames;
    final unmatched = names.where((n) => _mapping[n] == null).toList();
    final matched = names.where((n) => _mapping[n] != null).toList();

    Widget row(String name) {
      final count = _rows.where((r) => r.ledgerName == name).length;
      final total = _rows
          .where((r) => r.ledgerName == name)
          .fold<double>(0, (s, r) => s + r.amount);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              flex: 4,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  Text('$count advance(s) · UGX ${_money.format(total)}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[600])),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 4,
              child: DropdownButton<String>(
                isExpanded: true,
                value: _mapping[name],
                hint: const Text('Choose farmer…'),
                items: _farmers
                    .map((f) => DropdownMenuItem(
                          value: f.id,
                          child:
                              Text(f.name, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _mapping[name] = v),
              ),
            ),
          ],
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Farmer matching (${matched.length} of ${names.length} matched)',
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              _farmers.isEmpty
                  ? 'No farmers were found in this branch.'
                  : 'Names are matched ignoring case, spacing and punctuation. '
                      'Pick the right farmer for any name that was not recognised; '
                      'unmatched names are not imported.',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 12),
            if (unmatched.isNotEmpty) ...[
              Row(children: [
                Icon(Icons.help_outline, size: 18, color: Colors.red[700]),
                const SizedBox(width: 8),
                Text('Not matched (${unmatched.length})',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.red[700])),
              ]),
              ...unmatched.map(row),
            ] else
              Row(children: [
                Icon(Icons.check_circle, size: 18, color: Colors.green[700]),
                const SizedBox(width: 8),
                const Text('All farmers matched'),
              ]),
            if (matched.isNotEmpty)
              Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('Matched (${matched.length}) — tap to review',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600)),
                  children: matched.map(row).toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    final shown = _onlyIssues ? _rows.where((r) => !_isReady(r)).toList() : _rows;

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
                  'Preview (${shown.length} advances)',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Row(
                  children: [
                    const Text('Only rows needing attention',
                        style: TextStyle(fontSize: 13)),
                    Switch(
                      value: _onlyIssues,
                      activeColor: _green,
                      onChanged: (v) => setState(() => _onlyIssues = v),
                    ),
                  ],
                ),
              ],
            ),
            Text('Tap a date to correct it.',
                style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            const SizedBox(height: 12),
            SizedBox(
              height: 420,
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowColor: MaterialStateProperty.all(
                      _green.withOpacity(0.1),
                    ),
                    columns: const [
                      DataColumn(label: Text('Sheet row')),
                      DataColumn(label: Text('Farmer (ledger)')),
                      DataColumn(label: Text('Amount'), numeric: true),
                      DataColumn(label: Text('Date')),
                      DataColumn(label: Text('Recovered'), numeric: true),
                      DataColumn(label: Text('Status')),
                    ],
                    rows: shown.map(_buildDataRow).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildDataRow(_AdvRow r) {
    final matched = _mapping[r.ledgerName] != null;
    String status;
    Color statusColor;
    if (!matched) {
      status = 'No farmer match';
      statusColor = Colors.red[700]!;
    } else if (r.date == null) {
      status = r.dateIssue ?? 'Missing date';
      statusColor = Colors.red[700]!;
    } else if (r.note != null) {
      status = r.note!;
      statusColor = Colors.amber[900]!;
    } else {
      status = 'Ready';
      statusColor = Colors.green[700]!;
    }

    return DataRow(
      color: _isReady(r)
          ? null
          : MaterialStateProperty.all(Colors.red[50]),
      cells: [
        DataCell(Text('${r.sheetRow}')),
        DataCell(ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 260),
          child: Text(r.ledgerName, overflow: TextOverflow.ellipsis),
        )),
        DataCell(Text(_money.format(r.amount))),
        DataCell(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(r.date != null ? _dateFmt.format(r.date!) : 'Set date'),
              const SizedBox(width: 6),
              Icon(Icons.edit_calendar, size: 16, color: Colors.grey[600]),
            ],
          ),
          onTap: () => _pickDate(r),
        ),
        DataCell(Text(r.recovered > 0 ? _money.format(r.recovered) : '-')),
        DataCell(Text(status,
            style: TextStyle(color: statusColor, fontSize: 13))),
      ],
    );
  }

  Widget _buildMessagesCard({
    required String title,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required List<String> items,
  }) {
    return Card(
      color: color,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor),
                const SizedBox(width: 12),
                Text('$title (${items.length})',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            ...items.take(30).map((m) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text('• $m', style: const TextStyle(fontSize: 13)),
                )),
            if (items.length > 30)
              Text('… and ${items.length - 30} more',
                  style: const TextStyle(
                      fontSize: 13, fontStyle: FontStyle.italic)),
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
            Icon(Icons.check_circle_outline,
                color: Colors.green[700], size: 32),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Import finished',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(
                    'Imported $_importedCount advances to $_selectedBranchName'
                    '${_duplicateCount > 0 ? ' · skipped $_duplicateCount already-imported duplicates' : ''}',
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

  // ---------------------------------------------------------------------------
  // File picking
  // ---------------------------------------------------------------------------

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'], // the excel package cannot read old .xls
        withData: true, // needed on mobile/desktop to get the bytes
      );
      if (result == null) return;

      final file = result.files.single;
      if (file.bytes == null) {
        setState(() => _errors = ['Could not read the file contents.']);
        return;
      }

      _fileBytes = file.bytes!;
      _fileName = file.name;
      await _loadFarmers();
      _parseLedger();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  Future<void> _loadFarmers() async {
    if (_selectedBranchId == null) return;
    final snap = await _firestore
        .collection('farmers')
        .where('branchId', isEqualTo: _selectedBranchId)
        .get();
    final list = snap.docs
        .map((d) => _Farmer(d.id, (d.data()['name'] ?? '').toString().trim()))
        .where((f) => f.name.isNotEmpty)
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    if (mounted) setState(() => _farmers = list);
  }

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  /// Text of a cell. Formula cells give '' (their value is not computed by the
  /// excel package, and we never want formula text mistaken for data).
  String _cellText(Data? cell) {
    final v = cell?.value;
    if (v == null) return '';
    if (v is FormulaCellValue) return '';
    if (v is DateCellValue || v is DateTimeCellValue) return '';
    try {
      final dynamic raw = (v as dynamic).value;
      if (raw == null) return '';
      if (raw is String) return raw;
      if (raw is num || raw is bool) return raw.toString();
      // Rich text (newer excel versions): collect the plain text.
      final buf = StringBuffer();
      void walk(dynamic span) {
        final t = span.text;
        if (t != null) buf.write(t);
        final ch = span.children;
        if (ch != null) {
          for (final c in ch) {
            walk(c);
          }
        }
      }

      walk(raw);
      return buf.toString();
    } catch (_) {
      return v.toString();
    }
  }

  String _headerText(Data? cell) =>
      _cellText(cell).toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  String _cleanName(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();

  double? _parseAmount(String s) {
    final cleaned = s
        .toUpperCase()
        .replaceAll('UGX', '')
        .replaceAll(RegExp(r'[,\s\$]'), '');
    if (cleaned.isEmpty) return null;
    return double.tryParse(cleaned);
  }

  DateTime? _validDate(int y, int m, int d) {
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    final dt = DateTime(y, m, d);
    if (dt.year != y || dt.month != m || dt.day != d) return null;
    return dt;
  }

  /// Parses text dates like 22/7/2026, 20/8//2026, 2026-07-09, 1/10/26.
  /// Always day first (the ledger is d/m/yyyy). Returns null if unreadable.
  DateTime? _parseTextDate(String s) {
    final parts = s
        .trim()
        .split(RegExp(r'[/\-.\s]+'))
        .where((p) => p.isNotEmpty)
        .toList();
    final nums = parts.map(int.tryParse).toList();
    if (nums.any((n) => n == null)) return null;
    final n = nums.cast<int>();

    if (n.length == 3) {
      if (n[0] > 31) return _validDate(n[0], n[1], n[2]); // yyyy-mm-dd
      var y = n[2];
      if (y < 100) y += 2000;
      return _validDate(y, n[1], n[0]);
    }
    if (n.length == 2) {
      return _validDate(DateTime.now().year, n[1], n[0]);
    }
    return null;
  }

  void _parseLedger() {
    final bytes = _fileBytes;
    if (bytes == null) return;

    final rows = <_AdvRow>[];
    final warnings = <String>[];
    final errors = <String>[];

    try {
      final excel = Excel.decodeBytes(bytes);
      if (excel.tables.isEmpty) {
        throw 'No sheets found in the Excel file';
      }
      final sheet = excel.tables[excel.tables.keys.first];
      if (sheet == null || sheet.rows.isEmpty) {
        throw 'No data found in the first sheet';
      }
      final grid = sheet.rows;

      // ---- locate header row / columns ------------------------------------
      var headerRow = -1;
      var nameCol = 0, dateCol = 1, amountCol = 2;
      var recDateCol = -1, recAmountCol = -1;

      for (var r = 0; r < grid.length && r < 15; r++) {
        final texts = grid[r].map(_headerText).toList();
        final nIdx = texts.indexWhere((t) => t.contains('NAME'));
        if (nIdx < 0) continue;
        headerRow = r;
        nameCol = nIdx;

        var amtIdx = -1;
        for (var c = 0; c < texts.length; c++) {
          final t = texts[c];
          if (t.contains('RECOVERY') || t.contains('PAYMENT')) {
            recAmountCol = c;
          } else if (amtIdx < 0 && t.contains('AMOUNT')) {
            amtIdx = c;
          }
        }
        final dateIdxs = <int>[
          for (var c = 0; c < texts.length; c++)
            if (texts[c].contains('DATE')) c
        ];
        if (amtIdx < 0) {
          final firstDate = dateIdxs.isNotEmpty ? dateIdxs.first : nIdx + 1;
          amtIdx = firstDate + 1;
        }
        amountCol = amtIdx;
        final advDates = dateIdxs.where((c) => c < amountCol).toList();
        dateCol = advDates.isNotEmpty ? advDates.last : amountCol - 1;
        if (recAmountCol >= 0) {
          final recDates = dateIdxs
              .where((c) => c > amountCol && c < recAmountCol)
              .toList();
          if (recDates.isNotEmpty) recDateCol = recDates.last;
        }
        break;
      }

      if (headerRow < 0) {
        warnings.add(
            'Header row (NAME / DATE / AMOUNT) not found — assuming columns A = name, B = date, C = amount.');
      }

      Data? at(List<Data?> row, int c) =>
          (c >= 0 && c < row.length) ? row[c] : null;

      // ---- read ledger rows ------------------------------------------------
      var current = '';
      for (var r = headerRow + 1; r < grid.length; r++) {
        final row = grid[r];
        final sheetRow = r + 1;

        final name = _cleanName(_cellText(at(row, nameCol)));
        final upper = name.toUpperCase();
        if (upper == 'TOTAL' || upper.startsWith('TOTAL ')) continue;
        if (name.isNotEmpty) current = name;

        // Advance amount (never read from formula cells).
        final amtText = _cellText(at(row, amountCol)).trim();
        final amount = _parseAmount(amtText);
        if (amount == null) {
          if (amtText.isNotEmpty) {
            warnings.add(
                'Row $sheetRow: amount cell contains "$amtText", which is not a number — ignored.');
          }
          continue;
        }
        if (amount <= 0) continue;

        if (current.isEmpty) {
          warnings.add('Row $sheetRow: amount found but no farmer name above it — skipped.');
          continue;
        }

        // Advance date.
        final dateResult = _readDateCell(at(row, dateCol));

        // Recovery (optional).
        var recovered = 0.0;
        DateTime? recDate;
        if (recAmountCol >= 0) {
          recovered =
              _parseAmount(_cellText(at(row, recAmountCol)).trim()) ?? 0;
          if (recovered > 0 && recDateCol >= 0) {
            recDate = _readDateCell(at(row, recDateCol)).date;
          }
        }

        final adv = _AdvRow(
          sheetRow: sheetRow,
          ledgerName: current,
          amount: amount,
          date: dateResult.date,
          dateIssue: dateResult.issue,
          recovered: recovered,
          recoveryDate: recDate,
        );

        if (adv.date != null) {
          final today = DateTime.now();
          if (adv.date!.isAfter(today.add(const Duration(days: 1)))) {
            adv.note = 'Date is in the future — check';
          } else if (adv.date!.year < 2020) {
            adv.note = 'Date looks very old — check';
          }
        }
        if (recovered > amount) {
          adv.note = 'Recovered more than the advance — check';
        }
        rows.add(adv);
      }

      if (rows.isEmpty) {
        errors.add('No advances found in the file.');
      }
    } catch (e) {
      errors.add('Error reading Excel: $e');
    }

    setState(() {
      _rows = rows;
      _warnings = warnings;
      _errors = errors;
      _importedCount = 0;
      _duplicateCount = 0;
      _buildMapping();
    });
  }

  /// Reads a date cell. Real Excel date cells are flipped back to day/month
  /// when [_swapExcelDates] is on.
  _DateResult _readDateCell(Data? cell) {
    final v = cell?.value;

    int? y, m, d;
    if (v is DateCellValue) {
      y = v.year;
      m = v.month;
      d = v.day;
    } else if (v is DateTimeCellValue) {
      y = v.year;
      m = v.month;
      d = v.day;
    }
    if (y != null && m != null && d != null) {
      // Excel parsed a typed d/m date as m/d. Flip it back when possible.
      if (_swapExcelDates && d <= 12) {
        final flipped = _validDate(y, d, m);
        if (flipped != null) return _DateResult(flipped, null);
      }
      final asIs = _validDate(y, m, d);
      return _DateResult(asIs, asIs == null ? 'Invalid date' : null);
    }

    final text = _cellText(cell).trim();
    if (text.isEmpty) return _DateResult(null, 'Missing date');
    final parsed = _parseTextDate(text);
    if (parsed == null) {
      return _DateResult(null, 'Unreadable date "$text"');
    }
    return _DateResult(parsed, null);
  }

  // ---------------------------------------------------------------------------
  // Farmer matching
  // ---------------------------------------------------------------------------

  String _norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  /// Auto-matches each ledger name to a farmer: first by normalised exact
  /// name, then by name tokens (only when exactly one farmer fits). Choices the
  /// user already made are kept.
  void _buildMapping() {
    final old = Map<String, String?>.from(_mapping);
    _mapping.clear();

    final exact = <String, String>{};
    final tokens = <String, Set<String>>{};
    for (final f in _farmers) {
      exact.putIfAbsent(_norm(f.name), () => f.id);
      tokens[f.id] = _norm(f.name).split(' ').toSet();
    }

    for (final name in _ledgerNames) {
      final keep = old[name];
      if (keep != null && _farmers.any((f) => f.id == keep)) {
        _mapping[name] = keep;
        continue;
      }
      final n = _norm(name);
      String? id = exact[n];
      if (id == null && n.isNotEmpty) {
        final t = n.split(' ').toSet();
        final candidates = <String>[];
        tokens.forEach((fid, ft) {
          final smaller = t.length <= ft.length ? t : ft;
          final larger = t.length <= ft.length ? ft : t;
          if (smaller.length >= 2 && larger.containsAll(smaller)) {
            candidates.add(fid);
          }
        });
        if (candidates.length == 1) id = candidates.first;
      }
      _mapping[name] = id;
    }
  }

  // ---------------------------------------------------------------------------
  // Editing
  // ---------------------------------------------------------------------------

  Future<void> _pickDate(_AdvRow r) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: r.date ?? DateTime.now(),
      firstDate: DateTime(2015),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        r.date = picked;
        r.dateIssue = null;
        r.note = null;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Import
  // ---------------------------------------------------------------------------

  Future<void> _importData() async {
    if (_selectedBranchId == null) return;
    final ready = _rows.where(_isReady).toList();
    if (ready.isEmpty) return;

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _errors = ['Not logged in']);
      return;
    }

    setState(() {
      _isLoading = true;
      _errors = [];
      _importedCount = 0;
      _duplicateCount = 0;
    });

    try {
      // Existing advances for this branch -> used to skip duplicates when the
      // same file is imported twice.
      final keyFmt = DateFormat('yyyy-MM-dd');
      String keyOf(String farmerId, double amount, DateTime date) =>
          '$farmerId|${amount.round()}|${keyFmt.format(date)}';

      final existing = await _firestore
          .collection('advances')
          .where('branchId', isEqualTo: _selectedBranchId)
          .get();
      final existingKeys = <String>{};
      for (final doc in existing.docs) {
        final data = doc.data();
        final fid = data['farmerId']?.toString();
        final amt = (data['amount'] as num?)?.toDouble();
        final dv = data['date'];
        final dt = dv is Timestamp ? dv.toDate() : (dv is DateTime ? dv : null);
        if (fid != null && amt != null && dt != null) {
          existingKeys.add(keyOf(fid, amt, dt));
        }
      }

      final toWrite = <_AdvRow>[];
      var duplicates = 0;
      for (final r in ready) {
        final fid = _mapping[r.ledgerName]!;
        if (existingKeys.contains(keyOf(fid, r.amount, r.date!))) {
          duplicates++;
        } else {
          toWrite.add(r);
        }
      }

      // Each batch writes advances AND the matching farmer balance increments,
      // so a batch either fully succeeds or not at all (max 500 ops/batch).
      const chunkSize = 200;
      var imported = 0;
      for (var i = 0; i < toWrite.length; i += chunkSize) {
        final chunk = toWrite.sublist(
            i, i + chunkSize > toWrite.length ? toWrite.length : i + chunkSize);
        final batch = _firestore.batch();
        final balanceByFarmer = <String, double>{};

        for (final r in chunk) {
          final farmerId = _mapping[r.ledgerName]!;
          final farmer = _farmers.firstWhere((f) => f.id == farmerId);
          final balance = (r.amount - r.recovered).clamp(0, double.infinity);
          final ref = _firestore.collection('advances').doc();

          var notes = 'Imported from ledger';
          if (r.recovered > 0) {
            notes += ' · recovered UGX ${_money.format(r.recovered)}'
                '${r.recoveryDate != null ? ' on ${_dateFmt.format(r.recoveryDate!)}' : ''}';
          }

          batch.set(ref, {
            'farmerId': farmerId,
            'farmerName': farmer.name,
            'branchId': _selectedBranchId,
            'branchName': _selectedBranchName,
            'amount': r.amount,
            'balance': balance,
            'date': Timestamp.fromDate(r.date!),
            'notes': notes,
            'isActive': balance > 0,
            'createdBy': currentUser.uid,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          balanceByFarmer[farmerId] =
              (balanceByFarmer[farmerId] ?? 0) + balance.toDouble();
        }

        balanceByFarmer.forEach((farmerId, add) {
          if (add == 0) return;
          batch.update(_firestore.collection('farmers').doc(farmerId), {
            'advanceBalance': FieldValue.increment(add),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });

        await batch.commit();
        imported += chunk.length;
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _importedCount = imported;
        _duplicateCount = duplicates;
        // Keep only the rows that were not imported, so nothing can be
        // imported twice by pressing the button again.
        _rows = _rows.where((r) => !_isReady(r)).toList();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Imported $imported advances'
              '${duplicates > 0 ? ' ($duplicates duplicates skipped)' : ''}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errors = ['Import error: $e'];
        _isLoading = false;
      });
    }
  }
}