import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import '../models/user_profile.dart';

class StorageService {
  static const String _profileBoxName = 'user_profile_box';
  static const String _dailyBoxName = 'daily_metrics_box';
  static const String _workoutBoxName = 'workout_box';
  static const String _reminderBoxName = 'reminder_box';

  static late Box<UserProfile> _profileBox;
  static late Box<Map> _dailyBox;
  static late Box<Map> _workoutBox;
  static late Box<Map> _reminderBox;

  /// Initializes Hive database and opens the required boxes.
  static Future<void> init() async {
    await Hive.initFlutter();

    // Register adapters
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(UserProfileAdapter());
    }

    // Open boxes
    _profileBox = await Hive.openBox<UserProfile>(_profileBoxName);
    _dailyBox = await Hive.openBox<Map>(_dailyBoxName);
    _workoutBox = await Hive.openBox<Map>(_workoutBoxName);
    _reminderBox = await Hive.openBox<Map>(_reminderBoxName);


    // Seed realistic dummy data for interactive metrics visual experience
    seedDummyData();
  }

  /// Retrieves the saved user profile from Hive.
  static UserProfile? getUserProfile() {
    return _profileBox.get('current_profile');
  }

  /// Saves the user profile in Hive.
  static Future<void> saveUserProfile(UserProfile profile) async {
    await _profileBox.put('current_profile', profile);
  }

  /// Clears the user profile and daily stats (resets the database).
  static Future<void> clearAllData() async {
    await _profileBox.clear();
    await _dailyBox.clear();
    await _workoutBox.clear();
    await _reminderBox.clear();
  }

  /// Returns all dates that have logged metrics, sorted reverse chronologically (newest first).
  static List<String> getAllLoggedDates() {
    final Set<String> allDates = {};
    // Add real database keys
    allDates.addAll(_dailyBox.keys.map((k) => k.toString()));
    
    // Add mock dates for the past 15 days
    final now = DateTime.now();
    for (int i = 0; i < 15; i++) {
      final date = now.subtract(Duration(days: i));
      allDates.add(DateFormat('yyyy-MM-dd').format(date));
    }
    
    final sorted = allDates.toList();
    sorted.sort((a, b) => b.compareTo(a));
    return sorted;
  }

  /// Returns a clean map of daily metrics. If no entry exists for [dateStr], returns default zero values or mock seeds.
  static Map<String, dynamic> getDailyMetrics(String dateStr) {
    final rawMap = _dailyBox.get(dateStr);
    if (rawMap == null) {
      // Check if date falls in past 15 days (ending today) for mock data preloading
      try {
        final parsedDate = DateFormat('yyyy-MM-dd').parse(dateStr);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final diffDays = today.difference(parsedDate).inDays;
        if (diffDays >= 0 && diffDays < 15) {
          return _generateMockDailyMetrics(dateStr, diffDays);
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
    // Cast and return Map
    final metrics = Map<String, dynamic>.from(rawMap);
    if (!metrics.containsKey('logged_items')) {
      metrics['logged_items'] = [];
    }
    if (!metrics.containsKey('outside_food_cal')) {
      metrics['outside_food_cal'] = 0;
    }
    return metrics;
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
    return (rawList['list'] as List?)
            ?.map((e) => Map<String, dynamic>.from(e))
            .toList() ??
        [];
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
        {
          'name': 'Leg Day',
          'exercises': [
            {'name': 'Barbell Squat', 'category': 'Legs'},
            {'name': 'Leg Press', 'category': 'Legs'},
            {'name': 'Leg Extension', 'category': 'Legs'},
            {'name': 'Romanian Deadlift', 'category': 'Legs'},
          ],
        },
        {
          'name': 'Full Body AI',
          'exercises': [
            {'name': 'Bench Press', 'category': 'Chest'},
            {'name': 'Deadlift', 'category': 'Back'},
            {'name': 'Barbell Squat', 'category': 'Legs'},
            {'name': 'Pullups', 'category': 'Back'},
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

  /// REMINDERS PERSISTENCE LOGS
  static Map<String, dynamic> getReminders() {
    final rawMap = _reminderBox.get('reminder_settings');
    if (rawMap == null) {
      return {
        'water': {'label': 'Water', 'isEnabled': true, 'time': '09:00 AM'},
        'meal': {'label': 'Meals', 'isEnabled': true, 'time': '12:30 PM'},
        'workout': {'label': 'Workouts', 'isEnabled': true, 'time': '06:00 PM'},
        'supplement': {
          'label': 'Supplements',
          'isEnabled': false,
          'time': '08:00 AM',
        },
        'sleep': {'label': 'Sleep Time', 'isEnabled': true, 'time': '10:30 PM'},
      };
    }
    return Map<String, dynamic>.from(rawMap);
  }

  static Future<void> saveReminders(Map<String, dynamic> reminders) async {
    await _reminderBox.put('reminder_settings', reminders);
  }

  /// Seeds premium mock data for calories, macros, hydration, and workout history.
  static void seedDummyData() {
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
      _workoutBox.put('pinned_widgets_list', {
        'list': ['calorie', 'workout', 'scanner', 'progress']
      });
    }

    // 3. Seed Workouts Log History dynamically for the past 45 days
    if (_workoutBox.get('workout_list') == null) {
      final now = DateTime.now();
      String formatDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

      final List<Map<String, dynamic>> mockWorkouts = [];
      
      for (int i = 0; i < 45; i++) {
        // Log a workout session every 2 days for realistic metrics history
        if (i % 2 == 0) {
          final workoutDate = now.subtract(Duration(days: i));
          final int type = (i ~/ 2) % 3;
          
          if (type == 0) {
            mockWorkouts.add({
              'id': 'mock_push_$i',
              'date': formatDate(workoutDate),
              'exercises': [
                {
                  'name': 'Bench Press',
                  'category': 'Chest',
                  'sets': [
                    {'weight': 60.0 + (i % 5) * 5, 'reps': 10, 'durationSeconds': 0, 'isCompleted': true},
                    {'weight': 70.0 + (i % 5) * 5, 'reps': 8, 'durationSeconds': 0, 'isCompleted': true},
                  ],
                },
                {
                  'name': 'Tricep Pushdown',
                  'category': 'Arms',
                  'sets': [
                    {'weight': 20.0 + (i % 3) * 2.5, 'reps': 12, 'durationSeconds': 0, 'isCompleted': true},
                  ],
                },
              ],
              'durationSeconds': 2400,
              'notes': 'Great chest pump today, felt strong.',
            });
          } else if (type == 1) {
            mockWorkouts.add({
              'id': 'mock_pull_$i',
              'date': formatDate(workoutDate),
              'exercises': [
                {
                  'name': 'Pullups',
                  'category': 'Back',
                  'sets': [
                    {'weight': 0.0, 'reps': 10, 'durationSeconds': 0, 'isCompleted': true},
                    {'weight': 0.0, 'reps': 8, 'durationSeconds': 0, 'isCompleted': true},
                  ],
                },
                {
                  'name': 'Bicep Barbell Curl',
                  'category': 'Arms',
                  'sets': [
                    {'weight': 30.0 + (i % 4) * 2.5, 'reps': 12, 'durationSeconds': 0, 'isCompleted': true},
                  ],
                },
              ],
              'durationSeconds': 1800,
              'notes': 'Back feeling wider, curls felt solid.',
            });
          } else {
            mockWorkouts.add({
              'id': 'mock_legs_$i',
              'date': formatDate(workoutDate),
              'exercises': [
                {
                  'name': 'Barbell Squat',
                  'category': 'Legs',
                  'sets': [
                    {'weight': 80.0 + (i % 5) * 10, 'reps': 10, 'durationSeconds': 0, 'isCompleted': true},
                    {'weight': 100.0 + (i % 5) * 10, 'reps': 8, 'durationSeconds': 0, 'isCompleted': true},
                  ],
                },
              ],
              'durationSeconds': 2700,
              'notes': 'Crushed squats, quad pump is real!',
            });
          }
        }
      }

      _workoutBox.put('workout_list', {'list': mockWorkouts});
    }

    // 4. Seed Daily Nutrition Metrics for the past 45 days (providing a rich multi-week interactive history)
    final now = DateTime.now();
    String formatDate(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

    for (int i = 0; i < 45; i++) {
      final dateKey = formatDate(now.subtract(Duration(days: i)));
      if (_dailyBox.get(dateKey) == null) {
        // Vary the meal entries across 3 realistic diet templates for premium visual depth
        final int type = i % 3;
        final List<Map<String, dynamic>> items;
        if (type == 0) {
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
              'name': 'Protein Shake & Almonds',
              'calories': 320,
              'protein': 32,
              'carbs': 12,
              'fat': 14,
              'meal': 'SNACKS',
              'time': '4:45 PM',
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
        } else if (type == 1) {
          items = [
            {
              'name': 'Oatmeal & Blueberries',
              'calories': 350,
              'protein': 14,
              'carbs': 55,
              'fat': 6,
              'meal': 'BREAKFAST',
              'time': '8:00 AM',
            },
            {
              'name': 'Tuna Salad Wrap',
              'calories': 450,
              'protein': 38,
              'carbs': 32,
              'fat': 14,
              'meal': 'LUNCH',
              'time': '12:45 PM',
            },
            {
              'name': 'Greek Yogurt & Honey',
              'calories': 220,
              'protein': 18,
              'carbs': 24,
              'fat': 3,
              'meal': 'SNACKS',
              'time': '3:30 PM',
            },
            {
              'name': 'Sirloin Steak & Sweet Potato',
              'calories': 700,
              'protein': 52,
              'carbs': 45,
              'fat': 24,
              'meal': 'DINNER',
              'time': '7:30 PM',
            }
          ];
        } else {
          items = [
            {
              'name': 'Protein Waffles',
              'calories': 400,
              'protein': 30,
              'carbs': 45,
              'fat': 8,
              'meal': 'BREAKFAST',
              'time': '9:00 AM',
            },
            {
              'name': 'Turkey & Swiss Sandwich',
              'calories': 500,
              'protein': 35,
              'carbs': 40,
              'fat': 16,
              'meal': 'LUNCH',
              'time': '1:30 PM',
            },
            {
              'name': 'Apple & Peanut Butter',
              'calories': 280,
              'protein': 8,
              'carbs': 28,
              'fat': 16,
              'meal': 'SNACKS',
              'time': '4:00 PM',
            },
            {
              'name': 'Shrimp Pasta Primavera',
              'calories': 600,
              'protein': 42,
              'carbs': 65,
              'fat': 14,
              'meal': 'DINNER',
              'time': '8:15 PM',
            }
          ];
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

        // Cycle hydration levels between 1.5L and 3.5L to remain positive
        final int water = 1500 + ((i * 350) % 2100);

        _dailyBox.put(dateKey, {
          'water': water,
          'breakfast_cal': breakfast,
          'lunch_cal': lunch,
          'snacks_cal': snacks,
          'dinner_cal': dinner,
          'protein': protein,
          'carbs': carbs,
          'fat': fat,
          'logged_items': items,
        });
      }
    }
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
