import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'firebase_service.dart';

class PremiumService {
  // Public RevenueCat API Keys
  static const _googleApiKey = 'test_lcoJeqNUsQqlAnqFdRvrTBVWama';
  static const _appleApiKey = 'test_lcoJeqNUsQqlAnqFdRvrTBVWama';

  static bool _initialized = false;
  static bool get isInitialized => _initialized;

  static final ValueNotifier<bool> isPremiumNotifier = ValueNotifier<bool>(false);

  /// Initializes the RevenueCat SDK and sets up user session
  static Future<void> initialize() async {
    if (_initialized) return;

    try {
      await Purchases.setLogLevel(LogLevel.debug);

      PurchasesConfiguration configuration;
      if (Platform.isAndroid) {
        configuration = PurchasesConfiguration(_googleApiKey);
      } else if (Platform.isIOS) {
        configuration = PurchasesConfiguration(_appleApiKey);
      } else {
        // Unsupported platforms
        return;
      }

      await Purchases.configure(configuration);
      _initialized = true;
      debugPrint("RevenueCat SDK configured successfully.");

      // Sync active user identity and listen to future changes
      await syncUserSession();
      FirebaseService.authStateChanges.listen((user) {
        syncUserSession();
      });
    } catch (e) {
      debugPrint("Error initializing RevenueCat: $e");
    }
  }

  /// Syncs RevenueCat user identity with the Firebase UID
  static Future<void> syncUserSession() async {
    if (!_initialized) return;

    final currentUser = FirebaseService.currentUser;
    if (currentUser != null) {
      try {
        final loginResult = await Purchases.logIn(currentUser.uid);
        await updatePremiumStatus(loginResult.customerInfo);
      } catch (e) {
        debugPrint("Error logging in user to RevenueCat: $e");
      }
    } else {
      try {
        await Purchases.logOut();
        isPremiumNotifier.value = false;
      } catch (e) {
        debugPrint("Error logging out user from RevenueCat: $e");
      }
    }
  }

  /// Updates local Premium notifier status from CustomerInfo entitlements
  static Future<void> updatePremiumStatus(CustomerInfo customerInfo) async {
    final premiumActive = customerInfo.entitlements.all['premium']?.isActive ?? false;
    isPremiumNotifier.value = premiumActive;
    debugPrint("Premium entitlement active status updated: $premiumActive");
  }

  /// Refreshes user premium status manually by fetching latest CustomerInfo
  static Future<bool> checkPremiumStatus() async {
    if (!_initialized) return false;
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      await updatePremiumStatus(customerInfo);
      return isPremiumNotifier.value;
    } catch (e) {
      debugPrint("Error checking RevenueCat customer info: $e");
      return false;
    }
  }

  /// Fetches available offerings from RevenueCat dashboard
  static Future<Offerings?> getOfferings() async {
    if (!_initialized) return null;
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      debugPrint("Error fetching RevenueCat offerings: $e");
      return null;
    }
  }

  /// Purchases a selected RevenueCat package
  static Future<bool> purchasePackage(Package package) async {
    if (!_initialized) return false;
    try {
      final customerInfo = await Purchases.purchasePackage(package);
      await updatePremiumStatus(customerInfo);
      return isPremiumNotifier.value;
    } catch (e) {
      debugPrint("Error purchasing package: $e");
      return false;
    }
  }

  /// Restores previous purchases
  static Future<bool> restorePurchases() async {
    if (!_initialized) return false;
    try {
      final customerInfo = await Purchases.restorePurchases();
      await updatePremiumStatus(customerInfo);
      return isPremiumNotifier.value;
    } catch (e) {
      debugPrint("Error restoring purchases: $e");
      return false;
    }
  }
}
