import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../services/state_providers.dart';
import '../../services/storage_service.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key});

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  int _activeChartIndex =
      0; // 0 = Weight, 1 = Calories, 2 = Hydration, 3 = Workouts
  String _selectedFilter = 'Days'; // 'Days', 'Weeks', 'Months', 'Lifetime'

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final history = ref.watch(workoutHistoryProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final double currentWeight = profile?.weight ?? 70.0;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final List<String> labels = [];
    final List<double> weightLogs = [];
    final List<double> calorieLogs = [];
    final List<double> waterLogs = [];
    final List<dynamic> periodWorkouts = [];

    if (_selectedFilter == 'Days') {
      // 7 Days
      final List<DateTime> pastDays = List.generate(7, (index) {
        return today.subtract(Duration(days: 6 - index));
      });
      for (var day in pastDays) {
        labels.add(DateFormat('E').format(day));
        final dateStr = DateFormat('yyyy-MM-dd').format(day);
        final stats = StorageService.getDailyMetrics(dateStr);
        final double consumedCal = (((stats['breakfast_cal'] ?? 0) as num) +
                ((stats['lunch_cal'] ?? 0) as num) +
                ((stats['dinner_cal'] ?? 0) as num) +
                ((stats['snacks_cal'] ?? 0) as num) +
                ((stats['outside_food_cal'] ?? 0) as num))
            .toDouble();
        final double consumedWaterLtr = ((stats['water'] ?? 0) as num) / 1000.0;
        calorieLogs.add(consumedCal);
        waterLogs.add(consumedWaterLtr);
      }
      weightLogs.addAll([
        currentWeight + 0.6,
        currentWeight + 0.3,
        currentWeight + 0.5,
        currentWeight + 0.1,
        currentWeight - 0.2,
        currentWeight + 0.0,
        currentWeight,
      ]);
      periodWorkouts.addAll(history.where((session) {
        try {
          final parsedDate = DateFormat('yyyy-MM-dd').parse(session.date);
          return today.difference(parsedDate).inDays < 7;
        } catch (_) {
          return false;
        }
      }));
    } else if (_selectedFilter == 'Weeks') {
      // 4 Weeks
      for (int i = 3; i >= 0; i--) {
        final weekStart = today.subtract(Duration(days: (i * 7) + 6));
        if (i == 0) {
          labels.add('This W');
        } else if (i == 1) {
          labels.add('Last W');
        } else {
          labels.add('${i}w ago');
        }
        
        double weekCalSum = 0;
        double weekWaterSum = 0;
        for (int d = 0; d < 7; d++) {
          final day = weekStart.add(Duration(days: d));
          final dateStr = DateFormat('yyyy-MM-dd').format(day);
          final stats = StorageService.getDailyMetrics(dateStr);
          final double consumedCal = (((stats['breakfast_cal'] ?? 0) as num) +
                  ((stats['lunch_cal'] ?? 0) as num) +
                  ((stats['dinner_cal'] ?? 0) as num) +
                  ((stats['snacks_cal'] ?? 0) as num) +
                  ((stats['outside_food_cal'] ?? 0) as num))
              .toDouble();
          final double consumedWaterLtr = ((stats['water'] ?? 0) as num) / 1000.0;
          weekCalSum += consumedCal;
          weekWaterSum += consumedWaterLtr;
        }
        calorieLogs.add(weekCalSum / 7.0);
        waterLogs.add(weekWaterSum / 7.0);
        weightLogs.add(currentWeight + (i * 0.4) - 0.1);
      }
      
      periodWorkouts.addAll(history.where((session) {
        try {
          final parsedDate = DateFormat('yyyy-MM-dd').parse(session.date);
          return today.difference(parsedDate).inDays < 28;
        } catch (_) {
          return false;
        }
      }));
    } else if (_selectedFilter == 'Months') {
      // 6 Months
      for (int i = 5; i >= 0; i--) {
        final targetMonth = DateTime(today.year, today.month - i, 1);
        labels.add(DateFormat('MMM').format(targetMonth));
        
        final daysInMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
        double monthCalSum = 0;
        double monthWaterSum = 0;
        int sampledDays = 0;
        
        for (int d = 1; d <= daysInMonth; d++) {
          final day = DateTime(targetMonth.year, targetMonth.month, d);
          if (day.isAfter(today)) break;
          final dateStr = DateFormat('yyyy-MM-dd').format(day);
          final stats = StorageService.getDailyMetrics(dateStr);
          final double consumedCal = (((stats['breakfast_cal'] ?? 0) as num) +
                  ((stats['lunch_cal'] ?? 0) as num) +
                  ((stats['dinner_cal'] ?? 0) as num) +
                  ((stats['snacks_cal'] ?? 0) as num) +
                  ((stats['outside_food_cal'] ?? 0) as num))
              .toDouble();
          final double consumedWaterLtr = ((stats['water'] ?? 0) as num) / 1000.0;
          monthCalSum += consumedCal;
          monthWaterSum += consumedWaterLtr;
          sampledDays++;
        }
        
        calorieLogs.add(sampledDays > 0 ? (monthCalSum / sampledDays) : 0.0);
        waterLogs.add(sampledDays > 0 ? (monthWaterSum / sampledDays) : 0.0);
        weightLogs.add(currentWeight + (i * 0.6) - 0.2);
      }
      
      periodWorkouts.addAll(history.where((session) {
        try {
          final parsedDate = DateFormat('yyyy-MM-dd').parse(session.date);
          return today.difference(parsedDate).inDays < 180;
        } catch (_) {
          return false;
        }
      }));
    } else {
      // Lifetime (12 Months)
      for (int i = 11; i >= 0; i--) {
        final targetMonth = DateTime(today.year, today.month - i, 1);
        labels.add(DateFormat('MMM').format(targetMonth));
        
        final daysInMonth = DateTime(targetMonth.year, targetMonth.month + 1, 0).day;
        double monthCalSum = 0;
        double monthWaterSum = 0;
        int sampledDays = 0;
        
        for (int d = 1; d <= daysInMonth; d++) {
          final day = DateTime(targetMonth.year, targetMonth.month, d);
          if (day.isAfter(today)) break;
          final dateStr = DateFormat('yyyy-MM-dd').format(day);
          final stats = StorageService.getDailyMetrics(dateStr);
          final double consumedCal = (((stats['breakfast_cal'] ?? 0) as num) +
                  ((stats['lunch_cal'] ?? 0) as num) +
                  ((stats['dinner_cal'] ?? 0) as num) +
                  ((stats['snacks_cal'] ?? 0) as num) +
                  ((stats['outside_food_cal'] ?? 0) as num))
              .toDouble();
          final double consumedWaterLtr = ((stats['water'] ?? 0) as num) / 1000.0;
          monthCalSum += consumedCal;
          monthWaterSum += consumedWaterLtr;
          sampledDays++;
        }
        
        calorieLogs.add(sampledDays > 0 ? (monthCalSum / sampledDays) : 0.0);
        waterLogs.add(sampledDays > 0 ? (monthWaterSum / sampledDays) : 0.0);
        weightLogs.add(currentWeight + (i * 0.8) - 0.4);
      }
      
      periodWorkouts.addAll(history);
    }

    final double totalCal = calorieLogs.fold(0.0, (a, b) => a + b);
    final double totalWater = waterLogs.fold(0.0, (a, b) => a + b);
    final double avgCalories = calorieLogs.isNotEmpty ? (totalCal / calorieLogs.length) : 0.0;
    final double avgWater = waterLogs.isNotEmpty ? (totalWater / waterLogs.length) : 0.0;
    final int workoutsThisPeriodCount = periodWorkouts.length;

    final int targetSessionsGoal = _selectedFilter == 'Days' || _selectedFilter == 'Weeks'
        ? 4
        : (_selectedFilter == 'Months' ? 16 : 48);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(
            left: 20,
            right: 20,
            top: 12,
            bottom: 130,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              const Text(
                'Metrics Trends',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Visualize weight projections, calorie inflows, water ratios, and muscle load distributions.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Consistency Streak & Motivation Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1C1E1B) : AppTheme.glassBackground,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: isDark ? const Color(0xFF323530) : AppTheme.accentCyan.withOpacity(0.2), width: 1.0),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Text(
                        '🔥',
                        style: TextStyle(fontSize: 24),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '5-DAY CONSISTENCY STREAK',
                            style: TextStyle(
                              color: AppTheme.accentCyan,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "You are crushing it, Alex! You're in the top 3% of active athletes this week. Keep the fire burning!",
                            style: TextStyle(
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Bento Style Multi-Colored Overview Cards
              Column(
                children: [
                  Row(
                    children: [
                      // Weight Bento Card
                      Expanded(
                        child: GlassCard(
                          height: 140,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.scale_rounded,
                                    color: AppTheme.accentCyan,
                                    size: 22,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'WEIGHT',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${currentWeight.toStringAsFixed(1)} kg',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : AppTheme.textPrimary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    profile?.goal == 'lose'
                                        ? 'Active Fat Loss (-1.2kg) 🎯'
                                        : (profile?.goal == 'gain'
                                            ? 'Muscle Building (+0.4kg) 💪'
                                            : 'Optimal Maintenance ⚡'),
                                    style: const TextStyle(
                                      color: AppTheme.accentCyan,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Hydration Bento Card
                      Expanded(
                        child: GlassCard(
                          height: 140,
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.water_drop_rounded,
                                    color: AppTheme.accentOrange,
                                    size: 22,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'HYDRATION',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${avgWater.toStringAsFixed(1)} L',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : AppTheme.textPrimary,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    avgWater >= (profile?.waterGoal ?? 2500) / 1000.0
                                        ? 'Fully Hydrated! 💧'
                                        : 'Drink 0.6L more to align 🌊',
                                    style: const TextStyle(
                                      color: AppTheme.accentOrange,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Active Minutes Bento Card (Col-Span 2)
                  GlassCard(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.bolt_rounded,
                                  color: AppTheme.accentPurple,
                                  size: 20,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'ACTIVE LOGS',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '$workoutsThisPeriodCount sessions',
                              style: TextStyle(
                                color: isDark ? Colors.white : AppTheme.textPrimary,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Level Up progress: 80% to Gold Athlete tier! 🏆',
                              style: const TextStyle(
                                color: AppTheme.accentPurple,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        // Circular indicator showing workout logs frequency target progress (e.g. 4 workouts target)
                        SizedBox(
                          width: 54,
                          height: 54,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              CircularProgressIndicator(
                                value: 1.0,
                                backgroundColor: Colors.transparent,
                                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                                strokeWidth: 5,
                              ),
                              CircularProgressIndicator(
                                value: (workoutsThisPeriodCount / targetSessionsGoal).clamp(0.0, 1.0),
                                backgroundColor: Colors.transparent,
                                color: AppTheme.accentPurple,
                                strokeWidth: 5,
                                strokeCap: StrokeCap.round,
                              ),
                              Center(
                                child: Text(
                                  '${(workoutsThisPeriodCount / targetSessionsGoal * 100).round()}%',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : AppTheme.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Selector buttons row + filter row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        _buildSelectorChip('Weight', 0),
                        _buildSelectorChip('Calories', 1),
                        _buildSelectorChip('Water', 2),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: _buildFilterSelector(),
              ),
              const SizedBox(height: 12),

              // Active Chart Viewer Card
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: _buildActiveChart(
                  weightLogs: weightLogs,
                  calorieLogs: calorieLogs,
                  waterLogs: waterLogs,
                  history: periodWorkouts,
                  labels: labels,
                  profileCalorieGoal: (profile?.calorieGoal ?? 2000).toDouble(),
                  profileWaterGoalLtr: (profile?.waterGoal ?? 2500) / 1000.0,
                  currentWeight: currentWeight,
                ),
              ),
              const SizedBox(height: 24),

              // AI Performance Coach Header
              Row(
                children: [
                  const Icon(Icons.psychology_rounded, color: AppTheme.accentCyan, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'AI Performance Coach',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildInsightsPanel(
                avgCalories: avgCalories,
                avgWater: avgWater,
                workoutsCount: workoutsThisPeriodCount,
                currentWeight: currentWeight,
                calorieGoal: (profile?.calorieGoal ?? 2000).toDouble(),
                waterGoal: (profile?.waterGoal ?? 2500) / 1000.0,
              ),
              const SizedBox(height: 20),
          ],
        ),
      ),
    ),
  );
}

  Widget _buildSelectorChip(String label, int index) {
    final isSelected = _activeChartIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _activeChartIndex = index;
          });
        },
        child: Container(
          height: 38,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.accentCyan
                : (isDark
                    ? Colors.white.withOpacity(0.02)
                    : Colors.black.withOpacity(0.015)),
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(
              color: isSelected ? AppTheme.accentCyan : AppTheme.glassBorder.withOpacity(0.15),
              width: 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return GlassCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppTheme.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveChart({
    required List<double> weightLogs,
    required List<double> calorieLogs,
    required List<double> waterLogs,
    required List<dynamic> history,
    required List<String> labels,
    required double profileCalorieGoal,
    required double profileWaterGoalLtr,
    required double currentWeight,
  }) {
    switch (_activeChartIndex) {
      case 0:
        return _buildWeightChart(weightLogs, labels, currentWeight);
      case 1:
        return _buildCalorieChart(calorieLogs, labels, profileCalorieGoal);
      case 2:
        return _buildWaterChart(waterLogs, labels, profileWaterGoalLtr);
      case 3:
        return _buildWorkoutFrequencyChart(history);
      default:
        return const SizedBox();
    }
  }

  // 1. WEIGHT FLUCTUATIONS CHART (LineChart)
  Widget _buildWeightChart(
    List<double> weightLogs,
    List<String> labels,
    double currentWeight,
  ) {
    final double minWeight = weightLogs.reduce((a, b) => a < b ? a : b) - 1.0;
    final double maxWeight = weightLogs.reduce((a, b) => a > b ? a : b) + 1.0;

    return GlassCard(
      key: const ValueKey('weight_chart'),
      width: double.infinity,
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'WEIGHT TREND (KG)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentCyan,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                '${_selectedFilter} Trend',
                style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: minWeight,
                maxY: maxWeight,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: AppTheme.glassBorder,
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          value.toStringAsFixed(1),
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1.0,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < labels.length) {
                          return Text(
                            labels[index],
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    color: AppTheme.accentCyan,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.accentCyan.withOpacity(0.04),
                    ),
                    spots: List.generate(
                      weightLogs.length,
                      (i) => FlSpot(i.toDouble(), weightLogs[i]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. CALORIE INTAKE CHART (BarChart)
  Widget _buildCalorieChart(
    List<double> calorieLogs,
    List<String> labels,
    double dailyGoal,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      key: const ValueKey('calorie_chart'),
      width: double.infinity,
      height: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'WEEKLY CALORIE INFLOW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentPurple,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                'Goal: ${dailyGoal.round()} kcal',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.accentCyan,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) {
                        if (value % 1000 == 0) {
                          return Text(
                            '${(value ~/ 1000)}k',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 9,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1.0,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < labels.length) {
                          return Text(
                            labels[index],
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(calorieLogs.length, (i) {
                  final double val = calorieLogs[i];
                  // Color bar based on performance against goal
                  Color barColor = AppTheme.accentPurple;
                  if (val > 0) {
                    if (val > dailyGoal + 300) {
                      barColor = AppTheme.accentCoral; // Over budget
                    } else if (val >= dailyGoal - 200) {
                      barColor = AppTheme.accentEmerald; // Spot on target
                    } else {
                      barColor = AppTheme.accentCyan; // Under budget
                    }
                  } else {
                    barColor = AppTheme.glassBorder;
                  }

                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: val == 0 ? 100 : val, // tiny visual minimum
                        color: barColor,
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: dailyGoal + 500,
                          color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Daily totals row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.015) : Colors.black.withOpacity(0.015),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.glassBorder, width: 0.8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(calorieLogs.length, (i) {
                final dayName = labels[i];
                final caloriesVal = calorieLogs[i].round();
                
                // Color mapping matching bar
                Color textColor = AppTheme.textSecondary;
                if (caloriesVal > 0) {
                  if (caloriesVal > dailyGoal + 300) {
                    textColor = AppTheme.accentCoral;
                  } else if (caloriesVal >= dailyGoal - 200) {
                    textColor = AppTheme.accentEmerald;
                  } else {
                    textColor = AppTheme.accentCyan;
                  }
                }

                return Column(
                  children: [
                    Text(
                      dayName,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      caloriesVal > 0 ? '$caloriesVal' : '-',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // 3. HYDRATION WATER LOGGER CHART (LineChart)
  Widget _buildWaterChart(
    List<double> waterLogs,
    List<String> labels,
    double waterGoalLtr,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassCard(
      key: const ValueKey('water_chart'),
      width: double.infinity,
      height: 360,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'WATER INFLOW JOURNAL',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentEmerald,
                  letterSpacing: 1.5,
                ),
              ),
              Text(
                'Goal: ${waterGoalLtr.toStringAsFixed(1)}L',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppTheme.accentEmerald,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: waterGoalLtr + 1.0,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) => const FlLine(
                    color: AppTheme.glassBorder,
                    strokeWidth: 0.5,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 28,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${value.toStringAsFixed(1)}L',
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 9,
                          ),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1.0,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < labels.length) {
                          return Text(
                            labels[index],
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    isCurved: true,
                    color: AppTheme.accentEmerald,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.accentEmerald.withOpacity(0.04),
                    ),
                    spots: List.generate(
                      waterLogs.length,
                      (i) => FlSpot(i.toDouble(), waterLogs[i]),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Daily totals row
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.015) : Colors.black.withOpacity(0.015),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.glassBorder, width: 0.8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(waterLogs.length, (i) {
                final dayName = labels[i];
                final waterLtr = waterLogs[i];
                
                // Color mapping matching line color
                Color textColor = waterLtr >= waterGoalLtr
                    ? AppTheme.accentEmerald
                    : (waterLtr > 0 ? AppTheme.accentCyan : AppTheme.textSecondary);

                return Column(
                  children: [
                    Text(
                      dayName,
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      waterLtr > 0 ? '${waterLtr.toStringAsFixed(1)}L' : '-',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: textColor,
                      ),
                    ),
                  ],
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // 4. WORKOUT FREQUENCY CHART (BarChart)
  Widget _buildWorkoutFrequencyChart(List<dynamic> history) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Generate workout logs per category to visualize focus areas
    final Map<String, int> categoryFocus = {};
    for (var session in history) {
      for (var ex in session.exercises) {
        final cat = ex.category;
        categoryFocus[cat] = (categoryFocus[cat] ?? 0) + 1;
      }
    }

    final List<String> categories = [
      'Chest',
      'Back',
      'Legs',
      'Arms',
      'Shoulders',
      'Cardio',
    ];
    final List<double> focusValues = categories
        .map((cat) => (categoryFocus[cat] ?? 0).toDouble())
        .toList();
    final double maxFocus = focusValues.reduce((a, b) => a > b ? a : b);
    final double finalMaxY = maxFocus < 5 ? 5.0 : maxFocus + 1.0;

    return GlassCard(
      key: const ValueKey('workout_chart'),
      width: double.infinity,
      height: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'MUSCLE GROUP DENSITIES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: AppTheme.accentOrange,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 24,
                      getTitlesWidget: (value, meta) {
                        if (value % 1 == 0) {
                          return Text(
                            '${value.toInt()}',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 9,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1.0,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index >= 0 && index < categories.length) {
                          return Text(
                            categories[index].substring(0, 3).toUpperCase(),
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                ),
                barGroups: List.generate(categories.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: focusValues[i],
                        color: AppTheme.accentOrange,
                        width: 14,
                        borderRadius: BorderRadius.circular(4),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: finalMaxY,
                          color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightsPanel({
    required double avgCalories,
    required double avgWater,
    required int workoutsCount,
    required double currentWeight,
    required double calorieGoal,
    required double waterGoal,
  }) {
    String calorieFeedback =
        'Caloric intake is average. Update targets in profile as needed.';
    Color calColor = AppTheme.accentCyan;

    if (avgCalories > 0) {
      if (avgCalories > calorieGoal + 200) {
        calorieFeedback =
            'You are exceeding your daily target goal of ${calorieGoal.round()} kcal. Watch calorie density!';
        calColor = AppTheme.accentCoral;
      } else if (avgCalories >= calorieGoal - 200) {
        calorieFeedback =
            'Incredible! You are perfectly hitting your metabolic target. Maintain this consistency!';
        calColor = AppTheme.accentEmerald;
      } else {
        calorieFeedback =
            'Calorie budget is under target. Ensure you ingest ample proteins to retain muscle mass.';
        calColor = AppTheme.accentCyan;
      }
    }

    String hydrationFeedback =
        'Log water throughout the day to calibrate cellular retention.';
    if (avgWater > 0) {
      if (avgWater >= waterGoal) {
        hydrationFeedback =
            'Superb water levels logged! Your body is fully hydrated, helping flush metabolites.';
        hasCompleted = true;
      } else {
        hydrationFeedback =
            'Hydration is below goal of ${waterGoal.toStringAsFixed(1)}L. Try adding 250ml every 2 hours.';
      }
    }

    String gymFeedback =
        'Workouts build physical fitness. Complete sets in the gym tab!';
    if (workoutsCount >= 4) {
      gymFeedback =
          'Outstanding gym consistency! 4+ weekly sessions recorded. Remember to schedule recovery days.';
    } else if (workoutsCount > 0) {
      gymFeedback =
          '$workoutsCount active gym training sessions logged. Keep stacking physical progression!';
    }

    return Column(
      children: [
        _buildInsightCard(
          title: 'Metabolic Balance',
          subtitle: calorieFeedback,
          icon: Icons.bolt_rounded,
          color: calColor,
        ),
        _buildInsightCard(
          title: 'Hydration Consistency',
          subtitle: hydrationFeedback,
          icon: Icons.water_drop_rounded,
          color: AppTheme.accentCyan,
        ),
        _buildInsightCard(
          title: 'Active Recovery optimized',
          subtitle: gymFeedback,
          icon: Icons.lightbulb_rounded,
          color: AppTheme.accentOrange,
        ),
      ],
    );
  }

  static bool hasCompleted = false;

  Widget _buildInsightCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.glassBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorder, width: 1),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Left Accent Strip
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                color: color,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(icon, color: color, size: 20),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSelector() {
    final filters = ['Days', 'Weeks', 'Months', 'Lifetime'];
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: 36,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.015) : Colors.black.withOpacity(0.015),
        borderRadius: BorderRadius.circular(9999), // pill shape
        border: Border.all(color: AppTheme.glassBorder.withOpacity(0.2), width: 1.0), // hairline
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: filters.map((f) {
          final isSelected = _selectedFilter == f;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilter = f),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.accentCyan : Colors.transparent,
                borderRadius: BorderRadius.circular(9999), // pill shape
              ),
              alignment: Alignment.center,
              child: Text(
                f,
                style: TextStyle(
                  color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600, // semibold
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

