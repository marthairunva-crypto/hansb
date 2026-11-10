import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../home/dashboard_home_new.dart' show DashPalette;

/// Purchases - all coffee transactions (table on desktop, cards on mobile).
class PurchasesScreen extends StatefulWidget {
  const PurchasesScreen({Key? key}) : super(key: key);

  @override
  State<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _Purchase {
  final String id;
  final String farmerName;
  final String farmerId;
  final double gross;
  final double deduction;
  final double payable;
  final double pricePerKg;
  final double total;
  final double milling;
  final double advance;
  final double net;
  final DateTime date;

  const _Purchase({
    required this.id,
    required this.farmerName,
    required this.farmerId,
    required this.gross,
    required this.deduction,
    required this.payable,
    required this.pricePerKg,
    required this.total,
    required this.milling,
    required this.advance,
    required this.net,
    required this.date,
  });
}

class _PurchasesScreenState extends State<PurchasesScreen> {
  static const _periods = ['All', 'Today', 'This Week', 'This Month'];
  // Column flex values for the desktop table:
  // farmer, gross, payable, price, advance, net, actions
  static const _flex = [30, 12, 12, 12, 14, 16, 12];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _period = 'All';

  late final Stream<QuerySnapshot> _stream;

  @override
  void initState() {
    super.initState();
    _stream = AuthService.instance
        .applyBranchFilterToCollection(AppConstants.purchasesCollection)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ───────────────────────── Helpers ─────────────────────────

  double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    return 0.0;
  }

  String _money(double v) => NumberFormat('#,###', 'en_US').format(v.round());
  String _kg(double v) => '${NumberFormat('#,##0.0#', 'en_US').format(v)} kg';

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    final time = DateFormat('h:mm a').format(d);
    if (diff == 0) return 'Today, $time';
    if (diff == 1) return 'Yesterday, $time';
    return DateFormat('d MMM yyyy, h:mm a').format(d);
  }

  void _toast(String message, {Color color = DashPalette.greenDark}) {
    if (!mounted) return;
    final m = ScaffoldMessenger.of(context);
    m.hideCurrentSnackBar();
    m.showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  List<_Purchase> _parse(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekStart = today.subtract(Duration(days: today.weekday - 1));
    final monthStart = DateTime(now.year, now.month, 1);
    final q = _searchQuery.trim().toLowerCase();

    final out = <_Purchase>[];
    for (final doc in docs) {
      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) continue;
      if ((data['status'] ?? 'active') == 'voided') continue;

      final ts = data['createdAt'];
      final date = ts is Timestamp ? ts.toDate() : DateTime.now();

      switch (_period) {
        case 'Today':
          if (date.isBefore(today)) continue;
          break;
        case 'This Week':
          if (date.isBefore(weekStart)) continue;
          break;
        case 'This Month':
          if (date.isBefore(monthStart)) continue;
          break;
      }

      final name = (data['farmerName'] ?? 'Unknown').toString();
      if (q.isNotEmpty && !name.toLowerCase().contains(q)) continue;

      out.add(_Purchase(
        id: doc.id,
        farmerName: name,
        farmerId: (data['farmerId'] ?? '').toString(),
        gross: _toDouble(data['grossWeight']),
        deduction: _toDouble(data['deduction']),
        payable: _toDouble(data['payableWeight']),
        pricePerKg: _toDouble(data['pricePerKg']),
        total: _toDouble(data['totalAmount']),
        milling: _toDouble(data['millingCharge']),
        advance: _toDouble(data['advanceAmount']),
        net: _toDouble(data['netPayment']),
        date: date,
      ));
    }
    return out;
  }

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: LayoutBuilder(builder: (context, c) {
        final compact = c.maxWidth < 560;
        final wide = c.maxWidth >= 900;
        final pad = compact ? 16.0 : 24.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(pad, pad, pad, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Transactions',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: DashPalette.ink,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'All recorded coffee purchases',
                    style: TextStyle(fontSize: 13.5, color: DashPalette.muted),
                  ),
                  const SizedBox(height: 18),
                  _toolbar(wide),
                ],
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _stream,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return _stateView(Icons.error_outline_rounded,
                        'Something went wrong', '${snapshot.error}');
                  }
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(DashPalette.green),
                      ),
                    );
                  }
                  if (snapshot.data!.docs.isEmpty) {
                    return _stateView(Icons.shopping_cart_outlined,
                        'No purchases recorded yet',
                        'Tap the + button to record a purchase.');
                  }

                  final purchases = _parse(snapshot.data!.docs);
                  final filtering =
                      _searchQuery.isNotEmpty || _period != 'All';

                  return CustomScrollView(
                    slivers: [
                      SliverPadding(
                        padding: EdgeInsets.fromLTRB(pad, 0, pad, 20),
                        sliver: SliverToBoxAdapter(
                          child: _summary(purchases, wide, compact),
                        ),
                      ),
                      if (purchases.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _stateView(
                            Icons.search_off_rounded,
                            'No purchases found',
                            filtering
                                ? 'Try a different search or period.'
                                : 'Nothing to show yet.',
                          ),
                        )
                      else ...[
                        if (wide)
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(pad, 0, pad, 8),
                            sliver: SliverToBoxAdapter(child: _tableHeader()),
                          ),
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(pad, 0, pad, pad + 56),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, i) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: wide
                                    ? _tableRow(purchases[i])
                                    : _mobileCard(purchases[i]),
                              ),
                              childCount: purchases.length,
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        );
      }),
    );
  }

  // ───────────────────────── Toolbar ─────────────────────────

  Widget _toolbar(bool wide) {
    final search = TextField(
      controller: _searchController,
      onChanged: (v) => setState(() => _searchQuery = v),
      style: const TextStyle(fontSize: 14.5, color: DashPalette.ink),
      decoration: InputDecoration(
        hintText: 'Search by farmer name...',
        hintStyle: const TextStyle(color: DashPalette.muted, fontSize: 14),
        prefixIcon: const Icon(Icons.search_rounded, color: DashPalette.muted),
        suffixIcon: _searchQuery.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: DashPalette.muted),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              ),
        isDense: true,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DashPalette.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: DashPalette.green, width: 1.6),
        ),
      ),
    );

    final pills = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [for (final p in _periods) _pill(p)],
    );

    if (wide) {
      return Row(
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: search,
            ),
          ),
          const Spacer(),
          pills,
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [search, const SizedBox(height: 12), pills],
    );
  }

  Widget _pill(String label) {
    final selected = _period == label;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => setState(() => _period = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? DashPalette.greenSoft : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? DashPalette.green : DashPalette.border,
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: selected ? DashPalette.greenDark : DashPalette.muted,
          ),
        ),
      ),
    );
  }

  // ───────────────────────── Summary ─────────────────────────

  Widget _summary(List<_Purchase> list, bool wide, bool compact) {
    double weight = 0, net = 0, advances = 0;
    for (final p in list) {
      weight += p.payable;
      net += p.net;
      advances += p.advance;
    }

    final cards = [
      _statCard(Icons.receipt_long_rounded, DashPalette.amber, 'Transactions',
          '${list.length}', compact),
      _statCard(Icons.scale_rounded, DashPalette.blue, 'Payable weight',
          _kg(weight), compact),
      _statCard(Icons.account_balance_wallet_rounded, DashPalette.green,
          'Total paid', 'UGX ${_money(net)}', compact),
      _statCard(Icons.request_quote_rounded, const Color(0xFF8E44AD),
          'Advances recovered', 'UGX ${_money(advances)}', compact),
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
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
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

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: _cardDecoration(),
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

  // ───────────────────────── Desktop table ─────────────────────────

  Widget _tableHeader() {
    const titles = [
      'FARMER',
      'GROSS',
      'PAYABLE',
      'PRICE / KG',
      'ADVANCE',
      'NET PAYMENT',
      '',
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          for (var i = 0; i < titles.length; i++)
            Expanded(
              flex: _flex[i],
              child: Text(
                titles[i],
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: DashPalette.muted,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _avatar(String name) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    return Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        color: DashPalette.greenSoft,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: DashPalette.greenDark,
          ),
        ),
      ),
    );
  }

  Widget _cell(String text, {bool bold = false, Color? color}) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
        color: color ?? DashPalette.ink,
      ),
    );
  }

  Widget _tableRow(_Purchase p) {
    return Container(
      decoration: _cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          hoverColor: DashPalette.greenSoft.withOpacity(0.35),
          onTap: () => _showDetails(p),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  flex: _flex[0],
                  child: Row(
                    children: [
                      _avatar(p.farmerName),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              p.farmerName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: DashPalette.ink,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _formatDate(p.date),
                              style: const TextStyle(
                                fontSize: 12,
                                color: DashPalette.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(flex: _flex[1], child: _cell(_kg(p.gross))),
                Expanded(flex: _flex[2], child: _cell(_kg(p.payable))),
                Expanded(
                    flex: _flex[3], child: _cell(_money(p.pricePerKg))),
                Expanded(
                  flex: _flex[4],
                  child: p.advance > 0
                      ? _cell(_money(p.advance),
                          color: const Color(0xFFB7791F))
                      : _cell('-', color: DashPalette.muted),
                ),
                Expanded(
                  flex: _flex[5],
                  child: _cell('UGX ${_money(p.net)}',
                      bold: true, color: DashPalette.greenDark),
                ),
                Expanded(
                  flex: _flex[6],
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Flexible(
                        child: _iconAction(Icons.visibility_outlined, 'View',
                            DashPalette.blue, () => _showDetails(p)),
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: _iconAction(Icons.block_rounded, 'Void',
                            DashPalette.red, () => _confirmVoid(p)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _iconAction(
      IconData icon, String tooltip, Color color, VoidCallback onTap) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
      ),
    );
  }

  // ───────────────────────── Mobile card ─────────────────────────

  Widget _mobileCard(_Purchase p) {
    return Container(
      decoration: _cardDecoration(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _showDetails(p),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _avatar(p.farmerName),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            p.farmerName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: DashPalette.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(p.date),
                            style: const TextStyle(
                              fontSize: 12,
                              color: DashPalette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'UGX ${_money(p.net)}',
                      style: const TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: DashPalette.greenDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _chip('Gross ${_kg(p.gross)}'),
                    _chip('Payable ${_kg(p.payable)}'),
                    _chip('@ ${_money(p.pricePerKg)}/kg'),
                    if (p.advance > 0)
                      _chip('Advance ${_money(p.advance)}',
                          color: const Color(0xFFB7791F)),
                  ],
                ),
                const SizedBox(height: 6),
                const Divider(height: 20, color: DashPalette.border),
                Row(
                  children: [
                    _textAction(Icons.visibility_outlined, 'View',
                        DashPalette.blue, () => _showDetails(p)),
                    const Spacer(),
                    _textAction(Icons.block_rounded, 'Void', DashPalette.red,
                        () => _confirmVoid(p)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String text, {Color color = DashPalette.greenDark}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _textAction(
      IconData icon, String label, Color color, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: TextButton.styleFrom(
        foregroundColor: color,
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
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
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: DashPalette.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: DashPalette.muted),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────── Details dialog ─────────────────────────

  void _showDetails(_Purchase p) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(22),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        color: DashPalette.greenSoft,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.receipt_long_rounded,
                          color: DashPalette.greenDark),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Purchase details',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: DashPalette.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatDate(p.date),
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: DashPalette.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded,
                          color: DashPalette.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _detailRow('Farmer', p.farmerName, bold: true),
                const Divider(height: 22, color: DashPalette.border),
                _detailRow('Gross weight', _kg(p.gross)),
                _detailRow('Deduction', _kg(p.deduction)),
                _detailRow('Payable weight', _kg(p.payable), bold: true),
                const Divider(height: 22, color: DashPalette.border),
                _detailRow('Price per kg', 'UGX ${_money(p.pricePerKg)}'),
                _detailRow('Total amount', 'UGX ${_money(p.total)}'),
                _detailRow('Milling charge', '- UGX ${_money(p.milling)}'),
                if (p.advance > 0)
                  _detailRow('Advance deducted', '- UGX ${_money(p.advance)}',
                      color: const Color(0xFFB7791F)),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: DashPalette.greenSoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'NET PAYMENT',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: DashPalette.greenDark,
                          ),
                        ),
                      ),
                      Text(
                        'UGX ${_money(p.net)}',
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: DashPalette.greenDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value,
      {bool bold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: color ?? DashPalette.muted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 14,
                color: color ?? DashPalette.ink,
                fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Void flow ─────────────────────────

  void _confirmVoid(_Purchase p) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: DashPalette.red.withOpacity(0.12),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: DashPalette.red),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Void purchase?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: DashPalette.ink,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Void the UGX ${_money(p.net)} purchase for ${p.farmerName}?',
              style: const TextStyle(
                fontSize: 14.5,
                color: DashPalette.ink,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: DashPalette.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DashPalette.red.withOpacity(0.25)),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      color: DashPalette.red, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This cannot be undone. Any advance recovered on this purchase will be restored.',
                      style: TextStyle(
                        fontSize: 13,
                        color: DashPalette.red,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              await _voidPurchase(p.id, p.farmerId, p.advance);
            },
            style: FilledButton.styleFrom(backgroundColor: DashPalette.red),
            child: const Text('Void purchase'),
          ),
        ],
      ),
    );
  }

  Future<void> _voidPurchase(
      String purchaseId, String farmerId, double advanceAmount) async {
    try {
      final purchaseDoc = await FirebaseFirestore.instance
          .collection(AppConstants.purchasesCollection)
          .doc(purchaseId)
          .get();

      if (!purchaseDoc.exists) {
        throw Exception('Purchase not found');
      }

      final batch = FirebaseFirestore.instance.batch();

      // Mark purchase as voided
      final purchaseRef = FirebaseFirestore.instance
          .collection(AppConstants.purchasesCollection)
          .doc(purchaseId);
      batch.update(purchaseRef, {
        'status': 'voided',
        'voidedAt': FieldValue.serverTimestamp(),
      });

      // Restore advances if any were deducted
      if (advanceAmount > 0 && farmerId.isNotEmpty) {
        final advancesSnapshot = await FirebaseFirestore.instance
            .collection(AppConstants.advancesCollection)
            .where('farmerId', isEqualTo: farmerId)
            .get();

        double remainingToRestore = advanceAmount;

        final recoveredAdvances = advancesSnapshot.docs.where((doc) {
          final data = doc.data();
          return data['status'] == 'fully_recovered' ||
              data['status'] == 'active';
        }).toList();

        recoveredAdvances.sort((a, b) {
          final aTime = a.data()['createdAt'] as Timestamp?;
          final bTime = b.data()['createdAt'] as Timestamp?;
          if (aTime == null || bTime == null) return 0;
          return bTime.compareTo(aTime); // Newest first
        });

        for (var advDoc in recoveredAdvances) {
          if (remainingToRestore <= 0) break;

          final advData = advDoc.data();
          final originalAmount = _toDouble(advData['amount']);
          final currentRemaining = _toDouble(advData['remainingAmount']);
          final canRestore = originalAmount - currentRemaining;

          if (canRestore > 0) {
            final restoreAmount = canRestore <= remainingToRestore
                ? canRestore
                : remainingToRestore;
            final newRemaining = currentRemaining + restoreAmount;

            batch.update(advDoc.reference, {
              'remainingAmount': newRemaining,
              'status': 'active',
              'updatedAt': FieldValue.serverTimestamp(),
            });

            remainingToRestore -= restoreAmount;
          }
        }

        final farmerRef = FirebaseFirestore.instance
            .collection(AppConstants.farmersCollection)
            .doc(farmerId);
        batch.update(farmerRef, {
          'totalAdvances': FieldValue.increment(advanceAmount),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      _toast('Purchase voided and advances restored');
    } catch (e) {
      _toast('Error voiding purchase: $e', color: DashPalette.red);
    }
  }
}