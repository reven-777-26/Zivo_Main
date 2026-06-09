import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import '../../core/theme.dart';
import '../../services/state_providers.dart';
import '../../services/storage_service.dart';
import '../../utils/image_picker_helper.dart';
import '../../services/scanner/ai_analysis_service.dart';
import 'food_history_screen.dart';
import 'food_logger_dialog.dart';
import '../vision_lens/vision_lens/screens/unified_scanner_dialog.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _selectedMacro = 'Protein';

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final profile = ref.watch(profileProvider);
    final dailyStats = ref.watch(dailyMetricsProvider(selectedDate));
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Parsed date formatting
    final parsedDate = DateFormat('yyyy-MM-dd').parse(selectedDate);
    final formattedDateStr = DateFormat('EEEE, MMMM d').format(parsedDate);

    // Targets (Use default target 2200 cal, 150g protein, 3000ml water if none)
    final int calorieGoal = profile?.calorieGoal ?? 2200;
    final double proteinGoal = (profile?.proteinGoal ?? 150).toDouble();
    final double waterGoal = (profile?.waterGoal ?? 3000).toDouble();

    final int consumedCal =
        ((dailyStats['breakfast_cal'] ?? 0) as num).toInt() +
        ((dailyStats['lunch_cal'] ?? 0) as num).toInt() +
        ((dailyStats['dinner_cal'] ?? 0) as num).toInt() +
        ((dailyStats['snacks_cal'] ?? 0) as num).toInt() +
        ((dailyStats['outside_food_cal'] ?? 0) as num).toInt();

    final int remainingCal = calorieGoal - consumedCal;
    final caloriePercent = (consumedCal / calorieGoal).clamp(0.0, 1.0);

    // Carb and fat goals derived from profile split
    final int carbGoalInt =
        ((calorieGoal - (proteinGoal * 4) - (calorieGoal * 0.25)) / 4).round();
    final int fatGoalInt = ((calorieGoal * 0.25) / 9).round();

    final double carbGoal = carbGoalInt.toDouble();
    final double fatGoal = fatGoalInt.toDouble();

    final double pConsumed = (dailyStats['protein'] ?? 0).toDouble();
    final double cConsumed = (dailyStats['carbs'] ?? 0).toDouble();
    final double fConsumed = (dailyStats['fat'] ?? 0).toDouble();
    final int wConsumed = dailyStats['water'] ?? 0;

    final pPercent = (pConsumed / proteinGoal).clamp(0.0, 1.0);
    final cPercent = (cConsumed / carbGoal).clamp(0.0, 1.0);
    final fPercent = (fConsumed / fatGoal).clamp(0.0, 1.0);

    final List<dynamic> loggedItems = dailyStats['logged_items'] ?? [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // 1. Ambient Background Glows (Google Stitch Cyber Theme)
          if (isDark) ...[
            Positioned(
              top: -60,
              right: -60,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentCyan.withOpacity(0.08),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(begin: const Offset(1, 1), end: const Offset(1.15, 1.15), duration: 8.seconds, curve: Curves.easeInOut)
                  .custom(builder: (context, val, child) => ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                        child: child,
                      )),
            ),
            Positioned(
              bottom: 120,
              left: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentPurple.withOpacity(0.06),
                ),
              ).animate(onPlay: (c) => c.repeat(reverse: true))
                  .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 10.seconds, curve: Curves.easeInOut)
                  .custom(builder: (context, val, child) => ImageFiltered(
                        imageFilter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                        child: child,
                      )),
            ),
          ],

          // 2. Main Scrollable Container
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: 140,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top App Bar Greeting
                  _buildTopAppBar(context),
                  const SizedBox(height: 16),

                  // Weekly Calendar picker
                  _buildWeeklyCalendarBar(selectedDate, isDark),
                  const SizedBox(height: 16),

                  // Daily Goal Ring Section
                  _buildDailyGoalSummaryCard(
                    consumed: consumedCal,
                    remaining: remainingCal,
                    percent: caloriePercent,
                    waterConsumed: wConsumed,
                    waterGoal: waterGoal,
                    selectedDate: selectedDate,
                  ),
                  const SizedBox(height: 28),

                  // Macros Bento Section Title
                  Row(
                    children: [
                      const Icon(Icons.analytics_rounded, color: AppTheme.accentCyan, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Macro Targets',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Compact Premium Macro Targets Row (Side-by-Side)
                  Row(
                    children: [
                      Expanded(
                        child: _buildMacroCard(
                          title: 'Protein',
                          value: '${pConsumed.round()}g',
                          target: '${proteinGoal.round()}g',
                          imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuB2brSlsBgFFmGsip9c_GbksCXBfFKCIgXcey-f5BrJwkkPWEQjC-sUEd1tVxXASMRu__FqDDxIF9MhDwLZ_UCW5XLrEky021sbzy5pb5bQh3ObP3rtU3zoNA0dYNdHPKB1KcM1KgAvTflJikH-Uz8Pkd4w7ZwXidpEHOLubS0bPb_yX6LuQIFmy2TfeRp9iLTjR_BZSV7G44gZ6Ry9IIZiH3jp86HDRnqI_HoYoht8sgs4yTMO4ugB_i6sd0X9f44R7CjTKNqUiiQ',
                          isActive: _selectedMacro == 'Protein',
                          onTap: () {
                            setState(() {
                              _selectedMacro = 'Protein';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMacroCard(
                          title: 'Carbs',
                          value: '${cConsumed.round()}g',
                          target: '${carbGoal.round()}g',
                          imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuD4gdf3X8OnLsapm-Piw4rPMArGDzOLo7p-gnURZNjggLn2rmRQIqqpNSf6EjXEsUd3dA08wsh92W55i7CbD8kSLNRrJuH63mIq5BKmseO1WDdDPX571SnULDG3XSh9-f9dWXPw5C2E8KjF-h9VCbgmJXTsTHY6dU7_3QXHCty5DG9-5FufNgPt93xmFEdXz-VMh-h6mmpuD87hpUSw-DDrrn3Fhz-JcqZaU_Kh2E3KcqLScTzCoMaPsWqik1DaMNmFSdCQLmwlp38',
                          isActive: _selectedMacro == 'Carbs',
                          onTap: () {
                            setState(() {
                              _selectedMacro = 'Carbs';
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMacroCard(
                          title: 'Fats',
                          value: '${fConsumed.round()}g',
                          target: '${fatGoal.round()}g',
                          imageUrl: 'https://lh3.googleusercontent.com/aida-public/AB6AXuCFm2XsMjmJXAwf6NI19eSwHEj0P9zTCPYixIxf-0z0TEcCuUHilYMI3P4tUgUe-PdA9HXvnTLZZ1ndshzFd3I3DnyErcUadkcQJa9YLl1imhnDgQgG5Sze7_tsXER8ycWlX977B9ZhqsctcZIxLZVgAaulUYjOvqimZIh7pOZ4R0Tq-KJeeQ_vAi6NQACiSB_5dxlxijqCH2Smr5IoNorK8wcS2dHSA8j7v2W89G_EGOKHVnmkUg2OhkglDg0MKzwIWAJxCyJJaCQ',
                          isActive: _selectedMacro == 'Fats',
                          onTap: () {
                            setState(() {
                              _selectedMacro = 'Fats';
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),



                  // Quick Actions Row (Bento Style circles)
                  _buildQuickActionsRow(selectedDate),
                  const SizedBox(height: 28),

                  // Daily Food Journal Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Today's Entries",
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const FoodHistoryScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'VIEW ALL',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.accentCyan,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  _buildFoodJournalFeed(loggedItems),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // VIEW RENDER PARTS (STITCH COMPLIANT)
  // ==========================================

  Widget _buildTopAppBar(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            // High-resolution premium profile avatar
            GestureDetector(
              onTap: () {
                ref.read(activeTabProvider.notifier).state = 4;
              },
              child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accentCyan.withOpacity(0.3),
                    width: 2.0,
                  ),
                  image: const DecorationImage(
                    image: NetworkImage(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuDvTQLDMkUyYmJWBvwIdewLV0ZwujBodCYq_Ci2FVZMVhplZqTibf2hqWNADC4Po_Gy_kG9RWZHnLARwq9jymz6zRoriNAL_LQd90bTW6R7LgJKqxd16k9TMxgSBGpyF6bcnqq3ybcYAe7D12mq5urhogo8Z32HQwsnhwkzjT53CCd32X9PnTrQrFuZHLtZbXXknU_ahDBId16_uBbaggn--en1q3py_UFjUqK85z5AQawA8o7ZMA5qQ7OnQUJsYSlEuPd05l77DQY',
                    ),
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'GOOD MORNING,',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  'Alex',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.accentCyan,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ],
        ),

        // Notifications + Streak Flame
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accentCyan.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppTheme.accentCyan.withOpacity(0.15),
                  width: 1.0,
                ),
              ),
              child: const Row(
                children: [
                  Text('7', style: TextStyle(color: AppTheme.accentCyan, fontWeight: FontWeight.w900, fontSize: 12)),
                  SizedBox(width: 2),
                  Text('🔥', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            IconButton(
              icon: const Icon(Icons.notifications_rounded, color: AppTheme.textSecondary, size: 24),
              onPressed: () => _showNotificationsSheet(context),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildWeeklyCalendarBar(String selectedDate, bool isDark) {
    final now = DateTime.now();

    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 1000, // Virtually infinite past days
        itemBuilder: (context, index) {
          final date = now.subtract(Duration(days: index));
          final dateKey = DateFormat('yyyy-MM-dd').format(date);
          final isSelected = dateKey == selectedDate;
          final weekdayStr = DateFormat('E').format(date); // e.g. "Sun"
          final dayNumStr = DateFormat('d').format(date); // e.g. "12"
          final monthStr = DateFormat('MMM').format(date).toUpperCase(); // e.g. "NOV"

          return GestureDetector(
            onTap: () {
              ref.read(selectedDateProvider.notifier).state = dateKey;
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 50,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.accentCyan.withOpacity(0.08)
                    : (isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.015)),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? AppTheme.accentCyan
                      : (isDark ? Colors.white.withOpacity(0.06) : AppTheme.glassBorder),
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekdayStr.toUpperCase(),
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                      color: isSelected ? AppTheme.accentCyan : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    dayNumStr,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isSelected ? AppTheme.accentCyan : (isDark ? Colors.white : AppTheme.textPrimary),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    monthStr,
                    style: TextStyle(
                      fontSize: 7.5,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? AppTheme.accentCyan.withOpacity(0.85) : AppTheme.textSecondary.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDailyGoalSummaryCard({
    required int consumed,
    required int remaining,
    required double percent,
    required int waterConsumed,
    required double waterGoal,
    required String selectedDate,
  }) {
    final calorieLeftText = remaining >= 0 ? '$remaining' : '${remaining.abs()}';
    final calorieLabel = remaining >= 0 ? 'KCAL REMAINING' : 'KCAL SURPLUS';
    final calorieColor = remaining >= 0 ? AppTheme.accentCyan : AppTheme.accentCoral;
    final double waterPercent = (waterConsumed / waterGoal).clamp(0.0, 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      borderRadius: BorderRadius.circular(24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Left side - Circular percent indicator
          CircularPercentIndicator(
            radius: 72.0,
            lineWidth: 12.0,
            percent: percent,
            animation: true,
            animationDuration: 800,
            curve: Curves.easeInOutQuad,
            circularStrokeCap: CircularStrokeCap.round,
            backgroundColor: Colors.white.withOpacity(0.04),
            progressColor: calorieColor,
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  calorieLeftText,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: calorieColor,
                    letterSpacing: -1,
                  ),
                ),
                Text(
                  calorieLabel,
                  style: const TextStyle(
                    fontSize: 7,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 24),

          // Right side - Info headers & Hydration details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Text(
                        'Daily Goal Completion',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _showEditDailyGoalDialog(context, selectedDate),
                      child: const Text(
                        'Edit',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Hydration Row wrapped in GestureDetector to manage logs
                GestureDetector(
                  onTap: () => _showHydrationDialog(context, selectedDate, waterConsumed, waterGoal),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.water_drop_rounded,
                                color: AppTheme.accentPurple,
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Hydration',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${(waterPercent * 100).round()}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.accentPurple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$waterConsumed ml / ${waterGoal.toInt()} ml',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Custom refreshing water bar indicator
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          height: 6,
                          width: double.infinity,
                          color: Colors.white.withOpacity(0.04),
                          child: Stack(
                            children: [
                              FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: waterPercent,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AppTheme.accentPurple.withOpacity(0.8),
                                        AppTheme.accentPurple,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),

                // Quick tap log buttons
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await ref
                              .read(dailyMetricsProvider(selectedDate).notifier)
                              .addWater(250);
                          showWebNotification(
                            '💧 Hydration Logged!',
                            'Logged 250ml of clean drinking water. Total: ${waterConsumed + 250}ml.',
                          );
                        },
                        child: Container(
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppTheme.accentPurple.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.accentPurple.withOpacity(0.2),
                              width: 1.0,
                            ),
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add, size: 10, color: AppTheme.accentPurple),
                                SizedBox(width: 2),
                                Text(
                                  '250 ml',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accentPurple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          await ref
                              .read(dailyMetricsProvider(selectedDate).notifier)
                              .addWater(500);
                          showWebNotification(
                            '💧 Hydration Logged!',
                            'Logged 500ml of clean drinking water. Total: ${waterConsumed + 500}ml.',
                          );
                        },
                        child: Container(
                          height: 26,
                          decoration: BoxDecoration(
                            color: AppTheme.accentPurple.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.accentPurple.withOpacity(0.2),
                              width: 1.0,
                            ),
                          ),
                          child: const Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_outline_rounded, size: 10, color: AppTheme.accentPurple),
                                SizedBox(width: 2),
                                Text(
                                  '500 ml',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.accentPurple,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildMacroCard({
    required String title,
    required String value,
    required String target,
    required String imageUrl,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isActive ? AppTheme.accentCyan : Colors.white.withOpacity(0.04),
            width: 1.8,
          ),
          boxShadow: [
            if (isActive)
              BoxShadow(
                color: AppTheme.accentCyan.withOpacity(0.15),
                blurRadius: 10,
                spreadRadius: 1,
              ),
          ],
        ),
        child: Stack(
          children: [
            // Background Image
            Positioned.fill(
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
              ),
            ),
            
            // Dark elegant overlay to guarantee extreme text contrast
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF131722).withOpacity(0.35),
                      const Color(0xFF131722).withOpacity(0.88),
                    ],
                  ),
                ),
              ),
            ),
            
            // Text Content (Matching the layout style of 2nd screenshot)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'of $target',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textSecondary,
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

  Widget _buildQuickActionsRow(String selectedDate) {
    return Row(
      children: [
        Expanded(
          child: _buildQuickActionButton(
            label: 'Add Meal',
            icon: Icons.restaurant_rounded,
            color: AppTheme.accentCyan,
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const FoodLoggerDialog(),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickActionButton(
            label: 'Scan Barcode',
            icon: Icons.qr_code_scanner_rounded,
            color: AppTheme.accentOrange,
            onTap: () {
              showDialog(
                context: context,
                builder: (context) => const UnifiedVisionScannerDialog(),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _buildQuickActionButton(
            label: 'Workout Log',
            icon: Icons.fitness_center_rounded,
            color: AppTheme.accentPurple,
            onTap: () {
              ref.read(activeTabProvider.notifier).state = 1; // Go to Workouts
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                    color: color.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(
                icon,
                color: const Color(0xFF051424),
                size: 20,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFoodJournalFeed(List<dynamic> loggedItems) {
    if (loggedItems.isEmpty) {
      return GlassCard(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(
              Icons.restaurant_rounded,
              color: Colors.white.withOpacity(0.15),
              size: 36,
            ),
            const SizedBox(height: 8),
            const Text(
              'No food logged yet today.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: loggedItems.reversed.map((item) {
        final String name = item['name'] ?? 'Custom Meal';
        final String meal = item['meal'] ?? 'MEAL';
        final String time = item['time'] ?? '';
        final int calories = item['calories'] ?? 0;

        // Cover picture mappings based on name or meal category
        String foodThumbUrl = 'https://lh3.googleusercontent.com/aida-public/AB6AXuADGVXZpNft1ZskNUNac_6dKCCsmODEv5PjrcVfYZ6502KWP2CSkh-oV0apT-R7_Vy-htt3Ng_bdFZNpAydisZBPfaocCADnF3G_BLw75Wc2mFVtJPgmtT1iheLN0FxRrM2afP_xt6b4HKPZgiNk_rUUPTqMkm-6bFScLfZk9vXy1QpyTyHyT7LELsH9BOITdDUVon-DUos_gvbAFxDYAYiNZnUzqvto6eLgMAarsr0s1u0qWBHP53FTLaiT9vli-ehFEfSiNH0IiM';
        if (meal.contains('BREAKFAST') || name.toLowerCase().contains('egg')) {
          foodThumbUrl = 'https://lh3.googleusercontent.com/aida-public/AB6AXuDb6VrYtGeCuwXDAWX9AyzZijMEiCa-y5TwhJuqpiYZoi3rSVBulw2NVmOnzYSSsSeE6rwks7LWdUDj5BnLRU6rzjq6r_y3igVQbN2S9vK3o3dQgKxneb8Bvnsi0jTGc-8ZIFr0OPGJRkcHGjzc1MRmO_UZEcU0s-kzijOmrXvExqy-RMA8SFaz4fFRKVG1fy80wYNlfuc1QgmbG4CrQx5pvh8IMak3OZ-2DrNWt9xtwcXmB_0JO3enXcHRs6ZLibOf0kQltKkBajg';
        } else if (name.toLowerCase().contains('shake') || name.toLowerCase().contains('protein')) {
          foodThumbUrl = 'https://lh3.googleusercontent.com/aida-public/AB6AXuAu02ztHCanw1Xo-CIsQxvODCtZXuuPSSm0Kn4ZGG3jNSR0Ffx2Q5Q9ezBZymakx28NRatfkqbjwoU2ihTQJwLgBDIWKsZzvnBRAMkgG0j6Uz0sH5-uofS3PGDzF4acLg4DHNPPHAbQwbos-7Bq3B_mc5XWzCQt_0oXTJ1EXjvahwLqze45OL8C5aVKdO-10SRju8l4451S6qP7FBAwNzwklV4Ek-SVdF9fmeejvW_NNhv5bnuC8itvhdJkQLn1txc5IlKWvspYzec';
        }

        final String? customImageUrl = item['imageUrl'];
        ImageProvider imageProvider;
        if (customImageUrl != null && customImageUrl.isNotEmpty) {
          if (customImageUrl.startsWith('http')) {
            imageProvider = NetworkImage(customImageUrl);
          } else {
            try {
              String cleaned = customImageUrl;
              final commaIndex = cleaned.indexOf(',');
              if (commaIndex != -1) {
                cleaned = cleaned.substring(commaIndex + 1);
              }
              cleaned = cleaned.replaceAll(RegExp(r'\s+'), '');
              imageProvider = MemoryImage(base64Decode(cleaned));
            } catch (e) {
              imageProvider = NetworkImage(foodThumbUrl);
            }
          }
        } else {
          imageProvider = NetworkImage(foodThumbUrl);
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: GestureDetector(
            onTap: () => _showFoodDetailsDialog(context, Map<String, dynamic>.from(item)),
            child: GlassCard(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Rounded Image Thumbnail
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.06), width: 1.0),
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Title details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$meal • $time',
                          style: const TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Calorie value
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$calories',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.accentCyan,
                        ),
                      ),
                      const Text(
                        'KCAL',
                        style: TextStyle(
                          fontSize: 8,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Future<dynamic> _showFoodDetailsDialog(BuildContext context, Map<String, dynamic> item, {bool startInEditMode = false}) {
    final String initialName = item['name'] ?? 'Logged Meal';
    final String initialMeal = item['meal'] ?? 'MEAL';
    final String time = item['time'] ?? '8:00 AM';
    final int initialCalories = item['calories'] ?? 0;
    final int initialProtein = item['protein'] ?? 0;
    final int initialCarbs = item['carbs'] ?? 0;
    final int initialFat = item['fat'] ?? 0;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    final nameController = TextEditingController(text: initialName);
    final calController = TextEditingController(text: initialCalories.toString());
    final proteinController = TextEditingController(text: initialProtein.toString());
    final carbsController = TextEditingController(text: initialCarbs.toString());
    final fatController = TextEditingController(text: initialFat.toString());

    String initialMealKey = 'snacks_cal';
    final String upperMeal = initialMeal.toUpperCase();
    if (upperMeal == 'BREAKFAST') {
      initialMealKey = 'breakfast_cal';
    } else if (upperMeal == 'LUNCH') {
      initialMealKey = 'lunch_cal';
    } else if (upperMeal == 'DINNER') {
      initialMealKey = 'dinner_cal';
    } else if (upperMeal == 'SNACKS') {
      initialMealKey = 'snacks_cal';
    } else if (upperMeal == 'EATING OUT' || upperMeal == 'OUTSIDE FOOD') {
      initialMealKey = 'outside_food_cal';
    }

    String selectedMealKey = initialMealKey;
    bool isEditing = startInEditMode;

    return showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final categories = [
              {'name': 'Breakfast', 'key': 'breakfast_cal', 'icon': Icons.egg_rounded},
              {'name': 'Lunch', 'key': 'lunch_cal', 'icon': Icons.restaurant_rounded},
              {'name': 'Dinner', 'key': 'dinner_cal', 'icon': Icons.soup_kitchen_rounded},
              {'name': 'Snacks', 'key': 'snacks_cal', 'icon': Icons.bakery_dining_rounded},
              {'name': 'Eating Out', 'key': 'outside_food_cal', 'icon': Icons.delivery_dining_rounded},
            ];

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xEC090E18) : Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark ? AppTheme.glassBorder : const Color(0xFFEADBFF),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentCyan.withOpacity(0.12),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Row: Close Button & Category (or Category selector in edit mode)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (!isEditing)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentPurple.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppTheme.accentPurple.withOpacity(0.3),
                                    width: 1.2,
                                  ),
                                ),
                                child: Text(
                                  selectedMealKey == 'outside_food_cal'
                                      ? 'EATING OUT'
                                      : selectedMealKey.replaceAll('_cal', '').replaceAll('_', ' ').toUpperCase(),
                                  style: const TextStyle(
                                    color: AppTheme.accentPurple,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 10,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              )
                            else
                              const Text(
                                'EDIT ENTRY',
                                style: TextStyle(
                                  color: AppTheme.accentPurple,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            // Close button
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.04),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close_rounded,
                                  color: AppTheme.textSecondary,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        if (isEditing) ...[
                          const Text(
                            'MEAL CATEGORY',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: categories.map((cat) {
                              final isSelected = selectedMealKey == cat['key'];
                              return ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      cat['icon'] as IconData,
                                      size: 11,
                                      color: isSelected ? Colors.black : Colors.white70,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      cat['name'] as String,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: isSelected ? Colors.black : Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                                selected: isSelected,
                                selectedColor: AppTheme.accentCyan,
                                backgroundColor: Colors.white.withOpacity(0.03),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color: isSelected
                                        ? AppTheme.accentCyan
                                        : Colors.white.withOpacity(0.08),
                                  ),
                                ),
                                showCheckmark: false,
                                onSelected: (selected) {
                                  if (selected) {
                                    setState(() {
                                      selectedMealKey = cat['key'] as String;
                                    });
                                  }
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Meal Name (Text or TextField)
                        if (!isEditing)
                          Text(
                            nameController.text,
                            style: TextStyle(
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          )
                        else ...[
                          const Text(
                            'FOOD NAME',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nameController,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.02),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppTheme.accentCyan),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 8),

                        // Time indicator row (only show if not editing)
                        if (!isEditing)
                          Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                color: AppTheme.textSecondary,
                                size: 13,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Logged at $time',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                        if (item['imageUrl'] != null && (item['imageUrl'] as String).isNotEmpty) ...[
                          const SizedBox(height: 16),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: double.infinity,
                              height: 140,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.06),
                                ),
                              ),
                              child: () {
                                final imgStr = item['imageUrl'] as String;
                                if (imgStr.startsWith('http')) {
                                  return Image.network(imgStr, fit: BoxFit.cover);
                                }
                                try {
                                  String cleaned = imgStr;
                                  final commaIndex = cleaned.indexOf(',');
                                  if (commaIndex != -1) {
                                    cleaned = cleaned.substring(commaIndex + 1);
                                  }
                                  cleaned = cleaned.replaceAll(RegExp(r'\s+'), '');
                                  return Image.memory(base64Decode(cleaned), fit: BoxFit.cover);
                                } catch (e) {
                                  return const Center(
                                    child: Icon(Icons.broken_image_rounded, color: AppTheme.accentCoral),
                                  );
                                }
                              }(),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Bento-Grid of Calories (or TextField in edit mode)
                        if (!isEditing)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                            decoration: BoxDecoration(
                              color: AppTheme.accentCyan.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppTheme.accentCyan.withOpacity(0.25),
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentCyan.withOpacity(0.12),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.local_fire_department_rounded,
                                        color: AppTheme.accentCyan,
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'CALORIES',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                        Text(
                                          'Energy Output',
                                          style: TextStyle(
                                            color: AppTheme.textSecondary,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                Text(
                                  '${calController.text} kcal',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          const Text(
                            'CALORIES',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: calController,
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.02),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              suffixText: ' kcal',
                              suffixStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: const BorderSide(color: AppTheme.accentCyan),
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),

                        // Macros Splits
                        if (!isEditing)
                          Row(
                            children: [
                              Expanded(child: _buildDetailMacroCard('PROTEIN', '${proteinController.text}g', AppTheme.accentOrange, Icons.egg_rounded)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildDetailMacroCard('CARBS', '${carbsController.text}g', AppTheme.accentCyan, Icons.bakery_dining_rounded)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildDetailMacroCard('FAT', '${fatController.text}g', AppTheme.accentCoral, Icons.water_drop_rounded)),
                            ],
                          )
                        else ...[
                          const Text(
                            'MACRONUTRIENTS (G)',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(child: _buildMiniEditField("Protein", proteinController)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildMiniEditField("Carbs", carbsController)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildMiniEditField("Fat", fatController)),
                            ],
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Buttons section
                        if (!isEditing)
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final selectedDate = ref.read(selectedDateProvider);
                                    final currentMetrics = ref.read(dailyMetricsProvider(selectedDate));
                                    final updatedMetrics = Map<String, dynamic>.from(currentMetrics);

                                    final List<dynamic> loggedItems = List<dynamic>.from(updatedMetrics['logged_items'] ?? []);
                                    int removeIndex = -1;
                                    for (int i = 0; i < loggedItems.length; i++) {
                                      final currentItem = loggedItems[i];
                                      if (currentItem['name'] == item['name'] &&
                                          currentItem['calories'] == item['calories'] &&
                                          currentItem['protein'] == item['protein'] &&
                                          currentItem['carbs'] == item['carbs'] &&
                                          currentItem['fat'] == item['fat'] &&
                                          currentItem['meal'] == item['meal'] &&
                                          currentItem['time'] == item['time']) {
                                        removeIndex = i;
                                        break;
                                      }
                                    }

                                    if (removeIndex != -1) {
                                      loggedItems.removeAt(removeIndex);
                                      updatedMetrics['logged_items'] = loggedItems;

                                      updatedMetrics[initialMealKey] = ((updatedMetrics[initialMealKey] ?? 0) - initialCalories).clamp(0, 999999);
                                      updatedMetrics['protein'] = ((updatedMetrics['protein'] ?? 0) - initialProtein).clamp(0, 999999);
                                      updatedMetrics['carbs'] = ((updatedMetrics['carbs'] ?? 0) - initialCarbs).clamp(0, 999999);
                                      updatedMetrics['fat'] = ((updatedMetrics['fat'] ?? 0) - initialFat).clamp(0, 999999);

                                      await ref.read(dailyMetricsProvider(selectedDate).notifier).saveMetrics(updatedMetrics);

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          backgroundColor: AppTheme.accentCoral,
                                          content: Text("Deleted entry: ${initialName}"),
                                        ),
                                      );
                                    }
                                    Navigator.of(context).pop();
                                  },
                                  child: Container(
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentCoral.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppTheme.accentCoral.withOpacity(0.3),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.delete_outline_rounded, color: AppTheme.accentCoral, size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            "Delete",
                                            style: TextStyle(
                                              color: AppTheme.accentCoral,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    setState(() {
                                      isEditing = true;
                                    });
                                  },
                                  child: Container(
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentCyan.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: AppTheme.accentCyan.withOpacity(0.3),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.edit_rounded, color: AppTheme.accentCyan, size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            "Edit Entry",
                                            style: TextStyle(
                                              color: AppTheme.accentCyan,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          )
                        else
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    if (startInEditMode) {
                                      Navigator.of(context).pop();
                                    } else {
                                      setState(() {
                                        isEditing = false;
                                        // Reset fields
                                        nameController.text = initialName;
                                        calController.text = initialCalories.toString();
                                        proteinController.text = initialProtein.toString();
                                        carbsController.text = initialCarbs.toString();
                                        fatController.text = initialFat.toString();
                                        selectedMealKey = initialMealKey;
                                      });
                                    }
                                  },
                                  child: Container(
                                    height: 46,
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.04),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.08),
                                        width: 1.2,
                                      ),
                                    ),
                                    child: const Center(
                                      child: Text(
                                        "Cancel",
                                        style: TextStyle(
                                          color: AppTheme.textSecondary,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: GestureDetector(
                                  onTap: () async {
                                    final selectedDate = ref.read(selectedDateProvider);
                                    final currentMetrics = ref.read(dailyMetricsProvider(selectedDate));
                                    final updatedMetrics = Map<String, dynamic>.from(currentMetrics);

                                    final String newName = nameController.text.trim();
                                    final int newCal = int.tryParse(calController.text) ?? 0;
                                    final int newProt = int.tryParse(proteinController.text) ?? 0;
                                    final int newCarb = int.tryParse(carbsController.text) ?? 0;
                                    final int newFat = int.tryParse(fatController.text) ?? 0;

                                    final List<dynamic> loggedItems = List<dynamic>.from(updatedMetrics['logged_items'] ?? []);
                                    int updateIndex = -1;
                                    for (int i = 0; i < loggedItems.length; i++) {
                                      final currentItem = loggedItems[i];
                                      if (currentItem['name'] == item['name'] &&
                                          currentItem['calories'] == item['calories'] &&
                                          currentItem['protein'] == item['protein'] &&
                                          currentItem['carbs'] == item['carbs'] &&
                                          currentItem['fat'] == item['fat'] &&
                                          currentItem['meal'] == item['meal'] &&
                                          currentItem['time'] == item['time']) {
                                        updateIndex = i;
                                        break;
                                      }
                                    }

                                    if (updateIndex != -1) {
                                      // 1. Subtract original values from daily totals
                                      updatedMetrics[initialMealKey] = ((updatedMetrics[initialMealKey] ?? 0) - initialCalories).clamp(0, 999999);
                                      updatedMetrics['protein'] = ((updatedMetrics['protein'] ?? 0) - initialProtein).clamp(0, 999999);
                                      updatedMetrics['carbs'] = ((updatedMetrics['carbs'] ?? 0) - initialCarbs).clamp(0, 999999);
                                      updatedMetrics['fat'] = ((updatedMetrics['fat'] ?? 0) - initialFat).clamp(0, 999999);

                                      // 2. Add new values to daily totals
                                      updatedMetrics[selectedMealKey] = ((updatedMetrics[selectedMealKey] ?? 0) + newCal).clamp(0, 999999);
                                      updatedMetrics['protein'] = ((updatedMetrics['protein'] ?? 0) + newProt).clamp(0, 999999);
                                      updatedMetrics['carbs'] = ((updatedMetrics['carbs'] ?? 0) + newCarb).clamp(0, 999999);
                                      updatedMetrics['fat'] = ((updatedMetrics['fat'] ?? 0) + newFat).clamp(0, 999999);

                                      // 3. Update logged item entry
                                      final String newMealLabel = selectedMealKey == 'outside_food_cal'
                                          ? 'EATING OUT'
                                          : selectedMealKey.replaceAll('_cal', '').replaceAll('_', ' ').toUpperCase();

                                      loggedItems[updateIndex] = {
                                        ...loggedItems[updateIndex],
                                        'name': newName.isNotEmpty ? newName : "Logged Meal",
                                        'calories': newCal,
                                        'protein': newProt,
                                        'carbs': newCarb,
                                        'fat': newFat,
                                        'meal': newMealLabel,
                                      };
                                      updatedMetrics['logged_items'] = loggedItems;

                                      await ref.read(dailyMetricsProvider(selectedDate).notifier).saveMetrics(updatedMetrics);

                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          backgroundColor: AppTheme.accentEmerald,
                                          content: Text("Updated entry successfully!"),
                                        ),
                                      );
                                    }
                                    Navigator.of(context).pop();
                                  },
                                  child: Container(
                                    height: 46,
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.accentCyan.withOpacity(0.15),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Text(
                                        "Save Changes",
                                        style: TextStyle(
                                          color: Colors.black,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDetailMacroCard(String label, String val, Color col, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: col.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: col.withOpacity(0.2),
          width: 1.2,
        ),
      ),
      child: Column(
        children: [
          Icon(icon, color: col, size: 16),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            val,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniEditField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 9,
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white.withOpacity(0.02),
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      ],
    );
  }

  // Edit Daily Goal Dialog
  void _showEditDailyGoalDialog(BuildContext context, String dateStr) {
    final currentMetrics = ref.read(dailyMetricsProvider(dateStr));
    final breakfastController = TextEditingController(text: (currentMetrics['breakfast_cal'] ?? 0).toString());
    final lunchController = TextEditingController(text: (currentMetrics['lunch_cal'] ?? 0).toString());
    final dinnerController = TextEditingController(text: (currentMetrics['dinner_cal'] ?? 0).toString());
    final snacksController = TextEditingController(text: (currentMetrics['snacks_cal'] ?? 0).toString());
    final outsideFoodController = TextEditingController(text: (currentMetrics['outside_food_cal'] ?? 0).toString());
    final proteinController = TextEditingController(text: (currentMetrics['protein'] ?? 0).toString());
    final carbsController = TextEditingController(text: (currentMetrics['carbs'] ?? 0).toString());
    final fatController = TextEditingController(text: (currentMetrics['fat'] ?? 0).toString());
    final waterController = TextEditingController(text: (currentMetrics['water'] ?? 0).toString());

    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final latestMetrics = ref.read(dailyMetricsProvider(dateStr));
            final List<dynamic> loggedItems = latestMetrics['logged_items'] ?? [];

            IconData getMealIcon(String meal) {
              final upper = meal.toUpperCase();
              if (upper == 'BREAKFAST') return Icons.egg_rounded;
              if (upper == 'LUNCH') return Icons.restaurant_rounded;
              if (upper == 'DINNER') return Icons.soup_kitchen_rounded;
              if (upper == 'SNACKS') return Icons.bakery_dining_rounded;
              return Icons.delivery_dining_rounded;
            }

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(28),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 460),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xEC090E18) : Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark ? AppTheme.glassBorder : const Color(0xFFEADBFF),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentCyan.withOpacity(0.12),
                          blurRadius: 30,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Edit Daily Metrics',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.5,
                                      color: isDark ? Colors.white : AppTheme.textPrimary,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  const Text(
                                    'Manual overrides for the selected day',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: () => Navigator.of(context).pop(),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: AppTheme.textSecondary,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          const Text(
                            'CALORIES BY CATEGORY',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),

                          Row(
                            children: [
                              Expanded(child: _buildEditField("Breakfast", breakfastController, isDark)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildEditField("Lunch", lunchController, isDark)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(child: _buildEditField("Dinner", dinnerController, isDark)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildEditField("Snacks", snacksController, isDark)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildEditField("Eating Out", outsideFoodController, isDark),

                          const SizedBox(height: 20),
                          const Text(
                            'MACRONUTRIENTS (G)',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: _buildEditField("Protein", proteinController, isDark)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildEditField("Carbs", carbsController, isDark)),
                              const SizedBox(width: 8),
                              Expanded(child: _buildEditField("Fat", fatController, isDark)),
                            ],
                          ),

                          const SizedBox(height: 20),
                          const Text(
                            'HYDRATION',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          _buildEditField("Water Intake (ml)", waterController, isDark),

                          const SizedBox(height: 20),
                          const Divider(color: Colors.white12, height: 1),
                          const SizedBox(height: 20),
                          const Text(
                            'LOGGED FOOD HISTORY',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 10),
                          if (loggedItems.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 12),
                              child: Text(
                                'No food items logged for this day',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          else
                            ...loggedItems.map((item) {
                              final String name = item['name'] ?? 'Logged Meal';
                              final String meal = item['meal'] ?? 'MEAL';
                              final int calories = item['calories'] ?? 0;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.06),
                                    width: 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: AppTheme.accentCyan.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        getMealIcon(meal),
                                        color: AppTheme.accentCyan,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            name,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '$meal • $calories kcal',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: AppTheme.textSecondary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded, color: AppTheme.accentCyan, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () async {
                                        await _showFoodDetailsDialog(context, Map<String, dynamic>.from(item), startInEditMode: true);
                                        final updated = ref.read(dailyMetricsProvider(dateStr));
                                        breakfastController.text = (updated['breakfast_cal'] ?? 0).toString();
                                        lunchController.text = (updated['lunch_cal'] ?? 0).toString();
                                        dinnerController.text = (updated['dinner_cal'] ?? 0).toString();
                                        snacksController.text = (updated['snacks_cal'] ?? 0).toString();
                                        outsideFoodController.text = (updated['outside_food_cal'] ?? 0).toString();
                                        proteinController.text = (updated['protein'] ?? 0).toString();
                                        carbsController.text = (updated['carbs'] ?? 0).toString();
                                        fatController.text = (updated['fat'] ?? 0).toString();
                                        setState(() {});
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.accentCoral, size: 16),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () async {
                                        final latestMetrics = ref.read(dailyMetricsProvider(dateStr));
                                        final updatedMetrics = Map<String, dynamic>.from(latestMetrics);

                                        final List<dynamic> loggedItems = List<dynamic>.from(updatedMetrics['logged_items'] ?? []);
                                        int removeIndex = -1;
                                        for (int i = 0; i < loggedItems.length; i++) {
                                          final currentItem = loggedItems[i];
                                          if (currentItem['name'] == item['name'] &&
                                              currentItem['calories'] == item['calories'] &&
                                              currentItem['protein'] == item['protein'] &&
                                              currentItem['carbs'] == item['carbs'] &&
                                              currentItem['fat'] == item['fat'] &&
                                              currentItem['meal'] == item['meal'] &&
                                              currentItem['time'] == item['time']) {
                                            removeIndex = i;
                                            break;
                                          }
                                        }

                                        if (removeIndex != -1) {
                                          loggedItems.removeAt(removeIndex);
                                          updatedMetrics['logged_items'] = loggedItems;

                                          String mealKey;
                                          switch (meal.toUpperCase()) {
                                            case 'BREAKFAST':
                                              mealKey = 'breakfast_cal';
                                              break;
                                            case 'LUNCH':
                                              mealKey = 'lunch_cal';
                                              break;
                                            case 'DINNER':
                                              mealKey = 'dinner_cal';
                                              break;
                                            case 'SNACKS':
                                              mealKey = 'snacks_cal';
                                              break;
                                            case 'EATING OUT':
                                            case 'OUTSIDE FOOD':
                                              mealKey = 'outside_food_cal';
                                              break;
                                            default:
                                              mealKey = 'snacks_cal';
                                          }

                                          final int calVal = item['calories'] ?? 0;
                                          final int protVal = item['protein'] ?? 0;
                                          final int carbsVal = item['carbs'] ?? 0;
                                          final int fatVal = item['fat'] ?? 0;

                                          updatedMetrics[mealKey] = ((updatedMetrics[mealKey] ?? 0) - calVal).clamp(0, 999999);
                                          updatedMetrics['protein'] = ((updatedMetrics['protein'] ?? 0) - protVal).clamp(0, 999999);
                                          updatedMetrics['carbs'] = ((updatedMetrics['carbs'] ?? 0) - carbsVal).clamp(0, 999999);
                                          updatedMetrics['fat'] = ((updatedMetrics['fat'] ?? 0) - fatVal).clamp(0, 999999);

                                          await ref.read(dailyMetricsProvider(dateStr).notifier).saveMetrics(updatedMetrics);

                                          breakfastController.text = (updatedMetrics['breakfast_cal'] ?? 0).toString();
                                          lunchController.text = (updatedMetrics['lunch_cal'] ?? 0).toString();
                                          dinnerController.text = (updatedMetrics['dinner_cal'] ?? 0).toString();
                                          snacksController.text = (updatedMetrics['snacks_cal'] ?? 0).toString();
                                          outsideFoodController.text = (updatedMetrics['outside_food_cal'] ?? 0).toString();
                                          proteinController.text = (updatedMetrics['protein'] ?? 0).toString();
                                          carbsController.text = (updatedMetrics['carbs'] ?? 0).toString();
                                          fatController.text = (updatedMetrics['fat'] ?? 0).toString();

                                          setState(() {});

                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(
                                              backgroundColor: AppTheme.accentCoral,
                                              content: Text("Deleted entry: $name"),
                                            ),
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }),

                          const SizedBox(height: 28),

                          GestureDetector(
                            onTap: () async {
                              final latestMetricsForSave = ref.read(dailyMetricsProvider(dateStr));
                              final updatedMetrics = Map<String, dynamic>.from(latestMetricsForSave);
                              updatedMetrics['breakfast_cal'] = int.tryParse(breakfastController.text) ?? 0;
                              updatedMetrics['lunch_cal'] = int.tryParse(lunchController.text) ?? 0;
                              updatedMetrics['dinner_cal'] = int.tryParse(dinnerController.text) ?? 0;
                              updatedMetrics['snacks_cal'] = int.tryParse(snacksController.text) ?? 0;
                              updatedMetrics['outside_food_cal'] = int.tryParse(outsideFoodController.text) ?? 0;
                              updatedMetrics['protein'] = int.tryParse(proteinController.text) ?? 0;
                              updatedMetrics['carbs'] = int.tryParse(carbsController.text) ?? 0;
                              updatedMetrics['fat'] = int.tryParse(fatController.text) ?? 0;
                              updatedMetrics['water'] = int.tryParse(waterController.text) ?? 0;

                              await ref.read(dailyMetricsProvider(dateStr).notifier).saveMetrics(updatedMetrics);

                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: AppTheme.accentEmerald,
                                  content: Text("Daily metrics updated successfully!"),
                                ),
                              );
                              Navigator.of(context).pop();
                            },
                            child: Container(
                              height: 48,
                              decoration: BoxDecoration(
                                gradient: AppTheme.primaryGradient,
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppTheme.accentCyan.withOpacity(0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: const Center(
                                child: Text(
                                  "Save Changes",
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            filled: true,
            fillColor: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppTheme.glassBorder : Colors.black.withOpacity(0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? AppTheme.glassBorder : Colors.black.withOpacity(0.1),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppTheme.accentCyan),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================
  // ADD FOOD REGISTER BOTTOM MODAL
  // ==========================================

  void _showAddFoodBottomSheet(
    BuildContext context,
    String mealName,
    String mealKey,
    String selectedDate,
  ) {
    final foodNameController = TextEditingController();
    final caloriesController = TextEditingController();
    final proteinController = TextEditingController();
    final carbsController = TextEditingController();
    final fatController = TextEditingController();
    final textPromptController = TextEditingController();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Stateful state indicators
    int activeTab = 0; // 0 = AI Scan, 1 = Favourites
    String selectedMealKey = mealKey;
    bool isScanning = false;
    String scanStatusText = '';
    String? selectedFoodPic;
    bool saveAsFavorite = false;

    final categories = [
      {'name': 'Breakfast', 'key': 'breakfast_cal', 'icon': Icons.egg_rounded},
      {'name': 'Lunch', 'key': 'lunch_cal', 'icon': Icons.restaurant_rounded},
      {'name': 'Snacks', 'key': 'snacks_cal', 'icon': Icons.bakery_dining_rounded},
      {'name': 'Dinner', 'key': 'dinner_cal', 'icon': Icons.soup_kitchen_rounded},
      {'name': 'Eating Out', 'key': 'outside_food_cal', 'icon': Icons.delivery_dining_rounded},
    ];

    final List<Map<String, dynamic>> presetList = [
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
      {
        'name': 'Protein Shake & Almonds',
        'calories': 320,
        'protein': 32,
        'carbs': 12,
        'fat': 14,
        'imageUrl': 'https://lh3.googleusercontent.com/aida-public/AB6AXuAu02ztHCanw1Xo-CIsQxvODCtZXuuPSSm0Kn4ZGG3jNSR0Ffx2Q5Q9ezBZymakx28NRatfkqbjwoU2ihTQJwLgBDIWKsZzvnBRAMkgG0j6Uz0sH5-uofS3PGDzF4acLg4DHNPPHAbQwbos-7Bq3B_mc5XWzCQt_0oXTJ1EXjvahwLqze45OL8C5aVKdO-10SRju8l4451S6qP7FBAwNzwklV4Ek-SVdF9fmeejvW_NNhv5bnuC8itvhdJkQLn1txc5IlKWvspYzec',
      },
      {
        'name': 'Baked Salmon & Broccoli',
        'calories': 550,
        'protein': 46,
        'carbs': 15,
        'fat': 28,
        'imageUrl': 'https://lh3.googleusercontent.com/aida-public/AB6AXuCFm2XsMjmJXAwf6NI19eSwHEj0P9zTCPYixIxf-0z0TEcCuUHilYMI3P4tUgUe-PdA9HXvnTLZZ1ndshzFd3I3DnyErcUadkcQJa9YLl1imhnDgQgG5Sze7_tsXER8ycWlX977B9ZhqsctcZIxLZVgAaulUYjOvqimZIh7pOZ4R0Tq-KJeeQ_vAi6NQACiSB_5dxlxijqCH2Smr5IoNorK8wcS2dHSA8j7v2W89G_EGOKHVnmkUg2OhkglDg0MKzwIWAJxCyJJaCQ',
      },
      {
        'name': 'Caesar Salad with Chicken',
        'calories': 380,
        'protein': 28,
        'carbs': 12,
        'fat': 24,
        'imageUrl': 'https://images.unsplash.com/photo-1550304943-4f24f54ddde9?auto=format&fit=crop&q=80&w=300',
      },
      {
        'name': 'Double Cheeseburger',
        'calories': 750,
        'protein': 42,
        'carbs': 45,
        'fat': 38,
        'imageUrl': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?auto=format&fit=crop&q=80&w=300',
      },
      {
        'name': 'Sushi Platter',
        'calories': 450,
        'protein': 20,
        'carbs': 65,
        'fat': 8,
        'imageUrl': 'https://images.unsplash.com/photo-1579871494447-9811cf80d66c?auto=format&fit=crop&q=80&w=300',
      },
      {
        'name': 'Chicken Biryani',
        'calories': 650,
        'protein': 30,
        'carbs': 80,
        'fat': 20,
        'imageUrl': 'https://images.unsplash.com/photo-1563379091339-03b21ab4a4f8?auto=format&fit=crop&q=80&w=300',
      },
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> callRealGeminiApi({
              required String queryText,
              required String? imageBase64,
            }) async {
              setState(() {
                isScanning = true;
                scanStatusText = 'Checking Hive & matching profiles...';
              });

              try {
                final result = await AiAnalysisService.analyzeFood(
                  imageBase64: imageBase64,
                  queryText: queryText,
                  onProgress: (step) {
                    if (ctx.mounted) {
                      setState(() {
                        scanStatusText = step;
                      });
                    }
                  },
                );

                if (ctx.mounted) {
                  setState(() {
                    isScanning = false;
                    foodNameController.text = result['name'] ?? queryText;
                    caloriesController.text = (result['calories'] ?? 0).toString();
                    proteinController.text = (result['protein'] ?? 0).toString();
                    carbsController.text = (result['carbs'] ?? 0).toString();
                    fatController.text = (result['fat'] ?? 0).toString();
                    
                    final String portion = result['portion'] ?? '';
                    if (portion.isNotEmpty) {
                      foodNameController.text = "${result['name']} ($portion)";
                    }
                  });
                }
              } catch (e) {
                debugPrint("Aura Nutrient Ingestion pipeline failed: $e");
                if (ctx.mounted) {
                  setState(() {
                    isScanning = false;
                  });
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Ingestion pipeline failed. Triggering offline stubs...'),
                      backgroundColor: AppTheme.accentCoral,
                    ),
                  );
                }
              }
            }

            void simulateMockScan(Map<String, dynamic> food) {
              setState(() {
                isScanning = true;
                selectedFoodPic = food['imageUrl'];
                scanStatusText = 'AI Analysing...';
              });

              Future.delayed(const Duration(milliseconds: 800), () {
                if (ctx.mounted) {
                  setState(() {
                    isScanning = false;
                    foodNameController.text = food['name'];
                    caloriesController.text = food['calories'].toString();
                    proteinController.text = food['protein'].toString();
                    carbsController.text = food['carbs'].toString();
                    fatController.text = food['fat'].toString();
                  });
                }
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: Container(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.85),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.glassBackground : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  border: Border.all(
                    color: isDark ? AppTheme.glassBorder : const Color(0xFFEADBFF),
                    width: 1.0,
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Handle bar
                      Center(
                        child: Container(
                          width: 48,
                          height: 4.5,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Zivo Nutrient Logger',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'Select meal type and pick a fast logging method below.',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // 1. Meal Category Selector (Breakfast, Lunch, Snacks, Dinner, Eating Out)
                      const Text(
                        'MEAL TYPE',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 38,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: categories.length,
                          itemBuilder: (context, index) {
                            final cat = categories[index];
                            final isSelected = selectedMealKey == cat['key'];
                            final activeColor = isSelected ? AppTheme.accentCyan : AppTheme.textSecondary;

                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  selectedMealKey = cat['key'] as String;
                                });
                              },
                              child: Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppTheme.accentPurple.withOpacity(0.12)
                                      : (isDark ? Colors.white.withOpacity(0.03) : Colors.black.withOpacity(0.015)),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? AppTheme.accentCyan : AppTheme.glassBorder,
                                    width: 1.2,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(cat['icon'] as IconData, color: activeColor, size: 14),
                                    const SizedBox(width: 6),
                                    Text(
                                      cat['name'] as String,
                                      style: TextStyle(
                                        color: activeColor,
                                        fontSize: 11,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 2. Tab Navigation
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => activeTab = 0),
                              child: Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  color: activeTab == 0 ? AppTheme.accentCyan.withOpacity(0.08) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: activeTab == 0 ? AppTheme.accentCyan : Colors.transparent,
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    'AI Scan',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => setState(() => activeTab = 1),
                              child: Container(
                                height: 36,
                                decoration: BoxDecoration(
                                  color: activeTab == 1 ? AppTheme.accentCoral.withOpacity(0.08) : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: activeTab == 1 ? AppTheme.accentCoral : Colors.transparent,
                                  ),
                                ),
                                child: const Center(
                                  child: Text(
                                    'Favourites',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // 3. Tab contents
                      if (activeTab == 0) ...[
                        // Combined AI Scan & Snap + Manual Input Content
                        Container(
                          height: 160,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isScanning ? AppTheme.accentCyan : AppTheme.glassBorder,
                              width: 1.5,
                            ),
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Grid overlay
                              Opacity(
                                opacity: 0.15,
                                child: GridView.builder(
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 12,
                                  ),
                                  itemBuilder: (_, __) => Container(
                                    decoration: BoxDecoration(
                                      border: Border.all(color: AppTheme.accentCyan, width: 0.5),
                                    ),
                                  ),
                                ),
                              ),

                              // Preview Image
                              if (selectedFoodPic != null)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(18),
                                  child: Image.network(
                                    selectedFoodPic!,
                                    width: double.infinity,
                                    height: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),

                              // Sweeping laser animation
                              if (isScanning)
                                TweenAnimationBuilder<double>(
                                  tween: Tween(begin: 0.0, end: 1.0),
                                  duration: const Duration(seconds: 2),
                                  builder: (context, value, child) {
                                    return Positioned(
                                      top: value * 160,
                                      left: 0,
                                      right: 0,
                                      child: Container(
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: AppTheme.accentCyan,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.accentCyan.withOpacity(0.8),
                                              blurRadius: 10,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),

                              // Scan overlay panel
                              if (isScanning)
                                Container(
                                  color: Colors.black.withOpacity(0.65),
                                  child: Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const SizedBox(
                                          width: 32,
                                          height: 32,
                                          child: CircularProgressIndicator(
                                            color: AppTheme.accentCyan,
                                            strokeWidth: 3,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          scanStatusText,
                                          style: const TextStyle(
                                            color: AppTheme.accentCyan,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else if (selectedFoodPic == null)
                                GestureDetector(
                                  onTap: () {
                                    ImagePickerHelper.pickImage((base64, name, filePath) {
                                      setState(() {
                                        selectedFoodPic = 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&q=80&w=300';
                                      });
                                      callRealGeminiApi(queryText: name, imageBase64: base64);
                                    });
                                  },
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.camera_alt_rounded,
                                        color: AppTheme.accentCyan.withOpacity(0.8),
                                        size: 44,
                                      ),
                                      const SizedBox(height: 12),
                                      const Text(
                                        'Click / Upload Food Photo to Auto-Detect',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'Gemini AI will automatically calculate portions & nutrients.',
                                        style: TextStyle(
                                          color: AppTheme.textSecondary.withOpacity(0.8),
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Image Picker Click Button + Text Query integrated row
                        Row(
                          children: [
                            GestureDetector(
                              onTap: () {
                                ImagePickerHelper.pickImage((base64, name, filePath) {
                                  setState(() {
                                    selectedFoodPic = 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&q=80&w=300';
                                  });
                                  callRealGeminiApi(queryText: name, imageBase64: base64);
                                });
                              },
                              child: Container(
                                height: 48,
                                width: 52,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentCyan.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.accentCyan, width: 1.5),
                                ),
                                child: const Icon(Icons.add_a_photo_rounded, color: AppTheme.accentCyan, size: 20),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.obsidianBackground,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppTheme.glassBorder, width: 1.0),
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
                                child: TextField(
                                  controller: textPromptController,
                                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                                  decoration: const InputDecoration(
                                    hintText: 'Or describe meal (e.g. 2 eggs & banana)',
                                    hintStyle: TextStyle(color: AppTheme.textSecondary, fontSize: 11.5),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                final text = textPromptController.text.trim();
                                if (text.isNotEmpty) {
                                  callRealGeminiApi(queryText: text, imageBase64: null);
                                }
                              },
                              child: Container(
                                height: 48,
                                width: 52,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accentPurple.withOpacity(0.2),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          'TAP TO AI DETECT SAMPLE DISHES',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 70,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: 4,
                            itemBuilder: (context, index) {
                              final food = presetList[index];
                              return GestureDetector(
                                onTap: () => simulateMockScan(food),
                                child: Container(
                                  margin: const EdgeInsets.only(right: 10),
                                  width: 110,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AppTheme.glassBorder),
                                    image: DecorationImage(
                                      image: NetworkImage(food['imageUrl']),
                                      fit: BoxFit.cover,
                                      colorFilter: ColorFilter.mode(Colors.black.withOpacity(0.4), BlendMode.darken),
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      food['name'].split(' & ')[0].split(' with ')[0],
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ] else ...[
                        // Favourites Grid List (Tab 2)
                        const Text(
                          'YOUR PERSISTENT FAVORITE MEALS',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        () {
                          final favorites = StorageService.getFavoriteFoods();
                          if (favorites.isEmpty) {
                            return GlassCard(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
                              child: Column(
                                children: [
                                  Icon(Icons.favorite_border_rounded, color: AppTheme.accentCoral.withOpacity(0.4), size: 36),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'No favorite meals saved yet.',
                                    style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  const Text(
                                    'Toggle the heart button next to log button to add!',
                                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                  ),
                                ],
                              ),
                            );
                          }
                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 2.1,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                            ),
                            itemCount: favorites.length,
                            itemBuilder: (context, index) {
                              final food = favorites[index];
                              final String fName = food['name'] ?? 'Favourite';
                              final int fCalories = food['calories'] ?? 0;
                              final int fProtein = food['protein'] ?? 0;
                              final int fCarbs = food['carbs'] ?? 0;
                              final int fFat = food['fat'] ?? 0;
                              final String fImage = food['imageUrl'] ?? 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&q=80&w=200';

                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    selectedFoodPic = fImage;
                                    foodNameController.text = fName;
                                    caloriesController.text = fCalories.toString();
                                    proteinController.text = fProtein.toString();
                                    carbsController.text = fCarbs.toString();
                                    fatController.text = fFat.toString();
                                  });
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppTheme.obsidianBackground,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppTheme.glassBorder, width: 1.0),
                                  ),
                                  padding: const EdgeInsets.all(8),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 38,
                                        height: 38,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(8),
                                          image: DecorationImage(
                                            image: NetworkImage(fImage),
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    fName,
                                                    style: const TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.white,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                GestureDetector(
                                                  onTap: () async {
                                                    await StorageService.removeFavoriteFood(fName);
                                                    setState(() {});
                                                  },
                                                  child: const Icon(
                                                    Icons.delete_outline_rounded,
                                                    color: AppTheme.accentCoral,
                                                    size: 13,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '$fCalories kcal',
                                              style: const TextStyle(
                                                fontSize: 9.5,
                                                color: AppTheme.accentCyan,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              'P:${fProtein}g C:${fCarbs}g F:${fFat}g',
                                              style: const TextStyle(
                                                fontSize: 7.5,
                                                color: AppTheme.textSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          );
                        }(),
                      ],

                      const SizedBox(height: 24),
                      const Divider(color: AppTheme.glassBorder, height: 1),
                      const SizedBox(height: 20),

                      // Nutrient entry review fields
                      const Text(
                        'REVIEW & LOG INTAKE DETAILS (EDITABLE)',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _buildModalTextField(
                        foodNameController,
                        'Food Name (e.g. Grilled Salmon)',
                        '',
                        Icons.restaurant_menu_rounded,
                        AppTheme.accentCyan,
                        isText: true,
                      ),
                      const SizedBox(height: 12),

                      _buildModalTextField(
                        caloriesController,
                        'Calories',
                        'kcal',
                        Icons.bolt_rounded,
                        AppTheme.accentCyan,
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          Expanded(
                            child: _buildModalTextField(
                              proteinController,
                              'Protein',
                              'g',
                              Icons.egg_rounded,
                              AppTheme.accentOrange,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildModalTextField(
                              carbsController,
                              'Carbs',
                              'g',
                              Icons.bakery_dining_rounded,
                              AppTheme.accentCyan,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildModalTextField(
                              fatController,
                              'Fat',
                              'g',
                              Icons.water_drop_rounded,
                              AppTheme.accentCoral,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      // Side by side Log and Favorite Button
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                saveAsFavorite = !saveAsFavorite;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                color: saveAsFavorite ? AppTheme.accentCoral.withOpacity(0.12) : AppTheme.obsidianBackground,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: saveAsFavorite ? AppTheme.accentCoral : AppTheme.glassBorder,
                                  width: 1.5,
                                ),
                              ),
                              child: Icon(
                                saveAsFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: saveAsFavorite ? AppTheme.accentCoral : AppTheme.textSecondary,
                                size: 22,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                final name = foodNameController.text.trim();
                                final c = int.tryParse(caloriesController.text) ?? 0;
                                final p = int.tryParse(proteinController.text) ?? 0;
                                final cb = int.tryParse(carbsController.text) ?? 0;
                                final f = int.tryParse(fatController.text) ?? 0;

                                if (c > 0) {
                                  final loggedName = name.isNotEmpty ? name : 'Custom Meal';
                                  ref
                                      .read(dailyMetricsProvider(selectedDate).notifier)
                                      .logMeal(
                                        mealKey: selectedMealKey,
                                        calories: c,
                                        protein: p,
                                        carbs: cb,
                                        fat: f,
                                        foodName: loggedName,
                                      );

                                  if (saveAsFavorite) {
                                    await StorageService.saveFavoriteFood({
                                      'name': loggedName,
                                      'calories': c,
                                      'protein': p,
                                      'carbs': cb,
                                      'fat': f,
                                      'imageUrl': selectedFoodPic ?? 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&q=80&w=200',
                                    });
                                  }
                                }
                                Navigator.of(ctx).pop();
                              },
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  gradient: AppTheme.primaryGradient,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accentCyan.withOpacity(0.15),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: const Center(
                                  child: Text(
                                    'Add Meal Entry',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildModalTextField(
    TextEditingController ctrl,
    String label,
    String suffix,
    IconData icon,
    Color color, {
    bool isText = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.obsidianBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.glassBorder, width: 1.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: TextField(
        controller: ctrl,
        keyboardType: isText ? TextInputType.text : TextInputType.number,
        style: const TextStyle(
          color: AppTheme.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          icon: Icon(icon, color: color, size: 18),
          labelText: label,
          labelStyle: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
          ),
          suffixText: suffix.isEmpty ? null : suffix,
          suffixStyle: TextStyle(color: color, fontWeight: FontWeight.bold),
          border: InputBorder.none,
        ),
      ),
    );
  }

  void _showNotificationsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (sheetContext) {
        return Consumer(
          builder: (context, ref, child) {
            final profile = ref.watch(profileProvider);
            final history = ref.watch(workoutHistoryProvider);
            final systemNotifications = ref.watch(notificationsProvider);
            final auraNotifications = ref.read(notificationsProvider.notifier)
                .getAuraNotifications(profile, history);

            final isAuraEnabled = StorageService.getAuraNotificationsEnabled();
            final isSystemEnabled = StorageService.getSystemNotificationsEnabled();

            final displayAura = isAuraEnabled ? auraNotifications : <AppNotification>[];
            final displaySystem = isSystemEnabled ? systemNotifications : <AppNotification>[];

            final isEmpty = displayAura.isEmpty && displaySystem.isEmpty;

            return Container(
              height: MediaQuery.of(sheetContext).size.height * 0.75,
              decoration: const BoxDecoration(
                color: AppTheme.obsidianBackground,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                border: Border(
                  top: BorderSide(color: AppTheme.glassBorder, width: 1.5),
                ),
              ),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.bgGradient,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Notifications & Alerts',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                          Row(
                            children: [
                              if (displaySystem.isNotEmpty)
                                TextButton(
                                  onPressed: () {
                                    ref.read(notificationsProvider.notifier).clearAll();
                                  },
                                  child: const Text(
                                    'CLEAR ALL',
                                    style: TextStyle(
                                      color: AppTheme.accentCoral,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              IconButton(
                                icon: const Icon(Icons.close_rounded, color: Colors.white),
                                onPressed: () => Navigator.pop(sheetContext),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // List
                      Expanded(
                        child: isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.notifications_off_rounded,
                                      color: Colors.white.withOpacity(0.15),
                                      size: 56,
                                    ),
                                    const SizedBox(height: 16),
                                    const Text(
                                      'No notifications active.',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Toggle alerts in Profile settings.',
                                      style: TextStyle(
                                        color: AppTheme.textTertiary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : ListView(
                                physics: const BouncingScrollPhysics(),
                                children: [
                                  if (displayAura.isNotEmpty) ...[
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 10),
                                      child: Text(
                                        'AURA AI HEALTH INSIGHTS',
                                        style: TextStyle(
                                          color: AppTheme.accentOrange,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                    ...displayAura.map((notif) {
                                      IconData icon = Icons.lightbulb_rounded;
                                      Color color = AppTheme.accentOrange;

                                      if (notif.title.contains('Metabolic')) {
                                        icon = Icons.bolt_rounded;
                                        color = notif.body.contains('exceeding') 
                                            ? AppTheme.accentCoral 
                                            : (notif.body.contains('hitting') ? AppTheme.accentEmerald : AppTheme.accentCyan);
                                      } else if (notif.title.contains('Hydration')) {
                                        icon = Icons.water_drop_rounded;
                                        color = AppTheme.accentCyan;
                                      }

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
                                                padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
                                                child: Row(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Container(
                                                      width: 36,
                                                      height: 36,
                                                      decoration: BoxDecoration(
                                                        color: color.withOpacity(0.12),
                                                        shape: BoxShape.circle,
                                                      ),
                                                      child: Center(
                                                        child: Icon(icon, color: color, size: 18),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 14),
                                                    Expanded(
                                                      child: Column(
                                                        crossAxisAlignment: CrossAxisAlignment.start,
                                                        children: [
                                                          Text(
                                                            notif.title,
                                                            style: const TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 14,
                                                              color: Colors.white,
                                                            ),
                                                          ),
                                                          const SizedBox(height: 3),
                                                          Text(
                                                            notif.body,
                                                            style: const TextStyle(
                                                              color: AppTheme.textSecondary,
                                                              fontSize: 11.5,
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
                                    }),
                                    const SizedBox(height: 16),
                                  ],
                                  if (displaySystem.isNotEmpty) ...[
                                    const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 10),
                                      child: Text(
                                        'SYSTEM ALERTS',
                                        style: TextStyle(
                                          color: AppTheme.accentCyan,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                    ...displaySystem.map((notif) {
                                      final timeStr = DateFormat('h:mm a').format(notif.timestamp);
                                      return Container(
                                        margin: const EdgeInsets.only(bottom: 12),
                                        child: GlassCard(
                                          padding: const EdgeInsets.all(14),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: 36,
                                                height: 36,
                                                decoration: BoxDecoration(
                                                  color: AppTheme.accentCyan.withOpacity(0.1),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.notifications_active_rounded,
                                                    color: AppTheme.accentCyan,
                                                    size: 18,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          notif.title,
                                                          style: const TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 14,
                                                            color: Colors.white,
                                                          ),
                                                        ),
                                                        Text(
                                                          timeStr,
                                                          style: const TextStyle(
                                                            color: AppTheme.textTertiary,
                                                            fontSize: 10,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      notif.body,
                                                      style: const TextStyle(
                                                        color: AppTheme.textSecondary,
                                                        fontSize: 11.5,
                                                        height: 1.4,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showHydrationDialog(
    BuildContext context,
    String dateStr,
    int waterConsumed,
    double waterGoal,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? AppTheme.glassBackground : Colors.white;
    final dialogBorder = isDark ? AppTheme.glassBorder : const Color(0xFFEADBFF);
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    final controller = TextEditingController(text: waterConsumed.toString());

    showDialog(
      context: context,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final dailyStats = ref.watch(dailyMetricsProvider(dateStr));
            final currentWater = (dailyStats['water'] ?? 0) as int;
            final List<int> rawHistory = List<int>.from(dailyStats['water_history'] ?? []);

            return AlertDialog(
              backgroundColor: dialogBg,
              surfaceTintColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: dialogBorder, width: 1),
              ),
              title: Row(
                children: [
                  const Icon(Icons.water_drop_rounded, color: AppTheme.accentPurple, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    'Hydration Manager',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Log and adjust your daily water intake settings.',
                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: Column(
                        children: [
                          Text(
                            '$currentWater ml',
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              color: AppTheme.accentPurple,
                            ),
                          ),
                          Text(
                            'Goal: ${waterGoal.toInt()} ml (${((currentWater / waterGoal) * 100).round()}% Completed)',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'RECENT INPUT LOGS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      height: 80,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(isDark ? 0.02 : 0.015),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: dialogBorder, width: 0.8),
                      ),
                      child: rawHistory.isEmpty
                          ? const Center(
                              child: Text(
                                'No recent entries logged today',
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(8),
                              itemCount: rawHistory.length,
                              itemBuilder: (context, idx) {
                                final logAmount = rawHistory[idx];
                                return Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '💧 Water Input Log #${idx + 1}',
                                        style: TextStyle(color: textColor, fontSize: 12),
                                      ),
                                      Text(
                                        '+$logAmount ml',
                                        style: const TextStyle(
                                          color: AppTheme.accentPurple,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.accentCoral.withOpacity(0.12),
                              foregroundColor: AppTheme.accentCoral,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: const BorderSide(color: AppTheme.accentCoral, width: 0.5),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 8),
                            ),
                            icon: const Icon(Icons.undo_rounded, size: 14),
                            label: const Text('Undo Last Entry', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            onPressed: rawHistory.isEmpty
                                ? null
                                : () async {
                                    await ref
                                        .read(dailyMetricsProvider(dateStr).notifier)
                                        .removeLastWater();
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Last hydration log removed!'),
                                        backgroundColor: AppTheme.accentCoral,
                                      ),
                                    );
                                  },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Divider(color: AppTheme.glassBorder, height: 1),
                    const SizedBox(height: 16),
                    const Text(
                      'MANUAL VALUE OVERRIDE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textSecondary,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(isDark ? 0.02 : 0.015),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: dialogBorder, width: 0.8),
                            ),
                            child: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.bold),
                              decoration: const InputDecoration(
                                suffixText: 'ml',
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.accentPurple,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onPressed: () async {
                            final val = int.tryParse(controller.text);
                            if (val != null && val >= 0) {
                              await ref
                                  .read(dailyMetricsProvider(dateStr).notifier)
                                  .setManualWater(val);
                              Navigator.pop(ctx);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Hydration manually updated!'),
                                  backgroundColor: AppTheme.accentEmerald,
                                ),
                              );
                            }
                          },
                          child: const Text('Update', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Close', style: TextStyle(color: AppTheme.textSecondary)),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
