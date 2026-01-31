/// App-wide constants for PayroPOS
class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'PayroPOS';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Point of Sale with Customer Credit Tracking';

  // Firebase Collections
  static const String usersCollection = 'users';
  static const String storesCollection = 'stores';
  static const String productsCollection = 'products';
  static const String categoriesCollection = 'categories';
  static const String customersCollection = 'customers';
  static const String transactionsCollection = 'transactions';
  static const String creditsCollection = 'credits';
  static const String staffCollection = 'staff';
  static const String inventoryCollection = 'inventory';

  // User Roles
  static const String roleSuperAdmin = 'super_admin';
  static const String roleStoreOwner = 'store_owner';
  static const String roleStoreStaff = 'store_staff';
  static const String roleCustomer = 'customer';

  // Credit Status
  static const String creditStatusGood = 'good';
  static const String creditStatusWarning = 'warning';
  static const String creditStatusOverdue = 'overdue';

  // Transaction Types
  static const String transactionCash = 'cash';
  static const String transactionCredit = 'credit';
  static const String transactionPartial = 'partial';

  // Pagination
  static const int defaultPageSize = 20;
  static const int maxPageSize = 100;

  // Image Sizes
  static const int thumbnailSize = 150;
  static const int productImageSize = 500;
  static const int logoSize = 300;

  // Validation
  static const int minPasswordLength = 6;
  static const int maxProductNameLength = 100;
  static const int maxDescriptionLength = 500;

  // Currency (Philippine Peso)
  static const String currencySymbol = '₱';
  static const String currencyCode = 'PHP';

  // Date Formats
  static const String dateFormat = 'MMM dd, yyyy';
  static const String timeFormat = 'hh:mm a';
  static const String dateTimeFormat = 'MMM dd, yyyy hh:mm a';
}
