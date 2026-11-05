import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../core/constants/app_constants.dart';
import 'migration_helper.dart';

/// Database Helper for HANS. B Coffee Management System
/// Implements complete schema with proper relationships and indexes
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._();
  static Database? _database;
  
  DatabaseHelper._();
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), AppConstants.databaseName);
    return await openDatabase(
      path,
      version: 2, // Updated version for branch support
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }
  
  Future<void> _onCreate(Database db, int version) async {
    // Execute all table creation statements
    await _createTables(db);
    await _createIndexes(db);
    await _seedInitialData(db);
  }
  
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle database migrations
    if (oldVersion < 2 && newVersion >= 2) {
      // Migrate to branch support
      await MigrationHelper.migrateToV2(db);
    }
  }
  
  Future<void> _createTables(Database db) async {
    // 1. Branches Table (MUST be first - other tables reference it)
    await db.execute('''
      CREATE TABLE branches (
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
    
    // 2. Users Table
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        username TEXT NOT NULL UNIQUE,
        password_hash TEXT NOT NULL,
        full_name TEXT NOT NULL,
        phone TEXT,
        email TEXT,
        role_id INTEGER NOT NULL,
        branch_id INTEGER,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        last_login TEXT,
        FOREIGN KEY (role_id) REFERENCES roles(id),
        FOREIGN KEY (branch_id) REFERENCES branches(id)
      )
    ''');
    
    // 3. Roles Table
    await db.execute('''
      CREATE TABLE roles (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        permissions TEXT NOT NULL,
        created_at TEXT NOT NULL
      )
    ''');
    
    // 4. Farmers Table
    await db.execute('''
      CREATE TABLE farmers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        farmer_code TEXT NOT NULL UNIQUE,
        full_name TEXT NOT NULL,
        phone TEXT,
        alternative_phone TEXT,
        village TEXT,
        parish TEXT,
        sub_county TEXT,
        district TEXT,
        branch_id INTEGER,
        farmer_group_id INTEGER,
        collection_center_id INTEGER,
        farm_size REAL,
        coffee_type TEXT,
        registration_date TEXT NOT NULL,
        status TEXT DEFAULT 'ACTIVE',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (branch_id) REFERENCES branches(id),
        FOREIGN KEY (farmer_group_id) REFERENCES farmer_groups(id),
        FOREIGN KEY (collection_center_id) REFERENCES collection_centers(id)
      )
    ''');
    
    // 5. Farmer Groups Table
    await db.execute('''
      CREATE TABLE farmer_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        leader_name TEXT,
        phone TEXT,
        location TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    
    // 6. Collection Centers Table
    await db.execute('''
      CREATE TABLE collection_centers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        location TEXT,
        branch_id INTEGER,
        manager_name TEXT,
        contact_phone TEXT,
        status TEXT DEFAULT 'ACTIVE',
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (branch_id) REFERENCES branches(id)
      )
    ''');
    
    // 7. Coffee Types Table
    await db.execute('''
      CREATE TABLE coffee_types (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    
    // 8. Coffee Grades Table
    await db.execute('''
      CREATE TABLE coffee_grades (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    
    // 9. Seasons Table
    await db.execute('''
      CREATE TABLE seasons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        status TEXT DEFAULT 'ACTIVE',
        created_at TEXT NOT NULL
      )
    ''');
    
    // 10. Pricing Rules Table
    await db.execute('''
      CREATE TABLE pricing_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        coffee_type_id INTEGER NOT NULL,
        coffee_grade_id INTEGER,
        collection_center_id INTEGER,
        season_id INTEGER,
        price_per_kg REAL NOT NULL,
        effective_date TEXT NOT NULL,
        end_date TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        FOREIGN KEY (coffee_type_id) REFERENCES coffee_types(id),
        FOREIGN KEY (coffee_grade_id) REFERENCES coffee_grades(id),
        FOREIGN KEY (collection_center_id) REFERENCES collection_centers(id),
        FOREIGN KEY (season_id) REFERENCES seasons(id)
      )
    ''');
    
    // 11. Quality Deduction Rules Table
    await db.execute('''
      CREATE TABLE quality_deduction_rules (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        deduction_type TEXT NOT NULL,
        deduction_amount REAL NOT NULL,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');
    
    // 12. Advances Table
    await db.execute('''
      CREATE TABLE advances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        advance_number TEXT NOT NULL UNIQUE,
        farmer_id INTEGER NOT NULL,
        branch_id INTEGER,
        season_id INTEGER,
        amount REAL NOT NULL,
        purpose TEXT,
        approved_by INTEGER,
        issued_by INTEGER NOT NULL,
        payment_method TEXT,
        reference TEXT,
        status TEXT DEFAULT 'PENDING',
        date_issued TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (farmer_id) REFERENCES farmers(id),
        FOREIGN KEY (branch_id) REFERENCES branches(id),
        FOREIGN KEY (season_id) REFERENCES seasons(id),
        FOREIGN KEY (approved_by) REFERENCES users(id),
        FOREIGN KEY (issued_by) REFERENCES users(id)
      )
    ''');
    
    // 13. Advance Recoveries Table
    await db.execute('''
      CREATE TABLE advance_recoveries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        advance_id INTEGER NOT NULL,
        coffee_purchase_id INTEGER,
        amount_recovered REAL NOT NULL,
        recovery_date TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (advance_id) REFERENCES advances(id),
        FOREIGN KEY (coffee_purchase_id) REFERENCES coffee_purchases(id)
      )
    ''');
    
    // 14. Coffee Purchases Table (CRITICAL - Main buying transaction)
    await db.execute('''
      CREATE TABLE coffee_purchases (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        purchase_number TEXT NOT NULL UNIQUE,
        farmer_id INTEGER NOT NULL,
        branch_id INTEGER,
        collection_center_id INTEGER NOT NULL,
        coffee_type_id INTEGER NOT NULL,
        season_id INTEGER,
        gross_weight REAL NOT NULL,
        quality_deduction_amount REAL DEFAULT 0,
        payable_weight REAL NOT NULL,
        buying_price_per_kg REAL NOT NULL,
        coffee_value REAL NOT NULL,
        milling_rate_per_kg REAL NOT NULL,
        milling_charge REAL NOT NULL,
        milling_charge_base TEXT DEFAULT 'GROSS_WEIGHT',
        advance_recovery_amount REAL DEFAULT 0,
        other_deductions REAL DEFAULT 0,
        net_payment REAL NOT NULL,
        payment_status TEXT DEFAULT 'PENDING',
        payment_method TEXT,
        quality_condition TEXT,
        quality_rule_id INTEGER,
        staff_id INTEGER NOT NULL,
        purchase_date TEXT NOT NULL,
        notes TEXT,
        is_voided INTEGER DEFAULT 0,
        voided_by INTEGER,
        voided_at TEXT,
        void_reason TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (farmer_id) REFERENCES farmers(id),
        FOREIGN KEY (branch_id) REFERENCES branches(id),
        FOREIGN KEY (collection_center_id) REFERENCES collection_centers(id),
        FOREIGN KEY (coffee_type_id) REFERENCES coffee_types(id),
        FOREIGN KEY (season_id) REFERENCES seasons(id),
        FOREIGN KEY (quality_rule_id) REFERENCES quality_deduction_rules(id),
        FOREIGN KEY (staff_id) REFERENCES users(id),
        FOREIGN KEY (voided_by) REFERENCES users(id)
      )
    ''');
    
    // 15. Farmer Payments Table
    await db.execute('''
      CREATE TABLE farmer_payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        payment_number TEXT NOT NULL UNIQUE,
        farmer_id INTEGER NOT NULL,
        coffee_purchase_id INTEGER,
        amount REAL NOT NULL,
        payment_method TEXT NOT NULL,
        reference TEXT,
        payment_date TEXT NOT NULL,
        notes TEXT,
        created_by INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (farmer_id) REFERENCES farmers(id),
        FOREIGN KEY (coffee_purchase_id) REFERENCES coffee_purchases(id),
        FOREIGN KEY (created_by) REFERENCES users(id)
      )
    ''');
    
    // 16. Warehouses Table
    await db.execute('''
      CREATE TABLE warehouses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        location TEXT,
        branch_id INTEGER,
        capacity_kg REAL,
        manager_id INTEGER,
        status TEXT DEFAULT 'ACTIVE',
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (branch_id) REFERENCES branches(id),
        FOREIGN KEY (manager_id) REFERENCES users(id)
      )
    ''');
    
    // 17. Milling Batches Table
    await db.execute('''
      CREATE TABLE milling_batches (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        batch_number TEXT NOT NULL UNIQUE,
        source_center_id INTEGER,
        source_warehouse_id INTEGER,
        input_coffee_type_id INTEGER NOT NULL,
        input_quantity REAL NOT NULL,
        machine_name TEXT,
        operator_id INTEGER,
        start_time TEXT NOT NULL,
        end_time TEXT,
        status TEXT DEFAULT 'IN_PROGRESS',
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (source_center_id) REFERENCES collection_centers(id),
        FOREIGN KEY (source_warehouse_id) REFERENCES warehouses(id),
        FOREIGN KEY (input_coffee_type_id) REFERENCES coffee_types(id),
        FOREIGN KEY (operator_id) REFERENCES users(id)
      )
    ''');
    
    // 18. Milling Outputs Table
    await db.execute('''
      CREATE TABLE milling_outputs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        milling_batch_id INTEGER NOT NULL,
        output_type TEXT NOT NULL,
        coffee_grade_id INTEGER,
        quantity REAL NOT NULL,
        warehouse_id INTEGER,
        notes TEXT,
        created_at TEXT NOT NULL,
        FOREIGN KEY (milling_batch_id) REFERENCES milling_batches(id),
        FOREIGN KEY (coffee_grade_id) REFERENCES coffee_grades(id),
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(id)
      )
    ''');
    
    // 19. Inventory Transactions Table
    await db.execute('''
      CREATE TABLE inventory_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        transaction_type TEXT NOT NULL,
        warehouse_id INTEGER NOT NULL,
        coffee_type_id INTEGER NOT NULL,
        coffee_grade_id INTEGER,
        quantity REAL NOT NULL,
        reference_type TEXT,
        reference_id INTEGER,
        transaction_date TEXT NOT NULL,
        notes TEXT,
        created_by INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(id),
        FOREIGN KEY (coffee_type_id) REFERENCES coffee_types(id),
        FOREIGN KEY (coffee_grade_id) REFERENCES coffee_grades(id),
        FOREIGN KEY (created_by) REFERENCES users(id)
      )
    ''');
    
    // 20. Inventory Balances View (Materialized as table for performance)
    await db.execute('''
      CREATE TABLE inventory_balances (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        warehouse_id INTEGER NOT NULL,
        coffee_type_id INTEGER NOT NULL,
        coffee_grade_id INTEGER,
        quantity REAL NOT NULL DEFAULT 0,
        last_updated TEXT NOT NULL,
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(id),
        FOREIGN KEY (coffee_type_id) REFERENCES coffee_types(id),
        FOREIGN KEY (coffee_grade_id) REFERENCES coffee_grades(id),
        UNIQUE(warehouse_id, coffee_type_id, coffee_grade_id)
      )
    ''');
    
    // 21. Buyers Table
    await db.execute('''
      CREATE TABLE buyers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        company_name TEXT,
        phone TEXT,
        email TEXT,
        address TEXT,
        status TEXT DEFAULT 'ACTIVE',
        created_at TEXT NOT NULL,
        updated_at TEXT
      )
    ''');
    
    // 22. Coffee Sales Table
    await db.execute('''
      CREATE TABLE coffee_sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_number TEXT NOT NULL UNIQUE,
        buyer_id INTEGER NOT NULL,
        branch_id INTEGER,
        warehouse_id INTEGER NOT NULL,
        coffee_type_id INTEGER NOT NULL,
        coffee_grade_id INTEGER,
        quantity REAL NOT NULL,
        price_per_kg REAL NOT NULL,
        total_amount REAL NOT NULL,
        payment_status TEXT DEFAULT 'PENDING',
        payment_method TEXT,
        reference TEXT,
        sale_date TEXT NOT NULL,
        notes TEXT,
        created_by INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (buyer_id) REFERENCES buyers(id),
        FOREIGN KEY (branch_id) REFERENCES branches(id),
        FOREIGN KEY (warehouse_id) REFERENCES warehouses(id),
        FOREIGN KEY (coffee_type_id) REFERENCES coffee_types(id),
        FOREIGN KEY (coffee_grade_id) REFERENCES coffee_grades(id),
        FOREIGN KEY (created_by) REFERENCES users(id)
      )
    ''');
    
    // 23. Expense Categories Table
    await db.execute('''
      CREATE TABLE expense_categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    
    // 24. Expenses Table
    await db.execute('''
      CREATE TABLE expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        expense_number TEXT NOT NULL UNIQUE,
        branch_id INTEGER,
        category_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        description TEXT NOT NULL,
        payment_method TEXT,
        reference TEXT,
        expense_date TEXT NOT NULL,
        approved_by INTEGER,
        recorded_by INTEGER NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT,
        FOREIGN KEY (branch_id) REFERENCES branches(id),
        FOREIGN KEY (category_id) REFERENCES expense_categories(id),
        FOREIGN KEY (approved_by) REFERENCES users(id),
        FOREIGN KEY (recorded_by) REFERENCES users(id)
      )
    ''');
    
    // 25. Payment Methods Table
    await db.execute('''
      CREATE TABLE payment_methods (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        description TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
    
    // 26. Audit Logs Table
    await db.execute('''
      CREATE TABLE audit_logs (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        action TEXT NOT NULL,
        table_name TEXT NOT NULL,
        record_id INTEGER,
        old_values TEXT,
        new_values TEXT,
        ip_address TEXT,
        device_info TEXT,
        timestamp TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES users(id)
      )
    ''');
    
    // 27. System Settings Table
    await db.execute('''
      CREATE TABLE system_settings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        key TEXT NOT NULL UNIQUE,
        value TEXT NOT NULL,
        description TEXT,
        updated_by INTEGER,
        updated_at TEXT,
        FOREIGN KEY (updated_by) REFERENCES users(id)
      )
    ''');
  }
  
  Future<void> _createIndexes(Database db) async {
    // Branch indexes
    await db.execute('CREATE INDEX idx_branches_code ON branches(branch_code)');
    await db.execute('CREATE INDEX idx_branches_status ON branches(status)');
    
    // Farmers indexes
    await db.execute('CREATE INDEX idx_farmers_code ON farmers(farmer_code)');
    await db.execute('CREATE INDEX idx_farmers_phone ON farmers(phone)');
    await db.execute('CREATE INDEX idx_farmers_status ON farmers(status)');
    
    // Coffee purchases indexes
    await db.execute('CREATE INDEX idx_purchases_number ON coffee_purchases(purchase_number)');
    await db.execute('CREATE INDEX idx_purchases_farmer ON coffee_purchases(farmer_id)');
    await db.execute('CREATE INDEX idx_purchases_date ON coffee_purchases(purchase_date)');
    await db.execute('CREATE INDEX idx_purchases_season ON coffee_purchases(season_id)');
    
    // Advances indexes
    await db.execute('CREATE INDEX idx_advances_number ON advances(advance_number)');
    await db.execute('CREATE INDEX idx_advances_farmer ON advances(farmer_id)');
    await db.execute('CREATE INDEX idx_advances_status ON advances(status)');
    
    // Inventory indexes
    await db.execute('CREATE INDEX idx_inventory_warehouse ON inventory_transactions(warehouse_id)');
    await db.execute('CREATE INDEX idx_inventory_date ON inventory_transactions(transaction_date)');
    
    // Audit logs index
    await db.execute('CREATE INDEX idx_audit_timestamp ON audit_logs(timestamp)');
    await db.execute('CREATE INDEX idx_audit_user ON audit_logs(user_id)');
  }
  
  Future<void> _seedInitialData(Database db) async {
    final now = DateTime.now().toIso8601String();
    
    // Insert default branch (Head Office)
    await db.insert('branches', {
      'branch_code': 'HQ',
      'branch_name': 'Head Office',
      'location': AppConstants.companyLocation,
      'status': 'ACTIVE',
      'is_head_office': 1,
      'created_at': now,
    });
    
    // Insert default roles
    await db.insert('roles', {
      'name': 'SUPER_ADMIN',
      'description': 'Full system access',
      'permissions': 'ALL',
      'created_at': now,
    });
    
    await db.insert('roles', {
      'name': 'MANAGER',
      'description': 'Management access',
      'permissions': 'DASHBOARD,REPORTS,FARMERS,BUYING,ADVANCES,MILLING,INVENTORY,SALES',
      'created_at': now,
    });
    
    await db.insert('roles', {
      'name': 'BUYER',
      'description': 'Coffee buying operations',
      'permissions': 'FARMERS,BUYING,RECEIPTS',
      'created_at': now,
    });
    
    // Insert default coffee types
    final coffeeTypes = ['Parchment', 'Kiboko', 'Fresh Cherries', 'FAQ', 'Clean Coffee'];
    for (var type in coffeeTypes) {
      await db.insert('coffee_types', {
        'name': type,
        'is_active': 1,
        'created_at': now,
      });
    }
    
    // Insert default payment methods
    final paymentMethods = ['Cash', 'Mobile Money', 'Bank Transfer', 'Cheque'];
    for (var method in paymentMethods) {
      await db.insert('payment_methods', {
        'name': method,
        'is_active': 1,
        'created_at': now,
      });
    }
    
    // Insert default quality deduction rules
    await db.insert('quality_deduction_rules', {
      'name': 'Properly Dry',
      'description': 'No deduction - coffee is properly dry',
      'deduction_type': 'FIXED',
      'deduction_amount': 0.0,
      'is_active': 1,
      'created_at': now,
    });
    
    await db.insert('quality_deduction_rules', {
      'name': 'Not Sufficiently Dry',
      'description': 'Standard 2 kg deduction for insufficient dryness',
      'deduction_type': 'FIXED',
      'deduction_amount': 2.0,
      'is_active': 1,
      'created_at': now,
    });
    
    // Insert default expense categories
    final expenseCategories = [
      'Transport', 'Fuel', 'Labour', 'Milling', 'Repairs',
      'Utilities', 'Packaging', 'Administration', 'Farmer-related', 'Other'
    ];
    for (var category in expenseCategories) {
      await db.insert('expense_categories', {
        'name': category,
        'is_active': 1,
        'created_at': now,
      });
    }
    
    // Insert system settings
    final settings = {
      'company_name': AppConstants.companyName,
      'company_division': AppConstants.companyDivision,
      'company_location': AppConstants.companyLocation,
      'currency': AppConstants.currency,
      'default_milling_rate': AppConstants.defaultMillingRate.toString(),
      'milling_charge_base': AppConstants.millingChargeBase,
      'current_season_id': '',
    };
    
    for (var entry in settings.entries) {
      await db.insert('system_settings', {
        'key': entry.key,
        'value': entry.value,
        'updated_at': now,
      });
    }
  }
  
  /// Close database connection
  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}
