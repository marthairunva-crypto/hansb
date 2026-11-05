import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/branch.dart';
import '../home/dashboard_home_new.dart' show DashPalette;

/// Branch statistics page (opens inside the dashboard content panel)
class BranchStatsScreen extends StatefulWidget {
  final Branch branch;

  const BranchStatsScreen({Key? key, required this.branch}) : super(key: key);

  @override
  State<BranchStatsScreen> createState() => _BranchStatsScreenState();
}

class _BranchStatsScreenState extends State<BranchStatsScreen> {
  Branch get branch => widget.branch;

  // Created once (not inside build) so it doesn't reload on every rebuild
  late Future<Map<String, dynamic>> _future = _loadStats();

  void _refresh() => setState(() => _future = _loadStats());

  static double _d(dynamic v) => v is num ? v.toDouble() : 0.0;

  Future<Map<String, dynamic>> _loadStats() async {
    final branchId = branch.id!;
    final db = FirebaseFirestore.instance;

    final farmersSnapshot = await db
        .collection(AppConstants.farmersCollection)
        .where('branch_id', isEqualTo: branchId)
        .get();

    final activeFarmers = farmersSnapshot.docs
        .where((d) => d.data()['isActive'] == true)
        .length;

    final purchasesSnapshot = await db
        .collection(AppConstants.purchasesCollection)
        .where('branch_id', isEqualTo: branchId)
        .get();

    double totalCoffee = 0;
    double totalValue = 0;
    double totalAdvancesRecovered = 0;

    for (final doc in purchasesSnapshot.docs) {
      final data = doc.data();
      totalCoffee += _d(data['payableWeight']);
      totalValue += _d(data['totalAmount']);
      totalAdvancesRecovered += _d(data['advanceAmount']);
    }

    final advancesSnapshot = await db
        .collection(AppConstants.advancesCollection)
        .where('branch_id', isEqualTo: branchId)
        .get();

    double totalAdvancesGiven = 0;
    double outstandingAdvances = 0;

    for (final doc in advancesSnapshot.docs) {
      final data = doc.data();
      totalAdvancesGiven += _d(data['amount']);
      if (data['status'] == 'active') {
        outstandingAdvances += _d(data['remainingAmount']);
      }
    }

    return {
      'totalFarmers': farmersSnapshot.docs.length,
      'activeFarmers': activeFarmers,
      'totalPurchases': purchasesSnapshot.docs.length,
      'totalCoffeeKg': totalCoffee,
      'totalValue': totalValue,
      'totalAdvancesGiven': totalAdvancesGiven,
      'totalAdvancesRecovered': totalAdvancesRecovered,
      'outstandingAdvances': outstandingAdvances,
      'avgPricePerKg': totalCoffee > 0 ? totalValue / totalCoffee : 0.0,
    };
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _header(),
          const Divider(height: 1, color: DashPalette.line),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(DashPalette.green),
                    ),
                  );
                }
                if (snapshot.hasError) return _error('${snapshot.error}');
                return _content(snapshot.data!);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Header ─────────────────────────

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
      child: Row(
        children: [
          _iconButton(Icons.arrow_back_rounded, 'Back',
              () => Navigator.maybePop(context)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  branch.branchName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    color: DashPalette.ink,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF1EF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        branch.branchCode,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: DashPalette.muted,
                        ),
                      ),
                    ),
                    if (branch.location != null &&
                        branch.location!.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      const Icon(Icons.location_on_outlined,
                          size: 15, color: DashPalette.muted),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          branch.location!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 13, color: DashPalette.muted),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _statusBadge(branch.isActive),
          const SizedBox(width: 12),
          _iconButton(Icons.refresh_rounded, 'Refresh', _refresh),
        ],
      ),
    );
  }

  Widget _iconButton(IconData icon, String tooltip, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: DashPalette.line),
          ),
          child: Icon(icon, size: 19, color: DashPalette.ink),
        ),
      ),
    );
  }

  // ───────────────────────── Content ─────────────────────────

  Widget _content(Map<String, dynamic> s) {
    return LayoutBuilder(builder: (context, c) {
      final wide = c.maxWidth >= 900;
      final pad = c.maxWidth < 560 ? 16.0 : 24.0;

      final coffee = _section(
        'Coffee performance',
        Icons.coffee_rounded,
        DashPalette.greenDark,
        [
          _row('Total purchases', '${s['totalPurchases']}'),
          _row('Coffee purchased', '${_fmt(_d(s['totalCoffeeKg']), 2)} kg'),
          _row('Average price / kg',
              CurrencyFormatter.formatUGX(_d(s['avgPricePerKg']))),
          _row('Total value',
              CurrencyFormatter.formatUGX(_d(s['totalValue'])),
              bold: true),
        ],
      );

      final farmers = _section(
        'Farmers',
        Icons.groups_rounded,
        DashPalette.blue,
        [
          _row('Total registered', '${s['totalFarmers']}'),
          _row('Active', '${s['activeFarmers']}',
              valueColor: DashPalette.greenDark),
          _row('Inactive', '${s['totalFarmers'] - s['activeFarmers']}'),
        ],
      );

      final given = _d(s['totalAdvancesGiven']);
      final recovered = _d(s['totalAdvancesRecovered']);
      final rate = given > 0 ? (recovered / given).clamp(0.0, 1.0) : 0.0;

      final advances = _section(
        'Advances & recoveries',
        Icons.account_balance_wallet_outlined,
        DashPalette.amber,
        [
          _row('Total given', CurrencyFormatter.formatUGX(given)),
          _row('Recovered', CurrencyFormatter.formatUGX(recovered),
              valueColor: DashPalette.greenDark),
          _row('Outstanding',
              CurrencyFormatter.formatUGX(_d(s['outstandingAdvances'])),
              valueColor: DashPalette.red, bold: true),
          _recovery(rate),
        ],
      );

      final details = _section(
        'Branch details',
        Icons.store_rounded,
        DashPalette.greenDark,
        [
          _row('Branch code', branch.branchCode),
          _row('Location',
              (branch.location?.isNotEmpty ?? false) ? branch.location! : '—'),
          _row('Phone',
              (branch.phone?.isNotEmpty ?? false) ? branch.phone! : '—'),
          _row('Status', branch.isActive ? 'Active' : 'Inactive',
              valueColor:
                  branch.isActive ? DashPalette.greenDark : DashPalette.muted),
        ],
      );

      final kpis = [
        _kpi('Total coffee', '${_fmt(_d(s['totalCoffeeKg']), 1)} kg',
            Icons.coffee_rounded, DashPalette.greenDark),
        _kpi('Total value',
            CurrencyFormatter.formatUGXCompact(_d(s['totalValue'])),
            Icons.payments_rounded, DashPalette.green),
        _kpi('Active farmers', '${s['activeFarmers']}', Icons.groups_rounded,
            DashPalette.blue),
        _kpi('Purchases', '${s['totalPurchases']}',
            Icons.receipt_long_rounded, DashPalette.amber),
      ];

      return SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // KPI cards
            if (wide)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < kpis.length; i++) ...[
                      Expanded(child: kpis[i]),
                      if (i != kpis.length - 1) const SizedBox(width: 14),
                    ],
                  ],
                ),
              )
            else
              Column(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: kpis[0]),
                        const SizedBox(width: 12),
                        Expanded(child: kpis[1]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: kpis[2]),
                        const SizedBox(width: 12),
                        Expanded(child: kpis[3]),
                      ],
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),

            // Sections
            if (wide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(children: [
                      coffee,
                      const SizedBox(height: 20),
                      farmers,
                    ]),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(children: [
                      advances,
                      const SizedBox(height: 20),
                      details,
                    ]),
                  ),
                ],
              )
            else ...[
              coffee,
              const SizedBox(height: 16),
              farmers,
              const SizedBox(height: 16),
              advances,
              const SizedBox(height: 16),
              details,
            ],
          ],
        ),
      );
    });
  }

  // ───────────────────────── Pieces ─────────────────────────

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: DashPalette.border),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E2217).withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      );

  Widget _kpi(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: DashPalette.muted,
                  ),
                ),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: DashPalette.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
      String title, IconData icon, Color color, List<Widget> rows) {
    return Container(
      width: double.infinity,
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: DashPalette.ink,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: DashPalette.border),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: DashPalette.border),
            rows[i],
          ],
        ],
      ),
    );
  }

  Widget _row(String label, String value,
      {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: DashPalette.muted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: bold ? 16 : 14.5,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w700,
                color: valueColor ?? DashPalette.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recovery(double rate) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recovery rate',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: DashPalette.muted,
                  ),
                ),
              ),
              Text(
                '${(rate * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: DashPalette.greenDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: rate,
              minHeight: 8,
              backgroundColor: DashPalette.greenSoft,
              valueColor: const AlwaysStoppedAnimation(DashPalette.green),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(bool active) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
          Text(
            active ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: active ? DashPalette.greenDark : DashPalette.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _error(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: DashPalette.red.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.error_outline_rounded,
                  size: 30, color: DashPalette.red),
            ),
            const SizedBox(height: 14),
            const Text(
              'Could not load branch statistics',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                color: DashPalette.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 13.5, color: DashPalette.muted),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _refresh,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: DashPalette.ink,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(num v, [int decimals = 0]) {
    final s = v.toStringAsFixed(decimals);
    final parts = s.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  }
}