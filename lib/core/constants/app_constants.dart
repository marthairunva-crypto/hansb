/// Application-wide constants for HANS. B Trading Company Limited Coffee Management System
class AppConstants {
  // Company Information
  static const String companyName = 'HANS. B TRADING COMPANY LIMITED';
  static const String companyNameShort = 'HANS. B TRADING CO.';
  static const String companyDivision = 'COFFEE FACTORY';
  static const String companyLocation = 'NYAKYERA – OMUKATOOGO, NTUNGAMO';
  static const String supportPhone = '0392945082';
  static const String supportPhoneAlt = '0706256453';
  static const String supportEmail = 'hansbtrading@gmail.com';
  
  // Firebase Collections - Prefixed with hansb_
  static const String usersCollection = 'hansb_users';
  static const String farmersCollection = 'hansb_farmers';
  static const String purchasesCollection = 'hansb_purchases';
  static const String advancesCollection = 'hansb_advances';
  static const String salesCollection = 'hansb_sales';
  
  // Currency
  static const String currency = 'UGX';
  static const String currencySymbol = 'UGX';
  
  // Receipt Prefixes
  static const String purchasePrefix = 'HBT-PUR-';
  static const String advancePrefix = 'HBT-ADV-';
  static const String millingPrefix = 'HBT-MIL-';
  static const String salePrefix = 'HBT-SAL-';
  static const String paymentPrefix = 'HBT-PAY-';
  
  // Database
  static const String databaseName = 'hans_b_coffee.db';
  static const int databaseVersion = 1;
  
  // Date Formats
  static const String dateFormat = 'dd/MM/yyyy';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
  static const String timeFormat = 'HH:mm';
  
  // Pagination
  static const int defaultPageSize = 50;
  
  // Validation
  static const double minWeight = 0.01;
  static const double maxWeight = 100000.0;
  static const double minPrice = 0.01;
  static const double maxPrice = 1000000.0;
  
  // Business Rules
  static const String millingChargeBase = 'GROSS_WEIGHT'; // Options: GROSS_WEIGHT, PAYABLE_WEIGHT
  
  // Default Milling Rate (can be configured)
  static const double defaultMillingRate = 300.0;
}
