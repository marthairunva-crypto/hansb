import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/services/auth_service.dart';
import '../purchases/add_purchase_screen.dart';
import '../farmers/add_farmer_screen.dart';

/// Shared colour tokens for the dashboard (used by the shell too).
class DashPalette {
  static const ink = Color(0xFF111A14);
  static const muted = Color(0xFF4F5C54);
  static const line = Color(0xFFE3E9E5);
  static const border = Color(0xFFCBD5CF);
  static const tableHead = Color(0xFFF1F6F2);
  static const green = Color(0xFF4CB82A);
  static const greenDark = Color(0xFF2E8B1A);
  static const greenSoft = Color(0xFFEAF7E4);
  static const sidebar = Color(0xFF0E2217);
  static const navActive = Color(0xFF2C4A37);
  static const outer = Color(0xFFECEDED);
  static const amber = Color(0xFFF2B93B);
  static const blue = Color(0xFF4A90E2);
  static const red = Color(0xFFE5484D);
  static const redSoft = Color(0xFFFDECEC);
}

String dashGreeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good Morning';
  if (h < 17) return 'Good Afternoon';
  return 'Good Evening';
}

double _num(dynamic v) => v is num ? v.toDouble() : 0.0;

class _Tx {
  final String farmer;
  final double kg;
  final double amount;
  final DateTime date;
  final bool voided;
  _Tx(this.farmer, this.kg, this.amount, this.date, this.voided);
}

class _Data {
  double revenue = 0;
  double kg = 0;
  int count = 0;
  int farmers = 0;
  List<double> monthly = List.filled(12, 0);
  List<double> daily = List.filled(14, 0);
  List<MapEntry<String, double>> top = [];
  List<_Tx> recent = [];
  double advOutstanding = 0;
  int advCount = 0;
  double allRevenue = 0;
}

/// Modern responsive dashboard home.
class DashboardHomeNew extends StatefulWidget {
  final ValueChanged<int>? onNavigate;
  const DashboardHomeNew({Key? key, this.onNavigate}) : super(key: key);

  @override
  State<DashboardHomeNew> createState() => _DashboardHomeNewState();
}

class _DashboardHomeNewState extends State<DashboardHomeNew> {
  String _period = 'All Time';
  bool _hide = false;

  // Streams are created once so changing the period / refreshing does not
  // re-subscribe (which made the numbers flash to zero).
  late final Stream<QuerySnapshot> _farmersStream = AuthService.instance
      .applyBranchFilterToCollection(AppConstants.farmersCollection)
      .snapshots();
  late final Stream<QuerySnapshot> _purchasesStream = AuthService.instance
      .applyBranchFilterToCollection(AppConstants.purchasesCollection)
      .snapshots();
  late final Stream<QuerySnapshot> _advancesStream = AuthService.instance
      .applyBranchFilterToCollection(AppConstants.advancesCollection)
      .snapshots();

  DateTime _startDate() {
    final now = DateTime.now();
    switch (_period) {
      case 'Today':
        return DateTime(now.year, now.month, now.day);
      case 'This Week':
        return DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
      case 'This Month':
        return DateTime(now.year, now.month, 1);
      default:
        return DateTime(2000);
    }
  }

  _Data _compute(QuerySnapshot? purchases, QuerySnapshot? advances, int farmers) {
    final d = _Data()..farmers = farmers;
    final now = DateTime.now();
    final start = _startDate();
    final all = <_Tx>[];

    if (purchases != null) {
      for (final doc in purchases.docs) {
        final m = doc.data() as Map<String, dynamic>;
        final ts = m['createdAt'];
        final date =
            ts is Timestamp ? ts.toDate() : DateTime.fromMillisecondsSinceEpoch(0);
        all.add(_Tx(
          (m['farmerName'] ?? 'Unknown').toString(),
          _num(m['payableWeight']),
          _num(m['netPayment']),
          date,
          (m['status'] ?? 'active') == 'voided',
        ));
      }
    }
    all.sort((a, b) => b.date.compareTo(a.date));
    d.recent = all.take(5).toList();

    final active = all.where((t) => !t.voided).toList();
    final byFarmer = <String, double>{};

    for (final t in active) {
      d.allRevenue += t.amount;
      if (t.date.year == now.year && t.date.millisecondsSinceEpoch > 0) {
        d.monthly[t.date.month - 1] += math.max(0, t.amount);
      }
      final inPeriod = _period == 'All Time' || !t.date.isBefore(start);
      if (inPeriod) {
        d.count++;
        d.kg += t.kg;
        d.revenue += t.amount;
        byFarmer[t.farmer] = (byFarmer[t.farmer] ?? 0) + t.kg;
      }
    }

    final today = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < 14; i++) {
      final day = today.subtract(Duration(days: 13 - i));
      for (final t in active) {
        if (t.date.year == day.year &&
            t.date.month == day.month &&
            t.date.day == day.day) {
          d.daily[i] += t.kg;
        }
      }
    }

    d.top = byFarmer.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    if (advances != null) {
      for (final doc in advances.docs) {
        final m = doc.data() as Map<String, dynamic>;
        if (m['status'] == 'active') {
          d.advCount++;
          d.advOutstanding += _num(m['remainingAmount']);
        }
      }
    }
    return d;
  }

  void _go(int i) => widget.onNavigate?.call(i);

  void _push(Widget w) => showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 700,
              maxHeight: MediaQuery.of(context).size.height * 0.92,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Container(
                color: Colors.white,
                child: w,
              ),
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: _farmersStream,
      builder: (context, fs) {
        return StreamBuilder<QuerySnapshot>(
          stream: _purchasesStream,
          builder: (context, ps) {
            return StreamBuilder<QuerySnapshot>(
              stream: _advancesStream,
              builder: (context, adv) {
                final data = _compute(
                  ps.data,
                  adv.data,
                  fs.hasData ? fs.data!.docs.length : 0,
                );
                return _layout(data);
              },
            );
          },
        );
      },
    );
  }

  Widget _layout(_Data d) {
    return LayoutBuilder(builder: (context, c) {
      final ultra = c.maxWidth >= 1200;
      final wide = c.maxWidth >= 900;
      final narrow = c.maxWidth < 560;
      final pad = narrow ? 16.0 : 24.0;

      // ── Desktop: 3-column grid that fits one screen ──
      if (ultra) {
        final fit = c.maxHeight >= 780;
        final rowA = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 6, child: _hero(d)),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: _volumeCard(d)),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: _advancesCard(d)),
          ],
        );
        final rowB = Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 6, child: _monthlyCard(d, false, fill: true)),
            const SizedBox(width: 16),
            Expanded(flex: 4, child: _topFarmersCard(d, fill: true)),
            const SizedBox(width: 16),
            Expanded(flex: 5, child: _activityCard(d, fill: true)),
          ],
        );
        if (fit) {
          return Padding(
            padding: EdgeInsets.all(pad),
            child: Column(
              children: [
                _topBar(true),
                const SizedBox(height: 14),
                SizedBox(height: 206, child: rowA),
                const SizedBox(height: 16),
                Expanded(child: rowB),
                const SizedBox(height: 16),
                _footer(),
              ],
            ),
          );
        }
        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Column(
            children: [
              _topBar(true),
              const SizedBox(height: 14),
              SizedBox(height: 206, child: rowA),
              const SizedBox(height: 16),
              SizedBox(height: 500, child: rowB),
              const SizedBox(height: 24),
              _footer(),
            ],
          ),
        );
      }

      // ── Tablet / mobile ──
      final left = <Widget>[
        _hero(d),
        const SizedBox(height: 16),
        _volumeCard(d),
        const SizedBox(height: 16),
        _monthlyCard(d, narrow),
      ];
      final right = <Widget>[
        _topFarmersCard(d),
        const SizedBox(height: 16),
        _activityCard(d),
        const SizedBox(height: 16),
        _advancesCard(d),
      ];

      return SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: SizedBox(
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!wide) ...[
                Text('${dashGreeting()}, Admin',
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: DashPalette.ink)),
                const SizedBox(height: 14),
              ],
              _topBar(wide),
              const SizedBox(height: 18),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 11, child: Column(children: left)),
                    const SizedBox(width: 16),
                    Expanded(flex: 9, child: Column(children: right)),
                  ],
                )
              else
                Column(children: [...left, const SizedBox(height: 16), ...right]),
              const SizedBox(height: 24),
              _footer(),
            ],
          ),
        ),
      );
    });
  }

  // ───────────────────────── Top bar ─────────────────────────

  Widget _topBar(bool wide) {
    final date = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Today ${DateFormat('dd MMM yyyy').format(DateTime.now())}',
          style: const TextStyle(
              fontSize: 14, color: DashPalette.ink, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        InkWell(
          onTap: () => setState(() {}),
          borderRadius: BorderRadius.circular(20),
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: Icon(Icons.refresh_rounded, size: 17, color: DashPalette.green),
          ),
        ),
      ],
    );

    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _periodDropdown(),
        const SizedBox(width: 8),
        _ghostBtn(Icons.people_outline_rounded, 'Farmers', () => _go(1)),
        const SizedBox(width: 8),
        _ghostBtn(Icons.receipt_long_outlined, 'Transactions', () => _go(2)),
        const SizedBox(width: 8),
        _ghostBtn(Icons.inventory_2_outlined, 'Inventory', () => _go(3)),
      ],
    );

    if (wide) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [date, actions],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        date,
        const SizedBox(height: 12),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: actions),
      ],
    );
  }

  Widget _periodDropdown() {
    return Container(
      height: 38,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: DashPalette.line),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _period,
          isDense: true,
          icon: const Icon(Icons.keyboard_arrow_down_rounded,
              size: 18, color: DashPalette.muted),
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: DashPalette.ink),
          items: const ['Today', 'This Week', 'This Month', 'All Time']
              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
              .toList(),
          onChanged: (v) => setState(() => _period = v ?? 'All Time'),
        ),
      ),
    );
  }

  // ───────────────────────── Cards ─────────────────────────

  Widget _card({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
  }) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: DashPalette.line),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0E2217).withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _cardHeader(String title, {Widget? trailing, IconData? icon}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: DashPalette.greenSoft,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: DashPalette.greenDark),
                ),
                const SizedBox(width: 10),
              ],
              Flexible(
                child: Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: DashPalette.ink)),
              ),
            ],
          ),
        ),
        if (trailing != null) trailing,
      ],
    );
  }

  Widget _arrowBtn(VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: DashPalette.ink,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.north_east_rounded, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: DashPalette.line),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500, color: DashPalette.ink)),
    );
  }

  Widget _badge(String text, {bool positive = true}) {
    final fg = positive ? DashPalette.greenDark : DashPalette.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: positive ? DashPalette.greenSoft : DashPalette.redSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(positive ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
              size: 12, color: fg),
          const SizedBox(width: 3),
          Text(text,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w600, color: fg)),
        ],
      ),
    );
  }

  Widget _ghostBtn(IconData icon, String label, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: DashPalette.ink),
      label: Text(label,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w500, color: DashPalette.ink)),
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.white,
        side: const BorderSide(color: DashPalette.line),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        minimumSize: const Size(0, 38),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _darkBtn(IconData icon, String label, VoidCallback onTap) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16, color: Colors.white),
      label: Text(label,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: DashPalette.ink,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        minimumSize: const Size(0, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ───────────────────────── Hero ─────────────────────────

  Widget _hero(_Data d) {
    final amount = _hide ? 'UGX ••••••' : CurrencyFormatter.formatUGX(d.revenue);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: DashPalette.green, width: 1.6),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Colors.white, Color(0xFFF0FAEA)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Coffee Business, Every Day',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: DashPalette.ink)),
          const SizedBox(height: 4),
          const Text(
            'A complete overview of your purchases, farmers and payments.',
            style: TextStyle(fontSize: 13, color: DashPalette.muted),
          ),
          const SizedBox(height: 18),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(amount,
                                style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w700,
                                    color: DashPalette.ink,
                                    height: 1.1)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => setState(() => _hide = !_hide),
                          borderRadius: BorderRadius.circular(20),
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              _hide
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              size: 18,
                              color: DashPalette.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        _ghostBtn(Icons.add_rounded, 'New Purchase',
                            () => _push(const AddPurchaseScreen())),
                        _darkBtn(Icons.person_add_alt_1_rounded, 'Add Farmer',
                            () => _push(const AddFarmerScreen())),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _badge('${d.count} purchases'),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 80,
                    height: 60,
                    child: CustomPaint(
                        painter: _PixelPainter(d.daily.sublist(6))),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Volume (area chart) ─────────────────────────

  Widget _volumeCard(_Data d) {
    final kg = NumberFormat('#,##0').format(d.kg);
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader('Purchase Volume', icon: Icons.scale_rounded, trailing: _arrowBtn(() => _go(3))),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$kg kg',
                      style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: DashPalette.ink)),
                  const SizedBox(height: 8),
                  _badge('${d.farmers} farmers'),
                ],
              ),
              const SizedBox(width: 18),
              Expanded(
                child: SizedBox(
                  height: 70,
                  child: CustomPaint(painter: _AreaPainter(d.daily)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('Last 14 days',
              style: TextStyle(fontSize: 12, color: DashPalette.muted)),
        ],
      ),
    );
  }

  // ───────────────────────── Monthly bars ─────────────────────────

  Widget _monthlyCard(_Data d, bool narrow, {bool fill = false}) {
    final chart = SizedBox(
      width: double.infinity,
      height: fill ? null : (narrow ? 220 : 270),
      child: CustomPaint(
        painter: _BarsPainter(d.monthly, DateTime.now().month - 1),
      ),
    );
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader('Monthly Purchases',
              icon: Icons.bar_chart_rounded,
              trailing: _pill('${DateTime.now().year}')),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                    color: DashPalette.green, shape: BoxShape.circle),
              ),
              const SizedBox(width: 6),
              const Text('Revenue (UGX)',
                  style: TextStyle(fontSize: 13, color: DashPalette.muted)),
            ],
          ),
          const SizedBox(height: 14),
          if (fill) Expanded(child: chart) else chart,
        ],
      ),
    );
  }

  // ───────────────────────── Top farmers (doughnut) ─────────────────────────

  Widget _topFarmersCard(_Data d, {bool fill = false}) {
    final colors = [
      DashPalette.green,
      DashPalette.amber,
      DashPalette.blue,
      const Color(0xFFB8C2BC),
    ];
    final segs = <MapEntry<String, double>>[];
    for (var i = 0; i < d.top.length && i < 3; i++) {
      segs.add(d.top[i]);
    }
    if (d.top.length > 3) {
      final others = d.top.skip(3).fold<double>(0, (s, e) => s + e.value);
      segs.add(MapEntry('Others', others));
    }
    final total = d.kg;
    final hasData = segs.isNotEmpty && total > 0;

    final body = Column(
      children: [
        Center(
          child: SizedBox(
            width: 170,
            height: 170,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(170),
                  painter: _DonutPainter(
                    hasData ? segs.map((e) => e.value).toList() : const [],
                    colors,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(NumberFormat('#,##0').format(d.kg),
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: DashPalette.ink)),
                    const Text('kg supplied',
                        style: TextStyle(fontSize: 13, color: DashPalette.muted)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (!hasData)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('No purchases in this period',
                style: TextStyle(fontSize: 14, color: DashPalette.muted)),
          )
        else
          for (var i = 0; i < segs.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: const Color(0xFFF7FAF8),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: DashPalette.line),
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration:
                        BoxDecoration(color: colors[i], shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(segs[i].key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: DashPalette.ink)),
                  ),
                  Text('${NumberFormat('#,##0').format(segs[i].value)} kg',
                      style: const TextStyle(
                          fontSize: 13, color: DashPalette.muted)),
                  const SizedBox(width: 10),
                  Text('${(segs[i].value / total * 100).round()}%',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: DashPalette.ink)),
                ],
              ),
            ),
      ],
    );

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader('Top Farmers',
              icon: Icons.groups_rounded,
              trailing: _arrowBtn(() => _go(1))),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 2),
            child: Text(_period,
                style: const TextStyle(fontSize: 13, color: DashPalette.muted)),
          ),
          const SizedBox(height: 12),
          if (fill) Expanded(child: SingleChildScrollView(child: body)) else body,
        ],
      ),
    );
  }

  // ───────────────────────── Recent activity ─────────────────────────

  Widget _activityCard(_Data d, {bool fill = false}) {
    final box = Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: DashPalette.border),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: d.recent.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 28, horizontal: 16),
                child: Center(
                  child: Text(
                    'No transactions yet. Record a purchase to see it here.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: DashPalette.muted),
                  ),
                ),
              )
            : Table(
                columnWidths: const {
                  0: FlexColumnWidth(5),
                  1: FlexColumnWidth(3),
                  2: FlexColumnWidth(4),
                },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                border: const TableBorder(
                  horizontalInside: BorderSide(color: DashPalette.border),
                  verticalInside: BorderSide(color: DashPalette.border),
                ),
                children: [
                  TableRow(
                    decoration: const BoxDecoration(color: DashPalette.tableHead),
                    children: [
                      _th('Name'),
                      _th('Date'),
                      _th('Amount', right: true),
                    ],
                  ),
                  for (final t in d.recent) _activityRow(t),
                ],
              ),
      ),
    );
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader('Recent Activity',
              icon: Icons.receipt_long_rounded,
              trailing: _arrowBtn(() => _go(2))),
          const SizedBox(height: 14),
          if (fill) Expanded(child: SingleChildScrollView(child: box)) else box,
        ],
      ),
    );
  }

  Widget _th(String text, {bool right = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Text(
        text,
        textAlign: right ? TextAlign.right : TextAlign.left,
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
          color: DashPalette.ink,
        ),
      ),
    );
  }

  TableRow _activityRow(_Tx t) {
    final dateText = t.date.millisecondsSinceEpoch == 0
        ? 'N/A'
        : DateFormat('dd MMM').format(t.date);
    final initial = t.farmer.isNotEmpty ? t.farmer[0].toUpperCase() : '?';
    return TableRow(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: DashPalette.greenSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(initial,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: DashPalette.greenDark)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(t.farmer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: DashPalette.ink)),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Text(dateText,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: DashPalette.ink)),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                CurrencyFormatter.formatUGXCompact(t.amount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: t.voided ? DashPalette.muted : DashPalette.ink,
                  decoration: t.voided ? TextDecoration.lineThrough : null,
                ),
              ),
              if (t.voided)
                const Text('Void',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: DashPalette.red)),
            ],
          ),
        ),
      ],
    );
  }

  // ───────────────────────── Advances ─────────────────────────

  Widget _advancesCard(_Data d) {
    final ratio = d.allRevenue > 0
        ? (d.advOutstanding / d.allRevenue).clamp(0.0, 1.0)
        : 0.0;
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader('Farmer Advances',
              icon: Icons.payments_outlined, trailing: _pill('Outstanding')),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _miniTile(
                  color: DashPalette.green,
                  label: 'Total outstanding',
                  value: CurrencyFormatter.formatUGXCompact(d.advOutstanding),
                  progress: ratio,
                  footnote: '${(ratio * 100).round()}% of total paid',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _miniTile(
                  color: DashPalette.amber,
                  label: 'Active advances',
                  value: '${d.advCount}',
                  progress: null,
                  footnote: 'Currently open',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniTile({
    required Color color,
    required String label,
    required String value,
    required double? progress,
    required String footnote,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12.5, color: DashPalette.muted)),
          const SizedBox(height: 6),
          Text(value,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: DashPalette.ink)),
          const SizedBox(height: 8),
          if (progress != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: const Color(0xFFEEF1EF),
                valueColor: AlwaysStoppedAnimation(color),
              ),
            )
          else
            const SizedBox(height: 6),
          const SizedBox(height: 6),
          Text(footnote,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, color: DashPalette.muted)),
        ],
      ),
    );
  }

  // ───────────────────────── Footer ─────────────────────────

  Widget _footer() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: RichText(
          text: const TextSpan(
            style: TextStyle(
              fontSize: 16,
              color: DashPalette.muted,
              height: 1.4,
            ),
            children: [
              TextSpan(text: 'Powered by '),
              TextSpan(
                text: 'Infinitech Innovations LTD',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: DashPalette.green,
                ),
              ),
              TextSpan(text: ' • Version 1.0.0'),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════ Painters ═════════════════════════

void _drawText(
  Canvas canvas,
  String text,
  Offset at, {
  double size = 11.5,
  Color color = DashPalette.muted,
  TextAlign align = TextAlign.left,
  double maxWidth = 80,
  bool centerY = false,
}) {
  final tp = TextPainter(
    text: TextSpan(text: text, style: TextStyle(fontSize: size, color: color)),
    textDirection: TextDirection.ltr,
    textAlign: align,
  )..layout(maxWidth: maxWidth);
  var dx = at.dx;
  if (align == TextAlign.center) dx -= tp.width / 2;
  if (align == TextAlign.right) dx -= tp.width;
  final dy = centerY ? at.dy - tp.height / 2 : at.dy;
  tp.paint(canvas, Offset(dx, dy));
}

String _compactNum(double v) {
  String trim(double x) {
    final s = x.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  if (v >= 1e9) return '${trim(v / 1e9)}B';
  if (v >= 1e6) return '${trim(v / 1e6)}M';
  if (v >= 1e3) return '${trim(v / 1e3)}K';
  return v.toStringAsFixed(0);
}

class _AreaPainter extends CustomPainter {
  final List<double> values;
  _AreaPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxV = values.reduce(math.max);
    final top = size.height * 0.1;
    final usable = size.height * 0.85;
    final step = size.width / (values.length - 1);

    final pts = <Offset>[
      for (var i = 0; i < values.length; i++)
        Offset(
          i * step,
          maxV <= 0 ? size.height - 2 : top + usable * (1 - values[i] / maxV),
        ),
    ];

    final line = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final mid = (pts[i - 1].dx + pts[i].dx) / 2;
      line.cubicTo(mid, pts[i - 1].dy, mid, pts[i].dy, pts[i].dx, pts[i].dy);
    }

    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            DashPalette.green.withOpacity(0.38),
            DashPalette.green.withOpacity(0.0),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = DashPalette.green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _AreaPainter old) => true;
}

class _PixelPainter extends CustomPainter {
  final List<double> values; // 8 values
  _PixelPainter(this.values);

  @override
  void paint(Canvas canvas, Size size) {
    const rows = 6;
    const cell = 8.0;
    const gap = 2.0;
    final maxV = values.isEmpty ? 0.0 : values.reduce(math.max);
    for (var i = 0; i < values.length; i++) {
      var n = maxV > 0 ? (values[i] / maxV * rows).ceil() : 0;
      if (values[i] > 0 && n < 1) n = 1;
      for (var j = 0; j < n; j++) {
        final x = i * (cell + gap);
        final y = size.height - (j + 1) * (cell + gap) + gap;
        final alpha = 1.0 - j * 0.14;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(x, y, cell, cell), const Radius.circular(2)),
          Paint()..color = DashPalette.green.withOpacity(alpha.clamp(0.2, 1.0)),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PixelPainter old) => true;
}

class _BarsPainter extends CustomPainter {
  final List<double> values; // 12 months
  final int currentMonth;
  _BarsPainter(this.values, this.currentMonth);

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  void paint(Canvas canvas, Size size) {
    const leftPad = 40.0;
    const bottomPad = 24.0;
    final chartH = size.height - bottomPad;
    final chartW = size.width - leftPad;

    var maxV = values.reduce(math.max);
    if (maxV <= 0) maxV = 1;
    // round the axis max up to a "nice" number
    final mag = math.pow(10, (math.log(maxV) / math.ln10).floor()).toDouble();
    final norm = maxV / mag;
    final nice = (norm <= 1 ? 1 : norm <= 2 ? 2 : norm <= 5 ? 5 : 10) * mag;

    final grid = Paint()
      ..color = DashPalette.line
      ..strokeWidth = 1;
    for (var i = 0; i <= 4; i++) {
      final y = chartH - chartH * (i / 4);
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), grid);
      _drawText(canvas, _compactNum(nice * i / 4), Offset(leftPad - 8, y),
          align: TextAlign.right, maxWidth: leftPad - 8, centerY: true);
    }

    final slot = chartW / 12;
    final barW = math.min(slot * 0.58, 26.0);
    final short = slot < 30;

    for (var i = 0; i < 12; i++) {
      final cx = leftPad + slot * i + slot / 2;
      final h = chartH * (values[i] / nice);
      final isFuture = i > currentMonth;
      final color = i == currentMonth
          ? DashPalette.greenDark
          : isFuture
              ? DashPalette.green.withOpacity(0.15)
              : DashPalette.green;
      final barH = math.max(h, values[i] > 0 ? 3.0 : 0.0);
      if (barH > 0) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(cx - barW / 2, chartH - barH, barW, barH),
            topLeft: const Radius.circular(5),
            topRight: const Radius.circular(5),
          ),
          Paint()..color = color,
        );
      } else if (isFuture) {
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(cx - barW / 2, chartH - 4, barW, 4),
            topLeft: const Radius.circular(3),
            topRight: const Radius.circular(3),
          ),
          Paint()..color = DashPalette.green.withOpacity(0.15),
        );
      }
      _drawText(
        canvas,
        short ? _months[i][0] : _months[i],
        Offset(cx, chartH + 8),
        align: TextAlign.center,
        maxWidth: slot + 8,
        color: i == currentMonth ? DashPalette.ink : DashPalette.muted,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BarsPainter old) => true;
}

class _DonutPainter extends CustomPainter {
  final List<double> values;
  final List<Color> colors;
  _DonutPainter(this.values, this.colors);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 22.0;
    final rect = Offset(stroke / 2, stroke / 2) &
        Size(size.width - stroke, size.height - stroke);
    final total = values.fold<double>(0, (a, b) => a + b);

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = const Color(0xFFE9EEEB);

    if (total <= 0) {
      canvas.drawArc(rect, 0, math.pi * 2, false, base);
      return;
    }

    final gap = values.length > 1 ? 0.06 : 0.0;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final full = values[i] / total * math.pi * 2;
      final sweep = full - gap;
      if (sweep > 0) {
        canvas.drawArc(
          rect,
          start + gap / 2,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.butt
            ..color = colors[i % colors.length],
        );
      }
      start += full;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) => true;
}