import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'core/theme.dart';
import 'services/storage_service.dart';
import 'services/router_service.dart';
import 'services/state_providers.dart';
import 'services/premium_service.dart';
import 'services/local_notification_service.dart';
import 'firebase_options.dart';

void main() async {
  // Ensure framework services are initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase with fallback safety if configs are not populated yet
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization warning (expected if google-services.json is missing): $e");
  }

  // Initialize local Hive database box storage
  await StorageService.init();

  // Initialize Premium subscription client
  await PremiumService.initialize();

  // Initialize Local Notifications Service
  await LocalNotificationService.initialize();

  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Zivo',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      routerConfig: appRouter,
    );
  }
}
