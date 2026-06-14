import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../utils/web_notification_helper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/user_profile.dart';
import '../models/workout_log.dart';
import '../models/reminder_setting.dart';
import 'storage_service.dart';
import 'firebase_service.dart';
import 'widget_sync_service.dart';

class NotificationManager {
  static final StreamController<Map<String, String>> controller =
      StreamController<Map<String, String>>.broadcast();

  static void trigger(String title, String body) {
    controller.add({'title': title, 'body': body});
  }
}

void showWebNotification(String title, String body) {
  NotificationManager.trigger(title, body);
  if (kIsWeb) {
    showWebNotificationPlatform(title, body);
  }
}

class AppNotification {
  final String id;
  final String category; // 'aura' or 'system'
  final String title;
  final String body;
  final DateTime timestamp;
  final bool isRead;

  AppNotification({
    required this.id,
    required this.category,
    required this.title,
    required this.body,
    required this.timestamp,
    this.isRead = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'category': category,
    'title': title,
    'body': body,
    'timestamp': timestamp.toIso8601String(),
    'isRead': isRead,
  };

  factory AppNotification.fromJson(Map<String, dynamic> json) => AppNotification(
    id: json['id'] ?? '',
    category: json['category'] ?? 'system',
    title: json['title'] ?? '',
    body: json['body'] ?? '',
    timestamp: DateTime.tryParse(json['timestamp'] ?? '') ?? DateTime.now(),
    isRead: json['isRead'] ?? false,
  );
}

class NotificationsNotifier extends StateNotifier<List<AppNotification>> {
  final Ref ref;
  NotificationsNotifier(this.ref) : super([]) {
    _loadSystemNotifications();
  }

  void _loadSystemNotifications() {
    final raw = StorageService.getSystemNotifications();
    state = raw.map((e) => AppNotification.fromJson(e)).toList();
  }

  Future<void> addSystemNotification(String title, String body) async {
    final notif = AppNotification(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      category: 'system',
      title: title,
      body: body,
      timestamp: DateTime.now(),
    );
    final newState = [notif, ...state];
    state = newState;
    await StorageService.saveSystemNotifications(newState.map((e) => e.toJson()).toList());
  }

  Future<void> markAllAsRead() async {
    final newState = state.map((e) => AppNotification(
      id: e.id,
      category: e.category,
      title: e.title,
      body: e.body,
      timestamp: e.timestamp,
      isRead: true,
    )).toList();
    state = newState;
    await StorageService.saveSystemNotifications(newState.map((e) => e.toJson()).toList());
  }

  Future<void> clearAll() async {
    state = [];
    await StorageService.saveSystemNotifications([]);
  }

  List<AppNotification> getAuraNotifications(UserProfile? profile, List<WorkoutSession> history) {
    if (!StorageService.getAuraNotificationsEnabled()) {
      return [];
    }

    // Generate past 7 days average stats
    final now = DateTime.now();
    final List<DateTime> pastDays = List.generate(7, (index) {
      return now.subtract(Duration(days: 6 - index));
    });

    double totalCal = 0;
    double totalWater = 0;

    for (var day in pastDays) {
      final dateStr = DateFormat('yyyy-MM-dd').format(day);
      final stats = StorageService.getDailyMetrics(dateStr);

      final double consumedCal =
          (((stats['breakfast_cal'] ?? 0) as num) +
                  ((stats['lunch_cal'] ?? 0) as num) +
                  ((stats['dinner_cal'] ?? 0) as num) +
                  ((stats['snacks_cal'] ?? 0) as num) +
                  ((stats['outside_food_cal'] ?? 0) as num))
              .toDouble();

      final double consumedWaterLtr = ((stats['water'] ?? 0) as num) / 1000.0;
      totalCal += consumedCal;
      totalWater += consumedWaterLtr;
    }

    final double avgCalories = totalCal / 7.0;
    final double avgWater = totalWater / 7.0;

    final double calorieGoal = (profile?.calorieGoal ?? 2000).toDouble();
    final double waterGoal = (profile?.waterGoal ?? 2500) / 1000.0;

    final int workoutsThisWeekCount = history.where((session) {
      try {
        final parsedDate = DateFormat('yyyy-MM-dd').parse(session.date);
        return now.difference(parsedDate).inDays < 7;
      } catch (_) {
        return false;
      }
    }).length;

    final List<AppNotification> list = [];

    // 1. Calories Insight
    String calorieFeedback = 'Caloric intake is average. Update targets in profile as needed.';
    if (avgCalories > 0) {
      if (avgCalories > calorieGoal + 200) {
        calorieFeedback = 'You are exceeding your daily target goal of ${calorieGoal.round()} kcal. Watch calorie density!';
      } else if (avgCalories >= calorieGoal - 200) {
        calorieFeedback = 'Incredible! You are perfectly hitting your metabolic target. Maintain this consistency!';
      } else {
        calorieFeedback = 'Calorie budget is under target. Ensure you ingest ample proteins to retain muscle mass.';
      }
    }
    list.add(AppNotification(
      id: 'aura_cal',
      category: 'aura',
      title: 'Metabolic Balance',
      body: calorieFeedback,
      timestamp: DateTime.now(),
    ));

    // 2. Hydration Insight
    String hydrationFeedback = 'Log water throughout the day to calibrate cellular retention.';
    if (avgWater > 0) {
      if (avgWater >= waterGoal) {
        hydrationFeedback = 'Superb water levels logged! Your body is fully hydrated, helping flush metabolites.';
      } else {
        hydrationFeedback = 'Hydration is below goal of ${waterGoal.toStringAsFixed(1)}L. Try adding 250ml every 2 hours.';
      }
    }
    list.add(AppNotification(
      id: 'aura_water',
      category: 'aura',
      title: 'Hydration Consistency',
      body: hydrationFeedback,
      timestamp: DateTime.now(),
    ));

    // 3. Gym Insight
    String gymFeedback = 'Workouts build physical fitness. Complete sets in the gym tab!';
    if (workoutsThisWeekCount >= 4) {
      gymFeedback = 'Outstanding gym consistency! 4+ weekly sessions recorded. Remember to schedule recovery days.';
    } else if (workoutsThisWeekCount > 0) {
      gymFeedback = '$workoutsThisWeekCount active gym training sessions logged. Keep stacking physical progression!';
    }
    list.add(AppNotification(
      id: 'aura_gym',
      category: 'aura',
      title: 'Active Recovery Optimized',
      body: gymFeedback,
      timestamp: DateTime.now(),
    ));

    return list;
  }
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, List<AppNotification>>((ref) {
  return NotificationsNotifier(ref);
});

// Theme Mode Provider: Manages Light or Dark theme.
final themeModeProvider = StateProvider<ThemeMode>((ref) {
  return ThemeMode.dark; // Default to FitMax Premium Dark UI
});

// Selected Date Provider: Manages the active calendar selection date string (yyyy-MM-dd).
final selectedDateProvider = StateProvider<String>((ref) {
  return DateFormat('yyyy-MM-dd').format(DateTime.now());
});

// Active Navigation Tab Provider: Manages the selected bottom nav bar index.
final activeTabProvider = StateProvider<int>((ref) {
  return 0;
});

// Profile Picture Provider: Manages the base64 encoded profile picture string
final profilePictureProvider = StateProvider<String?>((ref) {
  return StorageService.getProfilePicture();
});

// Profile Provider: Manages the UserProfile state, loaded from Hive.
final profileProvider = StateNotifierProvider<ProfileNotifier, UserProfile?>((
  ref,
) {
  return ProfileNotifier();
});

class ProfileNotifier extends StateNotifier<UserProfile?> {
  ProfileNotifier() : super(StorageService.getUserProfile());

  Future<void> saveProfile(UserProfile profile) async {
    await StorageService.saveUserProfile(profile);
    await FirebaseService.saveProfileCloud(profile);
    state = profile;
    await WidgetSyncService.syncToWidget();
  }

  Future<void> clearProfile() async {
    await FirebaseService.signOut();
    state = null;
  }
}

// Daily Metrics Provider: Manages logged calories, macros, and water for a specific date.
final dailyMetricsProvider =
    StateNotifierProvider.family<
      DailyMetricsNotifier,
      Map<String, dynamic>,
      String
    >((ref, dateStr) {
      return DailyMetricsNotifier(dateStr);
    });

class DailyMetricsNotifier extends StateNotifier<Map<String, dynamic>> {
  final String dateStr;

  DailyMetricsNotifier(this.dateStr)
    : super(StorageService.getDailyMetrics(dateStr));

  /// Logs a custom meal with calories and custom macronutrients.
  Future<void> logMeal({
    required String mealKey, // 'breakfast_cal', 'lunch_cal', 'dinner_cal', 'snacks_cal', 'outside_food_cal'
    required int calories,
    required int protein,
    required int carbs,
    required int fat,
    String? foodName,
    String? imageUrl,
  }) async {
    debugPrint("STATE PROVIDER: logMeal called for $foodName with imageUrl length: ${imageUrl?.length ?? 0}");
    final metrics = StorageService.getDailyMetrics(dateStr);
    metrics[mealKey] = (metrics[mealKey] ?? 0) + calories;
    metrics['protein'] = (metrics['protein'] ?? 0) + protein;
    metrics['carbs'] = (metrics['carbs'] ?? 0) + carbs;
    metrics['fat'] = (metrics['fat'] ?? 0) + fat;

    if (foodName != null && foodName.trim().isNotEmpty) {
      final items = List<Map<String, dynamic>>.from(
        (metrics['logged_items'] as List?)?.map(
              (e) => Map<String, dynamic>.from(e),
            ) ??
            [],
      );
      final timestamp = DateFormat('h:mm a').format(DateTime.now());
      final String mealLabel = mealKey == 'outside_food_cal'
          ? 'EATING OUT'
          : mealKey.replaceAll('_cal', '').replaceAll('_', ' ').toUpperCase();
      items.add({
        'name': foodName,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'meal': mealLabel,
        'time': timestamp,
        if (imageUrl != null) 'imageUrl': imageUrl,
      });
      metrics['logged_items'] = items;
    }

    await StorageService.saveDailyMetrics(dateStr, metrics);
    await FirebaseService.saveDailyMetricsCloud(dateStr, metrics);

    // Refresh state
    state = metrics;
    await WidgetSyncService.syncToWidget();
  }

  /// Saves a completely updated metrics map to local and cloud storage.
  Future<void> saveMetrics(Map<String, dynamic> updatedMetrics) async {
    await StorageService.saveDailyMetrics(dateStr, updatedMetrics);
    await FirebaseService.saveDailyMetricsCloud(dateStr, updatedMetrics);
    state = updatedMetrics;
    await WidgetSyncService.syncToWidget();
  }

  /// Increments water intake in ml.
  Future<void> addWater(int amountMl) async {
    final metrics = StorageService.getDailyMetrics(dateStr);
    metrics['water'] = (metrics['water'] ?? 0) + amountMl;

    final List<int> history = List<int>.from(metrics['water_history'] ?? []);
    history.add(amountMl);
    metrics['water_history'] = history;

    await StorageService.saveDailyMetrics(dateStr, metrics);
    await FirebaseService.saveDailyMetricsCloud(dateStr, metrics);

    // Refresh state
    state = metrics;
    await WidgetSyncService.syncToWidget();
  }

  /// Removes last logged water entry.
  Future<void> removeLastWater() async {
    final metrics = StorageService.getDailyMetrics(dateStr);
    final List<int> history = List<int>.from(metrics['water_history'] ?? []);
    if (history.isNotEmpty) {
      final lastAmount = history.removeLast();
      metrics['water'] = ((metrics['water'] ?? 0) - lastAmount).clamp(0, 99999);
      metrics['water_history'] = history;

      await StorageService.saveDailyMetrics(dateStr, metrics);
      await FirebaseService.saveDailyMetricsCloud(dateStr, metrics);

      // Refresh state
      state = metrics;
      await WidgetSyncService.syncToWidget();
    }
  }

  /// Sets manual override for water intake.
  Future<void> setManualWater(int amountMl) async {
    final metrics = StorageService.getDailyMetrics(dateStr);
    metrics['water'] = amountMl.clamp(0, 99999);
    metrics['water_history'] = <int>[];

    await StorageService.saveDailyMetrics(dateStr, metrics);
    await FirebaseService.saveDailyMetricsCloud(dateStr, metrics);

    // Refresh state
    state = metrics;
    await WidgetSyncService.syncToWidget();
  }

  /// Resets daily metrics for testing.
  Future<void> resetDay() async {
    final metrics = {
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
    await StorageService.saveDailyMetrics(dateStr, metrics);
    state = metrics;
    await WidgetSyncService.syncToWidget();
  }
}

// =========================================================================
// REMINDERS STATE ENGINE
// =========================================================================
final remindersProvider =
    StateNotifierProvider<RemindersNotifier, Map<String, ReminderSetting>>((
      ref,
    ) {
      return RemindersNotifier();
    });

class RemindersNotifier extends StateNotifier<Map<String, ReminderSetting>> {
  RemindersNotifier() : super(_loadInitialReminders());

  static Map<String, ReminderSetting> _loadInitialReminders() {
    final raw = StorageService.getReminders();
    return raw.map(
      (key, val) => MapEntry(
        key,
        ReminderSetting.fromJson(Map<String, dynamic>.from(val)),
      ),
    );
  }

  Future<void> updateReminder(
    String key, {
    bool? isEnabled,
    String? time,
  }) async {
    final current = state[key];
    if (current == null) return;

    final updated = ReminderSetting(
      label: current.label,
      isEnabled: isEnabled ?? current.isEnabled,
      time: time ?? current.time,
    );

    final newState = Map<String, ReminderSetting>.from(state);
    newState[key] = updated;

    state = newState;

    // Save back to Hive
    final rawMap = newState.map((k, v) => MapEntry(k, v.toJson()));
    await StorageService.saveReminders(rawMap);
    await FirebaseService.saveRemindersCloud(rawMap);

    // If enabled, trigger a real push notification to confirm functionality
    if (updated.isEnabled) {
      showWebNotification(
        '🔔 ${updated.label} Reminder Scheduled!',
        'Aura will notify you daily at ${updated.time}.',
      );
    }
  }
}

// =========================================================================
// WORKOUT SESSION HISTORY STATE ENGINE
// =========================================================================
final workoutHistoryProvider =
    StateNotifierProvider<WorkoutHistoryNotifier, List<WorkoutSession>>((ref) {
      return WorkoutHistoryNotifier();
    });

class WorkoutHistoryNotifier extends StateNotifier<List<WorkoutSession>> {
  WorkoutHistoryNotifier() : super(_loadInitialWorkouts());

  static List<WorkoutSession> _loadInitialWorkouts() {
    final rawList = StorageService.getWorkouts();
    return rawList.map((e) => WorkoutSession.fromJson(e)).toList();
  }

  Future<void> logWorkout(WorkoutSession session) async {
    await StorageService.saveWorkout(session.toJson());
    await FirebaseService.saveWorkoutCloud(session.toJson());
    state = [...state, session];
  }

  Future<void> clearHistory() async {
    await StorageService.clearAllData();
    state = [];
  }
}

// =========================================================================
// ACTIVE LIVE WORKOUT STATE ENGINE (One-hand Gym Optimized)
// =========================================================================
class ActiveWorkout {
  final bool isActive;
  final String date;
  final List<ExerciseLog> exercises;
  final DateTime? startTime;
  final String notes;

  ActiveWorkout({
    required this.isActive,
    required this.date,
    required this.exercises,
    this.startTime,
    this.notes = '',
  });

  ActiveWorkout copyWith({
    bool? isActive,
    String? date,
    List<ExerciseLog>? exercises,
    DateTime? startTime,
    String? notes,
  }) {
    return ActiveWorkout(
      isActive: isActive ?? this.isActive,
      date: date ?? this.date,
      exercises: exercises ?? this.exercises,
      startTime: startTime ?? this.startTime,
      notes: notes ?? this.notes,
    );
  }
}

final activeWorkoutProvider =
    StateNotifierProvider<ActiveWorkoutNotifier, ActiveWorkout>((ref) {
      return ActiveWorkoutNotifier(ref);
    });

class ActiveWorkoutNotifier extends StateNotifier<ActiveWorkout> {
  final Ref ref;

  ActiveWorkoutNotifier(this.ref)
    : super(ActiveWorkout(isActive: false, date: '', exercises: []));

  ExerciseSet? _getLatestSetFromHistory(String name) {
    final history = ref.read(workoutHistoryProvider);
    for (final session in history.reversed) {
      for (final ex in session.exercises) {
        if (ex.name.toLowerCase() == name.toLowerCase() && ex.sets.isNotEmpty) {
          return ex.sets.last;
        }
      }
    }
    return null;
  }

  void startWorkout() {
    state = ActiveWorkout(
      isActive: true,
      date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      exercises: [],
      startTime: DateTime.now(),
    );
  }

  void startWorkoutWithExercises(List<Map<String, String>> exercisesList) {
    state = ActiveWorkout(
      isActive: true,
      date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
      exercises: exercisesList.map((ex) {
        final name = ex['name']!;
        final category = ex['category']!;
        double weight = 0.0;
        int reps = 0;
        final historicalSet = _getLatestSetFromHistory(name);
        if (historicalSet != null) {
          weight = historicalSet.weight;
          reps = historicalSet.reps;
        }
        return ExerciseLog(
          name: name,
          category: category,
          sets: [ExerciseSet(weight: weight, reps: reps, isCompleted: false)],
        );
      }).toList(),
      startTime: DateTime.now(),
    );
  }

  void cancelWorkout() {
    state = ActiveWorkout(isActive: false, date: '', exercises: []);
  }

  void addExercise(String name, String category) {
    if (!state.isActive) return;

    // Check if exercise already added
    final exists = state.exercises.any((e) => e.name == name);
    if (exists) return;

    double weight = 0.0;
    int reps = 0;
    final historicalSet = _getLatestSetFromHistory(name);
    if (historicalSet != null) {
      weight = historicalSet.weight;
      reps = historicalSet.reps;
    }

    final newExercise = ExerciseLog(
      name: name,
      category: category,
      sets: [ExerciseSet(weight: weight, reps: reps, isCompleted: false)],
    );

    state = state.copyWith(exercises: [...state.exercises, newExercise]);
  }

  void removeExercise(int index) {
    if (!state.isActive) return;
    final list = List<ExerciseLog>.from(state.exercises);
    list.removeAt(index);
    state = state.copyWith(exercises: list);
  }

  void addSet(int exerciseIndex) {
    if (!state.isActive) return;
    final list = List<ExerciseLog>.from(state.exercises);
    final exercise = list[exerciseIndex];

    // Auto-fill previous set values if possible
    double weight = 0.0;
    int reps = 0;
    if (exercise.sets.isNotEmpty) {
      weight = exercise.sets.last.weight;
      reps = exercise.sets.last.reps;
    }

    final newSets = [
      ...exercise.sets,
      ExerciseSet(weight: weight, reps: reps, isCompleted: false),
    ];

    list[exerciseIndex] = ExerciseLog(
      name: exercise.name,
      category: exercise.category,
      sets: newSets,
    );

    state = state.copyWith(exercises: list);
  }

  void removeSet(int exerciseIndex, int setIndex) {
    if (!state.isActive) return;
    final list = List<ExerciseLog>.from(state.exercises);
    final exercise = list[exerciseIndex];
    final setsList = List<ExerciseSet>.from(exercise.sets);

    if (setsList.length <= 1) return; // Must keep at least 1 set

    setsList.removeAt(setIndex);

    list[exerciseIndex] = ExerciseLog(
      name: exercise.name,
      category: exercise.category,
      sets: setsList,
    );

    state = state.copyWith(exercises: list);
  }

  void updateSet(
    int exerciseIndex,
    int setIndex, {
    double? weight,
    int? reps,
    bool? isCompleted,
  }) {
    if (!state.isActive) return;
    final list = List<ExerciseLog>.from(state.exercises);
    final exercise = list[exerciseIndex];
    final setsList = List<ExerciseSet>.from(exercise.sets);

    final set = setsList[setIndex];
    setsList[setIndex] = ExerciseSet(
      weight: weight ?? set.weight,
      reps: reps ?? set.reps,
      durationSeconds: set.durationSeconds,
      isCompleted: isCompleted ?? set.isCompleted,
    );

    list[exerciseIndex] = ExerciseLog(
      name: exercise.name,
      category: exercise.category,
      sets: setsList,
    );

    state = state.copyWith(exercises: list);
  }

  Future<void> finishWorkout(String notes) async {
    if (!state.isActive) return;

    final duration = DateTime.now()
        .difference(state.startTime ?? DateTime.now())
        .inSeconds;

    final session = WorkoutSession(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: state.date,
      exercises: state.exercises,
      durationSeconds: duration,
      notes: notes,
    );

    // Save to History Provider
    await ref.read(workoutHistoryProvider.notifier).logWorkout(session);

    // Reset active state
    state = ActiveWorkout(isActive: false, date: '', exercises: []);
  }
}

// =========================================================================
// PINNED WIDGETS STATE ENGINE (Modular Dashboard)
// =========================================================================
final pinnedWidgetsProvider =
    StateNotifierProvider<PinnedWidgetsNotifier, List<String>>((ref) {
  return PinnedWidgetsNotifier();
});

class PinnedWidgetsNotifier extends StateNotifier<List<String>> {
  PinnedWidgetsNotifier() : super(StorageService.getPinnedWidgets());

  Future<void> toggleWidget(String widgetId) async {
    final list = List<String>.from(state);
    if (list.contains(widgetId)) {
      list.remove(widgetId);
    } else {
      list.add(widgetId);
    }
    state = list;
    await StorageService.savePinnedWidgets(list);
  }
}
