import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/store/presentation/screens/store_setup_screen.dart';
import '../../features/store/presentation/screens/store_settings_screen.dart';
import '../../features/store/presentation/screens/edit_store_screen.dart';
import '../../features/store/presentation/screens/add_location_screen.dart';
import '../../features/store/presentation/screens/edit_location_screen.dart';
import '../../features/store/presentation/screens/sync_status_screen.dart';
import '../../features/pos/presentation/screens/home_screen.dart';
import '../../features/products/presentation/screens/products_screen.dart';
import '../../features/products/presentation/screens/add_product_screen.dart';
import '../../features/products/presentation/screens/edit_product_screen.dart';
import '../../features/products/presentation/screens/barcode_scanner_screen.dart';
import '../../features/products/presentation/screens/categories_screen.dart';
import '../../features/products/presentation/screens/restock_screen.dart';
import '../../features/pos/presentation/screens/pos_screen.dart';
import '../../features/pos/presentation/screens/checkout_screen.dart';
import '../../features/pos/presentation/screens/receipt_screen.dart';
import '../../features/staff/presentation/screens/staff_list_screen.dart';
import '../../features/staff/presentation/screens/add_staff_screen.dart';
import '../../features/reports/presentation/screens/reports_screen.dart';
import '../../features/customers/presentation/screens/customers_screen.dart';
import '../../features/customers/presentation/screens/add_customer_screen.dart';
import '../../features/customers/presentation/screens/customer_detail_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    routes: [
      // Splash Screen
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // Auth Routes
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: 'register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: 'forgotPassword',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // Store Setup
      GoRoute(
        path: '/store-setup',
        name: 'storeSetup',
        builder: (context, state) => const StoreSetupScreen(),
      ),

      // Main App Routes
      GoRoute(
        path: '/home',
        name: 'home',
        builder: (context, state) => const HomeScreen(),
      ),

      // Store Settings Routes
      GoRoute(
        path: '/store-settings',
        name: 'storeSettings',
        builder: (context, state) => const StoreSettingsScreen(),
      ),
      GoRoute(
        path: '/store-settings/edit-store',
        name: 'editStore',
        builder: (context, state) => const EditStoreScreen(),
      ),
      GoRoute(
        path: '/store-settings/add-location',
        name: 'addLocation',
        builder: (context, state) => const AddLocationScreen(),
      ),
      GoRoute(
        path: '/store-settings/edit-location/:locationId',
        name: 'editLocation',
        builder: (context, state) {
          final locationId = state.pathParameters['locationId']!;
          return EditLocationScreen(locationId: locationId);
        },
      ),
      GoRoute(
        path: '/sync-status',
        name: 'syncStatus',
        builder: (context, state) => const SyncStatusScreen(),
      ),

      // Product Routes
      GoRoute(
        path: '/products',
        name: 'products',
        builder: (context, state) => const ProductsScreen(),
      ),
      GoRoute(
        path: '/products/categories',
        name: 'categories',
        builder: (context, state) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '/products/add',
        name: 'addProduct',
        builder: (context, state) {
          final scannedBarcode = state.extra as String?;
          return AddProductScreen(scannedBarcode: scannedBarcode);
        },
      ),
      GoRoute(
        path: '/products/scan',
        name: 'scanBarcode',
        builder: (context, state) {
          final returnResult = state.extra as bool? ?? true;
          return BarcodeScannerScreen(returnResult: returnResult);
        },
      ),
      GoRoute(
        path: '/products/edit/:productId',
        name: 'editProduct',
        builder: (context, state) {
          final productId = state.pathParameters['productId']!;
          return EditProductScreen(productId: productId);
        },
      ),
      GoRoute(
        path: '/products/:productId/restock',
        name: 'restockProduct',
        builder: (context, state) {
          final productId = state.pathParameters['productId']!;
          return RestockScreen(productId: productId);
        },
      ),

      // Staff Management Routes
      GoRoute(
        path: '/staff',
        name: 'staffList',
        builder: (context, state) => const StaffListScreen(),
      ),
      GoRoute(
        path: '/staff/add',
        name: 'addStaff',
        builder: (context, state) => const AddStaffScreen(),
      ),

      // POS / Sales Routes
      GoRoute(
        path: '/pos',
        name: 'pos',
        builder: (context, state) => const PosScreen(),
      ),
      GoRoute(
        path: '/checkout',
        name: 'checkout',
        builder: (context, state) => const CheckoutScreen(),
      ),
      GoRoute(
        path: '/receipt/:transactionId',
        name: 'receipt',
        builder: (context, state) {
          final transactionId = state.pathParameters['transactionId']!;
          return ReceiptScreen(transactionId: transactionId);
        },
      ),

      // Reports Route
      GoRoute(
        path: '/reports',
        name: 'reports',
        builder: (context, state) => const ReportsScreen(),
      ),

      // Customer Routes
      GoRoute(
        path: '/customers',
        name: 'customers',
        builder: (context, state) => const CustomersScreen(),
      ),
      GoRoute(
        path: '/customers/add',
        name: 'addCustomer',
        builder: (context, state) => const AddCustomerScreen(),
      ),
      GoRoute(
        path: '/customers/:customerId',
        name: 'customerDetail',
        builder: (context, state) {
          final customerId = state.pathParameters['customerId']!;
          return CustomerDetailScreen(customerId: customerId);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              state.uri.toString(),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/login'),
              child: const Text('Go to Login'),
            ),
          ],
        ),
      ),
    ),
  );
});
