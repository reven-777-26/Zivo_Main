import 'dart:async';
import 'dart:js' as js;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/user_profile.dart';
import '../models/workout_log.dart';
import '../models/reminder_setting.dart';
import 'storage_service.dart';

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
    try {
      js.context.callMethod('eval', [
        """
        if (window.Notification) {
          Notification.requestPermission().then(function(permission) {
            if (permission === 'granted') {
              new Notification('$title', {
                body: '$body',
                icon: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCoqjP7BFZ5G58JZ9dWkY7i2nuxlXG22yw4_kp_tZDq9_LFlGpDXZN7CW3mbIisWHeikqi3HAtRW3GIE3Yv25gBdC20K-f5kYqQWbCYwr59BI8F9VS5Px2JuUIN1vtuKG2z93p-pIAb6Ea3-53UcUQzDXCzvR9Ar7P2inSnzRzOu5DHjU442uippjL0VveOFZ3BBk_TEVeMPIfcupH3xh7AswuFV2aHm9hmqFljLzwDutvFMQRHy3SZzrRekzi82S15S4nTDmbypbM'
              });
            }
          });
        }
        """
      ]);
    } catch (e) {
      debugPrint('Web Notification error: $e');
    }
  }
}

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
    state = profile;
  }

  Future<void> clearProfile() async {
    await StorageService.clearAllData();
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
  }) async {
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
      });
      metrics['logged_items'] = items;
    }

    await StorageService.saveDailyMetrics(dateStr, metrics);

    // Refresh state
    state = metrics;
  }

  /// Increments water intake in ml.
  Future<void> addWater(int amountMl) async {
    final metrics = StorageService.getDailyMetrics(dateStr);
    metrics['water'] = (metrics['water'] ?? 0) + amountMl;

    await StorageService.saveDailyMetrics(dateStr, metrics);

    // Refresh state
    state = metrics;
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
      exercises: exercisesList.map((ex) => ExerciseLog(
        name: ex['name']!,
        category: ex['category']!,
        sets: [ExerciseSet(weight: 0.0, reps: 0, isCompleted: false)],
      )).toList(),
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

    final newExercise = ExerciseLog(
      name: name,
      category: category,
      sets: [ExerciseSet(weight: 0.0, reps: 0, isCompleted: false)],
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
