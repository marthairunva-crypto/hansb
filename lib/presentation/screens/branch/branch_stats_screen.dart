import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/branch.dart';
import '../home/dashboard_home_new.dart' show DashPalette;

/// Full-screen branch statistics
class BranchStatsScreen extends StatelessWidget {
  final Branch branch;

  const BranchStatsScreen({Key? key, required this.branch}) : super(key: key);

  Future<Map<String, dynamic>> _loadStats() async {
    final branchId = branch.id!;
    
    // Get farmers
    final farmersSnapshot = await FirebaseFirestore.instance
        .collection(AppConstants.farmersCollection)
        .where('branch_id', isEqualTo: branchId)
        .get();
    
    final activeFarmers = farmersSnapshot.docs
        .where((d) => d.data()['isActive'] == true)
        .length;
    
    // Get purchases
    final purchasesSnapshot = await FirebaseFirestore.instance
        .collection(AppConstants.purchasesCollection)
        .where('branch_id', isEqualTo: branchId)
        .get();
    
    double totalCoffee = 0;
    double totalValue = 0;
    double totalAdvancesRecovered = 0;
    
    for (var doc in purchasesSnapshot.docs) {
      final data = doc.data();
      totalCoffee += (data['payableWeight'] ?? 0.0);
      totalValue += (data['totalAmount'] ?? 0.0);
      totalAdvancesRecovered += (data['advanceAmount'] ?? 0.0);
    }
    
    // Get advances
    final advancesSnapshot = await FirebaseFirestore.instance
        .collection(AppConstants.advancesCollection)
        .where('branch_id', isEqualTo: branchId)
        .get();
    
    double totalAdvancesGiven = 0;
    double outstandingAdvances = 0;
    
    for (var doc in advancesSnapshot.docs) {
      final data = doc.data();
      final amount = (data['amount'] ?? 0.0);
      totalAdvancesGiven += amount;
      
      if (data['status'] == 'active') {
        outstandingAdvances += (data['remainingAmount'] ?? 0.0);
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
      'avgPricePerKg': totalCoffee > 0 ? totalValue / totalCoffee : 0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DashPalette.outer,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: DashPalette.ink),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              branch.branchName,
              style: const TextStyle(
                color: DashPalette.ink,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              branch.location ?? 'No location',
              style: const TextStyle(
                color: DashPalette.muted,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: DashPalette.line, height: 1),
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _loadStats(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation(DashPalette.green),
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Error loading stats: ${snapshot.error}',
                style: const TextStyle(color: DashPalette.red),
              ),
            );
          }

          final stats = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Branch Info Card
                _buildInfoCard(),
                const SizedBox(height: 20),

                // Key Metrics Grid
                _buildMetricsGrid(stats),
                const SizedBox(height: 20),

                // Coffee Performance
                _buildSection(
                  'Coffee Performance',
                  Icons.coffee_rounded,
                  DashPalette.greenDark,
                  [
                    _buildStatRow('Total Purchases', '${stats['totalPurchases']}'),
                    _buildStatRow('Total Coffee Purchased',
                        '${_fmt(stats['totalCoffeeKg'], decimals: 2)} kg'),
                    _buildStatRow('Average Price/kg',
                        CurrencyFormatter.formatUGX(stats['avgPricePerKg'])),
                    _buildStatRow('Total Value',
                        CurrencyFormatter.formatUGX(stats['totalValue'])),
                  ],
                ),
                const SizedBox(height: 16),

                // Farmers Stats
                _buildSection(
                  'Farmers',
                  Icons.groups_rounded,
                  DashPalette.blue,
                  [
                    _buildStatRow('Total Registered', '${stats['totalFarmers']}'),
                    _buildStatRow('Active Farmers', '${stats['activeFarmers']}'),
                    _buildStatRow('Inactive',
                        '${stats['totalFarmers'] - stats['activeFarmers']}'),
                  ],
                ),
                const SizedBox(height: 16),

                // Advances
                _buildSection(
                  'Advances & Recoveries',
                  Icons.account_balance_wallet_outlined,
                  DashPalette.amber,
                  [
                    _buildStatRow('Total Given',
                        CurrencyFormatter.formatUGX(stats['totalAdvancesGiven'])),
                    _buildStatRow('Recovered',
                        CurrencyFormatter.formatUGX(stats['totalAdvancesRecovered'])),
                    _buildStatRow(
                      'Outstanding',
                      CurrencyFormatter.formatUGX(stats['outstandingAdvances']),
                      valueColor: DashPalette.red,
                    ),
                    _buildStatRow(
                      'Recovery Rate',
                      stats['totalAdvancesGiven'] > 0
                          ? '${((stats['totalAdvancesRecovered'] / stats['totalAdvancesGiven']) * 100).toStringAsFixed(1)}%'
                          : '0%',
                      valueColor: DashPalette.green,
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: branch.isActive
                      ? DashPalette.greenSoft
                      : const Color(0xFFEEF1EF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.store,
                  color: branch.isActive ? DashPalette.greenDark : DashPalette.muted,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      branch.branchCode,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: DashPalette.muted,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      branch.branchName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: DashPalette.ink,
                      ),
                    ),
                  ],
                ),
              ),
              _statusBadge(branch.isActive),
            ],
          ),
          if (branch.location != null) ...[
            const SizedBox(height: 16),
            const Divider(color: DashPalette.line),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(Icons.location_on_outlined,
                    size: 18, color: DashPalette.muted),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    branch.location!,
                    style: const TextStyle(
                      fontSize: 14,
                      color: DashPalette.ink,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (branch.phone != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.phone_outlined,
                    size: 18, color: DashPalette.muted),
                const SizedBox(width: 8),
                Text(
                  branch.phone!,
                  style: const TextStyle(
                    fontSize: 14,
                    color: DashPalette.ink,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(Map<String, dynamic> stats) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildMetricCard(
          'Total Coffee',
          '${_fmt(stats['totalCoffeeKg'], decimals: 1)} kg',
          Icons.coffee_rounded,
          DashPalette.greenDark,
        ),
        _buildMetricCard(
          'Total Value',
          CurrencyFormatter.formatUGXCompact(stats['totalValue']),
          Icons.payments_rounded,
          DashPalette.green,
        ),
        _buildMetricCard(
          'Active Farmers',
          '${stats['activeFarmers']}',
          Icons.groups_rounded,
          DashPalette.blue,
        ),
        _buildMetricCard(
          'Purchases',
          '${stats['totalPurchases']}',
          Icons.receipt_long_rounded,
          DashPalette.amber,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: DashPalette.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: DashPalette.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      String title, IconData icon, Color color, List<Widget> children) {
    return Container(
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
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
                    fontWeight: FontWeight.w700,
                    color: DashPalette.ink,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: DashPalette.line),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: DashPalette.muted,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: valueColor ?? DashPalette.ink,
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
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: active ? DashPalette.greenDark : DashPalette.muted,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(num v, {int decimals = 0}) {
    final s = v.toStringAsFixed(decimals);
    final parts = s.split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    return parts.length > 1 ? '$intPart.${parts[1]}' : intPart;
  }
}
