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
    this.fixedFrom,
  });

  final int sheetRow;
  final String ledgerName;
  final double amount;
  DateTime? date;
  String? dateIssue; // set when the date is missing / unreadable
  String? note; // soft warning, row can still be imported
  final double recovered;
  final DateTime? recoveryDate;
  final String? fixedFrom; // e.g. 'Excel showed 09/07/2026' when corrected
}

class _DateResult {
  _DateResult(this.date, this.issue, [this.fixedFrom]);
  final DateTime? date;
  final String? issue;
  final String? fixedFrom;
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
  bool _swapExcelDates = false; // default: use dates exactly as Excel shows them
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
  // Design tokens
  // ---------------------------------------------------------------------------

  static const _ink = Color(0xFF1F2937);
  static const _muted = Color(0xFF6B7280);
  static const _line = Color(0xFFE5E7EB);
  static const _bad = Color(0xFFC62828);
  static const _warn = Color(0xFFB26A00);
  static const _info = Color(0xFF1565C0);

  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _showSnack(String msg, {bool error = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Colors.red[700] : Colors.green[700],
        duration: Duration(seconds: error ? 10 : 4),
      ),
    );
  }

  void _scrollTop() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0,
          duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    }
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _line),
      );

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      appBar: AppBar(
        title: const Text('Import Advance Ledger'),
        backgroundColor: _green,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: LayoutBuilder(builder: (context, c) {
        final wide = c.maxWidth >= 1000;

        final left = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildIntro(),
            const SizedBox(height: 20),
            _buildBranchCard(),
            const SizedBox(height: 20),
            _buildFileCard(),
          ],
        );

        final right = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_importedCount > 0 || _duplicateCount > 0) ...[
              _buildSuccessMessage(),
              const SizedBox(height: 20),
            ],
            if (_errors.isNotEmpty) ...[
              _buildMessagesCard(
                title: 'Errors',
                icon: Icons.error_outline,
                color: Colors.red[50]!,
                iconColor: _bad,
                items: _errors,
                expanded: true,
              ),
              const SizedBox(height: 20),
            ],
            if (_rows.isNotEmpty) ...[
              _buildSummary(),
              const SizedBox(height: 20),
              _buildMatchingSection(),
              const SizedBox(height: 20),
              _buildPreviewSection(),
            ] else
              _buildEmptyState(),
            if (_warnings.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildMessagesCard(
                title: 'Warnings',
                icon: Icons.warning_amber_rounded,
                color: Colors.amber[50]!,
                iconColor: Colors.amber[800]!,
                items: _warnings,
              ),
            ],
          ],
        );

        return SingleChildScrollView(
          controller: _scroll,
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

    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: _line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
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
      ),
    );
  }

  Widget _pill(String text, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
          ],
          Text(text,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600, color: color)),
        ],
      ),
    );
  }

  Widget _kpi({
    required IconData icon,
    required String label,
    required String value,
    String? sub,
    required Color color,
  }) {
    return Container(
      width: 245,
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
                    style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _ink)),
                if (sub != null)
                  Text(sub,
                      style: const TextStyle(fontSize: 12, color: _muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Intro
  // ---------------------------------------------------------------------------

  Widget _buildIntro() {
    Widget point(IconData icon, String text) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: _green),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(fontSize: 13, color: _ink)),
          ],
        );

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Import advance ledger',
              style: TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 4),
          const Text(
            'Bring previous advances in from your ADVANCE LEDGER Excel file '
            '(.xlsx). The farmer name is read from the first row of each '
            'farmer; the rows below it belong to the same farmer.',
            style: TextStyle(fontSize: 14, color: _muted, height: 1.4),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 22,
            runSpacing: 8,
            children: [
              point(Icons.functions, 'Totals & balances are ignored'),
              point(Icons.person_search_outlined, 'Farmers matched automatically'),
              point(Icons.edit_calendar_outlined, 'Fix dates before importing'),
              point(Icons.verified_outlined, 'Duplicates are skipped'),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Left column: branch and file
  // ---------------------------------------------------------------------------

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 72),
      decoration: _cardDecoration,
      child: Column(
        children: [
          Icon(Icons.table_view_outlined, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 16),
          const Text('No ledger loaded yet',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: _ink)),
          const SizedBox(height: 6),
          const Text(
            'Choose a branch and upload your ADVANCE LEDGER. The summary, '
            'farmer matching and a preview of every advance appear here for '
            'you to check before anything is saved.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: _muted, height: 1.45),
          ),
        ],
      ),
    );
  }

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
            items: branches.map((doc) {
              return DropdownMenuItem(
                value: doc.id,
                child: Text((doc['branch_name'] ?? 'Unknown').toString()),
              );
            }).toList(),
            onChanged: (value) async {
              final doc = branches.firstWhere((d) => d.id == value);
              setState(() {
                _selectedBranchId = value;
                _selectedBranchName = (doc['branch_name'] ?? '').toString();
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
    );
  }

  Widget _buildFileCard() {
    final enabled = _selectedBranchId != null && !_isLoading;
    final hasFile = _fileName != null;

    final String title = _selectedBranchId == null
        ? 'Select a branch first'
        : (hasFile ? _fileName! : 'Choose Excel file');
    final String sub = _selectedBranchId == null
        ? 'The file is matched against the farmers of the chosen branch'
        : (hasFile
            ? 'Click to replace the file'
            : 'Click to browse · .xlsx only');

    return _stepCard(
      step: '2',
      title: 'Upload ledger',
      subtitle: 'Your ADVANCE LEDGER Excel file',
      done: hasFile && _rows.isNotEmpty,
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
                  if (enabled)
                    Icon(Icons.chevron_right, color: _green.withOpacity(0.7)),
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
                  value: _swapExcelDates,
                  activeColor: _green,
                  onChanged: (v) {
                    setState(() => _swapExcelDates = v);
                    if (_fileBytes != null) _parseLedger();
                  },
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
                        'them. Turn ON only if a date typed as 7/9/2026 (7 Sept) '
                        'shows in Excel as 9 July.',
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

  // ---------------------------------------------------------------------------
  // Summary + import button
  // ---------------------------------------------------------------------------

  Widget _buildSummary() {
    final needAttention = _rows.length - _readyCount;
    final names = _ledgerNames;
    final matchedFarmers = names.where((n) => _mapping[n] != null).length;

    return _stepCard(
      icon: Icons.dashboard_outlined,
      title: 'Summary',
      subtitle:
          'Compare the ledger total with the TOTAL at the bottom of your Excel sheet',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _kpi(
                icon: Icons.receipt_long_outlined,
                label: 'Advances in file',
                value: '${_rows.length}',
                sub: 'UGX ${_money.format(_allTotal)}',
                color: _info,
              ),
              _kpi(
                icon: Icons.check_circle_outline,
                label: 'Ready to import',
                value: '$_readyCount',
                sub: 'UGX ${_money.format(_readyTotal)}',
                color: _green,
              ),
              _kpi(
                icon: Icons.report_problem_outlined,
                label: 'Need attention',
                value: '$needAttention',
                sub: needAttention == 0 ? 'All good' : 'Fix below',
                color: needAttention == 0 ? _muted : _bad,
              ),
              _kpi(
                icon: Icons.groups_outlined,
                label: 'Farmers matched',
                value: '$matchedFarmers of ${names.length}',
                sub: matchedFarmers == names.length ? 'All matched' : 'Match below',
                color: matchedFarmers == names.length ? _green : _warn,
              ),
            ],
          ),
          const Divider(height: 32, color: _line),
          Row(
            children: [
              Expanded(
                child: Text(
                  needAttention == 0
                      ? 'Everything is ready to import.'
                      : '$needAttention advance(s) need attention and will be '
                          'skipped until fixed.',
                  style: const TextStyle(fontSize: 13.5, color: _muted),
                ),
              ),
              const SizedBox(width: 16),
              if (_isLoading)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(strokeWidth: 3),
                )
              else
                ElevatedButton.icon(
                  onPressed: _readyCount == 0 ? null : _importData,
                  icon: const Icon(Icons.upload, size: 20),
                  label: Text('Import $_readyCount advances'),
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
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 3: farmer matching
  // ---------------------------------------------------------------------------

  Widget _matchRow(String name) {
    final count = _rows.where((r) => r.ledgerName == name).length;
    final total = _rows
        .where((r) => r.ledgerName == name)
        .fold<double>(0, (s, r) => s + r.amount);
    final isMatched = _mapping[name] != null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(
            isMatched ? Icons.check_circle : Icons.help_outline,
            size: 20,
            color: isMatched ? _green : _bad,
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _ink)),
                Text('$count advance(s) · UGX ${_money.format(total)}',
                    style: const TextStyle(fontSize: 12, color: _muted)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: isMatched ? _line : _bad.withOpacity(0.5)),
              ),
              child: DropdownButtonHideUnderline(
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchingSection() {
    final names = _ledgerNames;
    final unmatched = names.where((n) => _mapping[n] == null).toList();
    final matched = names.where((n) => _mapping[n] != null).toList();

    return _stepCard(
      step: '3',
      title: 'Match farmers',
      subtitle: _farmers.isEmpty
          ? 'No farmers were found in this branch.'
          : 'Names are matched ignoring case, spacing and punctuation. '
              'Pick the right farmer for any name that was not recognised; '
              'unmatched names are not imported.',
      done: unmatched.isEmpty,
      trailing: _pill(
        '${matched.length} of ${names.length} matched',
        unmatched.isEmpty ? _green : _bad,
        icon: unmatched.isEmpty ? Icons.check : Icons.priority_high,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (unmatched.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _bad.withOpacity(0.25)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, bottom: 4),
                    child: Text('Not matched (${unmatched.length})',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: _bad)),
                  ),
                  ...unmatched.map(_matchRow),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle, size: 20, color: Colors.green[700]),
                  const SizedBox(width: 10),
                  const Text('All farmers in the ledger were matched',
                      style: TextStyle(fontSize: 14, color: _ink)),
                ],
              ),
            ),
          if (matched.isNotEmpty)
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 8),
                title: Text('Matched farmers (${matched.length}) · tap to review',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _ink)),
                children: matched.map(_matchRow).toList(),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Step 4: preview table
  // ---------------------------------------------------------------------------

  Widget _buildPreviewSection() {
    final issues = _rows.where((r) => !_isReady(r)).toList();
    final shown = _onlyIssues ? issues : _rows;

    Widget filterChip(String label, bool selected, VoidCallback onTap) {
      return ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: _green.withOpacity(0.15),
        labelStyle: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: selected ? _green : _muted,
        ),
        side: BorderSide(color: selected ? _green : _line),
        showCheckmark: false,
      );
    }

    return _stepCard(
      step: '4',
      title: 'Review advances',
      subtitle: 'Tap a date to correct it before importing',
      trailing: Wrap(
        spacing: 8,
        children: [
          filterChip('All (${_rows.length})', !_onlyIssues,
              () => setState(() => _onlyIssues = false)),
          filterChip('Needs attention (${issues.length})', _onlyIssues,
              () => setState(() => _onlyIssues = true)),
        ],
      ),
      child: shown.isEmpty
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 32),
              alignment: Alignment.center,
              child: const Text('No rows need attention.',
                  style: TextStyle(fontSize: 14, color: _muted)),
            )
          : Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _line),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 460),
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
                              DataColumn(label: Text('ROW')),
                              DataColumn(label: Text('FARMER (LEDGER)')),
                              DataColumn(label: Text('AMOUNT'), numeric: true),
                              DataColumn(label: Text('DATE')),
                              DataColumn(
                                  label: Text('RECOVERED'), numeric: true),
                              DataColumn(label: Text('STATUS')),
                            ],
                            rows: shown.map(_buildDataRow).toList(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  DataRow _buildDataRow(_AdvRow r) {
    final matched = _mapping[r.ledgerName] != null;
    Widget status;
    if (!matched) {
      status = _pill('No farmer match', _bad, icon: Icons.person_off_outlined);
    } else if (r.date == null) {
      status = _pill(r.dateIssue ?? 'Missing date', _bad,
          icon: Icons.event_busy_outlined);
    } else if (r.note != null) {
      status = _pill(r.note!, _warn, icon: Icons.warning_amber_rounded);
    } else {
      status = _pill('Ready', _green, icon: Icons.check);
    }

    return DataRow(
      color: _isReady(r) ? null : MaterialStateProperty.all(Colors.red[50]),
      cells: [
        DataCell(Text('${r.sheetRow}',
            style: const TextStyle(color: _muted, fontSize: 13))),
        DataCell(ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 280),
          child: Text(r.ledgerName,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, fontSize: 13.5, color: _ink)),
        )),
        DataCell(Text(_money.format(r.amount),
            style: const TextStyle(fontSize: 13.5, color: _ink))),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                  color: r.date == null ? _bad.withOpacity(0.6) : _line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  r.date != null ? _dateFmt.format(r.date!) : 'Set date',
                  style: TextStyle(
                    fontSize: 13,
                    color: r.date == null ? _bad : _ink,
                    fontWeight:
                        r.date == null ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.edit_calendar_outlined,
                    size: 15, color: _muted),
                if (r.fixedFrom != null) ...[
                  const SizedBox(width: 10),
                  Text(r.fixedFrom!,
                      style: const TextStyle(fontSize: 11.5, color: _warn)),
                ],
              ],
            ),
          ),
          onTap: () => _pickDate(r),
        ),
        DataCell(Text(r.recovered > 0 ? _money.format(r.recovered) : '–',
            style: const TextStyle(fontSize: 13.5, color: _ink))),
        DataCell(status),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Messages + success
  // ---------------------------------------------------------------------------

  Widget _buildMessagesCard({
    required String title,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required List<String> items,
    bool expanded = false,
  }) {
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
          key: ValueKey('$title-${items.length}'),
          initiallyExpanded: expanded,
          leading: Icon(icon, color: iconColor),
          title: Text('$title (${items.length})',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.w700, color: _ink)),
          subtitle: expanded
              ? null
              : const Text('Tap to view details',
                  style: TextStyle(fontSize: 12, color: _muted)),
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
                      fontSize: 13, fontStyle: FontStyle.italic, color: _muted)),
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
                  '${_duplicateCount > 0 ? ' · skipped $_duplicateCount already-imported duplicates' : ''}',
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
  // File picking
  // ---------------------------------------------------------------------------

  Future<void> _pickFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'], // the excel package cannot read old .xls
      );
      if (files == null || files.isEmpty) return;

      final file = files.first;
      final bytes = await file.readAsBytes();

      _fileBytes = bytes;
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
          fixedFrom: dateResult.fixedFrom,
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
        if (flipped != null) {
          final raw = _validDate(y, m, d);
          final changed = raw != null && (raw.day != flipped.day || raw.month != flipped.month);
          return _DateResult(
            flipped,
            null,
            changed ? 'Excel showed ${_dateFmt.format(raw!)}' : null,
          );
        }
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
      _showSnack('You are not signed in. Please sign out and sign in again.');
      _scrollTop();
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

      _showSnack(
        'Imported $imported advances'
        '${duplicates > 0 ? ' ($duplicates duplicates skipped)' : ''}',
        error: false,
      );
      _scrollTop();
    } catch (e, st) {
      debugPrint('Import error: $e\n$st');
      if (!mounted) return;
      setState(() {
        _errors = ['Import error: $e'];
        _isLoading = false;
      });
      _showSnack('Import failed: $e');
      _scrollTop();
    }
  }
}