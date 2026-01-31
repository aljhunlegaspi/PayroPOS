import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/supabase_config.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/database/hive_service.dart';
import 'shared/services/connectivity_service.dart';
import 'shared/services/sync_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  await Supabase.initialize(
    url: SupabaseConfig.projectUrl,
    anonKey: SupabaseConfig.anonKey,
  );

  // Initialize local database for offline support
  await HiveService.instance.initialize();

  // Initialize connectivity monitoring
  await ConnectivityService.instance.initialize();

  // Initialize sync service
  await SyncService.instance.initialize();

  runApp(
    const ProviderScope(
      child: PayroPOSApp(),
    ),
  );
}

/// Get Supabase client instance
SupabaseClient get supabase => Supabase.instance.client;

class PayroPOSApp extends ConsumerStatefulWidget {
  const PayroPOSApp({super.key});

  @override
  ConsumerState<PayroPOSApp> createState() => _PayroPOSAppState();
}

class _PayroPOSAppState extends ConsumerState<PayroPOSApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize connectivity and sync providers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // This ensures the providers are initialized
      ref.read(connectivityProvider);
      ref.read(syncProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    if (state == AppLifecycleState.resumed) {
      // Check connectivity and trigger sync when app resumes
      ref.read(connectivityProvider.notifier).checkConnectivity();
      if (ref.read(connectivityProvider).isOnline) {
        ref.read(syncProvider.notifier).syncNow();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'PayroPOS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      routerConfig: router,
    );
  }
}
