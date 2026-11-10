import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/sms_service.dart';
import '../../../core/services/farmers_export_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/currency_formatter.dart';
import '../home/dashboard_home_new.dart' show DashPalette;
import 'farmer_details_screen.dart';

class _Farmer {
  final String id;
  final String name;
  final String phone;
  final String district;
  final String subcounty;
  final String parish;
  final String village;
  final String? branchId;
  final String? branchName;
  final double advances;
  final bool active;
  _Farmer(this.id, this.name, this.phone, this.district, this.subcounty,
      this.parish, this.village, this.branchId, this.branchName, this.advances, this.active);

  String get location {
    final parts = [village, parish, subcounty, district]
        .where((e) => e.isNotEmpty && e != 'N/A')
        .toList();
    return parts.isEmpty ? 'N/A' : parts.join(', ');
  }

  bool get hasPhone => phone.isNotEmpty && phone != 'N/A';
  String get initial => name.isNotEmpty ? name[0].toUpperCase() : '?';
}

/// Farmers Management Screen - View all registered farmers
class FarmersScreen extends StatefulWidget {
  const FarmersScreen({Key? key}) : super(key: key);

  @override
  State<FarmersScreen> createState() => _FarmersScreenState();
}

class _FarmersScreenState extends State<FarmersScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _query = '';

  // Created once so typing never re-subscribes the stream.
  late final Stream<QuerySnapshot> _farmersStream = AuthService.instance
      .applyBranchFilterToCollection(AppConstants.farmersCollection)
      .orderBy('name')
      .snapshots();

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _export(String type, List<_Farmer> list) async {
    final messenger = ScaffoldMessenger.of(context);
    if (list.isEmpty) {
      messenger.showSnackBar(
          const SnackBar(content: Text('There are no farmers to export.')));
      return;
    }
    try {
      final rows = list
          .map((f) => ExportFarmer(
                name: f.name,
                phone: f.phone,
                location: f.location,
                advances: f.advances,
                active: f.active,
              ))
          .toList();
      if (type == 'pdf') {
        await FarmersExportService.exportPdf(rows);
      } else {
        await FarmersExportService.exportExcel(rows);
      }
      messenger.showSnackBar(SnackBar(
        backgroundColor: DashPalette.greenDark,
        content: Text(
            'Exported ${rows.length} farmers as ${type == 'pdf' ? 'PDF' : 'Excel'}.'),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        backgroundColor: DashPalette.red,
        content: Text('Export failed: $e'),
      ));
    }
  }

  void _openDetails(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => FarmerDetailsScreen(farmerId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: StreamBuilder<QuerySnapshot>(
        stream: _farmersStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _message(Icons.error_outline_rounded,
                'Could not load farmers', '${snapshot.error}',
                color: DashPalette.red);
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(DashPalette.green),
              ),
            );
          }

          final all = (snapshot.data?.docs ?? []).map((doc) {
            final d = doc.data() as Map<String, dynamic>;
            return _Farmer(
              doc.id,
              (d['name'] ?? 'Unknown').toString(),
              (d['phone'] ?? 'N/A').toString(),
              (d['district'] ?? '').toString(),
              (d['subcounty'] ?? '').toString(),
              (d['parish'] ?? '').toString(),
              (d['village'] ?? '').toString(),
              (d['branch_id'] ?? '').toString(),
              (d['branch_name'] ?? '').toString(),
              (d['totalAdvances'] is num)
                  ? (d['totalAdvances'] as num).toDouble()
                  : 0.0,
              d['isActive'] ?? true,
            );
          }).toList();

          final farmers = all.where((f) {
            if (_query.isEmpty) return true;
            return f.name.toLowerCase().contains(_query) ||
                f.phone.toLowerCase().contains(_query) ||
                f.location.toLowerCase().contains(_query);
          }).toList();

          return LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 820;
            final compact = c.maxWidth < 560;
            final pad = compact ? 12.0 : 24.0;
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(pad, pad, pad, 96),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _stats(all, wide),
                  SizedBox(height: compact ? 14 : 20),
                  _searchBar(all.length, farmers, compact: compact),
                  const SizedBox(height: 16),
                  if (all.isEmpty)
                    _emptyCard(Icons.people_outline_rounded,
                        'No farmers registered yet',
                        'Tap the + button to add your first farmer.')
                  else if (farmers.isEmpty)
                    _emptyCard(Icons.search_off_rounded, 'No farmers found',
                        'Nothing matches "$_query". Try a different name or number.')
                  else
                    _table(farmers),
                ],
              ),
            );
          });
        },
      ),
    );
  }

  // ───────────────────────── Stats ─────────────────────────

  Widget _stats(List<_Farmer> all, bool wide) {
    final active = all.where((f) => f.active).length;
    final withAdv = all.where((f) => f.advances > 0).length;
    final totalAdv = all.fold<double>(0, (s, f) => s + f.advances);

    final tiles = [
      _statTile(Icons.groups_rounded, 'Total farmers', '${all.length}',
          DashPalette.green),
      _statTile(Icons.verified_user_outlined, 'Active', '$active',
          DashPalette.blue),
      _statTile(Icons.account_balance_wallet_outlined, 'With advances',
          '$withAdv', DashPalette.amber),
      _statTile(Icons.payments_outlined, 'Advances given',
          CurrencyFormatter.formatUGXCompact(totalAdv), DashPalette.red),
    ];

    if (wide) {
      return Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            Expanded(child: tiles[i]),
            if (i != tiles.length - 1) const SizedBox(width: 14),
          ],
        ],
      );
    }
    return Column(
      children: [
        Row(children: [
          Expanded(child: tiles[0]),
          const SizedBox(width: 12),
          Expanded(child: tiles[1]),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: tiles[2]),
          const SizedBox(width: 12),
          Expanded(child: tiles[3]),
        ]),
      ],
    );
  }

  Widget _statTile(IconData icon, String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DashPalette.line),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E2217).withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: DashPalette.muted)),
                const SizedBox(height: 2),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(value,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: DashPalette.ink)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Search ─────────────────────────

  Widget _searchBar(int total, List<_Farmer> shown, {bool compact = false}) {
    final field = TextField(
      key: const ValueKey('farmers-search'),
      controller: _searchController,
      focusNode: _searchFocus,
      style: const TextStyle(fontSize: 15, color: DashPalette.ink),
      decoration: InputDecoration(
        hintText: compact ? 'Search farmers' : 'Search by name, phone or location',
        hintStyle: const TextStyle(fontSize: 14, color: DashPalette.muted),
        prefixIcon: const Icon(Icons.search_rounded,
            color: DashPalette.green, size: 22),
        suffixIcon: IconButton(
          icon: Icon(Icons.close_rounded,
              size: 18,
              color: _query.isEmpty ? Colors.transparent : DashPalette.muted),
          onPressed: _query.isEmpty
              ? null
              : () {
                  _searchController.clear();
                  setState(() => _query = '');
                  _searchFocus.requestFocus();
                },
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 0),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DashPalette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DashPalette.green, width: 1.6),
        ),
      ),
      onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
    );

    final exportBtn = PopupMenuButton<String>(
      tooltip: 'Export farmers',
      offset: const Offset(0, 50),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (v) => _export(v, shown),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'pdf',
          child: Row(children: [
            Icon(Icons.picture_as_pdf_rounded, size: 20, color: DashPalette.red),
            SizedBox(width: 10),
            Text('Export as PDF',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
        PopupMenuItem(
          value: 'xlsx',
          child: Row(children: [
            Icon(Icons.table_chart_rounded,
                size: 20, color: DashPalette.greenDark),
            SizedBox(width: 10),
            Text('Export as Excel',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
          ]),
        ),
      ],
      child: Container(
        height: 46,
        padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 18),
        decoration: BoxDecoration(
          color: DashPalette.ink,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.file_download_outlined,
                size: 20, color: Colors.white),
            if (!compact) ...[
              const SizedBox(width: 8),
              const Text('Export',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: Colors.white),
            ],
          ],
        ),
      ),
    );

    final countStyle = const TextStyle(
        fontSize: 13.5, fontWeight: FontWeight.w600, color: DashPalette.muted);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: SizedBox(height: 46, child: field)),
            if (!compact) ...[
              const SizedBox(width: 14),
              Text('${shown.length} of $total', style: countStyle),
            ],
            const SizedBox(width: 12),
            exportBtn,
          ],
        ),
        if (compact) ...[
          const SizedBox(height: 8),
          Text('${shown.length} of $total farmers', style: countStyle),
        ],
      ],
    );
  }

  // ───────────────────────── Table / Cards ─────────────────────────

  // Column order: #, Farmer, Phone, Location, Branch, Advances, Status, Contact
  // Minimum pixel widths. Sum = 894, so the table needs >= 900px.
  static const _baseWidths = <double>[40, 150, 110, 140, 105, 125, 100, 124];
  // Columns that receive any extra space on wide screens.
  static const _growCols = <int>[1, 3, 4];
  static const _tableBreakpoint = 900.0;

  static const _th = TextStyle(
      fontSize: 13.5, fontWeight: FontWeight.w800, color: DashPalette.ink);

  List<double> _columnWidths(double available) {
    final w = List<double>.of(_baseWidths);
    final extra = available - w.reduce((a, b) => a + b);
    if (extra > 0) {
      final share = extra / _growCols.length;
      for (final i in _growCols) {
        w[i] += share;
      }
    }
    return w;
  }

  Widget _tableHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: DashPalette.greenSoft,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.groups_rounded,
                size: 18, color: DashPalette.greenDark),
          ),
          const SizedBox(width: 10),
          const Flexible(
            child: Text('Farmers Directory',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: DashPalette.ink)),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: DashPalette.greenSoft,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('$count',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: DashPalette.greenDark)),
          ),
        ],
      ),
    );
  }

  Widget _table(List<_Farmer> farmers) {
    final totalAdv = farmers.fold<double>(0, (s, f) => s + f.advances);

    return LayoutBuilder(builder: (context, c) {
      // ── Narrow screens: cards ──
      if (c.maxWidth < _tableBreakpoint) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _tableHeader(farmers.length),
            for (var i = 0; i < farmers.length; i++) ...[
              _farmerCard(farmers[i]),
              const SizedBox(height: 10),
            ],
            _totalCard(farmers.length, totalAdv),
          ],
        );
      }

      // ── Wide screens: table ──
      final widths = _columnWidths(c.maxWidth - 2); // minus border
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: DashPalette.border),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF0E2217).withOpacity(0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _tableHeader(farmers.length),
              const Divider(height: 1, color: DashPalette.border),
              _tableRow(
                widths: widths,
                header: true,
                cells: const [
                  Text('#', style: _th),
                  Text('Farmer', style: _th),
                  Text('Phone', style: _th),
                  Text('Location', style: _th),
                  Text('Branch', style: _th),
                  Text('Advances', maxLines: 1, style: _th),
                  Text('Status', maxLines: 1, style: _th),
                  Text('Contact', maxLines: 1, style: _th),
                ],
              ),
              for (var i = 0; i < farmers.length; i++)
                _farmerRow(farmers[i], i, widths),
              _tableRow(
                widths: widths,
                header: true,
                last: true,
                cells: [
                  const SizedBox.shrink(),
                  Text('Total (${farmers.length})',
                      maxLines: 1, overflow: TextOverflow.ellipsis, style: _th),
                  const SizedBox.shrink(),
                  const SizedBox.shrink(),
                  const SizedBox.shrink(),
                  Text(
                    totalAdv > 0 ? CurrencyFormatter.formatUGX(totalAdv) : '—',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _th.copyWith(color: DashPalette.red),
                  ),
                  const SizedBox.shrink(),
                  const SizedBox.shrink(),
                ],
              ),
            ],
          ),
        ),
      );
    });
  }

  Widget _tableRow({
    required List<Widget> cells,
    required List<double> widths,
    bool header = false,
    bool last = false,
    Color? bg,
    VoidCallback? onTap,
  }) {
    final row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cells.length; i++)
            Container(
              width: widths[i],
              alignment: Alignment.centerLeft,
              padding: EdgeInsets.symmetric(
                  horizontal: 10, vertical: header ? 13 : 12),
              decoration: BoxDecoration(
                border: Border(
                  right: i == cells.length - 1
                      ? BorderSide.none
                      : const BorderSide(color: DashPalette.border),
                ),
              ),
              child: cells[i],
            ),
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: header ? DashPalette.tableHead : (bg ?? Colors.white),
        border: Border(
          bottom: last
              ? BorderSide.none
              : const BorderSide(color: DashPalette.border),
        ),
      ),
      child: onTap == null
          ? row
          : Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                hoverColor: DashPalette.greenSoft.withOpacity(0.6),
                child: row,
              ),
            ),
    );
  }

  Widget _farmerRow(_Farmer f, int index, List<double> widths) {
    return _tableRow(
      widths: widths,
      bg: index.isOdd ? const Color(0xFFFAFCFB) : Colors.white,
      onTap: () => _openDetails(f.id),
      cells: [
        Text('${index + 1}',
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: DashPalette.muted)),
        Row(
          children: [
            _avatar(f, 32),
            const SizedBox(width: 10),
            Expanded(
              child: Text(f.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: DashPalette.ink)),
            ),
          ],
        ),
        Text(f.hasPhone ? f.phone : '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: DashPalette.ink)),
        Tooltip(
          message: f.location,
          child: Text(f.location,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: DashPalette.ink)),
        ),
        Text(f.branchName?.isNotEmpty == true ? f.branchName! : '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: DashPalette.greenDark)),
        f.advances > 0
            ? Text(CurrencyFormatter.formatUGX(f.advances),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: DashPalette.red))
            : const Text('—',
                style: TextStyle(fontSize: 14, color: DashPalette.muted)),
        FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: _statusBadge(f.active)),
        f.hasPhone
            ? FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: _actions(f, 30))
            : const Text('—',
                style: TextStyle(fontSize: 14, color: DashPalette.muted)),
      ],
    );
  }

  // ───────────────────────── Cards (narrow) ─────────────────────────

  Widget _farmerCard(_Farmer f) {
    Widget info(IconData icon, String text, {Color? color, FontWeight? w}) {
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 15, color: DashPalette.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: w ?? FontWeight.w500,
                      color: color ?? DashPalette.ink)),
            ),
          ],
        ),
      );
    }

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _openDetails(f.id),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: DashPalette.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _avatar(f, 40),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(f.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: DashPalette.ink)),
                  ),
                  const SizedBox(width: 8),
                  _statusBadge(f.active),
                ],
              ),
              const SizedBox(height: 6),
              info(Icons.phone_outlined, f.hasPhone ? f.phone : '—'),
              info(Icons.place_outlined, f.location),
              if (f.branchName?.isNotEmpty == true)
                info(Icons.store_mall_directory_outlined, f.branchName!,
                    color: DashPalette.greenDark, w: FontWeight.w600),
              const SizedBox(height: 10),
              const Divider(height: 1, color: DashPalette.border),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Advances',
                            style: TextStyle(
                                fontSize: 12, color: DashPalette.muted)),
                        const SizedBox(height: 2),
                        Text(
                          f.advances > 0
                              ? CurrencyFormatter.formatUGX(f.advances)
                              : '—',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: f.advances > 0
                                  ? DashPalette.red
                                  : DashPalette.muted),
                        ),
                      ],
                    ),
                  ),
                  if (f.hasPhone) _actions(f, 36),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _totalCard(int count, double totalAdv) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: DashPalette.tableHead,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: DashPalette.border),
      ),
      child: Row(
        children: [
          Expanded(child: Text('Total ($count)', style: _th)),
          Flexible(
            child: Text(
              totalAdv > 0 ? CurrencyFormatter.formatUGX(totalAdv) : '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _th.copyWith(color: DashPalette.red),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Shared bits ─────────────────────────

  Widget _actions(_Farmer f, double size) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _iconAction(Icons.call_rounded, DashPalette.blue, 'Call', size,
            () => SmsService.makeCall(phoneNumber: f.phone, context: context)),
        const SizedBox(width: 6),
        _iconAction(Icons.sms_rounded, DashPalette.greenDark, 'SMS', size,
            () => SmsService.sendSMS(phoneNumber: f.phone, context: context)),
        const SizedBox(width: 6),
        _iconAction(Icons.chat_rounded, const Color(0xFF1FA855), 'WhatsApp',
            size,
            () => SmsService.openWhatsApp(
                phoneNumber: f.phone, context: context)),
      ],
    );
  }

  Widget _iconAction(IconData icon, Color color, String tooltip, double size,
      VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Icon(icon, size: size * 0.5, color: color),
        ),
      ),
    );
  }

  Widget _avatar(_Farmer f, double size) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: f.active ? DashPalette.greenSoft : const Color(0xFFEEF1EF),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Text(f.initial,
          style: TextStyle(
              fontSize: size * 0.42,
              fontWeight: FontWeight.w800,
              color: f.active ? DashPalette.greenDark : DashPalette.muted)),
    );
  }

  Widget _statusBadge(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: active ? DashPalette.greenSoft : const Color(0xFFEEF1EF),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: active ? DashPalette.green : DashPalette.muted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(active ? 'Active' : 'Inactive',
              maxLines: 1,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: active ? DashPalette.greenDark : DashPalette.muted)),
        ],
      ),
    );
  }

  Widget _emptyCard(IconData icon, String title, String sub) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DashPalette.border),
      ),
      child: _message(icon, title, sub),
    );
  }

  Widget _message(IconData icon, String title, String sub,
      {Color color = DashPalette.green}) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: color),
          ),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: DashPalette.ink)),
          const SizedBox(height: 6),
          Text(sub,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: DashPalette.muted)),
        ],
      ),
    );
  }
}