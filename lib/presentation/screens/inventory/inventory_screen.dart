import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../home/dashboard_home_new.dart' show DashPalette;

/// Inventory - stock levels from purchases, grouped by farmer.
class InventoryScreen extends StatefulWidget {
  const InventoryScreen({Key? key}) : super(key: key);

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _FarmerStock {
  final String name;
  double weight = 0;
  double value = 0;
  int purchases = 0;
  _FarmerStock(this.name);
}

class _InventoryScreenState extends State<InventoryScreen> {
  // Column flex values for the desktop table: farmer, purchases, stock, value, share
  static const _flex = [28, 12, 32, 16, 10];

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  late final Stream<QuerySnapshot> _stream;

  @override
  void initState() {
    super.initState();
    _stream = AuthService.instance
        .applyBranchFilterToCollection(AppConstants.purchasesCollection)
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
  String _kg(double v) => '${NumberFormat('#,##0.#', 'en_US').format(v)} kg';

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

  // ───────────────────────── Build ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: LayoutBuilder(builder: (context, c) {
        final compact = c.maxWidth < 560;
        final wide = c.maxWidth >= 900;
        final pad = compact ? 16.0 : 24.0;

        return StreamBuilder<QuerySnapshot>(
          stream: _stream,
          builder: (context, snapshot) {
            Widget header(bool showSearch) => Padding(
                  padding: EdgeInsets.fromLTRB(pad, pad, pad, 20),
                  child: _header(wide, showSearch),
                );

            if (snapshot.hasError) {
              return Column(children: [
                header(false),
                Expanded(
                  child: _stateView(Icons.error_outline_rounded,
                      'Something went wrong', '${snapshot.error}'),
                ),
              ]);
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation(DashPalette.green),
                ),
              );
            }

            // Aggregate (voided purchases are not stock)
            double totalStock = 0, totalValue = 0;
            int totalPurchases = 0;
            final byFarmer = <String, _FarmerStock>{};

            for (final doc in snapshot.data!.docs) {
              final data = doc.data() as Map<String, dynamic>?;
              if (data == null) continue;
              if ((data['status'] ?? 'active') == 'voided') continue;

              final weight = _toDouble(data['payableWeight']);
              final value = _toDouble(data['totalAmount']);
              final name = (data['farmerName'] ?? 'Unknown').toString();
              final id = (data['farmerId'] ?? '').toString();
              final key = id.isNotEmpty ? id : name;

              totalStock += weight;
              totalValue += value;
              totalPurchases += 1;

              final f = byFarmer.putIfAbsent(key, () => _FarmerStock(name));
              f.weight += weight;
              f.value += value;
              f.purchases += 1;
            }

            if (totalPurchases == 0) {
              return Column(children: [
                header(false),
                Expanded(
                  child: _stateView(Icons.inventory_2_outlined,
                      'No inventory data',
                      'Stock appears here once purchases are recorded.'),
                ),
              ]);
            }

            final q = _searchQuery.trim().toLowerCase();
            final farmers = byFarmer.values
                .where((f) => q.isEmpty || f.name.toLowerCase().contains(q))
                .toList()
              ..sort((a, b) => b.weight.compareTo(a.weight));
            final maxWeight = farmers.isEmpty ? 1.0 : farmers.first.weight;

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, pad, pad, 20),
                  sliver: SliverToBoxAdapter(child: _header(wide, true)),
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(pad, 0, pad, 24),
                  sliver: SliverToBoxAdapter(
                    child: _summary(totalStock, totalPurchases, totalValue,
                        byFarmer.length, wide, compact),
                  ),
                ),
                if (farmers.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: _stateView(Icons.search_off_rounded,
                        'No farmers found', 'Try a different search.'),
                  )
                else ...[
                  if (wide)
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(pad, 0, pad, 8),
                      sliver: SliverToBoxAdapter(child: _tableHeader()),
                    ),
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: wide
                              ? _tableRow(farmers[i], maxWeight, totalStock)
                              : _mobileCard(farmers[i], maxWeight, totalStock),
                        ),
                        childCount: farmers.length,
                      ),
                    ),
                  ),
                ],
              ],
            );
          },
        );
      }),
    );
  }

  // ───────────────────────── Header / search ─────────────────────────

  Widget _header(bool wide, bool showSearch) {
    final title = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          'Stock overview',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: DashPalette.ink,
          ),
        ),
        SizedBox(height: 3),
        Text(
          'Coffee in stock, grouped by farmer',
          style: TextStyle(fontSize: 13.5, color: DashPalette.muted),
        ),
      ],
    );

    if (!showSearch) return title;

    final search = SizedBox(
      width: wide ? 340 : double.infinity,
      child: TextField(
        controller: _searchController,
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(fontSize: 14.5, color: DashPalette.ink),
        decoration: InputDecoration(
          hintText: 'Search farmer...',
          hintStyle: const TextStyle(color: DashPalette.muted, fontSize: 14),
          prefixIcon:
              const Icon(Icons.search_rounded, color: DashPalette.muted),
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
      ),
    );

    if (wide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [Expanded(child: title), search],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [title, const SizedBox(height: 14), search],
    );
  }

  // ───────────────────────── Summary ─────────────────────────

  Widget _summary(double stock, int purchases, double value, int farmers,
      bool wide, bool compact) {
    final cards = [
      _statCard(Icons.inventory_2_rounded, DashPalette.amber, 'Total stock',
          _kg(stock), compact),
      _statCard(Icons.shopping_bag_rounded, DashPalette.green, 'Purchases',
          '$purchases', compact),
      _statCard(Icons.account_balance_wallet_rounded,
          const Color(0xFF8E44AD), 'Total value', 'UGX ${_money(value)}',
          compact),
      _statCard(Icons.groups_rounded, DashPalette.blue, 'Farmers supplying',
          '$farmers', compact),
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

  // ───────────────────────── Table (desktop) ─────────────────────────

  Widget _tableHeader() {
    const titles = ['FARMER', 'PURCHASES', 'STOCK', 'VALUE', 'SHARE'];
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

  Widget _bar(double ratio) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: ratio.clamp(0.0, 1.0).toDouble(),
        minHeight: 6,
        backgroundColor: DashPalette.greenSoft,
        valueColor: const AlwaysStoppedAnimation(DashPalette.green),
      ),
    );
  }

  Widget _tableRow(_FarmerStock f, double maxWeight, double totalStock) {
    final share = totalStock > 0 ? f.weight / totalStock * 100 : 0.0;
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: _flex[0],
            child: Row(
              children: [
                _avatar(f.name),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    f.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: DashPalette.ink,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: _flex[1],
            child: Text(
              '${f.purchases}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: DashPalette.ink,
              ),
            ),
          ),
          Expanded(
            flex: _flex[2],
            child: Padding(
              padding: const EdgeInsets.only(right: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _kg(f.weight),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: DashPalette.greenDark,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _bar(maxWeight > 0 ? f.weight / maxWeight : 0),
                ],
              ),
            ),
          ),
          Expanded(
            flex: _flex[3],
            child: Text(
              'UGX ${_money(f.value)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: DashPalette.ink,
              ),
            ),
          ),
          Expanded(
            flex: _flex[4],
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: DashPalette.greenSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${share.toStringAsFixed(1)}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: DashPalette.greenDark,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────── Mobile card ─────────────────────────

  Widget _mobileCard(_FarmerStock f, double maxWeight, double totalStock) {
    final share = totalStock > 0 ? f.weight / totalStock * 100 : 0.0;
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _avatar(f.name),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.name,
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
                      '${f.purchases} ${f.purchases == 1 ? 'purchase' : 'purchases'}',
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
                _kg(f.weight),
                style: const TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: DashPalette.greenDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _bar(maxWeight > 0 ? f.weight / maxWeight : 0),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'UGX ${_money(f.value)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: DashPalette.muted,
                  ),
                ),
              ),
              Text(
                '${share.toStringAsFixed(1)}% of stock',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: DashPalette.greenDark,
                ),
              ),
            ],
          ),
        ],
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
}