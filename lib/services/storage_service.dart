import 'dart:convert';
import 'dart:math';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user_profile.dart';

class StorageService {
  static const String _profileBoxName = 'user_profile_box';
  static const String _dailyBoxName = 'daily_metrics_box';
  static const String _workoutBoxName = 'workout_box';
  static const String _reminderBoxName = 'reminder_box';
  static const String _barcodeCacheBoxName = 'barcode_cache_box';
  static const String _productCacheBoxName = 'product_cache_box';
  static const String _analysisCacheBoxName = 'analysis_cache_box';
  static const String _recentScansBoxName = 'recent_scans_box';

  static late Box<UserProfile> _profileBox;
  static late Box<Map> _dailyBox;
  static late Box<Map> _workoutBox;
  static late Box<Map> _reminderBox;
  static late Box<Map> _barcodeCacheBox;
  static late Box<Map> _productCacheBox;
  static late Box<Map> _analysisCacheBox;
  static late Box<Map> _recentScansBox;

  static Future<List<int>> _getOrCreateEncryptionKey() async {
    const secureStorage = FlutterSecureStorage();
    try {
      final base64Key = await secureStorage.read(key: 'hive_encryption_key');
      if (base64Key == null) {
        final key = Hive.generateSecureKey();
        await secureStorage.write(key: 'hive_encryption_key', value: base64Encode(key));
        return key;
      } else {
        return base64Decode(base64Key);
      }
    } catch (e) {
      // Fallback key derivation in case secure storage is not available (e.g. test environment or unsupported platform)
      final fallbackSeed = 'zivofit_secure_local_encryption_key_seed_10385';
      return List<int>.generate(32, (i) => (fallbackSeed.codeUnitAt(i % fallbackSeed.length) + i) % 256);
    }
  }

  /// Initializes Hive database and opens the required boxes.
  static Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserProfileAdapter());
    }

    final encryptionKey = await _getOrCreateEncryptionKey();
    final cipher = HiveAesCipher(encryptionKey);

    Future<Box<T>> openSecureBox<T>(String name) async {
      try {
        return await Hive.openBox<T>(name, encryptionCipher: cipher);
      } catch (e) {
        // Fallback for upgrade cases where database was previously unencrypted
        await Hive.deleteBoxFromDisk(name);
        return await Hive.openBox<T>(name, encryptionCipher: cipher);
      }
    }

    // Open encrypted boxes
    _profileBox = await openSecureBox<UserProfile>(_profileBoxName);
    _dailyBox = await openSecureBox<Map>(_dailyBoxName);
    _workoutBox = await openSecureBox<Map>(_workoutBoxName);
    _reminderBox = await openSecureBox<Map>(_reminderBoxName);
    _barcodeCacheBox = await openSecureBox<Map>(_barcodeCacheBoxName);
    _productCacheBox = await openSecureBox<Map>(_productCacheBoxName);
    _analysisCacheBox = await openSecureBox<Map>(_analysisCacheBoxName);
    _recentScansBox = await openSecureBox<Map>(_recentScansBoxName);

    // Do not seed dummy data automatically on startup per user request
  }

  /// Retrieves the saved user profile from Hive.
  static UserProfile? getUserProfile() {
    return _profileBox.get('current_profile');
  }

  /// Saves the user profile in Hive.
  static Future<void> saveUserProfile(UserProfile profile) async {
    await _profileBox.put('current_profile', profile);
  }

  /// Retrieves the profile picture base64 from Hive.
  static String? getProfilePicture() {
    final raw = _reminderBox.get('profile_picture');
    if (raw == null) return null;
    return raw['base64'] as String?;
  }

  /// Saves the profile picture base64 to Hive.
  static Future<void> saveProfilePicture(String? base64Str) async {
    if (base64Str == null) {
      await _reminderBox.delete('profile_picture');
    } else {
      await _reminderBox.put('profile_picture', {'base64': base64Str});
    }
  }

  /// Retrieves the custom background wallpaper base64 from Hive.
  static String? getCustomBackground() {
    final raw = _reminderBox.get('custom_background');
    if (raw == null) return null;
    return raw['base64'] as String?;
  }

  /// Saves the custom background wallpaper base64 to Hive.
  static Future<void> saveCustomBackground(String? base64Str) async {
    if (base64Str == null) {
      await _reminderBox.delete('custom_background');
    } else {
      await _reminderBox.put('custom_background', {'base64': base64Str});
    }
  }

  /// Retrieves the accent color index from Hive.
  static int getAccentColorIndex() {
    final raw = _reminderBox.get('accent_color_index');
    if (raw == null) return 0;
    return raw['index'] as int? ?? 0;
  }

  /// Saves the accent color index to Hive.
  static Future<void> saveAccentColorIndex(int index) async {
    await _reminderBox.put('accent_color_index', {'index': index});
  }

  /// Retrieves whether mock/fake data is enabled.
  static bool getFakeDataEnabled() {
    final raw = _reminderBox.get('fake_data_enabled');
    if (raw == null) return false;
    return raw['enabled'] as bool? ?? false;
  }

  /// Saves whether mock/fake data is enabled.
  static Future<void> saveFakeDataEnabled(bool enabled) async {
    await _reminderBox.put('fake_data_enabled', {'enabled': enabled});
  }

  /// Retrieves the custom carbs goal.
  static int getCarbsGoal() {
    final raw = _reminderBox.get('carbs_goal');
    if (raw == null) return 260;
    return raw['val'] as int? ?? 260;
  }

  /// Saves the custom carbs goal.
  static Future<void> saveCarbsGoal(int val) async {
    await _reminderBox.put('carbs_goal', {'val': val});
  }

  /// Retrieves the custom fats goal.
  static int getFatsGoal() {
    final raw = _reminderBox.get('fats_goal');
    if (raw == null) return 70;
    return raw['val'] as int? ?? 70;
  }

  /// Saves the custom fats goal.
  static Future<void> saveFatsGoal(int val) async {
    await _reminderBox.put('fats_goal', {'val': val});
  }

  /// Clears only mock nutrition logs and workout logs.
  static Future<void> clearMockDataOnly() async {
    final keys = List<String>.from(_dailyBox.keys.map((k) => k.toString()));
    for (final key in keys) {
      final val = _dailyBox.get(key);
      if (val != null) {
        final map = Map<String, dynamic>.from(val);
        final bool isMock = map['is_mock'] == true || (
          map['logged_items'] != null &&
          (map['logged_items'] as List).isNotEmpty &&
          !(map['logged_items'] as List).any((item) {
            final name = item['name']?.toString() ?? '';
            return name != 'Oatmeal & Banana' &&
                   name != 'Protein Shake & Banana' &&
                   name != 'Tuna Salad Wrap' &&
                   name != 'Avocado Toast & Eggs' &&
                   name != 'Grilled Chicken & Rice' &&
                   name != 'Baked Salmon & Broccoli' &&
                   name != 'Baked Salmon & Asparagus' &&
                   name != 'Whey Protein Shake & Almonds';
          })
        );
        if (isMock) {
          await _dailyBox.delete(key);
        }
      }
    }

    final rawList = _workoutBox.get('workout_list');
    if (rawList != null) {
      final list = (rawList['list'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [];
      list.removeWhere((w) => w['id']?.toString().startsWith('mock_') ?? false);
      await _workoutBox.put('workout_list', {'list': list});
    }
  }

  /// Clears the user profile and daily stats (resets the database).
  static Future<void> clearAllData() async {
    await _profileBox.clear();
    await _dailyBox.clear();
    await _workoutBox.clear();
    await _reminderBox.clear();
    await _barcodeCacheBox.clear();
    await _productCacheBox.clear();
    await _analysisCacheBox.clear();
    await _recentScansBox.clear();
  }

  // --- Zivofit Vision Lens Cache API ---

  /// Reads a product by barcode. If TTL (30 Days) has expired, removes it from cache and returns null.
  static Map<String, dynamic>? getCachedBarcode(String barcode) {
    final raw = _barcodeCacheBox.get(barcode);
    if (raw == null) return null;
    final map = Map<String, dynamic>.from(raw);
    final timestamp = map['timestamp'] as int?;
    if (timestamp == null || DateTime.now().millisecondsSinceEpoch - timestamp > 30 * 24 * 60 * 60 * 1000) {
      _barcodeCacheBox.delete(barcode);
      return null;
    }
    return Map<String, dynamic>.from(map['data']);
  }

  /// Caches a product by barcode with the current timestamp.
  static Future<void> saveCachedBarcode(String barcode, Map<String, dynamic> productJson) async {
    await _barcodeCacheBox.put(barcode, {
      'data': productJson,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Reads a search result by term. If TTL (30 Days) has expired, removes it from cache and returns null.
  static Map<String, dynamic>? getCachedProductSearch(String term) {
    final cleanTerm = term.trim().toLowerCase();
    final raw = _productCacheBox.get(cleanTerm);
    if (raw == null) return null;
    final map = Map<String, dynamic>.from(raw);
    final timestamp = map['timestamp'] as int?;
    if (timestamp == null || DateTime.now().millisecondsSinceEpoch - timestamp > 30 * 24 * 60 * 60 * 1000) {
      _productCacheBox.delete(cleanTerm);
      return null;
    }
    return Map<String, dynamic>.from(map['data']);
  }

  /// Caches a search result by term with current timestamp.
  static Future<void> saveCachedProductSearch(String term, Map<String, dynamic> productJson) async {
    final cleanTerm = term.trim().toLowerCase();
    await _productCacheBox.put(cleanTerm, {
      'data': productJson,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Reads analysis cache by key. If TTL (30 Days) has expired, removes it and returns null.
  static Map<String, dynamic>? getCachedAnalysis(String key) {
    final raw = _analysisCacheBox.get(key);
    if (raw == null) return null;
    final map = Map<String, dynamic>.from(raw);
    final timestamp = map['timestamp'] as int?;
    if (timestamp == null || DateTime.now().millisecondsSinceEpoch - timestamp > 30 * 24 * 60 * 60 * 1000) {
      _analysisCacheBox.delete(key);
      return null;
    }
    return Map<String, dynamic>.from(map['data']);
  }

  /// Caches analysis result by key with current timestamp.
  static Future<void> saveCachedAnalysis(String key, Map<String, dynamic> analysisJson) async {
    await _analysisCacheBox.put(key, {
      'data': analysisJson,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Retrieves list of all recent scans. Handles TTL filter for scan entries.
  static List<Map<String, dynamic>> getRecentScans() {
    final rawList = _recentScansBox.get('scans_list');
    if (rawList == null) return [];
    final list = (rawList['list'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    
    // Filter out expired items (> 30 days)
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final filtered = list.where((item) {
      final timestamp = item['timestamp'] as int?;
      if (timestamp == null) return false;
      return (nowMs - timestamp) <= 30 * 24 * 60 * 60 * 1000;
    }).toList();

    if (filtered.length != list.length) {
      // Update cache box if some items expired
      _recentScansBox.put('scans_list', {'list': filtered});
    }

    return filtered;
  }

  /// Adds a product to the recent scans list.
  static Future<void> addRecentScan(Map<String, dynamic> productJson) async {
    final list = getRecentScans();
    final name = productJson['name'];
    // Remove duplicate by name to keep it on top
    list.removeWhere((item) => item['name'] == name);
    list.insert(0, {
      ...productJson,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    });
    await _recentScansBox.put('scans_list', {'list': list});
  }

  /// Saves the full list of recent scans.
  static Future<void> saveRecentScansList(List<Map<String, dynamic>> list) async {
    await _recentScansBox.put('scans_list', {'list': list});
  }


  /// Returns all dates that have logged metrics, sorted reverse chronologically (newest first).
  static List<String> getAllLoggedDates() {
    final Set<String> allDates = {};
    // Add real database keys
    allDates.addAll(_dailyBox.keys.map((k) => k.toString()));
    
    // Add mock dates for the past 15 days only if fake data is enabled
    if (getFakeDataEnabled()) {
      final now = DateTime.now();
      for (int i = 0; i < 15; i++) {
        final date = now.subtract(Duration(days: i));
        allDates.add(DateFormat('yyyy-MM-dd').format(date));
      }
    }
    
    final sorted = allDates.toList();
    sorted.sort((a, b) => b.compareTo(a));
    return sorted;
  }

  /// Returns a clean map of daily metrics. If no entry exists for [dateStr], returns default zero values or mock seeds.
  /// Returns a clean map of daily metrics. If no entry exists for [dateStr], returns default zero values or mock seeds.
  static Map<String, dynamic> getDailyMetrics(String dateStr) {
    final rawMap = _dailyBox.get(dateStr);
    if (rawMap != null) {
      final metrics = Map<String, dynamic>.from(rawMap);
      
      // Determine if this is a seeded mock entry to hide when fake data is disabled
      final bool isMockEntry = metrics['is_mock'] == true || (
        !getFakeDataEnabled() && metrics['logged_items'] != null &&
        (metrics['logged_items'] as List).isNotEmpty &&
        !(metrics['logged_items'] as List).any((item) {
          final name = item['name']?.toString() ?? '';
          return name != 'Oatmeal & Banana' &&
                 name != 'Protein Shake & Banana' &&
                 name != 'Tuna Salad Wrap' &&
                 name != 'Avocado Toast & Eggs' &&
                 name != 'Grilled Chicken & Rice' &&
                 name != 'Baked Salmon & Broccoli' &&
                 name != 'Baked Salmon & Asparagus' &&
                 name != 'Whey Protein Shake & Almonds';
        })
      );

      if (isMockEntry && !getFakeDataEnabled()) {
        // Return default empty metrics instead of mock data
      } else {
        if (!metrics.containsKey('logged_items')) {
          metrics['logged_items'] = [];
        }
        if (!metrics.containsKey('outside_food_cal')) {
          metrics['outside_food_cal'] = 0;
        }
        return metrics;
      }
    }

    // Check if date falls in the current week (Monday to Sunday) relative to today
    try {
      final parsedDate = DateFormat('yyyy-MM-dd').parse(dateStr);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final diffDays = today.difference(parsedDate).inDays;

      final mondayOfCurrentWeek = today.subtract(Duration(days: today.weekday - 1));
      final sundayOfCurrentWeek = mondayOfCurrentWeek.add(const Duration(days: 6));

      if (getFakeDataEnabled()) {
        if (!parsedDate.isBefore(mondayOfCurrentWeek) && !parsedDate.isAfter(sundayOfCurrentWeek)) {
          return _generateSpecificWeekMockMetrics(parsedDate.weekday, diffDays);
        }

        if (diffDays >= 0 && diffDays < 15) {
          return _generateMockDailyMetrics(dateStr, diffDays);
        }
      }
    } catch (_) {}

    return {
      'water': 0,
      'breakfast_cal': 0,
      'lunch_cal': 0,
      'dinner_cal': 0,
      'snacks_cal': 0,
      'outside_food_cal': 0,
      'protein': 0,
      'carbs': 0,
      'fat': 0,
      'logged_items': [],
    };
  }

  static Map<String, dynamic> _generateSpecificWeekMockMetrics(int weekday, int diffDays) {
    int calories = 0;
    int protein = 110;
    int carbs = 210;
    int fat = 60;
    int water = 2000;

    if (weekday == 1) {
      calories = 1980; // Mon
      protein = 130;
      carbs = 215;
      fat = 65;
      water = 2400;
    } else if (weekday == 2) {
      calories = 2245; // Tue
      protein = 148;
      carbs = 250;
      fat = 72;
      water = 2800;
    } else if (weekday == 3) {
      calories = 2130; // Wed
      protein = 138;
      carbs = 240;
      fat = 68;
      water = 2500;
    } else if (weekday == 4) {
      calories = 1895; // Thu
      protein = 125;
      carbs = 210;
      fat = 62;
      water = 2200;
    } else if (weekday == 5) {
      calories = 2310; // Fri
      protein = 152;
      carbs = 265;
      fat = 75;
      water = 3100;
    } else if (weekday == 6) {
      calories = 2080; // Sat
      protein = 140;
      carbs = 235;
      fat = 67;
      water = 2600;
    } else if (weekday == 7) {
      calories = 1970; // Sun (Today / In Progress)
      protein = 142;
      carbs = 228;
      fat = 58;
      water = 2300; // 2.3L
    }

    int breakfast = (calories * 0.25).round();
    int lunch = (calories * 0.40).round();
    int dinner = (calories * 0.35).round();

    return {
      'water': water,
      'breakfast_cal': breakfast,
      'lunch_cal': lunch,
      'dinner_cal': dinner,
      'snacks_cal': 0,
      'outside_food_cal': 0,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'logged_items': [
        {
          'name': weekday == 7 ? 'Avocado Toast & Eggs' : 'Standard Fitness Meal',
          'calories': breakfast,
          'protein': (protein * 0.25).round(),
          'carbs': (carbs * 0.25).round(),
          'fat': (fat * 0.25).round(),
          'meal': 'BREAKFAST',
          'time': '8:30 AM',
        },
        {
          'name': weekday == 7 ? 'Grilled Chicken & Rice' : 'Standard Fitness Meal',
          'calories': lunch,
          'protein': (protein * 0.45).round(),
          'carbs': (carbs * 0.45).round(),
          'fat': (fat * 0.45).round(),
          'meal': 'LUNCH',
          'time': '1:15 PM',
        },
        {
          'name': weekday == 7 ? 'Baked Salmon & Broccoli' : 'Standard Fitness Meal',
          'calories': dinner,
          'protein': (protein * 0.30).round(),
          'carbs': (carbs * 0.30).round(),
          'fat': (fat * 0.30).round(),
          'meal': 'DINNER',
          'time': '8:00 PM',
        }
      ],
    };
  }

  static Map<String, dynamic> _generateMockDailyMetrics(String dateStr, int diffDays) {
    if (diffDays == 0) {
      // Today: prefill breakfast, snacks, and some water
      return {
        'water': 1200,
        'breakfast_cal': 340,
        'lunch_cal': 0,
        'dinner_cal': 0,
        'snacks_cal': 200,
        'outside_food_cal': 0,
        'protein': 32,
        'carbs': 73,
        'fat': 13,
        'logged_items': [
          {
            'name': 'Oatmeal & Fresh Berries',
            'calories': 340,
            'protein': 12,
            'carbs': 58,
            'fat': 6,
            'meal': 'BREAKFAST',
            'time': '8:15 AM',
          },
          {
            'name': 'Protein Bar (Choc Chip)',
            'calories': 200,
            'protein': 20,
            'carbs': 15,
            'fat': 7,
            'meal': 'SNACKS',
            'time': '11:30 AM',
          },
        ],
      };
    }

    if (diffDays % 3 == 0) {
      // High protein day
      return {
        'water': 2400,
        'breakfast_cal': 340,
        'lunch_cal': 480,
        'dinner_cal': 520,
        'snacks_cal': 200,
        'outside_food_cal': 0,
        'protein': 112,
        'carbs': 97,
        'fat': 69,
        'logged_items': [
          {
            'name': 'Oatmeal & Fresh Berries',
            'calories': 340,
            'protein': 12,
            'carbs': 58,
            'fat': 6,
            'meal': 'BREAKFAST',
            'time': '8:30 AM',
          },
          {
            'name': 'Grilled Chicken Caesar Salad',
            'calories': 480,
            'protein': 42,
            'carbs': 14,
            'fat': 24,
            'meal': 'LUNCH',
            'time': '1:15 PM',
          },
          {
            'name': 'Whey Protein shake',
            'calories': 200,
            'protein': 20,
            'carbs': 15,
            'fat': 7,
            'meal': 'SNACKS',
            'time': '4:45 PM',
          },
          {
            'name': 'Baked Salmon & Asparagus',
            'calories': 520,
            'protein': 38,
            'carbs': 10,
            'fat': 32,
            'meal': 'DINNER',
            'time': '7:30 PM',
          },
        ],
      };
    } else if (diffDays % 3 == 1) {
      // Balanced Eating Out day
      return {
        'water': 2800,
        'breakfast_cal': 480,
        'lunch_cal': 450,
        'dinner_cal': 510,
        'snacks_cal': 0,
        'outside_food_cal': 450,
        'protein': 94,
        'carbs': 213,
        'fat': 58,
        'logged_items': [
          {
            'name': 'Avocado Toast & Hard-Boiled Eggs',
            'calories': 480,
            'protein': 24,
            'carbs': 38,
            'fat': 22,
            'meal': 'BREAKFAST',
            'time': '7:45 AM',
          },
          {
            'name': 'Turkey Breast & Cheese Sandwich',
            'calories': 450,
            'protein': 32,
            'carbs': 42,
            'fat': 12,
            'meal': 'LUNCH',
            'time': '12:30 PM',
          },
          {
            'name': 'Stir-fry Tofu & Brown Rice',
            'calories': 510,
            'protein': 18,
            'carbs': 68,
            'fat': 16,
            'meal': 'DINNER',
            'time': '6:45 PM',
          },
          {
            'name': 'Sushi Platter (Eating Out)',
            'calories': 450,
            'protein': 20,
            'carbs': 65,
            'fat': 8,
            'meal': 'EATING OUT',
            'time': '8:30 PM',
          },
        ],
      };
    } else {
      // High Calorie Bulking day
      return {
        'water': 2200,
        'breakfast_cal': 320,
        'lunch_cal': 650,
        'dinner_cal': 620,
        'snacks_cal': 180,
        'outside_food_cal': 0,
        'protein': 128,
        'carbs': 158,
        'fat': 64,
        'logged_items': [
          {
            'name': 'Protein Shake & Banana',
            'calories': 320,
            'protein': 30,
            'carbs': 38,
            'fat': 5,
            'meal': 'BREAKFAST',
            'time': '9:00 AM',
          },
          {
            'name': 'Steak Burrito Bowl (Guacamole)',
            'calories': 650,
            'protein': 44,
            'carbs': 68,
            'fat': 18,
            'meal': 'LUNCH',
            'time': '1:30 PM',
          },
          {
            'name': 'Roasted Mixed Almonds',
            'calories': 180,
            'protein': 6,
            'carbs': 8,
            'fat': 15,
            'meal': 'SNACKS',
            'time': '4:15 PM',
          },
          {
            'name': 'Beef Sirloin Steak & Sweet Potatoes',
            'calories': 620,
            'protein': 48,
            'carbs': 44,
            'fat': 26,
            'meal': 'DINNER',
            'time': '7:00 PM',
          },
        ],
      };
    }
  }

  /// Saves a full daily metrics map.
  static Future<void> saveDailyMetrics(
    String dateStr,
    Map<String, dynamic> metrics,
  ) async {
    await _dailyBox.put(dateStr, metrics);
  }

  /// Updates/Increments a daily metric value.
  static Future<void> incrementDailyMetric(
    String dateStr,
    String key,
    num incrementValue,
  ) async {
    final metrics = getDailyMetrics(dateStr);
    final currentValue = metrics[key] ?? 0;
    metrics[key] = currentValue + incrementValue;
    await _dailyBox.put(dateStr, metrics);
  }

  /// Sets a specific daily metric value directly.
  static Future<void> setDailyMetric(
    String dateStr,
    String key,
    num value,
  ) async {
    final metrics = getDailyMetrics(dateStr);
    metrics[key] = value;
    await _dailyBox.put(dateStr, metrics);
  }

  /// WORKOUT PERSISTENCE LOGS
  static List<Map<String, dynamic>> getWorkouts() {
    final rawList = _workoutBox.get('workout_list');
    if (rawList == null) return [];
    final list = (rawList['list'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    if (!getFakeDataEnabled()) {
      list.removeWhere((w) => w['id']?.toString().startsWith('mock_') ?? false);
    }
    return list;
  }

  static Future<void> saveWorkout(Map<String, dynamic> workoutJson) async {
    final list = getWorkouts();
    list.add(workoutJson);
    await _workoutBox.put('workout_list', {'list': list});
  }

  /// PINNED WIDGETS PERSISTENCE
  static List<String> getPinnedWidgets() {
    final list = _workoutBox.get('pinned_widgets_list');
    if (list == null) {
      return ['calorie', 'workout', 'scanner', 'progress'];
    }
    return List<String>.from(list['list'] ?? ['calorie', 'workout', 'scanner', 'progress']);
  }

  static Future<void> savePinnedWidgets(List<String> list) async {
    await _workoutBox.put('pinned_widgets_list', {'list': list});
  }

  /// WORKOUT TEMPLATES PERSISTENCE
  static List<Map<String, dynamic>> getWorkoutTemplates() {
    final rawList = _workoutBox.get('workout_templates');
    if (rawList == null) {
      // Return predefined templates
      return [
        {
          'name': 'Push Day',
          'exercises': [
            {'name': 'Bench Press', 'category': 'Chest'},
            {'name': 'Incline Dumbbell Press', 'category': 'Chest'},
            {'name': 'Dumbbell Flys', 'category': 'Chest'},
            {'name': 'Overhead Barbell Press', 'category': 'Shoulders'},
            {'name': 'Tricep Pushdown', 'category': 'Arms'},
          ],
        },
        {
          'name': 'Pull Day',
          'exercises': [
            {'name': 'Deadlift', 'category': 'Back'},
            {'name': 'Pullups', 'category': 'Back'},
            {'name': 'Lat Pulldown', 'category': 'Back'},
            {'name': 'Bent Over Row', 'category': 'Back'},
            {'name': 'Bicep Barbell Curl', 'category': 'Arms'},
          ],
        },
      ];
    }
    return (rawList['list'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
  }

  static Future<void> saveWorkoutTemplate(Map<String, dynamic> templateJson) async {
    final list = getWorkoutTemplates();
    final name = templateJson['name'];
    final index = list.indexWhere((t) => t['name'] == name);
    if (index != -1) {
      list[index] = templateJson;
    } else {
      list.add(templateJson);
    }
    await _workoutBox.put('workout_templates', {'list': list});
  }

  static Future<void> deleteWorkoutTemplate(String templateName) async {
    final list = getWorkoutTemplates();
    list.removeWhere((t) => t['name'] == templateName);
    await _workoutBox.put('workout_templates', {'list': list});
  }

  /// FAVORITE FOODS PERSISTENCE
  static List<Map<String, dynamic>> getFavoriteFoods() {
    final raw = _workoutBox.get('favorite_foods_list');
    final defaultFavs = [
      {
        'name': 'Avocado Toast & Eggs',
        'calories': 480,
        'protein': 24,
        'carbs': 38,
        'fat': 22,
        'imageUrl': 'https://lh3.googleusercontent.com/aida-public/AB6AXuDb6VrYtGeCuwXDAWX9AyzZijMEiCa-y5TwhJuqpiYZoi3rSVBulw2NVmOnzYSSsSeE6rwks7LWdUDj5BnLRU6rzjq6r_y3igVQbN2S9vK3o3dQgKxneb8Bvnsi0jTGc-8ZIFr0OPGJRkcHGjzc1MRmO_UZEcU0s-kzijOmrXvExqy-RMA8SFaz4fFRKVG1fy80wYNlfuc1QgmbG4CrQx5pvh8IMak3OZ-2DrNWt9xtwcXmB_0JO3enXcHRs6ZLibOf0kQltKkBajg',
      },
      {
        'name': 'Grilled Chicken & Rice',
        'calories': 620,
        'protein': 54,
        'carbs': 48,
        'fat': 12,
        'imageUrl': 'https://lh3.googleusercontent.com/aida-public/AB6AXuD4gdf3X8OnLsapm-Piw4rPMArGDzOLo7p-gnURZNjggLn2rmRQIqqpNSf6EjXEsUd3dA08wsh92W55i7CbD8kSLNRrJuH63mIq5BKmseO1WDdDPX571SnULDG3XSh9-f9dWXPw5C2E8KjF-h9VCbgmJXTsTHY6dU7_3QXHCty5DG9-5FufNgPt93xmFEdXz-VMh-h6mmpuD87hpUSw-DDrrn3Fhz-JcqZaU_Kh2E3KcqLScTzCoMaPsWqik1DaMNmFSdCQLmwlp38',
      },
    ];
    if (raw == null) return defaultFavs;
    final list = (raw['list'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
    return list.isEmpty ? defaultFavs : list;
  }

  static Future<void> saveFavoriteFood(Map<String, dynamic> food) async {
    final list = getFavoriteFoods();
    list.removeWhere((item) => item['name'] == food['name']);
    list.add(food);
    await _workoutBox.put('favorite_foods_list', {'list': list});
  }

  static Future<void> removeFavoriteFood(String name) async {
    final list = getFavoriteFoods();
    list.removeWhere((item) => item['name'] == name);
    await _workoutBox.put('favorite_foods_list', {'list': list});
  }

  /// Saves the full list of favorite foods.
  static Future<void> saveFavoriteFoodsList(List<Map<String, dynamic>> list) async {
    await _workoutBox.put('favorite_foods_list', {'list': list});
  }

  /// Saves the full list of workouts.
  static Future<void> saveWorkoutsList(List<Map<String, dynamic>> list) async {
    await _workoutBox.put('workout_list', {'list': list});
  }

  /// REMINDERS PERSISTENCE LOGS
  static Map<String, dynamic> getReminders() {
    final rawMap = _reminderBox.get('reminder_settings');
    if (rawMap == null) {
      return {};
    }
    return Map<String, dynamic>.from(rawMap);
  }

  static Future<void> saveReminders(Map<String, dynamic> reminders) async {
    await _reminderBox.put('reminder_settings', reminders);
  }

  /// Seeds premium mock data for calories, macros, hydration, and workout history.
  static Future<void> seedDummyData() async {
    // Check db version to force re-seeding if we upgraded the schema
    final Map? currentDbVersionMap = _workoutBox.get('db_version');
    final String? currentDbVersion = currentDbVersionMap?['version'] as String?;
    if (currentDbVersion != 'v8') {
      await _dailyBox.clear();
      await _workoutBox.clear();
      await _workoutBox.put('db_version', {'version': 'v8'});
    }

    // 1. Seed User Profile if not existing
    if (_profileBox.get('current_profile') == null) {
      _profileBox.put(
        'current_profile',
        UserProfile(
          goal: 'lose',
          gender: 'male',
          age: 26,
          weight: 78.4,
          height: 182.0,
          activityLevel: 'moderate',
          calorieGoal: 2200,
          proteinGoal: 150,
          waterGoal: 3000,
        ),
      );
    }

    // 2. Seed Pinned Widgets if not existing
    if (_workoutBox.get('pinned_widgets_list') == null) {
      await _workoutBox.put('pinned_widgets_list', {
        'list': ['calorie', 'workout', 'scanner', 'progress']
      });
    }

    // 3. Seed Workouts and Nutrition history dynamically for the past 100 days (around 3 months)
    final now = DateTime.now();
    String formatDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

    final List<Map<String, dynamic>> mockWorkouts = [];
    
    for (int i = 0; i < 100; i++) {
      final date = now.subtract(Duration(days: i));
      final dateKey = formatDate(date);
        
        // ── Only the last 18 days are active unbroken streak, older days have normal training frequencies ──
        int level = 0;
        if (i < 18) {
          // 18-day streak with organic shade variation (level 1-4, never 0)
          const recentLevels = [
            3, 4, 2, 4, 3, 2, 3, 4, 1, // days 0-8  (today → 8 days ago)
            3, 2, 4, 3, 1, 2, 4, 3, 2, // days 9-17 (9 → 17 days ago)
          ];
          level = recentLevels[i];
        } else {
          // Beyond 18 days, simulate organic human behavior using a deterministic random seed per day
          final rand = Random(i + 1337);
          final double roll = rand.nextDouble();
          if (roll < 0.22) {
            level = 4; // High activity (Workout + good nutrition)
          } else if (roll < 0.52) {
            level = 3; // Medium-high activity
          } else if (roll < 0.72) {
            level = 2; // Medium activity (Active rest/Cardio/Light logs)
          } else if (roll < 0.88) {
            level = 1; // Light activity
          } else {
            level = 0; // Complete rest day / missed log
          }
        }

        // 1. Generate workouts based on level
        if (level == 4) {
          // Intense workout
          mockWorkouts.add({
            'id': 'mock_legs_$i',
            'date': dateKey,
            'exercises': [
              {
                'name': 'Barbell Squat',
                'category': 'Legs',
                'sets': [
                  {'weight': 80.0 + (i % 3) * 10, 'reps': 10, 'durationSeconds': 0, 'isCompleted': true},
                  {'weight': 100.0 + (i % 3) * 10, 'reps': 8, 'durationSeconds': 0, 'isCompleted': true},
                  {'weight': 110.0 + (i % 3) * 10, 'reps': 6, 'durationSeconds': 0, 'isCompleted': true},
                ],
              },
              {
                'name': 'Leg Extension',
                'category': 'Legs',
                'sets': [
                  {'weight': 40.0, 'reps': 12, 'durationSeconds': 0, 'isCompleted': true},
                  {'weight': 50.0, 'reps': 10, 'durationSeconds': 0, 'isCompleted': true},
                ],
              },
            ],
            'durationSeconds': 3300,
            'notes': 'Absolutely demolished leg day. New squat PR! 🦵🔥',
          });
        } else if (level == 3) {
          // Normal workout
          mockWorkouts.add({
            'id': 'mock_push_$i',
            'date': dateKey,
            'exercises': [
              {
                'name': 'Bench Press',
                'category': 'Chest',
                'sets': [
                  {'weight': 60.0 + (i % 3) * 5, 'reps': 10, 'durationSeconds': 0, 'isCompleted': true},
                  {'weight': 70.0 + (i % 3) * 5, 'reps': 8, 'durationSeconds': 0, 'isCompleted': true},
                ],
              },
              {
                'name': 'Tricep Pushdown',
                'category': 'Arms',
                'sets': [
                  {'weight': 20.0, 'reps': 12, 'durationSeconds': 0, 'isCompleted': true},
                ],
              },
            ],
            'durationSeconds': 2400,
            'notes': 'Great upper body session, bench press feels solid.',
          });
        } else if (level == 2 && (i % 3 == 0)) {
          // Light workout / Active Recovery walk
          mockWorkouts.add({
            'id': 'mock_walk_$i',
            'date': dateKey,
            'exercises': [
              {
                'name': 'Outdoor Walking',
                'category': 'Cardio',
                'sets': [
                  {'weight': 0.0, 'reps': 20, 'durationSeconds': 1200, 'isCompleted': true},
                ],
              },
            ],
            'durationSeconds': 1200,
            'notes': 'Active recovery walk around the neighborhood. 🚶‍♂️✨',
          });
        }

        // 2. Generate daily metrics based on level
        int water = 0;
        List<Map<String, dynamic>> items = [];
        
        if (level == 1) {
          water = 1000;
          items = [
            {
              'name': 'Oatmeal & Banana',
              'calories': 320,
              'protein': 10,
              'carbs': 60,
              'fat': 4,
              'meal': 'BREAKFAST',
              'time': '8:15 AM',
            }
          ];
        } else if (level == 2) {
          water = 1800;
          items = [
            {
              'name': 'Protein Shake & Banana',
              'calories': 340,
              'protein': 30,
              'carbs': 40,
              'fat': 5,
              'meal': 'BREAKFAST',
              'time': '9:00 AM',
            },
            {
              'name': 'Tuna Salad Wrap',
              'calories': 450,
              'protein': 35,
              'carbs': 15,
              'fat': 18,
              'meal': 'LUNCH',
              'time': '1:15 PM',
            }
          ];
        } else if (level == 3) {
          water = 2500;
          items = [
            {
              'name': 'Avocado Toast & Eggs',
              'calories': 480,
              'protein': 24,
              'carbs': 38,
              'fat': 22,
              'meal': 'BREAKFAST',
              'time': '8:30 AM',
            },
            {
              'name': 'Grilled Chicken & Rice',
              'calories': 620,
              'protein': 54,
              'carbs': 48,
              'fat': 12,
              'meal': 'LUNCH',
              'time': '1:15 PM',
            },
            {
              'name': 'Baked Salmon & Broccoli',
              'calories': 550,
              'protein': 46,
              'carbs': 15,
              'fat': 28,
              'meal': 'DINNER',
              'time': '8:00 PM',
            }
          ];
        } else if (level == 4) {
          water = 3200;
          items = [
            {
              'name': 'Avocado Toast & Eggs',
              'calories': 480,
              'protein': 24,
              'carbs': 38,
              'fat': 22,
              'meal': 'BREAKFAST',
              'time': '8:30 AM',
            },
            {
              'name': 'Grilled Chicken & Rice',
              'calories': 620,
              'protein': 54,
              'carbs': 48,
              'fat': 12,
              'meal': 'LUNCH',
              'time': '1:15 PM',
            },
            {
              'name': 'Whey Protein Shake & Almonds',
              'calories': 320,
              'protein': 32,
              'carbs': 12,
              'fat': 14,
              'meal': 'SNACKS',
              'time': '4:45 PM',
            },
            {
              'name': 'Baked Salmon & Asparagus',
              'calories': 550,
              'protein': 46,
              'carbs': 15,
              'fat': 28,
              'meal': 'DINNER',
              'time': '8:00 PM',
            }
          ];
        } else {
          // level == 0
          water = 250;
          items = [];
        }

        int breakfast = 0;
        int lunch = 0;
        int snacks = 0;
        int dinner = 0;
        int protein = 0;
        int carbs = 0;
        int fat = 0;

        for (final item in items) {
          final cal = item['calories'] as int;
          final p = item['protein'] as int;
          final c = item['carbs'] as int;
          final f = item['fat'] as int;
          final meal = item['meal'] as String;

          protein += p;
          carbs += c;
          fat += f;

          if (meal == 'BREAKFAST') breakfast = cal;
          if (meal == 'LUNCH') lunch = cal;
          if (meal == 'SNACKS') snacks = cal;
          if (meal == 'DINNER') dinner = cal;
        }

        await _dailyBox.put(dateKey, {
          'water': water,
          'breakfast_cal': breakfast,
          'lunch_cal': lunch,
          'snacks_cal': snacks,
          'dinner_cal': dinner,
          'protein': protein,
          'carbs': carbs,
          'fat': fat,
          'logged_items': items,
          'is_mock': true,
        });
      }

      await _workoutBox.put('workout_list', {'list': mockWorkouts});
  }

  /// PERSISTENT SECURE GEMINI KEYS Rotator
  static List<String> getGeminiApiKeys() {
    return const [];
  }

  /// PERSISTENT SECURE OPENAI KEY
  static String getOpenAiApiKey() {
    return '';
  }

  /// NOTIFICATIONS SETTINGS
  static bool getAuraNotificationsEnabled() {
    final raw = _reminderBox.get('aura_notifications_enabled');
    if (raw == null) return true;
    return (raw['val'] as bool?) ?? true;
  }

  static Future<void> setAuraNotificationsEnabled(bool enabled) async {
    await _reminderBox.put('aura_notifications_enabled', {'val': enabled});
  }

  static bool getSystemNotificationsEnabled() {
    final raw = _reminderBox.get('system_notifications_enabled');
    if (raw == null) return true;
    return (raw['val'] as bool?) ?? true;
  }

  static Future<void> setSystemNotificationsEnabled(bool enabled) async {
    await _reminderBox.put('system_notifications_enabled', {'val': enabled});
  }

  static List<Map<String, dynamic>> getSystemNotifications() {
    final raw = _reminderBox.get('system_notifications_list');
    if (raw == null) {
      return [
        {
          'id': 'welcome_notif',
          'category': 'system',
          'title': '💪 Zivo Active & Ready!',
          'body': 'Push reminders and notification systems are fully integrated. Stay on track!',
          'timestamp': DateTime.now().toIso8601String(),
          'isRead': false,
        }
      ];
    }
    return (raw['list'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
  }

  static Future<void> saveSystemNotifications(List<Map<String, dynamic>> list) async {
    await _reminderBox.put('system_notifications_list', {'list': list});
  }
}
