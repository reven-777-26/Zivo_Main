import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:home_widget/home_widget.dart';
import 'storage_service.dart';
import '../models/workout_log.dart';

class WidgetSyncService {
  /// Syncs current stats to Android home widget SharedPreferences
  static Future<void> syncToWidget() async {
    if (kIsWeb) return;
    try {
      final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final metrics = StorageService.getDailyMetrics(todayStr);
      final profile = StorageService.getUserProfile();
      final workoutsRaw = StorageService.getWorkouts();
      final workouts = workoutsRaw.map((e) => WorkoutSession.fromJson(e)).toList();

      final int calorieGoal = profile?.calorieGoal ?? 2200;
      final double consumedCal = (((metrics['breakfast_cal'] ?? 0) as num) +
              ((metrics['lunch_cal'] ?? 0) as num) +
              ((metrics['dinner_cal'] ?? 0) as num) +
              ((metrics['snacks_cal'] ?? 0) as num) +
              ((metrics['outside_food_cal'] ?? 0) as num))
          .toDouble();

      final int waterLogged = ((metrics['water'] ?? 0) as num).toInt();
      final int waterGoal = profile?.waterGoal ?? 3000;

      final streak = _calculateStreak(workouts);

      // Save to home_widget SharedPreferences
      await HomeWidget.saveWidgetData<int>('streak', streak);
      await HomeWidget.saveWidgetData<int>('calories_logged', consumedCal.round());
      await HomeWidget.saveWidgetData<int>('calorie_goal', calorieGoal);
      await HomeWidget.saveWidgetData<int>('water_logged', waterLogged);
      await HomeWidget.saveWidgetData<int>('water_goal', waterGoal);

      // Trigger Android Widget update
      await HomeWidget.updateWidget(
        name: 'ZivoWidgetProvider',
        androidName: 'ZivoWidgetProvider',
      );
    } catch (e) {
      print("Error syncing to widget: $e");
    }
  }

  /// Checks if any water was logged on the widget and imports it to Hive daily metrics
  static Future<void> checkAndSyncWidgetLogs(Function(int amountSynced) onSyncComplete) async {
    if (kIsWeb) return;
    try {
      final int? waterToSync = await HomeWidget.getWidgetData<int>('water_to_sync');
      if (waterToSync != null && waterToSync > 0) {
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        final metrics = StorageService.getDailyMetrics(todayStr);

        // Add to current water metrics
        metrics['water'] = (metrics['water'] ?? 0) + waterToSync;
        final List<int> history = List<int>.from(metrics['water_history'] ?? []);
        history.add(waterToSync);
        metrics['water_history'] = history;

        await StorageService.saveDailyMetrics(todayStr, metrics);

        // Reset the water_to_sync value in SharedPreferences
        await HomeWidget.saveWidgetData<int>('water_to_sync', 0);
        
        // Re-sync correct state back to widget
        await syncToWidget();

        onSyncComplete(waterToSync);
      }
    } catch (e) {
      print("Error checkAndSyncWidgetLogs: $e");
    }
  }

  // Helper calculation matching dashboard_screen.dart
  static int _calculateStreak(List<WorkoutSession> workouts) {
    final today = DateTime.now();
    int streak = 0;

    bool todayActive = _isDayActive(today, workouts);
    DateTime checkDate = todayActive ? today : today.subtract(const Duration(days: 1));

    while (_isDayActive(checkDate, workouts)) {
      streak++;
      checkDate = checkDate.subtract(const Duration(days: 1));
      if (streak > 365) break;
    }

    return streak;
  }

  static bool _isDayActive(DateTime date, List<WorkoutSession> workouts) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final metrics = StorageService.getDailyMetrics(dateStr);

    final double consumedCal = (((metrics['breakfast_cal'] ?? 0) as num) +
            ((metrics['lunch_cal'] ?? 0) as num) +
            ((metrics['dinner_cal'] ?? 0) as num) +
            ((metrics['snacks_cal'] ?? 0) as num) +
            ((metrics['outside_food_cal'] ?? 0) as num))
        .toDouble();

    final profile = StorageService.getUserProfile();
    final goal = profile?.calorieGoal ?? 2200;

    if (goal > 0 && consumedCal >= goal * 0.70) {
      return true;
    }

    final List loggedItems = metrics['logged_items'] ?? [];
    if (loggedItems.isNotEmpty) {
      return true;
    }

    final hasWorkout = workouts.any((w) => w.date == dateStr);
    if (hasWorkout) {
      return true;
    }

    try {
      final recentScans = StorageService.getRecentScans();
      final hasScan = recentScans.any((scan) {
        final timestamp = scan['timestamp'] as int?;
        if (timestamp == null) return false;
        final scanDate = DateTime.fromMillisecondsSinceEpoch(timestamp);
        return DateFormat('yyyy-MM-dd').format(scanDate) == dateStr;
      });
      if (hasScan) {
        return true;
      }
    } catch (_) {}

    return false;
  }

  /// Syncs active workout timer details to Android widget SharedPreferences
  static Future<void> syncWorkoutTimer(bool isActive, String timerStr) async {
    if (kIsWeb) return;
    try {
      await HomeWidget.saveWidgetData<bool>('workout_active', isActive);
      await HomeWidget.saveWidgetData<String>('workout_timer', timerStr);
      await HomeWidget.updateWidget(
        name: 'ZivoWidgetProvider',
        androidName: 'ZivoWidgetProvider',
      );
    } catch (e) {
      print("Error syncing workout timer to widget: $e");
    }
  }
}
