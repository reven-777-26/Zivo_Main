import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../services/state_providers.dart';
import '../services/insight_engine.dart';

final insightCardsProvider = Provider<List<InsightCard>>((ref) {
  final profile = ref.watch(profileProvider);
  final history = ref.watch(workoutHistoryProvider);
  
  final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
  final todayMetrics = ref.watch(dailyMetricsProvider(todayStr));

  final double actualKcal = (((todayMetrics['breakfast_cal'] ?? 0) as num) +
      ((todayMetrics['lunch_cal'] ?? 0) as num) +
      ((todayMetrics['dinner_cal'] ?? 0) as num) +
      ((todayMetrics['snacks_cal'] ?? 0) as num) +
      ((todayMetrics['outside_food_cal'] ?? 0) as num)).toDouble();

  final double actualWaterL = ((todayMetrics['water'] ?? 0) as num) / 1000.0;

  final double targetKcal = (profile?.calorieGoal ?? 2000).toDouble();
  final double targetWaterL = (profile?.waterGoal ?? 2500) / 1000.0;

  final String rawGoal = profile?.goal ?? 'maintain';
  final String goalType = rawGoal == 'lose' ? 'cut' : (rawGoal == 'gain' ? 'bulk' : 'maintain');

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final mondayOfCurrentWeek = today.subtract(Duration(days: today.weekday - 1));

  final sessionsThisWeek = history.where((session) {
    try {
      final parsedDate = DateFormat('yyyy-MM-dd').parse(session.date);
      return !parsedDate.isBefore(mondayOfCurrentWeek) && !parsedDate.isAfter(today);
    } catch (_) {
      return false;
    }
  }).toList();

  final int workoutSessionsThisWeek = sessionsThisWeek.length;
  final int uniqueWorkoutDays = sessionsThisWeek.map((s) => s.date).toSet().length;
  final int restDaysThisWeek = max(0, today.weekday - uniqueWorkoutDays);

  return InsightEngine.generateDailyInsights(
    actualKcal: actualKcal,
    targetKcal: targetKcal,
    goalType: goalType,
    actualWaterL: actualWaterL,
    targetWaterL: targetWaterL,
    workoutSessionsThisWeek: workoutSessionsThisWeek,
    restDaysThisWeek: restDaysThisWeek,
  );
});
