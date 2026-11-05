import 'package:cloud_firestore/cloud_firestore.dart';
import '../../data/models/branch.dart';

/// Service for managing branches using Firebase Firestore
class BranchService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'branches';
  
  /// Get all branches
  Future<List<Branch>> getAllBranches() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .orderBy('branch_name')
          .get();
      
      // Sort in memory to avoid needing a composite index
      final branches = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Branch.fromMap(data);
      }).toList();
      
      // Sort: head office first, then by name
      branches.sort((a, b) {
        if (a.isHeadOffice && !b.isHeadOffice) return -1;
        if (!a.isHeadOffice && b.isHeadOffice) return 1;
        return a.branchName.compareTo(b.branchName);
      });
      
      return branches;
    } catch (e) {
      print('Error loading branches: $e');
      return [];
    }
  }
  
  /// Get active branches only
  Future<List<Branch>> getActiveBranches() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: 'ACTIVE')
          .get();
      
      // Sort in memory to avoid needing indexes
      final branches = snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return Branch.fromMap(data);
      }).toList();
      
      // Sort: head office first, then by name
      branches.sort((a, b) {
        if (a.isHeadOffice && !b.isHeadOffice) return -1;
        if (!a.isHeadOffice && b.isHeadOffice) return 1;
        return a.branchName.compareTo(b.branchName);
      });
      
      return branches;
    } catch (e) {
      print('Error loading active branches: $e');
      return [];
    }
  }
  
  /// Get branch by ID
  Future<Branch?> getBranchById(String id) async {
    final doc = await _firestore.collection(_collection).doc(id).get();
    
    if (!doc.exists) return null;
    
    final data = doc.data()!;
    data['id'] = doc.id;
    return Branch.fromMap(data);
  }
  
  /// Get branch by code
  Future<Branch?> getBranchByCode(String code) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('branch_code', isEqualTo: code)
        .limit(1)
        .get();
    
    if (snapshot.docs.isEmpty) return null;
    
    final doc = snapshot.docs.first;
    final data = doc.data();
    data['id'] = doc.id;
    return Branch.fromMap(data);
  }
  
  /// Get head office branch
  Future<Branch?> getHeadOfficeBranch() async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('is_head_office', isEqualTo: true)
        .limit(1)
        .get();
    
    if (snapshot.docs.isEmpty) return null;
    
    final doc = snapshot.docs.first;
    final data = doc.data();
    data['id'] = doc.id;
    return Branch.fromMap(data);
  }
  
  /// Create new branch
  Future<String> createBranch(Branch branch) async {
    // If this is marked as head office, remove that flag from other branches
    if (branch.isHeadOffice) {
      final existing = await _firestore
          .collection(_collection)
          .where('is_head_office', isEqualTo: true)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in existing.docs) {
        batch.update(doc.reference, {'is_head_office': false});
      }
      await batch.commit();
    }
    
    final data = branch.toMap();
    data['created_at'] = FieldValue.serverTimestamp();
    data.remove('id'); // Remove ID field, Firestore will auto-generate
    
    final docRef = await _firestore.collection(_collection).add(data);
    return docRef.id;
  }
  
  /// Update branch
  Future<void> updateBranch(Branch branch) async {
    if (branch.id == null) throw Exception('Branch ID is required for update');
    
    // If this is marked as head office, remove that flag from other branches
    if (branch.isHeadOffice) {
      final existing = await _firestore
          .collection(_collection)
          .where('is_head_office', isEqualTo: true)
          .get();
      
      final batch = _firestore.batch();
      for (var doc in existing.docs) {
        if (doc.id != branch.id) {
          batch.update(doc.reference, {'is_head_office': false});
        }
      }
      await batch.commit();
    }
    
    final data = branch.copyWith(updatedAt: DateTime.now()).toMap();
    data['updated_at'] = FieldValue.serverTimestamp();
    data.remove('id'); // Don't store ID in document data
    
    await _firestore.collection(_collection).doc(branch.id).update(data);
  }
  
  /// Delete branch (soft delete by setting status to INACTIVE)
  Future<void> deleteBranch(String id) async {
    // Check if this is the head office
    final branch = await getBranchById(id);
    if (branch?.isHeadOffice == true) {
      throw Exception('Cannot delete head office branch');
    }
    
    // Check if branch has any associated records
    final hasRecords = await _hasBranchRecords(id);
    if (hasRecords) {
      // Soft delete - just mark as inactive
      await _firestore.collection(_collection).doc(id).update({
        'status': 'INACTIVE',
        'updated_at': FieldValue.serverTimestamp(),
      });
    } else {
      // Hard delete if no records
      await _firestore.collection(_collection).doc(id).delete();
    }
  }
  
  /// Check if branch has any associated records
  Future<bool> _hasBranchRecords(String branchId) async {
    // Check farmers
    final farmersSnapshot = await _firestore
        .collection('farmers')
        .where('branch_id', isEqualTo: branchId)
        .limit(1)
        .get();
    if (farmersSnapshot.docs.isNotEmpty) return true;
    
    // Check users
    final usersSnapshot = await _firestore
        .collection('users')
        .where('branch_id', isEqualTo: branchId)
        .limit(1)
        .get();
    if (usersSnapshot.docs.isNotEmpty) return true;
    
    // Check purchases
    final purchasesSnapshot = await _firestore
        .collection('coffee_purchases')
        .where('branch_id', isEqualTo: branchId)
        .limit(1)
        .get();
    if (purchasesSnapshot.docs.isNotEmpty) return true;
    
    return false;
  }
  
  /// Get branch statistics
  Future<Map<String, dynamic>> getBranchStats(String branchId) async {
    // Get total farmers
    final farmersSnapshot = await _firestore
        .collection('hansb_farmers')
        .where('branch_id', isEqualTo: branchId)
        .where('isActive', isEqualTo: true)
        .get();
    final farmerCount = farmersSnapshot.docs.length;
    
    // Get total purchases
    final purchasesSnapshot = await _firestore
        .collection('hansb_purchases')
        .where('branch_id', isEqualTo: branchId)
        .get();
    final purchaseCount = purchasesSnapshot.docs.length;
    
    // Calculate total coffee and value
    double totalCoffee = 0.0;
    double totalValue = 0.0;
    
    for (var doc in purchasesSnapshot.docs) {
      final data = doc.data();
      totalCoffee += (data['payableWeight'] ?? 0).toDouble();
      totalValue += (data['totalAmount'] ?? 0).toDouble();
    }
    
    return {
      'farmerCount': farmerCount,
      'purchaseCount': purchaseCount,
      'totalCoffeeKg': totalCoffee,
      'totalValue': totalValue,
    };
  }
  
  /// Search branches
  Future<List<Branch>> searchBranches(String query) async {
    // Note: Firestore doesn't support LIKE queries, so we fetch all and filter in memory
    final snapshot = await _firestore
        .collection(_collection)
        .orderBy('branch_name')
        .get();
    
    final queryLower = query.toLowerCase();
    return snapshot.docs
        .where((doc) {
          final data = doc.data();
          final name = (data['branch_name'] ?? '').toLowerCase();
          final code = (data['branch_code'] ?? '').toLowerCase();
          final location = (data['location'] ?? '').toLowerCase();
          return name.contains(queryLower) ||
              code.contains(queryLower) ||
              location.contains(queryLower);
        })
        .map((doc) {
          final data = doc.data();
          data['id'] = doc.id;
          return Branch.fromMap(data);
        })
        .toList();
  }
}
