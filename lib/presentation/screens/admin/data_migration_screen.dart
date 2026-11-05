import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/auth_service.dart';
import '../home/dashboard_home_new.dart' show DashPalette;

/// Data Migration Tool - Admin Only
/// Fixes old records without branch_id
class DataMigrationScreen extends StatefulWidget {
  const DataMigrationScreen({Key? key}) : super(key: key);

  @override
  State<DataMigrationScreen> createState() => _DataMigrationScreenState();
}

class _DataMigrationScreenState extends State<DataMigrationScreen> {
  bool _isLoading = false;
  String _status = '';
  final Map<String, int> _stats = {};

  Future<void> _fixMissingBranchIds() async {
    if (!AuthService.instance.isSuperAdmin) {
      _showMessage('Only super admins can run migrations', isError: true);
      return;
    }

    setState(() {
      _isLoading = true;
      _status = 'Starting migration...';
      _stats.clear();
    });

    try {
      final batch = FirebaseFirestore.instance.batch();
      int batchCount = 0;
      int totalFixed = 0;

      // Get default branch ID (first active branch or create one)
      String? defaultBranchId;
      String? defaultBranchName;
      
      final branchesSnapshot = await FirebaseFirestore.instance
          .collection('branches')
          .where('status', isEqualTo: 'ACTIVE')
          .limit(1)
          .get();
      
      if (branchesSnapshot.docs.isNotEmpty) {
        defaultBranchId = branchesSnapshot.docs.first.id;
        defaultBranchName = branchesSnapshot.docs.first.data()['branch_name'];
      }

      if (defaultBranchId == null) {
        throw Exception('No active branch found. Please create at least one branch first.');
      }

      setState(() => _status = 'Using default branch: $defaultBranchName');

      // Fix farmers without branch_id
      setState(() => _status = 'Fixing farmers...');
      final farmersSnapshot = await FirebaseFirestore.instance
          .collection(AppConstants.farmersCollection)
          .get();
      
      int farmerCount = 0;
      for (var doc in farmersSnapshot.docs) {
        final data = doc.data();
        if (data['branch_id'] == null || data['branch_id'] == '') {
          batch.update(doc.reference, {
            'branch_id': defaultBranchId,
            'branch_name': defaultBranchName,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          farmerCount++;
          batchCount++;
          
          if (batchCount >= 500) {
            await batch.commit();
            totalFixed += batchCount;
            batchCount = 0;
          }
        }
      }
      _stats['farmers'] = farmerCount;

      // Fix purchases without branch_id
      setState(() => _status = 'Fixing purchases...');
      final purchasesSnapshot = await FirebaseFirestore.instance
          .collection(AppConstants.purchasesCollection)
          .get();
      
      int purchaseCount = 0;
      for (var doc in purchasesSnapshot.docs) {
        final data = doc.data();
        if (data['branch_id'] == null || data['branch_id'] == '') {
          batch.update(doc.reference, {
            'branch_id': defaultBranchId,
            'branch_name': defaultBranchName,
          });
          purchaseCount++;
          batchCount++;
          
          if (batchCount >= 500) {
            await batch.commit();
            totalFixed += batchCount;
            batchCount = 0;
          }
        }
      }
      _stats['purchases'] = purchaseCount;

      // Fix advances without branch_id
      setState(() => _status = 'Fixing advances...');
      final advancesSnapshot = await FirebaseFirestore.instance
          .collection(AppConstants.advancesCollection)
          .get();
      
      int advanceCount = 0;
      for (var doc in advancesSnapshot.docs) {
        final data = doc.data();
        if (data['branch_id'] == null || data['branch_id'] == '') {
          batch.update(doc.reference, {
            'branch_id': defaultBranchId,
            'branch_name': defaultBranchName,
          });
          advanceCount++;
          batchCount++;
          
          if (batchCount >= 500) {
            await batch.commit();
            totalFixed += batchCount;
            batchCount = 0;
          }
        }
      }
      _stats['advances'] = advanceCount;

      // Commit remaining batch
      if (batchCount > 0) {
        await batch.commit();
        totalFixed += batchCount;
      }

      setState(() {
        _status = 'Migration complete! Fixed $totalFixed records.';
        _isLoading = false;
      });

      _showMessage('Successfully migrated $totalFixed records to $defaultBranchName branch');
    } catch (e) {
      setState(() {
        _status = 'Error: $e';
        _isLoading = false;
      });
      _showMessage('Migration failed: $e', isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? DashPalette.red : DashPalette.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Data Migration Tool',
          style: TextStyle(
            color: DashPalette.ink,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: DashPalette.line, height: 1),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: DashPalette.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: DashPalette.amber.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: DashPalette.amber, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Branch Data Migration',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: DashPalette.ink,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'This tool assigns branch IDs to old records that don\'t have them. '
                          'All unassigned records will be moved to the first active branch.',
                          style: TextStyle(
                            fontSize: 14,
                            color: DashPalette.muted,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (_status.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: DashPalette.greenSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    if (_isLoading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation(DashPalette.greenDark),
                        ),
                      )
                    else
                      const Icon(Icons.check_circle,
                          color: DashPalette.greenDark, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _status,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: DashPalette.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_stats.isNotEmpty) ...[
              const SizedBox(height: 24),
              const Text(
                'Migration Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: DashPalette.ink,
                ),
              ),
              const SizedBox(height: 12),
              ..._stats.entries.map((e) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${e.key.toUpperCase()}:',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: DashPalette.muted,
                          ),
                        ),
                        Text(
                          '${e.value} fixed',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: DashPalette.greenDark,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _fixMissingBranchIds,
                style: ElevatedButton.styleFrom(
                  backgroundColor: DashPalette.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Run Migration',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
