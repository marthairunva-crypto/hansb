import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as auth;
import 'package:shared_preferences/shared_preferences.dart';

/// User roles in the system
enum UserRole {
  superAdmin, // Can see all branches
  branchManager, // Can see only their branch
  branchWorker, // Can see only their branch
}

/// Current user session information
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? branchId; // null for super admin, specific branch ID for workers
  final String? branchName;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.branchId,
    this.branchName,
  });

  bool get isSuperAdmin => role == UserRole.superAdmin;
  bool get canViewAllBranches => role == UserRole.superAdmin;
  bool get isRestrictedToBranch => branchId != null;

  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    final roleStr = map['role'] ?? 'branchWorker';
    UserRole role;
    switch (roleStr) {
      case 'superAdmin':
        role = UserRole.superAdmin;
        break;
      case 'branchManager':
        role = UserRole.branchManager;
        break;
      default:
        role = UserRole.branchWorker;
    }

    return AppUser(
      uid: uid,
      email: map['email'] ?? '',
      displayName: map['display_name'] ?? map['full_name'] ?? 'User',
      role: role,
      branchId: map['branch_id'],
      branchName: map['branch_name'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'display_name': displayName,
      'role': role.name,
      'branch_id': branchId,
      'branch_name': branchName,
    };
  }
}

/// Authentication and Authorization Service
class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final auth.FirebaseAuth _auth = auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AppUser? _currentUser;

  /// Get current logged-in user
  AppUser? get currentUser => _currentUser;

  /// Check if user is super admin
  bool get isSuperAdmin => _currentUser?.isSuperAdmin ?? false;

  /// Get current user's branch ID (null if super admin)
  String? get userBranchId => _currentUser?.branchId;

  /// Set current user (for Firestore-only authentication)
  Future<void> setCurrentUser(AppUser user) async {
    _currentUser = user;
    await _cacheUserSession();
  }

  /// Initialize user session from cached data or Firebase Auth
  Future<void> initializeSession() async {
    // First try to restore from cache
    final prefs = await SharedPreferences.getInstance();
    final cachedUid = prefs.getString('user_uid');
    
    if (cachedUid != null) {
      // Try to restore from Firestore
      try {
        final userDoc = await _firestore
            .collection('hansb_users')
            .doc(cachedUid)
            .get();
            
        if (userDoc.exists) {
          _currentUser = AppUser.fromMap(userDoc.data()!, userDoc.id);
          return;
        }
      } catch (e) {
        print('Error restoring user session: $e');
      }
    }

    // Fallback: check Firebase Auth (for legacy compatibility)
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      _currentUser = null;
      await clearSession();
      return;
    }

    // Fetch user data from Firestore
    final userDoc = await _firestore
        .collection('hansb_users')
        .doc(firebaseUser.uid)
        .get();

    if (userDoc.exists) {
      _currentUser = AppUser.fromMap(userDoc.data()!, firebaseUser.uid);
    } else {
      // If no user document, check if it's the default admin
      if (firebaseUser.email == 'admin@hansb.com') {
        _currentUser = AppUser(
          uid: firebaseUser.uid,
          email: firebaseUser.email!,
          displayName: 'Super Admin',
          role: UserRole.superAdmin,
          branchId: null,
          branchName: null,
        );
        // Create user document
        await _createUserDocument(_currentUser!);
      }
    }

    // Cache user session
    await _cacheUserSession();
  }

  /// Create user document in Firestore
  Future<void> _createUserDocument(AppUser user) async {
    await _firestore.collection('hansb_users').doc(user.uid).set({
      'email': user.email,
      'display_name': user.displayName,
      'name': user.displayName,
      'role': user.role.name,
      'branch_id': user.branchId,
      'branch_name': user.branchName,
      'created_at': FieldValue.serverTimestamp(),
      'is_active': true,
      'isActive': true,
    });
  }

  /// Cache user session to SharedPreferences
  Future<void> _cacheUserSession() async {
    if (_currentUser == null) return;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_uid', _currentUser!.uid);
    await prefs.setString('user_role', _currentUser!.role.name);
    await prefs.setString('user_branch_id', _currentUser!.branchId ?? '');
    await prefs.setString('user_display_name', _currentUser!.displayName);
  }

  /// Clear user session
  Future<void> clearSession() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  /// Login with email and password
  Future<AppUser?> login(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        await initializeSession();
        return _currentUser;
      }
      return null;
    } catch (e) {
      print('Login error: $e');
      rethrow;
    }
  }

  /// Logout
  Future<void> logout() async {
    await _auth.signOut();
    await clearSession();
  }

  /// Apply branch filter to Firestore query
  /// If user is super admin, returns query unchanged
  /// If user is branch worker, adds branch_id filter
  Query<Map<String, dynamic>> applyBranchFilter(
    Query<Map<String, dynamic>> query,
  ) {
    if (_currentUser == null || _currentUser!.isSuperAdmin) {
      return query; // Super admin sees all data
    }

    if (_currentUser!.branchId != null) {
      return query.where('branch_id', isEqualTo: _currentUser!.branchId);
    }

    return query;
  }

  /// Apply branch filter to collection reference
  Query<Map<String, dynamic>> applyBranchFilterToCollection(
    String collectionPath,
  ) {
    final collection = _firestore.collection(collectionPath);

    // Debug logging
    print('🔍 [BranchFilter] Collection: $collectionPath');
    print('🔍 [BranchFilter] Current User: ${_currentUser?.displayName}');
    print('🔍 [BranchFilter] Role: ${_currentUser?.role.name}');
    print('🔍 [BranchFilter] Branch ID: ${_currentUser?.branchId}');
    print('🔍 [BranchFilter] Is SuperAdmin: ${_currentUser?.isSuperAdmin}');

    if (_currentUser == null || _currentUser!.isSuperAdmin) {
      print('✅ [BranchFilter] Super admin - NO FILTER applied');
      return collection; // Super admin sees all data
    }

    if (_currentUser!.branchId != null) {
      // For non-super-admins, ONLY show records with matching branch_id
      // This excludes records with null or missing branch_id
      print('🔒 [BranchFilter] Filtering by branch_id = ${_currentUser!.branchId}');
      return collection.where('branch_id', isEqualTo: _currentUser!.branchId);
    }

    // If user has no branch assigned and is not super admin, show nothing
    // This is a safety measure - return an impossible query
    print('⚠️ [BranchFilter] No branch_id - returning EMPTY results');
    return collection.where('branch_id', isEqualTo: '__NO_BRANCH__');
  }

  /// Get filtered stream for a collection
  Stream<QuerySnapshot<Map<String, dynamic>>> getFilteredStream(
    String collectionPath,
  ) {
    return applyBranchFilterToCollection(collectionPath).snapshots();
  }
}
