import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/models/branch.dart';
import 'branch_service.dart';

/// Global branch context manager
/// Maintains the currently selected branch for operations
class BranchContext extends ChangeNotifier {
  static final BranchContext instance = BranchContext._();
  
  BranchContext._();
  
  Branch? _currentBranch;
  final BranchService _branchService = BranchService();
  
  static const String _prefKey = 'selected_branch_id';
  
  /// Get current branch
  Branch? get currentBranch => _currentBranch;
  
  /// Check if a branch is selected
  bool get hasBranch => _currentBranch != null;
  
  /// Get current branch ID (throws if no branch selected)
  String get currentBranchId {
    if (_currentBranch == null) {
      throw Exception('No branch selected. Please select a branch first.');
    }
    return _currentBranch!.id!;
  }
  
  /// Initialize branch context - load last selected or default branch
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedBranchId = prefs.getString(_prefKey);
      
      if (savedBranchId != null) {
        // Try to load saved branch
        final branch = await _branchService.getBranchById(savedBranchId);
        if (branch != null && branch.isActive) {
          _currentBranch = branch;
          notifyListeners();
          return;
        }
      }
      
      // If no saved branch or inactive, try to load head office
      final headOffice = await _branchService.getHeadOfficeBranch();
      if (headOffice != null && headOffice.isActive) {
        await selectBranch(headOffice);
        return;
      }
      
      // Otherwise, load first active branch
      final branches = await _branchService.getActiveBranches();
      if (branches.isNotEmpty) {
        await selectBranch(branches.first);
      }
    } catch (e) {
      debugPrint('Error initializing branch context: $e');
    }
  }
  
  /// Select a branch
  Future<void> selectBranch(Branch branch) async {
    if (!branch.isActive) {
      throw Exception('Cannot select an inactive branch');
    }
    
    _currentBranch = branch;
    notifyListeners();
    
    // Save selection
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey, branch.id!);
    } catch (e) {
      debugPrint('Error saving branch selection: $e');
    }
  }
  
  /// Select branch by ID
  Future<void> selectBranchById(String branchId) async {
    final branch = await _branchService.getBranchById(branchId);
    if (branch == null) {
      throw Exception('Branch not found');
    }
    await selectBranch(branch);
  }
  
  /// Clear branch selection
  Future<void> clearSelection() async {
    _currentBranch = null;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey);
    } catch (e) {
      debugPrint('Error clearing branch selection: $e');
    }
  }
  
  /// Refresh current branch data
  Future<void> refresh() async {
    if (_currentBranch?.id != null) {
      final updated = await _branchService.getBranchById(_currentBranch!.id!);
      if (updated != null) {
        _currentBranch = updated;
        notifyListeners();
      }
    }
  }
  
  /// Get all available branches
  Future<List<Branch>> getAvailableBranches() async {
    return await _branchService.getActiveBranches();
  }
}
