import 'package:sqflite/sqflite.dart';

/// Helper class for database migrations
/// Handles upgrading from old schema to new multi-branch schema
class MigrationHelper {
  /// Migrate from v1 to v2 (add branch support)
  static Future<void> migrateToV2(Database db) async {
    // Add branches table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS branches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        branch_code TEXT NOT NULL UNIQUE,
        branch_name TEXT NOT NULL,
        location TEXT,
        address TEXT,
        manager_name TEXT,
        phone TEXT,
        email TEXT,
        status TEXT DEFAULT 'ACTIVE',
        is_head_office INTEGER DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');
    
    // Create indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_branches_code ON branches(branch_code)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_branches_status ON branches(status)');
    
    // Insert default head office branch if not exists
    final now = DateTime.now().toIso8601String();
    final branchExists = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM branches')
    );
    
    if (branchExists == 0) {
      await db.insert('branches', {
        'branch_code': 'HQ',
        'branch_name': 'Head Office',
        'location': 'NYAKYERA – OMUKATOOGO, NTUNGAMO',
        'status': 'ACTIVE',
        'is_head_office': 1,
        'created_at': now,
      });
    }
    
    // Get the head office branch ID
    final headOfficeId = Sqflite.firstIntValue(
      await db.rawQuery('SELECT id FROM branches WHERE is_head_office = 1 LIMIT 1')
    ) ?? 1;
    
    // Add branch_id columns to existing tables
    await _addBranchColumn(db, 'users', headOfficeId);
    await _addBranchColumn(db, 'farmers', headOfficeId);
    await _addBranchColumn(db, 'collection_centers', headOfficeId);
    await _addBranchColumn(db, 'coffee_purchases', headOfficeId);
    await _addBranchColumn(db, 'advances', headOfficeId);
    await _addBranchColumn(db, 'warehouses', headOfficeId);
    await _addBranchColumn(db, 'coffee_sales', headOfficeId);
    await _addBranchColumn(db, 'expenses', headOfficeId);
  }
  
  /// Add branch_id column to a table
  static Future<void> _addBranchColumn(
    Database db,
    String tableName,
    int defaultBranchId,
  ) async {
    try {
      // Check if column exists
      final columns = await db.rawQuery('PRAGMA table_info($tableName)');
      final hasBranchColumn = columns.any((col) => col['name'] == 'branch_id');
      
      if (!hasBranchColumn) {
        // Add column with default value
        await db.execute(
          'ALTER TABLE $tableName ADD COLUMN branch_id INTEGER DEFAULT $defaultBranchId'
        );
        
        print('✓ Added branch_id to $tableName');
      }
    } catch (e) {
      print('⚠ Error adding branch_id to $tableName: $e');
      // Continue with other tables even if one fails
    }
  }
  
  /// Check if migration is needed
  static Future<bool> needsMigration(Database db) async {
    try {
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='branches'"
      );
      return tables.isEmpty;
    } catch (e) {
      return true;
    }
  }
}
