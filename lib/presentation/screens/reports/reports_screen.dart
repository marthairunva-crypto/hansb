import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../home/dashboard_home_new.dart' show DashPalette;

/// Reports - revenue, weight, top farmers for Today / Week / Month / All Time.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({Key? key}) : super(key: key);

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

// ───────────────────────── Data models ─────────────────────────

class _Point {
  final String label;
  final double value;
  const _Point(this.label, this.value);
}

class _FarmerStat {
  final String name;
  double weight = 0;
  double revenue = 0;
  int count = 0;
  _FarmerStat(this.name);
}

class _ReportData {
  final double revenue;
  final double weight;
  final double advances;
  final int count;
  final String seriesCaption;
  final List<_Point> revenueSeries;
  final List<_Point> weightSeries;
  final List<_FarmerStat> topFarmers;

  const _ReportData({
    required this.revenue,
    required this.weight,
    required this.advances,
    required this.count,
    required this.seriesCaption,
    required this.revenueSeries,
    required this.weightSeries,
    required this.topFarmers,
  });
}

class _Row {
  final DateTime date;
  final double net;
  final double weight;
  final double advance;
  final String farmerId;
  final String farmerName;
  const _Row(this.date, this.net, this.weight, this.advance, this.farmerId,
      this.farmerName);
}

class _ReportsScreenState extends State<ReportsScreen> {
  static const _periods = ['Today', 'This Week', 'This Month', 'All Time'];

  /// Revenue targets used by the performance gauge. Edit to suit your business.
  static const Map<String, double> _targets = {
    'Today': 10000000,
    'This Week': 10000000,
    'This Month': 10000000,
    'All Time': 10000000,
  };

  static const Color _purple = Color(0xFF8E44AD);

  String _period = 'Today';

  late final Stream<QuerySnapshot> _stream;
  QuerySnapshot? _lastSnap;
  String? _lastPeriod;
  _ReportData? _data;

  @override
  void initState() {
    super.initState();
    _stream = AuthService.instance
        .applyBranchFilterToCollection(AppConstants.purchasesCollection)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: LayoutBuilder(builder: (context, c) {
        final compact = c.maxWidth < 560;
        final wide = c.maxWidth >= 1000;
        final pad = compact ? 16.0 : 24.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pad, pad, pad, 20),
              child: _header(wide),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _stateView(Icons.error_outline_rounded,
                        'Error loading reports', 'Please try again later.');
                  }
                  final snap = snapshot.data;
                  if (snap == null) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(DashPalette.green),
                      ),
                    );
                  }
                  if (snap.docs.isEmpty) {
                    return _stateView(Icons.analytics_outlined,
                        'No purchase data yet',
                        'Purchases you record will show up here.');
                  }

                  if (!identical(snap, _lastSnap) || _lastPeriod != _period) {
                    _data = _compute(snap.docs);
                    _lastSnap = snap;
                    _lastPeriod = _period;
                  }
                  final d = _data!;

                  if (d.count == 0) {
                    return _stateView(Icons.inbox_outlined,
                        'No purchases for $_period',
                        'Try a different period.');
                  }

                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
                    child: Column(
                      children: [
                        _statsSection(d, wide, compact),
                        const SizedBox(height: 20),
                        if (wide) ...[
                          SizedBox(
                            height: 380,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 2, child: _revenueCard(d, true)),
                                const SizedBox(width: 20),
                                Expanded(flex: 1, child: _gaugeCard(d, true)),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 400,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(flex: 2, child: _weightCard(d, true)),
                                const SizedBox(width: 20),
                                Expanded(flex: 1, child: _farmersCard(d, true)),
                              ],
                            ),
                          ),
                        ] else ...[
                          _revenueCard(d, false),
                          const SizedBox(height: 20),
                          _gaugeCard(d, false),
                          const SizedBox(height: 20),
                          _weightCard(d, false),
                          const SizedBox(height: 20),
                          _farmersCard(d, false),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }

  // ───────────────────────── Header ─────────────────────────

  Widget _header(bool wide) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Reports',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: DashPalette.ink,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          'Purchase performance - ${_periodRange()}',
          style: const TextStyle(fontSize: 13.5, color: DashPalette.muted),
        ),
      ],
    );

    final pills = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final p in _periods) _periodPill(p)],
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [Expanded(child: title), pills],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [title, const SizedBox(height: 14), pills],
    );
  }

  Widget _periodPill(String label) {
    final selected = _period == label;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _period = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? DashPalette.green : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? DashPalette.green : DashPalette.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? Colors.white : DashPalette.muted,
          ),
        ),
      ),
    );
  }

  String _periodRange() {
    final now = DateTime.now();
    final f = DateFormat('d MMM yyyy');
    switch (_period) {
      case 'Today':
        return DateFormat('EEEE, d MMM yyyy').format(now);
      case 'This Week':
        final start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1));
        return '${f.format(start)} to ${f.format(start.add(const Duration(days: 6)))}';
      case 'This Month':
        return DateFormat('MMMM yyyy').format(now);
      default:
        return 'Everything recorded';
    }
  }

  // ───────────────────────── Computation ─────────────────────────

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  _ReportData _compute(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);

    bool inPeriod(DateTime d) {
      switch (_period) {
        case 'Today':
          return !d.isBefore(today);
        case 'This Week':
          return !d.isBefore(weekStart);
        case 'This Month':
          return !d.isBefore(monthStart);
        default:
          return true;
      }
    }

    final rows = <_Row>[];
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      if ((data['status'] ?? 'active') == 'voided') continue;
      final ts = data['createdAt'];
      if (ts is! Timestamp) continue;
      final date = ts.toDate();
      if (!inPeriod(date)) continue;
      rows.add(_Row(
        date,
        _toDouble(data['netPayment']),
        _toDouble(data['payableWeight']),
        _toDouble(data['advanceAmount']),
        (data['farmerId'] ?? '').toString(),
        (data['farmerName'] ?? 'Unknown').toString(),
      ));
    }

    double revenue = 0, weight = 0, advances = 0;
    final farmers = <String, _FarmerStat>{};
    for (final r in rows) {
      revenue += r.net;
      weight += r.weight;
      advances += r.advance;
      if (r.farmerId.isNotEmpty) {
        final f = farmers.putIfAbsent(r.farmerId, () => _FarmerStat(r.farmerName));
        f.weight += r.weight;
        f.revenue += r.net;
        f.count += 1;
      }
    }

    // Chart buckets
    late List<String> labels;
    late int Function(DateTime) bucketOf;
    late String caption;

    switch (_period) {
      case 'Today':
        labels = [for (var h = 0; h < 24; h += 2) '${h.toString().padLeft(2, '0')}h'];
        bucketOf = (d) => d.hour ~/ 2;
        caption = 'Per 2-hour period';
        break;
      case 'This Week':
        labels = const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        bucketOf = (d) => d.weekday - 1;
        caption = 'Per day';
        break;
      case 'This Month':
        final days = DateTime(now.year, now.month + 1, 0).day;
        final n = ((days - 1) ~/ 7) + 1;
        labels = [for (var i = 1; i <= n; i++) 'W$i'];
        bucketOf = (d) => math.min((d.day - 1) ~/ 7, n - 1);
        caption = 'Per week';
        break;
      default:
        final months = [for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i, 1)];
        labels = [for (final m in months) DateFormat('MMM').format(m)];
        bucketOf = (d) {
          for (var i = 0; i < months.length; i++) {
            if (months[i].year == d.year && months[i].month == d.month) return i;
          }
          return -1;
        };
        caption = 'Last 6 months';
    }

    final rev = List<double>.filled(labels.length, 0);
    final wt = List<double>.filled(labels.length, 0);
    for (final r in rows) {
      final i = bucketOf(r.date);
      if (i < 0 || i >= labels.length) continue;
      rev[i] += r.net;
      wt[i] += r.weight;
    }

    final top = farmers.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));

    return _ReportData(
      revenue: revenue,
      weight: weight,
      advances: advances,
      count: rows.length,
      seriesCaption: caption,
      revenueSeries: [for (var i = 0; i < labels.length; i++) _Point(labels[i], rev[i])],
      weightSeries: [for (var i = 0; i < labels.length; i++) _Point(labels[i], wt[i])],
      topFarmers: top.take(5).toList(),
    );
  }

  // ───────────────────────── Formatting ─────────────────────────

  String _money(double v) => NumberFormat('#,###', 'en_US').format(v.round());

  String _num(double v) => NumberFormat('#,##0.#', 'en_US').format(v);

  String _compact(double v) {
    String t(double x) {
      final s = x.toStringAsFixed(1);
      return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
    }

    if (v >= 1e9) return '${t(v / 1e9)}B';
    if (v >= 1e6) return '${t(v / 1e6)}M';
    if (v >= 1e3) return '${t(v / 1e3)}K';
    return v.round().toString();
  }

  // ───────────────────────── Shared card bits ─────────────────────────

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
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
      ),
      child: child,
    );
  }

  Widget _cardHeader(IconData icon, Color color, String title,
      {String? caption}) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: DashPalette.ink,
                ),
              ),
              if (caption != null)
                Text(
                  caption,
                  style: const TextStyle(
                    fontSize: 12,
                    color: DashPalette.muted,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stateView(IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: const BoxDecoration(
                color: DashPalette.greenSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: DashPalette.green),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: DashPalette.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 14, color: DashPalette.muted),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Stat cards ─────────────────────────

  Widget _statsSection(_ReportData d, bool wide, bool compact) {
    final cards = [
      _statCard(Icons.account_balance_wallet_rounded, DashPalette.green,
          'Total revenue', 'UGX ${_money(d.revenue)}', compact),
      _statCard(Icons.scale_rounded, DashPalette.blue, 'Total weight',
          '${_num(d.weight)} kg', compact),
      _statCard(Icons.receipt_long_rounded, DashPalette.amber, 'Transactions',
          '${d.count}', compact),
      _statCard(Icons.request_quote_rounded, _purple, 'Advances used',
          'UGX ${_money(d.advances)}', compact),
    ];

    if (wide) {
      return Row(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 20),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }
    final gap = compact ? 12.0 : 20.0;
    return Column(
      children: [
        Row(children: [
          Expanded(child: cards[0]),
          SizedBox(width: gap),
          Expanded(child: cards[1]),
        ]),
        SizedBox(height: gap),
        Row(children: [
          Expanded(child: cards[2]),
          SizedBox(width: gap),
          Expanded(child: cards[3]),
        ]),
      ],
    );
  }

  Widget _statCard(IconData icon, Color color, String label, String value,
      bool compact) {
    final iconBox = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, size: 23, color: color),
    );

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: DashPalette.muted,
          ),
        ),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: DashPalette.ink,
            ),
          ),
        ),
      ],
    );

    return _card(
      padding: EdgeInsets.all(compact ? 14 : 18),
      child: compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [iconBox, const SizedBox(height: 12), text],
            )
          : Row(
              children: [
                iconBox,
                const SizedBox(width: 14),
                Expanded(child: text),
              ],
            ),
    );
  }

  // ───────────────────────── Charts ─────────────────────────

  Widget _chartCard({
    required bool fill,
    required Widget header,
    required Widget chart,
  }) {
    return _card(
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 20),
          if (fill) Expanded(child: chart) else SizedBox(height: 240, child: chart),
        ],
      ),
    );
  }

  Widget _revenueCard(_ReportData d, bool fill) {
    return _chartCard(
      fill: fill,
      header: _cardHeader(Icons.trending_up_rounded, DashPalette.green,
          'Revenue trend (UGX)',
          caption: d.seriesCaption),
      chart: _lineChart(d.revenueSeries),
    );
  }

  Widget _weightCard(_ReportData d, bool fill) {
    return _chartCard(
      fill: fill,
      header: _cardHeader(Icons.scale_rounded, DashPalette.blue,
          'Weight purchased (kg)',
          caption: d.seriesCaption),
      chart: _barChart(d.weightSeries),
    );
  }

  double _maxOf(List<_Point> pts) {
    var m = 0.0;
    for (final p in pts) {
      if (p.value > m) m = p.value;
    }
    return m > 0 ? m : 100;
  }

  FlTitlesData _titles(List<_Point> pts, double interval) {
    final step = (pts.length / 6).ceil().clamp(1, 99).toDouble();
    const axisStyle = TextStyle(color: DashPalette.muted, fontSize: 11);
    return FlTitlesData(
      show: true,
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 30,
          interval: step,
          getTitlesWidget: (value, meta) {
            final i = value.toInt();
            if (i < 0 || i >= pts.length) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(pts[i].label, style: axisStyle),
            );
          },
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 46,
          interval: interval,
          getTitlesWidget: (value, meta) => Text(
            _compact(value),
            style: axisStyle,
          ),
        ),
      ),
    );
  }

  FlGridData _grid(double interval) => FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: DashPalette.border, strokeWidth: 1),
      );

  Widget _lineChart(List<_Point> pts) {
    final maxY = _maxOf(pts) * 1.2;
    final interval = maxY / 4;
    return LineChart(
      LineChartData(
        gridData: _grid(interval),
        titlesData: _titles(pts, interval),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (pts.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          LineChartBarData(
            spots: [
              for (var i = 0; i < pts.length; i++)
                FlSpot(i.toDouble(), pts[i].value),
            ],
            isCurved: true,
            curveSmoothness: 0.25,
            preventCurveOverShooting: true,
            color: DashPalette.green,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(show: pts.length <= 12),
            belowBarData: BarAreaData(
              show: true,
              color: DashPalette.green.withOpacity(0.12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _barChart(List<_Point> pts) {
    final maxY = _maxOf(pts) * 1.2;
    final interval = maxY / 4;
    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxY,
        gridData: _grid(interval),
        titlesData: _titles(pts, interval),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < pts.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: pts[i].value,
                  color: DashPalette.blue,
                  width: pts.length > 8 ? 12 : 22,
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(6)),
                ),
              ],
            ),
        ],
      ),
    );
  }

  // ───────────────────────── Gauge ─────────────────────────

  Widget _gaugeCard(_ReportData d, bool fill) {
    final target = _targets[_period] ?? 10000000.0;
    final ratio = target > 0 ? d.revenue / target : 0.0;

    final gauge = LayoutBuilder(builder: (context, c) {
      final w = math.min(c.maxWidth, 300.0);
      final h = w / 2 + 14;
      return SizedBox(
        width: w,
        height: h,
        child: Stack(
          children: [
            CustomPaint(
              size: Size(w, h),
              painter: _GaugePainter(ratio.clamp(0.0, 1.0).toDouble()),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(ratio * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: DashPalette.ink,
                      height: 1.1,
                    ),
                  ),
                  const Text(
                    'of target',
                    style: TextStyle(fontSize: 12.5, color: DashPalette.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });

    final metrics = Row(
      children: [
        Expanded(child: _gaugeMetric('Current', _compact(d.revenue), DashPalette.green)),
        Container(width: 1, height: 36, color: DashPalette.border),
        Expanded(child: _gaugeMetric('Target', _compact(target), DashPalette.ink)),
      ],
    );

    return _card(
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.speed_rounded, DashPalette.greenDark,
              'Performance',
              caption: 'Revenue vs target'),
          if (fill)
            Expanded(child: Center(child: gauge))
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(child: gauge),
            ),
          metrics,
        ],
      ),
    );
  }

  Widget _gaugeMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: DashPalette.muted),
        ),
      ],
    );
  }

  // ───────────────────────── Top farmers ─────────────────────────

  Widget _farmersCard(_ReportData d, bool fill) {
    final farmers = d.topFarmers;
    final topRevenue = farmers.isEmpty ? 1.0 : math.max(farmers.first.revenue, 1.0);

    final list = farmers.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text(
                'No farmer data',
                style: TextStyle(color: DashPalette.muted),
              ),
            ),
          )
        : Column(
            children: [
              for (var i = 0; i < farmers.length; i++)
                _farmerRow(i + 1, farmers[i], farmers[i].revenue / topRevenue),
            ],
          );

    return _card(
      child: Column(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardHeader(Icons.emoji_events_rounded, DashPalette.amber,
              'Top farmers',
              caption: 'By revenue'),
          const SizedBox(height: 12),
          if (fill) Expanded(child: SingleChildScrollView(child: list)) else list,
        ],
      ),
    );
  }

  Widget _farmerRow(int rank, _FarmerStat f, double share) {
    final Color badge = rank == 1
        ? const Color(0xFFE6A700)
        : rank == 2
            ? const Color(0xFF9AA79F)
            : rank == 3
                ? const Color(0xFFB07A4A)
                : DashPalette.greenDark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: badge.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '$rank',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: badge,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        f.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: DashPalette.ink,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _compact(f.revenue),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: DashPalette.greenDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${_num(f.weight)} kg - ${f.count} ${f.count == 1 ? 'purchase' : 'purchases'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: DashPalette.muted,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: share.clamp(0.0, 1.0).toDouble(),
                    minHeight: 5,
                    backgroundColor: DashPalette.greenSoft,
                    valueColor: const AlwaysStoppedAnimation(DashPalette.green),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Gauge painter ─────────────────────────

class _GaugePainter extends CustomPainter {
  final double fraction; // 0..1
  _GaugePainter(this.fraction);

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 20.0;
    final rect = Rect.fromLTWH(
        stroke / 2, stroke / 2, size.width - stroke, size.width - stroke);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = DashPalette.border;
    canvas.drawArc(rect, math.pi, math.pi, false, track);

    if (fraction > 0) {
      final fill = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = DashPalette.green;
      canvas.drawArc(rect, math.pi, math.pi * fraction, false, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.fraction != fraction;
}