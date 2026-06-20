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
import '../../services/firebase_service.dart';
import 'food_history_screen.dart';
import 'food_logger_dialog.dart';
import '../../models/workout_log.dart';
import 'package:go_router/go_router.dart';
import '../../services/premium_service.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  String _selectedMacro = 'Protein';
  late ScrollController _streakScrollController;
  final ScrollController _calendarScrollController = ScrollController();
  String _visibleMonthStr = '';
  String _visibleYearStr = '';

  bool get isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonthStr = DateFormat('MMM').format(now).toUpperCase();
    _visibleYearStr = DateFormat('yyyy').format(now);
    _calendarScrollController.addListener(_onCalendarScroll);

    _streakScrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_streakScrollController.hasClients) {
        _streakScrollController.jumpTo(_streakScrollController.position.maxScrollExtent);
      }
    });
  }

  void _onCalendarScroll() {
    if (!_calendarScrollController.hasClients) return;
    final offset = _calendarScrollController.offset;
    final scrolledDays = (offset / 58.0).round();
    final targetDate = DateTime.now().subtract(Duration(days: scrolledDays.clamp(0, 1000)));
    final newMonth = DateFormat('MMM').format(targetDate).toUpperCase();
    final newYear = DateFormat('yyyy').format(targetDate);
    if (newMonth != _visibleMonthStr || newYear != _visibleYearStr) {
      setState(() {
        _visibleMonthStr = newMonth;
        _visibleYearStr = newYear;
      });
    }
  }

  @override
  void dispose() {
    _calendarScrollController.removeListener(_onCalendarScroll);
    _calendarScrollController.dispose();
    _streakScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedDate = ref.watch(selectedDateProvider);
    final profile = ref.watch(profileProvider);
    final dailyStats = ref.watch(dailyMetricsProvider(selectedDate));
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final workouts = ref.watch(workoutHistoryProvider);
    final systemStatus = ref.watch(systemStatusProvider).value;

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

    // Carb and fat goals derived from profile targets
    final double carbGoal = StorageService.getCarbsGoal().toDouble();
    final double fatGoal = StorageService.getFatsGoal().toDouble();

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
          // No ambient background glows per Apple Design System (quiet aesthetic)

          // 2. Main Scrollable Container
          SafeArea(
            bottom: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 12,
                bottom: 110,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // System Status / Maintenance Banner
                  if (systemStatus != null && systemStatus['active'] == true) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: (systemStatus['type'] == 'critical'
                            ? const Color(0xFFEF4444)
                            : const Color(0xFFF59E0B)).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: (systemStatus['type'] == 'critical'
                              ? const Color(0xFFEF4444)
                              : const Color(0xFFF59E0B)).withOpacity(0.3),
                          width: 1.0,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            systemStatus['type'] == 'critical' ? '🚨' : '⚠️',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  systemStatus['message'] ?? 'We are experiencing technical issues.',
                                  style: TextStyle(
                                    color: systemStatus['type'] == 'critical'
                                        ? const Color(0xFFFCA5A5)
                                        : const Color(0xFFFDE68A),
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.2,
                                    decoration: TextDecoration.none,
                                  ),
                                ),
                                if (systemStatus['eta'] != null && systemStatus['eta'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    'Resolution ETA: ${systemStatus['eta']}',
                                    style: TextStyle(
                                      color: (systemStatus['type'] == 'critical'
                                          ? const Color(0xFFFCA5A5)
                                          : const Color(0xFFFDE68A)).withOpacity(0.7),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Top App Bar Greeting
                  _buildTopAppBar(context, workouts),
                  const SizedBox(height: 12),

                  // Weekly Calendar picker
                  _buildWeeklyCalendarBar(selectedDate, isDark),
                  const SizedBox(height: 12),

                  // Daily Goal Ring Section
                  _buildDailyGoalSummaryCard(
                    consumed: consumedCal,
                    remaining: remainingCal,
                    percent: caloriePercent,
                    waterConsumed: wConsumed,
                    waterGoal: waterGoal,
                    selectedDate: selectedDate,
                    proteinConsumed: pConsumed,
                    proteinGoal: proteinGoal,
                    carbConsumed: cConsumed,
                    carbGoal: carbGoal,
                    fatConsumed: fConsumed,
                    fatGoal: fatGoal,
                  ),
                  const SizedBox(height: 12),
                  // Quick Actions Row (Bento Style circles)
                  _buildQuickActionsRow(selectedDate),
                  const SizedBox(height: 12),

                  // Daily Streaks Section
                  _buildDailyStreakCard(workouts, isDark),
                  const SizedBox(height: 16),

                  // Daily Food Journal Section
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'FOOD JOURNAL',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.4,
                              color: AppTheme.accentCyan,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Today's Entries",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (context) => const FoodHistoryScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppTheme.accentCyan.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3), width: 1.0),
                          ),
                          child: const Text(
                            'VIEW ALL',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.accentCyan,
                              letterSpacing: 0.8,
                            ),
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

  Widget _buildTopAppBar(BuildContext context, List<WorkoutSession> workouts) {
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
                  color: isDark ? const Color(0xFF121214) : const Color(0xFFE8EBE6),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.accentCyan.withOpacity(0.3),
                    width: 2.0,
                  ),
                ),
                child: () {
                  final profilePic = ref.watch(profilePictureProvider);
                  if (profilePic != null && profilePic.isNotEmpty) {
                    if (profilePic.startsWith('http')) {
                      return ClipOval(
                        child: Image.network(
                          profilePic,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(
                              Icons.person_rounded,
                              color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                              size: 22,
                            );
                          },
                        ),
                      );
                    }
                    try {
                      String cleaned = profilePic;
                      final commaIndex = cleaned.indexOf(',');
                      if (commaIndex != -1) {
                        cleaned = cleaned.substring(commaIndex + 1);
                      }
                      cleaned = cleaned.replaceAll(RegExp(r'\s+'), '');
                      return ClipOval(
                        child: Image.memory(
                          base64Decode(cleaned),
                          fit: BoxFit.cover,
                        ),
                      );
                    } catch (e) {
                      debugPrint("Error loading profile picture memory: $e");
                    }
                  }
                  return Icon(
                    Icons.person_rounded,
                    color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                    size: 22,
                  );
                }(),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  () {
                    final hour = DateTime.now().hour;
                    if (hour < 12) {
                      return 'GOOD MORNING,';
                    } else if (hour < 17) {
                      return 'GOOD AFTERNOON,';
                    } else if (hour < 21) {
                      return 'GOOD EVENING,';
                    } else {
                      return 'GOOD NIGHT,';
                    }
                  }(),
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.0,
                    color: AppTheme.textSecondary,
                  ),
                ),
                Text(
                  () {
                    final name = FirebaseService.currentUser?.displayName;
                    if (name != null && name.trim().isNotEmpty) {
                      return name.split(' ').first;
                    }
                    return 'User';
                  }(),
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900, // Wise Sans display weight
                    color: isDark ? AppTheme.accentCyan : const Color(0xFF163300),
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
            GestureDetector(
              onTap: () {
                if (!PremiumService.hasFeatureAccess('daily_streaks')) {
                  context.push('/premium');
                  return;
                }
                final workoutsList = ref.read(workoutHistoryProvider);
                _showStreakDetailsBottomSheet(context, workoutsList);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121214) : const Color(0xFFD9FF00).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(9999), // pill shape
                  border: Border.all(
                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFD9FF00).withOpacity(0.3),
                    width: 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      '🔥',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${_calculateStreak(workouts)} ${_calculateStreak(workouts) == 1 ? "Day" : "Days"} Streak',
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF5A6B00),
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: const Icon(Icons.notifications_rounded, color: AppTheme.textSecondary, size: 24),
              onPressed: () => _showNotificationsSheet(context),
            ),
          ],
        ),
      ],
    );
  }

  void _showMonthPickerBottomSheet(BuildContext context, int year, int month, List<WorkoutSession> workouts) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    final textMutedColor = isDark ? const Color(0xFF868685) : AppTheme.textSecondary;
    final interactiveBgColor = isDark ? const Color(0xFF121214) : const Color(0xFFF5F5F5);
    final borderColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6);

    final String monthName = DateFormat('MMMM yyyy').format(DateTime(year, month));
    final int daysInMonth = DateTime(year, month + 1, 0).day;
    final today = DateTime.now();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return GlassCard(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 20),
              customBgColor: isDark ? const Color(0xFF121214) : Colors.white,
              customBorder: Border(
                top: BorderSide(
                  color: borderColor,
                  width: 1.0,
                ),
              ),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '$monthName Logs',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                          letterSpacing: -0.5,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close_rounded,
                          color: textColor,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      physics: const BouncingScrollPhysics(),
                      itemCount: daysInMonth,
                      itemBuilder: (context, index) {
                        final int day = daysInMonth - index;
                        final DateTime date = DateTime(year, month, day);
                        final String dateKey = DateFormat('yyyy-MM-dd').format(date);
                        final isFuture = date.isAfter(today);

                        if (isFuture) {
                          return const SizedBox.shrink();
                        }

                        final metrics = StorageService.getDailyMetrics(dateKey);
                        final int actLevel = _getDayActivityLevel(date, workouts);
                        
                        final int consumedCal =
                            ((metrics['breakfast_cal'] ?? 0) as num).toInt() +
                            ((metrics['lunch_cal'] ?? 0) as num).toInt() +
                            ((metrics['dinner_cal'] ?? 0) as num).toInt() +
                            ((metrics['snacks_cal'] ?? 0) as num).toInt() +
                            ((metrics['outside_food_cal'] ?? 0) as num).toInt();

                        final int waterConsumed = ((metrics['water'] ?? 0) as num).toInt();
                        final int loggedFoodCount = (metrics['logged_items'] as List?)?.length ?? 0;
                        final hasWorkout = workouts.any((w) => w.date == dateKey);

                        String summaryText = "";
                        if (consumedCal > 0 || waterConsumed > 0 || loggedFoodCount > 0 || hasWorkout) {
                          final List<String> parts = [];
                          if (consumedCal > 0) parts.add("$consumedCal kcal");
                          if (waterConsumed > 0) parts.add("${waterConsumed}ml Water");
                          if (loggedFoodCount > 0) parts.add("$loggedFoodCount foods");
                          if (hasWorkout) parts.add("🏋️ Workout");
                          summaryText = parts.join(" • ");
                        } else {
                          summaryText = "No logs recorded (Rest Day)";
                        }

                        Color cellColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6);
                        if (actLevel > 0) {
                          double opacity = 0.2;
                          if (actLevel == 2) opacity = 0.45;
                          if (actLevel == 3) opacity = 0.7;
                          if (actLevel == 4) opacity = 1.0;
                          cellColor = const Color(0xFFD9FF00).withOpacity(opacity);
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: interactiveBgColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
                              width: 1.0,
                            ),
                          ),
                          child: ListTile(
                            onTap: () {
                              Navigator.pop(context);
                              _showDayStreakDetailBottomSheet(context, date, workouts);
                            },
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            leading: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: cellColor,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.5),
                                  width: 0.5,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  "$day",
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: actLevel >= 3 ? Colors.black : textColor,
                                  ),
                                ),
                              ),
                            ),
                            title: Text(
                              DateFormat('EEEE, MMMM d').format(date),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            subtitle: Text(
                              summaryText,
                              style: TextStyle(
                                fontSize: 11,
                                color: textMutedColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            trailing: Icon(
                              Icons.chevron_right_rounded,
                              color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                              size: 20,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showStreakDetailsBottomSheet(BuildContext context, List<WorkoutSession> workouts) {
    final streak = _calculateStreak(workouts);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    final textMutedColor = isDark ? const Color(0xFF868685) : AppTheme.textSecondary;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return GlassCard(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 32),
          customBgColor: isDark ? const Color(0xFF121214) : Colors.white,
          customBorder: Border(
            top: BorderSide(
              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
              width: 1.0,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 24),

              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD9FF00).withOpacity(0.1),
                  border: Border.all(
                    color: const Color(0xFFD9FF00).withOpacity(0.3),
                    width: 2.0,
                  ),
                ),
                child: const Center(
                  child: Text(
                    '🔥',
                    style: TextStyle(fontSize: 40),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              Text(
                '$streak ${streak == 1 ? "Day" : "Days"} Streak!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 8),

              Text(
                streak == 0
                    ? 'Start your streak today! 🚀'
                    : streak == 1
                        ? 'First milestone unlocked! 🔥'
                        : streak < 7
                            ? 'Consistency is building! ⚡'
                            : 'Top 18% of users this month! 🏆',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD9FF00),
                ),
              ),
              const SizedBox(height: 24),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF121214) : const Color(0xFFF0F2EE),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
                    width: 1.0,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HOW IT WORKS',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: textMutedColor,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildRuleItem('🥗', 'Log any meal in your journal', isDark),
                    const SizedBox(height: 10),
                    _buildRuleItem('📷', 'Scan a product with Zivo Analyser', isDark),
                    const SizedBox(height: 10),
                    _buildRuleItem('🏋️', 'Complete a workout session', isDark),
                    const SizedBox(height: 10),
                    _buildRuleItem('🎯', 'Reach 70%+ of your calorie target', isDark),
                    const SizedBox(height: 16),
                    Divider(color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.08), height: 1),
                    const SizedBox(height: 12),
                    Text(
                      '💡 Completing any single task keeps your daily streak active. Completing multiple logs (e.g. workout + 3 meals) boosts your daily activity grid color to Level 4!',
                      style: TextStyle(
                        fontSize: 11,
                        color: textMutedColor,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD9FF00),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Awesome, keep it up!',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRuleItem(String emoji, String description, bool isDark) {
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            description,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: textColor,
            ),
          ),
        ),
      ],
    );
  }

  void _showDayStreakDetailBottomSheet(BuildContext context, DateTime date, List<WorkoutSession> workouts) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final metrics = StorageService.getDailyMetrics(dateStr);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    final textMutedColor = isDark ? const Color(0xFF868685) : AppTheme.textSecondary;
    final accentColor = const Color(0xFFD9FF00); // Neon Lime

    // Calorie Metrics
    final int consumedCal =
        ((metrics['breakfast_cal'] ?? 0) as num).toInt() +
        ((metrics['lunch_cal'] ?? 0) as num).toInt() +
        ((metrics['dinner_cal'] ?? 0) as num).toInt() +
        ((metrics['snacks_cal'] ?? 0) as num).toInt() +
        ((metrics['outside_food_cal'] ?? 0) as num).toInt();

    final profile = ref.read(profileProvider);
    final int calorieGoal = profile?.calorieGoal ?? 2200;
    final double waterGoal = (profile?.waterGoal ?? 3000).toDouble();
    final double proteinGoal = (profile?.proteinGoal ?? 150).toDouble();
    final double carbGoal = StorageService.getCarbsGoal().toDouble();
    final double fatGoal = StorageService.getFatsGoal().toDouble();

    // Macro Metrics
    final double proteinConsumed = (metrics['protein'] ?? 0).toDouble();
    final double carbConsumed = (metrics['carbs'] ?? 0).toDouble();
    final double fatConsumed = (metrics['fat'] ?? 0).toDouble();

    // Water Logged
    final int waterConsumed = ((metrics['water'] ?? 0) as num).toInt();

    // Logged Food list
    final List loggedItems = metrics['logged_items'] ?? [];

    // Workouts on this day
    final List<WorkoutSession> dayWorkouts = workouts.where((w) => w.date == dateStr).toList();

    // Determine shade level
    final int actLevel = _getDayActivityLevel(date, workouts);

    // Custom status design based on shade level
    String statusBadge = "REST & RECOVER 🧘";
    Color badgeBg = isDark ? const Color(0xFF121214) : const Color(0xFFF0F0F0);
    Color badgeColor = textMutedColor;
    String motivationTitle = "GROWTH HAPPENS NOW";
    String motivationHeader = "RECOVERY PROTOCOL SECURED 🧘";
    String motivationQuote = "Quality rest is where the magic happens! Your muscles are rebuilding, fibers are repairing, and your glycogen is replenishing. Drink your water and rest up! 🔋💎";

    if (actLevel == 4) {
      statusBadge = "BEAST MODE ACTIVATED ⚡";
      badgeBg = const Color(0xFFD9FF00).withOpacity(0.12);
      badgeColor = const Color(0xFFD9FF00);
      motivationTitle = "CONQUEROR OF THE DAY";
      motivationHeader = "FULL GOALS DEMOLISHED! 🏆⚡";
      motivationQuote = "YOU SHATTERED THE BARRIERS TODAY! Lion mentality. You logged your foods, crushed your training, and hit hydration targets. This is how consistency breeds champions. Do not break the chain! 🦁🔥";
    } else if (actLevel == 3) {
      statusBadge = "CRUSHING IT 💪";
      badgeBg = const Color(0xFF4ADE80).withOpacity(0.12);
      badgeColor = const Color(0xFF4ADE80);
      motivationTitle = "CONSISTENCY SECURED";
      motivationHeader = "HIGH PERFORMANCE DAY! 🏋️✨";
      motivationQuote = "ABSOLUTE POWER! You dialed in your nutrition and put in the work. You are making real, tangible progress towards your ultimate self. Sleep well, recover, and let's go again! 🦾💎";
    } else if (actLevel == 2) {
      statusBadge = "SOLID EFFORT ✅";
      badgeBg = const Color(0xFF22D3EE).withOpacity(0.12);
      badgeColor = const Color(0xFF22D3EE);
      motivationTitle = "PROGRESS SECURED";
      motivationHeader = "HABITS COMPOUNDING! 🚀⚡";
      motivationQuote = "GREAT ENERGY! You locked in your daily habits and kept the momentum alive. Remember: small daily wins compound into massive transformations. Keep stacking your score! 📈✨";
    } else if (actLevel == 1) {
      statusBadge = "HABIT BUILDER 🌱";
      badgeBg = const Color(0xFF4ADE80).withOpacity(0.12);
      badgeColor = const Color(0xFF4ADE80);
      motivationTitle = "KEEP MOVING FORWARD";
      motivationHeader = "STREAK PRESERVED! ✅🌱";
      motivationQuote = "EVERY SINGLE LOG COUNTS! You showed up for yourself today. Even on busy days, keeping the habit alive is what separates you from the rest. Tomorrow, let's step it up to a new level! 🦁🚀";
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
            child: Container(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xEC121214) : Colors.white.withOpacity(0.95),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  topRight: Radius.circular(28),
                ),
                border: Border.all(
                  color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
                  width: 1.5,
                ),
              ),
              padding: const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 32),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Slide indicator handle
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Date & Status Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('EEEE, MMM d, yyyy').format(date).toUpperCase(),
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.2,
                                  color: textMutedColor,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                motivationHeader,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: badgeColor.withOpacity(0.3), width: 1.0),
                          ),
                          child: Text(
                            statusBadge,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w900,
                              color: badgeColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // --- DETAILED HABITS BENTO GRID ---
                    
                    // 1. Calories Bento Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141618) : const Color(0xFFF9F9F9),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "CALORIE ENERGY TRACKER",
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 1.0,
                                  color: AppTheme.accentCyan,
                                ),
                              ),
                              Text(
                                "$consumedCal / $calorieGoal kcal",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w900,
                                  color: textColor,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (consumedCal / calorieGoal).clamp(0.0, 1.2),
                              minHeight: 8,
                              backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                consumedCal > calorieGoal 
                                    ? const Color(0xFFEF4444) 
                                    : const Color(0xFFD9FF00)
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            consumedCal >= calorieGoal 
                                ? "Fueled up! Calories fully stocked for muscular hypertrophy."
                                : "Remaining deficit room: ${(calorieGoal - consumedCal)} kcal left to hit target goal.",
                            style: TextStyle(
                              fontSize: 11,
                              color: textMutedColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 2. Row of Water & Food Log Counters
                    Row(
                      children: [
                        // Hydration Bento
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF141618) : const Color(0xFFF9F9F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
                                width: 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "HYDRATION",
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                    color: AppTheme.accentCyan,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Text('💧', style: TextStyle(fontSize: 20)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "$waterConsumed ml",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: textColor,
                                            ),
                                          ),
                                          Text(
                                            "Goal: ${waterGoal.toInt()}ml",
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: textMutedColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Food Logs Bento
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF141618) : const Color(0xFFF9F9F9),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
                                width: 1.0,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  "JOURNAL LOGS",
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.0,
                                    color: AppTheme.accentCyan,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Text('📝', style: TextStyle(fontSize: 20)),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "${loggedItems.length} food logs",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                              color: textColor,
                                            ),
                                          ),
                                          Text(
                                            "Items tracked",
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: textMutedColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // 3. Macronutrient detailed breakdown bento
                    if (loggedItems.isNotEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF141618) : const Color(0xFFF9F9F9),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
                            width: 1.0,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "MACRONUTRIENT RATIOS",
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: AppTheme.accentCyan,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Protein
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('🍗', style: TextStyle(fontSize: 12)),
                                        const SizedBox(width: 4),
                                        Text('Protein', style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text('${proteinConsumed.round()}g / ${proteinGoal.round()}g', style: TextStyle(fontSize: 12, color: textMutedColor, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                // Carbs
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('🍚', style: TextStyle(fontSize: 12)),
                                        const SizedBox(width: 4),
                                        Text('Carbs', style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text('${carbConsumed.round()}g / ${carbGoal.round()}g', style: TextStyle(fontSize: 12, color: textMutedColor, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                                // Fat
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text('💧', style: TextStyle(fontSize: 12)),
                                        const SizedBox(width: 4),
                                        Text('Fats', style: TextStyle(fontSize: 11, color: textColor, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text('${fatConsumed.round()}g / ${fatGoal.round()}g', style: TextStyle(fontSize: 12, color: textMutedColor, fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    if (loggedItems.isNotEmpty) const SizedBox(height: 20),

                    // 4. Detailed Workouts Breakdown Box
                    Text(
                      'WORKOUTS COMPLETED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: AppTheme.accentCyan,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (dayWorkouts.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF121214) : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Text('🧘 ', style: TextStyle(fontSize: 16)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Active Rest & Recovery Day',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Growth happens during recovery. Let muscles rebuild!',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: textMutedColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...dayWorkouts.map((workout) {
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF141618) : const Color(0xFFF9FBE7),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: accentColor.withOpacity(0.2),
                              width: 1.0,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text('🏋️ ', style: TextStyle(fontSize: 14)),
                                  Expanded(
                                    child: Text(
                                      workout.notes.isNotEmpty ? workout.notes : 'Strength Training Session',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${workout.exercises.length} exercises completed • ${(workout.durationSeconds ~/ 60)} min session duration',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: textMutedColor,
                                ),
                              ),
                              const Divider(height: 16, color: Color(0x1AFFFFFF)),
                              // Exercise level detail logs
                              ...workout.exercises.map<Widget>((ExerciseLog ex) {
                                final completedSets = ex.sets.where((ExerciseSet s) => s.isCompleted).length;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 4.0, left: 4.0),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: Color(0xFFD9FF00), size: 13),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          '${ex.name}: $completedSets set${completedSets == 1 ? '' : 's'} (${ex.sets.map((s) => '${s.weight.round()}kg x ${s.reps}').join(', ')})',
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: textColor.withOpacity(0.9),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        );
                      }).toList(),
                    const SizedBox(height: 20),

                    // 5. Detailed Foods Eaten Box
                    Text(
                      'FOODS LOGGED',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.4,
                        color: AppTheme.accentCyan,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (loggedItems.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF121214) : const Color(0xFFF5F5F5),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Text('🍽️ ', style: TextStyle(fontSize: 16)),
                            Text(
                              'No food logged on this day',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      ...loggedItems.map((item) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF121214) : const Color(0xFFF5F5F5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              () {
                                final String? customImageUrl = item['imageUrl'];
                                if (customImageUrl != null && customImageUrl.isNotEmpty) {
                                  ImageProvider? imageProvider;
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
                                      // Fallback
                                    }
                                  }
                                  if (imageProvider != null) {
                                    return Container(
                                      width: 24,
                                      height: 24,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(6),
                                        image: DecorationImage(
                                          image: imageProvider,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    );
                                  }
                                }
                                return Text(
                                  item['meal'] == 'BREAKFAST'
                                      ? '🍳 '
                                      : item['meal'] == 'LUNCH'
                                          ? '🥗 '
                                          : item['meal'] == 'DINNER'
                                              ? '🥩 '
                                              : '🍎 ',
                                  style: const TextStyle(fontSize: 14),
                                );
                              }(),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item['name'],
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'P: ${item['protein'] ?? 0}g • C: ${item['carbs'] ?? 0}g • F: ${item['fat'] ?? 0}g',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: textMutedColor,
                                      ),
                                    ),
                                    if (item['items'] != null && (item['items'] as List).isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      ...(item['items'] as List).map((bi) {
                                        final sizeVal = bi['servingSize'] != null ? (bi['servingSize'] as num).toDouble() : 1.0;
                                        final sizeStr = sizeVal % 1 == 0 ? sizeVal.toInt().toString() : sizeVal.toString();
                                        return Padding(
                                          padding: const EdgeInsets.only(left: 6.0, top: 2.0),
                                          child: Text(
                                            "• ${bi['name']} ($sizeStr ${bi['servingUnit'] ?? 'piece'}): ${bi['calories']} kcal",
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              color: textMutedColor.withOpacity(0.8),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${item['calories']} kcal',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? const Color(0xFFD9FF00) : const Color(0xFF5A6B00),
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    const SizedBox(height: 24),

                    // 6. Motivation Central Premium Banner
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141618) : const Color(0xFFF2FBE7),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: accentColor.withOpacity(0.25),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('🔥 ', style: TextStyle(fontSize: 14)),
                              Flexible(
                                child: Text(
                                  motivationTitle,
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                    color: Color(0xFFD9FF00),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Text(' 🔥', style: TextStyle(fontSize: 14)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            motivationQuote,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              height: 1.4,
                              color: isDark ? Colors.white.withOpacity(0.9) : AppTheme.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStreakDetailStatTile({
    required String icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    final textMutedColor = isDark ? const Color(0xFF868685) : AppTheme.textSecondary;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF121214) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Text(icon, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: textMutedColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: textColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCalendarBar(String selectedDate, bool isDark) {
    final now = DateTime.now();
    final parsed = DateFormat('yyyy-MM-dd').parse(selectedDate);
    final String? vMonth = _visibleMonthStr;
    final String? vYear = _visibleYearStr;
    final displayMonth = (vMonth != null && vMonth.isNotEmpty) ? vMonth : DateFormat('MMM').format(parsed).toUpperCase();
    final displayYear = (vYear != null && vYear.isNotEmpty) ? vYear : DateFormat('yyyy').format(parsed);

    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          margin: const EdgeInsets.only(right: 6),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(14), // Curvy corners
            border: Border.all(
              color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
              width: 1.0,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                displayMonth,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: AppTheme.accentCyan,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                displayYear,
                style: TextStyle(
                  fontSize: 8,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white60 : Colors.black54,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 52, // Square height
            child: ListView.builder(
              controller: _calendarScrollController,
              scrollDirection: Axis.horizontal,
              reverse: true,
              itemCount: 1000, // Virtually infinite past days
              itemBuilder: (context, index) {
                final date = now.subtract(Duration(days: index));
                final dateKey = DateFormat('yyyy-MM-dd').format(date);
                final isSelected = dateKey == selectedDate;
                final weekdayStr = DateFormat('E').format(date); // e.g. "Sun"
                final dayNumStr = DateFormat('d').format(date); // e.g. "12"

                return GestureDetector(
                  onTap: () {
                    ref.read(selectedDateProvider.notifier).state = dateKey;
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 52,
                    height: 52,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accentCyan
                          : (isDark ? const Color(0xFF121214) : AppTheme.glassBackground),
                      borderRadius: BorderRadius.circular(14), // Curvy corners
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.accentCyan
                            : (isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          weekdayStr.toUpperCase(),
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.0,
                            color: isSelected ? const Color(0xFF5A6B00) : const Color(0xFFC5C9AC),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          dayNumStr,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: isSelected ? const Color(0xFF5A6B00) : (isDark ? Colors.white : AppTheme.textPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  bool _isDayActive(DateTime date, List<WorkoutSession> workouts) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final metrics = StorageService.getDailyMetrics(dateStr);

    final profile = ref.read(profileProvider);
    final double goal = (profile?.calorieGoal ?? 2200).toDouble();

    final int consumedCal =
        ((metrics['breakfast_cal'] ?? 0) as num).toInt() +
        ((metrics['lunch_cal'] ?? 0) as num).toInt() +
        ((metrics['dinner_cal'] ?? 0) as num).toInt() +
        ((metrics['snacks_cal'] ?? 0) as num).toInt() +
        ((metrics['outside_food_cal'] ?? 0) as num).toInt();

    if (goal > 0 && consumedCal >= goal * 0.70) {
      return true;
    }

    final List loggedItems = metrics['logged_items'] ?? [];
    if (loggedItems.isNotEmpty) {
      return true;
    }

    final hasWorkout = workouts.any((WorkoutSession w) => w.date == dateStr);
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

  int _getDayActivityLevel(DateTime date, List<WorkoutSession> workouts) {
    final dateStr = DateFormat('yyyy-MM-dd').format(date);
    final metrics = StorageService.getDailyMetrics(dateStr);
    
    final int water = ((metrics['water'] ?? 0) as num).toInt();
    final List loggedItems = metrics['logged_items'] ?? [];
    final hasWorkout = workouts.any((WorkoutSession w) => w.date == dateStr);

    // Active rest day / minimal log counts as level 0
    if (water <= 250 && loggedItems.isEmpty && !hasWorkout) {
      return 0;
    }

    // Level calculation based on healthy habits progress
    if ((hasWorkout && loggedItems.length >= 3) ||
        (hasWorkout && water >= 1500) ||
        (loggedItems.length >= 3 && water >= 2000)) {
      return 4; // Max activity
    } else if (hasWorkout ||
               loggedItems.length >= 3 ||
               water >= 1500 ||
               (loggedItems.length >= 2 && water >= 1000)) {
      return 3; // High activity
    } else if (loggedItems.length >= 2 ||
               water >= 1000 ||
               (loggedItems.length >= 1 && water >= 500)) {
      return 2; // Medium activity
    } else {
      return 1; // Light activity
    }
  }

  int _calculateStreak(List<WorkoutSession> workouts) {
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

  Widget _buildDailyStreakCard(List<WorkoutSession> workouts, bool isDark) {
    final streak = _calculateStreak(workouts);
    final cardBgColor = isDark ? const Color(0xFF121214) : AppTheme.glassBackground;
    final borderColor = isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    final textMutedColor = isDark ? const Color(0xFF868685) : AppTheme.textSecondary;
    final interactiveBgColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6);

    final today = DateTime.now();
    final bool isTodayActive = _isDayActive(today, workouts);

    // Start date is exactly 364 days ago adjusted to a Sunday.
    final DateTime gridStart = today.subtract(Duration(days: 364 + today.weekday % 7));

    // Zoomed sizes: cell size 12x12, margins: 2.0 horizontal/vertical.
    // So column spacing is 12 + 4.0 = 16.0. Row height is 12 + 4.0 = 16.0.
    const double cellWidth = 12.0;
    const double cellHeightVal = 12.0;
    const double cellMarginY = 2.0;
    const double cellPaddingX = 2.0;

    const double colSpacing = cellWidth + (cellPaddingX * 2); // 16.0
    const double cellHeight = cellHeightVal + (cellMarginY * 2); // 16.0

    // Construct years headers
    final List<Widget> yearLabels = [];
    int? lastYear;

    for (int col = 0; col < 53; col++) {
      final sundayOfThisWeek = gridStart.add(Duration(days: col * 7));
      final yearVal = sundayOfThisWeek.year;
      
      if (col == 0 || yearVal != lastYear) {
        yearLabels.add(
          Container(
            width: colSpacing * 8, // Scale with colSpacing
            alignment: Alignment.centerLeft,
            child: Text(
              '$yearVal',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w900,
                color: textMutedColor,
              ),
            ),
          ),
        );
        lastYear = yearVal;
        col += 7;
      } else {
        yearLabels.add(
          const SizedBox(width: colSpacing),
        );
      }
    }

    // Group columns by month for invisible monthly button hit test grids and aligned headers
    final List<Map<String, dynamic>> monthGroups = [];
    for (int colIndex = 0; colIndex < 53; colIndex++) {
      final DateTime sundayOfThisWeek = gridStart.add(Duration(days: colIndex * 7));
      final int y = sundayOfThisWeek.year;
      final int m = sundayOfThisWeek.month;
      
      if (monthGroups.isEmpty || monthGroups.last['year'] != y || monthGroups.last['month'] != m) {
        monthGroups.add({
          'year': y,
          'month': m,
          'columns': [colIndex],
        });
      } else {
        (monthGroups.last['columns'] as List<int>).add(colIndex);
      }
    }

    // Construct months headers styled in rectangular boxes aligned perfectly to columns
    final List<Widget> monthLabels = [];
    for (final group in monthGroups) {
      final int y = group['year'];
      final int m = group['month'];
      final List<int> cols = group['columns'];
      final String monthStr = DateFormat('MMM').format(DateTime(y, m));
      final double monthWidth = cols.length * colSpacing;

      monthLabels.add(
        GestureDetector(
          onTap: () => _showMonthPickerBottomSheet(context, y, m, workouts),
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: monthWidth,
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            alignment: Alignment.center,
            child: OverflowBox(
              minWidth: 0,
              maxWidth: double.infinity,
              minHeight: 0,
              maxHeight: double.infinity,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 3.0),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: AppTheme.accentCyan.withOpacity(0.35),
                    width: 1.0,
                  ),
                ),
                child: Center(
                  widthFactor: 1.0,
                  heightFactor: 1.0,
                  child: Text(
                    monthStr,
                    style: const TextStyle(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.accentCyan,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Horizontal grid scroll container with pinch-to-zoom support and monthly hit test button blocks
    return GestureDetector(
      onTap: () {
        if (!PremiumService.hasFeatureAccess('daily_streaks')) {
          context.push('/premium');
          return;
        }
        _showStreakDetailsBottomSheet(context, workouts);
      },
      child: GlassCard(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        borderRadius: BorderRadius.circular(24),
        customBgColor: cardBgColor,
        customBorder: Border.all(color: borderColor, width: 1.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      'Daily Streaks',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: textMutedColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '(Tap month to view list)',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentCyan,
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    const Text(
                      '🔥 ',
                      style: TextStyle(fontSize: 12),
                    ),
                    Text(
                      '$streak ${streak == 1 ? "Day" : "Days"}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFD9FF00) : const Color(0xFF5A6B00),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Horizontal grid scroll container with pinch-to-zoom support and monthly hit test button blocks
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Weekday labels Mon, Wed, Fri aligned exactly to cell centers
                Padding(
                  padding: const EdgeInsets.only(right: 6.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Exact height matching Year Row (12) + Spacing (2) + Month Row (20) + Spacing (4) = 38
                      const SizedBox(height: 38),

                      // Aligned cells scaled dynamically with cellHeight (Cyan/Yellow color to match Month names)
                      Container(
                        height: cellHeight,
                        alignment: Alignment.centerLeft,
                        child: const Text('Sun', style: TextStyle(fontSize: 8, color: AppTheme.accentCyan, fontWeight: FontWeight.w800)),
                      ),
                      SizedBox(height: cellHeight), // Row 1 (Mon)
                      Container(
                        height: cellHeight,
                        alignment: Alignment.centerLeft,
                        child: const Text('Tue', style: TextStyle(fontSize: 8, color: AppTheme.accentCyan, fontWeight: FontWeight.w800)),
                      ),
                      SizedBox(height: cellHeight), // Row 3 (Wed)
                      Container(
                        height: cellHeight,
                        alignment: Alignment.centerLeft,
                        child: const Text('Thu', style: TextStyle(fontSize: 8, color: AppTheme.accentCyan, fontWeight: FontWeight.w800)),
                      ),
                      SizedBox(height: cellHeight), // Row 5 (Fri)
                      Container(
                        height: cellHeight,
                        alignment: Alignment.centerLeft,
                        child: const Text('Sat', style: TextStyle(fontSize: 8, color: AppTheme.accentCyan, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                ),

                // The scrolling grid itself
                Expanded(
                  child: SingleChildScrollView(
                    controller: _streakScrollController,
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Year Names Row
                        SizedBox(
                          height: 12,
                          child: Row(
                            children: yearLabels,
                          ),
                        ),
                        const SizedBox(height: 2),
                        // Month Names Row
                        SizedBox(
                          height: 20,
                          child: Row(
                            children: monthLabels,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Weeks grid columns grouped by month as clickable sections
                        Row(
                          children: monthGroups.map((group) {
                            final int y = group['year'];
                            final int m = group['month'];
                            final List<int> cols = group['columns'];

                            return GestureDetector(
                              onTap: () {
                                if (!PremiumService.hasFeatureAccess('daily_streaks')) {
                                  context.push('/premium');
                                  return;
                                }
                                _showMonthPickerBottomSheet(context, y, m, workouts);
                              },
                              behavior: HitTestBehavior.opaque,
                              child: Row(
                                children: cols.map((colIndex) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 2.0),
                                    child: Column(
                                      children: List.generate(7, (rowIndex) {
                                        final DateTime date = gridStart.add(Duration(days: colIndex * 7 + rowIndex));
                                        final isFuture = date.isAfter(today);
                                        final int actLevel = isFuture ? 0 : _getDayActivityLevel(date, workouts);
                                        
                                        Color cellColor = interactiveBgColor;
                                        if (!isFuture && actLevel > 0) {
                                          double opacity = 0.2;
                                          if (actLevel == 2) opacity = 0.45;
                                          if (actLevel == 3) opacity = 0.7;
                                          if (actLevel == 4) opacity = 1.0;
                                          cellColor = const Color(0xFFD9FF00).withOpacity(opacity);
                                        } else if (isFuture) {
                                          cellColor = Colors.transparent;
                                        }

                                        return Container(
                                          width: cellWidth,
                                          height: cellHeightVal,
                                          margin: const EdgeInsets.symmetric(vertical: cellMarginY),
                                          decoration: BoxDecoration(
                                            color: cellColor,
                                            borderRadius: BorderRadius.circular(2.5),
                                            border: isFuture
                                                ? null
                                                : Border.all(
                                                    color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.5),
                                                    width: 0.5,
                                                  ),
                                          ),
                                        );
                                      }),
                                    ),
                                  );
                                }).toList(),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            // Footer / Legend Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Log food, water or workouts daily to stack your score',
                    style: TextStyle(
                      fontSize: 9,
                      color: textMutedColor,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Less ', style: TextStyle(fontSize: 9, color: textMutedColor)),
                    _buildLegendCell(interactiveBgColor, isDark),
                    _buildLegendCell(const Color(0xFFD9FF00).withOpacity(0.2), isDark),
                    _buildLegendCell(const Color(0xFFD9FF00).withOpacity(0.45), isDark),
                    _buildLegendCell(const Color(0xFFD9FF00).withOpacity(0.7), isDark),
                    _buildLegendCell(const Color(0xFFD9FF00), isDark),
                    Text(' More', style: TextStyle(fontSize: 9, color: textMutedColor)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Motivation Banner Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF151811) : const Color(0xFFF9FBE7), // Subtle neon tint background
                borderRadius: BorderRadius.circular(12), // clean look inside circular(24) card
                border: Border.all(
                  color: isDark ? const Color(0xFF272C15) : const Color(0xFFD9FF00).withOpacity(0.3),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    '💡 ',
                    style: TextStyle(fontSize: 16),
                  ),
                  Expanded(
                    child: Text(
                      !isTodayActive
                          ? "Keep your streak alive today by logging one meal."
                          : streak == 1
                              ? "You started your streak today! Keep the momentum going! 🚀"
                              : streak == 2
                                  ? "2-day streak! You are building consistency. 🔥"
                                  : streak == 3
                                      ? "3-day streak! Consistency is the key to progress. ⚡"
                                      : streak < 7
                                          ? "Looking strong! $streak-day consistency streak. 🌟"
                                          : "You're in the top 18% of users this month. 🔥 Keep it up!",
                      style: TextStyle(
                        fontSize: 12,
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
    );
  }

  Widget _buildLegendCell(Color color, bool isDark) {
    return Container(
      width: 11,
      height: 11,
      margin: const EdgeInsets.symmetric(horizontal: 1.5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(2.0),
        border: Border.all(
          color: isDark ? Colors.black.withOpacity(0.3) : Colors.white.withOpacity(0.5),
          width: 0.5,
        ),
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
    required double proteinConsumed,
    required double proteinGoal,
    required double carbConsumed,
    required double carbGoal,
    required double fatConsumed,
    required double fatGoal,
  }) {
    final calorieLeftText = remaining >= 0 ? '$remaining' : '${remaining.abs()}';
    final calorieLabel = remaining >= 0 ? 'KCAL REMAINING' : 'KCAL SURPLUS';
    final calorieColor = remaining >= 0 ? AppTheme.accentCyan : AppTheme.accentCoral;
    final double waterPercent = (waterConsumed / waterGoal).clamp(0.0, 1.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBgColor = isDark ? const Color(0xFF121214) : AppTheme.glassBackground;
    final interactiveBgColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6);
    final borderColor = isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    final textMutedColor = isDark ? const Color(0xFF868685) : AppTheme.textSecondary;

    final parsedDate = DateFormat('yyyy-MM-dd').parse(selectedDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isDayEnded = parsedDate.isBefore(today);

    return GlassCard(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      borderRadius: BorderRadius.circular(24),
      customBgColor: cardBgColor,
      customBorder: Border.all(color: borderColor, width: 1.0),
      child: Column(
        children: [
          // Row 1: Header Goal Text & Edit Action
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Daily Goal: ${consumed + remaining}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              if (!isDayEnded)
                GestureDetector(
                  onTap: () => _showEditDailyGoalDialog(context, selectedDate),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentCyan,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Calories Ring & Hydration
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left side - Circular percent indicator
              CircularPercentIndicator(
                radius: 50.0,
                lineWidth: 9.0,
                percent: percent,
                animation: true,
                animationDuration: 800,
                curve: Curves.easeInOutQuad,
                circularStrokeCap: CircularStrokeCap.round,
                backgroundColor: interactiveBgColor,
                progressColor: calorieColor,
                center: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      calorieLeftText,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: calorieColor,
                        letterSpacing: -0.5,
                      ),
                    ),
                    Text(
                      calorieLabel,
                      style: const TextStyle(
                        fontSize: 6.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.2,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),

              // Right side - Hydration details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
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
                                    color: Colors.blueAccent,
                                    size: 13,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Hydration',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: textColor,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                '${(waterPercent * 100).round()}%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentCyan,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$waterConsumed ml / ${waterGoal.toInt()} ml',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w900,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 6),

                          // Hydration progress bar
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              height: 4,
                              width: double.infinity,
                              color: interactiveBgColor,
                              child: Stack(
                                children: [
                                  FractionallySizedBox(
                                    alignment: Alignment.centerLeft,
                                    widthFactor: waterPercent,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                        color: AppTheme.accentCyan,
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
                              if (isDayEnded) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("This day has ended. You cannot log water."),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              await ref
                                  .read(dailyMetricsProvider(selectedDate).notifier)
                                  .addWater(250);
                              showWebNotification(
                                '💧 Hydration Logged!',
                                'Logged 250ml of clean drinking water. Total: ${waterConsumed + 250}ml.',
                              );
                            },
                            child: Container(
                              height: 28,
                              decoration: BoxDecoration(
                                color: interactiveBgColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add, size: 10, color: textColor),
                                    const SizedBox(width: 2),
                                    Text(
                                      '250 ml',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              if (isDayEnded) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text("This day has ended. You cannot log water."),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                                return;
                              }
                              await ref
                                  .read(dailyMetricsProvider(selectedDate).notifier)
                                  .addWater(500);
                              showWebNotification(
                                '💧 Hydration Logged!',
                                'Logged 500ml of clean drinking water. Total: ${waterConsumed + 500}ml.',
                              );
                            },
                            child: Container(
                              height: 28,
                              decoration: BoxDecoration(
                                color: interactiveBgColor,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add, size: 10, color: textColor),
                                    const SizedBox(width: 2),
                                    Text(
                                      '500 ml',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
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
          
          // Divider
          Container(
            height: 1.0,
            margin: const EdgeInsets.symmetric(vertical: 12),
            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
          ),

          // Row 3: Macro Rings
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Expanded(
                child: _buildMacroProgressRing(
                  label: 'Protein',
                  value: '${proteinConsumed.round()}g/${proteinGoal.round()}g',
                  percent: (proteinConsumed / proteinGoal).clamp(0.0, 1.0),
                  color: const Color(0xFF22D3EE),
                  centerWidget: const Text(
                    '🍗',
                    style: TextStyle(fontSize: 13),
                  ),
                  isDark: isDark,
                ),
              ),
              Expanded(
                child: _buildMacroProgressRing(
                  label: 'Carbs',
                  value: '${carbConsumed.round()}g/${carbGoal.round()}g',
                  percent: (carbConsumed / carbGoal).clamp(0.0, 1.0),
                  color: const Color(0xFF4ADE80),
                  centerWidget: const Text(
                    '🍚',
                    style: TextStyle(fontSize: 13),
                  ),
                  isDark: isDark,
                ),
              ),
              Expanded(
                child: _buildMacroProgressRing(
                  label: 'Fats',
                  value: '${fatConsumed.round()}g/${fatGoal.round()}g',
                  percent: (fatConsumed / fatGoal).clamp(0.0, 1.0),
                  color: const Color(0xFFF87171),
                  centerWidget: const Text(
                    '🥑',
                    style: TextStyle(fontSize: 13),
                  ),
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMacroProgressRing({
    required String label,
    required String value,
    required double percent,
    required Color color,
    required Widget centerWidget,
    required bool isDark,
  }) {
    return Column(
      children: [
        CircularPercentIndicator(
          radius: 22.0,
          lineWidth: 5.0,
          percent: percent,
          animation: true,
          animationDuration: 800,
          curve: Curves.easeInOutQuad,
          circularStrokeCap: CircularStrokeCap.round,
          backgroundColor: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
          progressColor: color,
          center: centerWidget,
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.0,
            color: Colors.white,
          ),
        ),
      ],
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
          borderRadius: BorderRadius.circular(24), // rounded.xl (24px)
          border: Border.all(
            color: isActive ? AppTheme.accentCyan : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF323530) : AppTheme.glassBorder),
            width: 1.5,
          ),
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
                color: const Color(0xFF0E0F0C).withOpacity(0.75), // Near-black solid translucent overlay
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
    final parsedDate = DateFormat('yyyy-MM-dd').parse(selectedDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isDayEnded = parsedDate.isBefore(today);

    return SizedBox(
      height: 80,
      child: Row(
        children: [
          Expanded(
            child: _buildQuickActionButton(
              label: 'Add Meal',
              icon: Icons.restaurant_rounded,
              onTap: () {
                if (isDayEnded) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("This day has ended. You cannot log new meals."),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }
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
              label: 'Zivo analyser',
              icon: Icons.center_focus_strong_rounded,
              onTap: () {
                if (!PremiumService.hasFeatureAccess('zivo_analyser')) {
                  context.push('/premium');
                  return;
                }
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
              onTap: () {
                ref.read(activeTabProvider.notifier).state = 1; // Go to Workouts
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF121214) : AppTheme.glassBackground;
    final innerBgColor = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6);
    final borderColor = isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    const Color limeGreen = Color(0xFFD9FF00);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: cardBgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.0),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: innerBgColor,
              ),
              child: Center(
                child: Icon(
                  icon,
                  color: limeGreen,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
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
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.15)
                  : Colors.black.withOpacity(0.1),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF141618) : AppTheme.glassBackground;
    final borderColor = isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    final textMutedColor = isDark ? const Color(0xFF868685) : AppTheme.textSecondary;

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
          margin: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTap: () => _showFoodDetailsDialog(context, Map<String, dynamic>.from(item)),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardBgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: borderColor, width: 1.0),
              ),
              child: Row(
                children: [
                  // Rounded Rectangular Image Thumbnail
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor, width: 1.0),
                      image: DecorationImage(
                        image: imageProvider,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Title details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark ? const Color(0xFF3A3A3C) : AppTheme.glassBorder,
                              width: 1.0,
                            ),
                          ),
                          child: Text(
                            '$meal • $time'.toUpperCase(),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                            ),
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
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: textColor,
                        ),
                      ),
                      Text(
                        'KCAL',
                        style: TextStyle(
                          fontSize: 8,
                          color: textMutedColor,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
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
    final selectedDate = ref.read(selectedDateProvider);
    final parsedDate = DateFormat('yyyy-MM-dd').parse(selectedDate);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isDayEnded = parsedDate.isBefore(today);

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
    bool isEditing = isDayEnded ? false : startInEditMode;

    final String? imageUrl = item['imageUrl'];
    final bool hasRealImage = imageUrl != null &&
        imageUrl.isNotEmpty &&
        !imageUrl.contains('aida-public') &&
        !imageUrl.contains('photo-1546069901-ba9599a7e63c');

    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      enableDrag: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Widget buildMiniMacroIndicator(String label, String value, Color color) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "$label:",
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              );
            }

            final categories = [
              {'name': 'Breakfast', 'key': 'breakfast_cal', 'icon': Icons.egg_rounded},
              {'name': 'Lunch', 'key': 'lunch_cal', 'icon': Icons.restaurant_rounded},
              {'name': 'Dinner', 'key': 'dinner_cal', 'icon': Icons.soup_kitchen_rounded},
              {'name': 'Snacks', 'key': 'snacks_cal', 'icon': Icons.bakery_dining_rounded},
              {'name': 'Eating Out', 'key': 'outside_food_cal', 'icon': Icons.delivery_dining_rounded},
            ];

            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.85,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0E0F0C) : Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      border: Border(
                        top: BorderSide(
                          color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
                          width: 1.0,
                        ),
                      ),
                    ),
                    padding: const EdgeInsets.only(left: 24, right: 24, top: 16, bottom: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        // Fixed Header Row: Close Button & Category
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            if (!isEditing)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.accentCyan.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppTheme.accentCyan.withOpacity(0.3),
                                    width: 1.0,
                                  ),
                                ),
                                child: Text(
                                  selectedMealKey == 'outside_food_cal'
                                      ? 'EATING OUT'
                                      : selectedMealKey.replaceAll('_cal', '').replaceAll('_', ' ').toUpperCase(),
                                  style: const TextStyle(
                                    color: AppTheme.accentCyan,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 9,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              )
                            else
                              const Text(
                                'EDIT ENTRY',
                                style: TextStyle(
                                  color: AppTheme.accentCyan,
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

                        // Scrollable middle details section
                        Flexible(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            selectedMealKey = cat['key'] as String;
                                          });
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(milliseconds: 200),
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                          decoration: BoxDecoration(
                                            color: isSelected
                                                ? AppTheme.accentCyan
                                                : Colors.white.withOpacity(0.03),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isSelected
                                                  ? AppTheme.accentCyan
                                                  : Colors.white.withOpacity(0.08),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Row(
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
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                  const SizedBox(height: 16),
                                ],

                                // Meal Name
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
                                      fillColor: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppTheme.accentCyan, width: 1.5),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 8),

                                // Time indicator row
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

                                if (hasRealImage) ...[
                                  const SizedBox(height: 16),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: () {
                                      final imgStr = imageUrl;
                                      Widget? imageWidget;
                                      if (imgStr.startsWith('http')) {
                                        imageWidget = Image.network(
                                          imgStr,
                                          fit: BoxFit.cover,
                                          height: 160,
                                          width: double.infinity,
                                          errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                        );
                                      } else {
                                        try {
                                          String cleaned = imgStr;
                                          final commaIndex = cleaned.indexOf(',');
                                          if (commaIndex != -1) {
                                            cleaned = cleaned.substring(commaIndex + 1);
                                          }
                                          cleaned = cleaned.replaceAll(RegExp(r'\s+'), '');
                                          imageWidget = Image.memory(
                                            base64Decode(cleaned),
                                            fit: BoxFit.cover,
                                            height: 160,
                                            width: double.infinity,
                                            errorBuilder: (context, error, stackTrace) => const SizedBox.shrink(),
                                          );
                                        } catch (e) {
                                          imageWidget = const SizedBox.shrink();
                                        }
                                      }
                                      return imageWidget;
                                    }(),
                                  ),
                                ],
                                const SizedBox(height: 20),

                                // Calories field styled like 3rd screenshot
                                if (!isEditing)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Padding(
                                        padding: EdgeInsets.only(left: 4, bottom: 6),
                                        child: Text(
                                          "Calories",
                                          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Container(
                                        width: double.infinity,
                                        height: 52,
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        decoration: BoxDecoration(
                                          color: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(
                                            color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
                                            width: 1.0,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Row(
                                              children: [
                                                const Text('🔥', style: TextStyle(fontSize: 20)),
                                                const SizedBox(width: 12),
                                                Text(
                                                  calController.text,
                                                  style: TextStyle(
                                                    color: isDark ? Colors.white : Colors.black,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              "kcal",
                                              style: TextStyle(
                                                color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
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
                                      fillColor: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                      suffixText: ' kcal',
                                      suffixStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppTheme.accentCyan, width: 1.5),
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 12),

                                // Macros Splits styled like 3rd screenshot
                                if (!isEditing) ...[
                                  const Padding(
                                    padding: EdgeInsets.only(left: 4, bottom: 8),
                                    child: Text(
                                      "MACRONUTRIENTS",
                                      style: TextStyle(color: AppTheme.textSecondary, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Padding(
                                              padding: EdgeInsets.only(left: 4, bottom: 6),
                                              child: Text(
                                                "Protein",
                                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            Container(
                                              height: 48,
                                              padding: const EdgeInsets.symmetric(horizontal: 10),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Text('🍗', style: TextStyle(fontSize: 16)),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        proteinController.text,
                                                        style: TextStyle(
                                                          color: isDark ? Colors.white : Colors.black,
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    "g",
                                                    style: TextStyle(
                                                      color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Padding(
                                              padding: EdgeInsets.only(left: 4, bottom: 6),
                                              child: Text(
                                                "Carbs",
                                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            Container(
                                              height: 48,
                                              padding: const EdgeInsets.symmetric(horizontal: 10),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Text('🍚', style: TextStyle(fontSize: 16)),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        carbsController.text,
                                                        style: TextStyle(
                                                          color: isDark ? Colors.white : Colors.black,
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    "g",
                                                    style: TextStyle(
                                                      color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Padding(
                                              padding: EdgeInsets.only(left: 4, bottom: 6),
                                              child: Text(
                                                "Fat",
                                                style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                                              ),
                                            ),
                                            Container(
                                              height: 48,
                                              padding: const EdgeInsets.symmetric(horizontal: 10),
                                              decoration: BoxDecoration(
                                                color: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
                                                  width: 1.0,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      const Text('🥑', style: TextStyle(fontSize: 16)),
                                                      const SizedBox(width: 6),
                                                      Text(
                                                        fatController.text,
                                                        style: TextStyle(
                                                          color: isDark ? Colors.white : Colors.black,
                                                          fontWeight: FontWeight.w600,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Text(
                                                    "g",
                                                    style: TextStyle(
                                                      color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
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
                                ]
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

                                if (!isEditing && item['items'] != null && (item['items'] as List).isNotEmpty) ...[
                                  const SizedBox(height: 18),
                                  const Text(
                                    'MEAL BREAKDOWN',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 1.0,
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isDark ? const Color(0xFF0C0D0B) : Colors.black.withOpacity(0.01),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark ? const Color(0xFF232521) : AppTheme.glassBorder,
                                        width: 1.0,
                                      ),
                                    ),
                                    child: ListView.separated(
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      itemCount: (item['items'] as List).length,
                                      separatorBuilder: (context, index) => Divider(
                                        color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.04),
                                        height: 12,
                                      ),
                                      itemBuilder: (context, index) {
                                        final rawItem = (item['items'] as List)[index];
                                        final name = rawItem['name'] ?? rawItem['foodName'] ?? 'Ingredient';
                                        final sizeVal = rawItem['servingSize'] != null ? (rawItem['servingSize'] as num).toDouble() : 1.0;
                                        final sizeStr = sizeVal % 1 == 0 ? sizeVal.toInt().toString() : sizeVal.toString();
                                        final unit = rawItem['servingUnit'] ?? 'piece';
                                        final cal = rawItem['calories'] ?? 0;
                                        final prot = rawItem['protein'] ?? 0;
                                        final carb = rawItem['carbs'] ?? 0;
                                        final fat = rawItem['fat'] ?? 0;
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: AppTheme.accentCyan,
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Text(
                                                          name,
                                                          style: TextStyle(
                                                            color: isDark ? Colors.white : AppTheme.textPrimary,
                                                            fontSize: 13,
                                                            fontWeight: FontWeight.bold,
                                                            letterSpacing: -0.2,
                                                          ),
                                                        ),
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: AppTheme.accentCyan.withOpacity(0.08),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            "$sizeStr $unit",
                                                            style: const TextStyle(
                                                              color: AppTheme.accentCyan,
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w800,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Row(
                                                      children: [
                                                        Text(
                                                          "$cal kcal",
                                                          style: TextStyle(
                                                            color: isDark ? Colors.white70 : Colors.black87,
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w800,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        Container(
                                                          width: 3,
                                                          height: 3,
                                                          decoration: BoxDecoration(
                                                            shape: BoxShape.circle,
                                                            color: isDark ? Colors.white24 : Colors.black12,
                                                          ),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        buildMiniMacroIndicator('P', '${prot}g', AppTheme.accentOrange),
                                                        const SizedBox(width: 8),
                                                        buildMiniMacroIndicator('C', '${carb}g', AppTheme.accentCyan),
                                                        const SizedBox(width: 8),
                                                        buildMiniMacroIndicator('F', '${fat}g', AppTheme.accentCoral),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Buttons section
                        if (isDayEnded)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E2124) : const Color(0xFFF5F7F4),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.lock_outline_rounded, color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  "Logs are locked for ended days",
                                  style: TextStyle(
                                    color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else if (!isEditing)
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
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isDark ? AppTheme.accentCoral.withOpacity(0.06) : Colors.red.withOpacity(0.03),
                                      borderRadius: BorderRadius.circular(24),
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
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: AppTheme.accentCyan,
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppTheme.accentCyan.withOpacity(0.2),
                                          blurRadius: 10,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Center(
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.edit_rounded, color: Colors.black, size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            "Edit Entry",
                                            style: TextStyle(
                                              color: Colors.black,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w900,
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
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.03),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
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
                                    height: 48,
                                    decoration: BoxDecoration(
                                      gradient: AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(24),
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
                                          fontWeight: FontWeight.w900,
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

  Widget _buildDetailMacroCard(String label, String val, Color col, String emoji) {
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
          Text(emoji, style: const TextStyle(fontSize: 16)),
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

                          _buildDialogSectionCard(
                            title: 'Calories by Category',
                            isDark: isDark,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: _buildEditField("Breakfast", breakfastController, isDark, Icons.wb_twilight_rounded, "kcal")),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildEditField("Lunch", lunchController, isDark, Icons.wb_sunny_rounded, "kcal")),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(child: _buildEditField("Dinner", dinnerController, isDark, Icons.nights_stay_rounded, "kcal")),
                                  const SizedBox(width: 12),
                                  Expanded(child: _buildEditField("Snacks", snacksController, isDark, Icons.cookie_rounded, "kcal")),
                                ],
                              ),
                              const SizedBox(height: 12),
                              _buildEditField("Eating Out", outsideFoodController, isDark, Icons.restaurant_rounded, "kcal"),
                            ],
                          ),

                          _buildDialogSectionCard(
                            title: 'Macronutrients',
                            isDark: isDark,
                            children: [
                              Row(
                                children: [
                                  Expanded(child: _buildEditField("Protein", proteinController, isDark, Icons.bolt_rounded, "g")),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildEditField("Carbs", carbsController, isDark, Icons.grain_rounded, "g")),
                                  const SizedBox(width: 8),
                                  Expanded(child: _buildEditField("Fat", fatController, isDark, Icons.opacity_rounded, "g")),
                                ],
                              ),
                            ],
                          ),

                          _buildDialogSectionCard(
                            title: 'Hydration',
                            isDark: isDark,
                            children: [
                              _buildEditField("Water Intake", waterController, isDark, Icons.water_drop_rounded, "ml"),
                            ],
                          ),

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
                                  color: isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.02),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.06),
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
                                        color: isDark ? AppTheme.accentCyan : const Color(0xFF5A6B00),
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
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : AppTheme.textPrimary,
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
                                      icon: Icon(Icons.edit_rounded, color: isDark ? AppTheme.accentCyan : const Color(0xFF5A6B00), size: 16),
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
                                color: AppTheme.accentCyan,
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

  Widget _buildDialogSectionCard({required String title, required List<Widget> children, required bool isDark}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111315) : const Color(0xFFF5F7F4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1E2124) : const Color(0xFFE8EBE6),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.0,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, bool isDark, IconData icon, String suffix) {
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
            fillColor: isDark ? const Color(0xFF16181A) : Colors.white,
            prefixIcon: Icon(icon, color: isDark ? AppTheme.accentCyan : const Color(0xFF5A6B00), size: 16),
            suffixText: suffix,
            suffixStyle: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF2C2C2E) : Colors.black.withOpacity(0.1),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? const Color(0xFF2C2C2E) : Colors.black.withOpacity(0.1),
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
              if (!PremiumService.canPerformAiScan()) {
                if (ctx.mounted) {
                  setState(() {
                    isScanning = false;
                  });
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(
                      content: Text(PremiumService.isPremiumNotifier.value
                          ? "Daily limit of 50 AI scans reached to prevent abuse. Try again tomorrow!"
                          : "Trial daily limit of 20 AI scans reached. Upgrade to Zivofit Premium for more!"),
                      backgroundColor: AppTheme.accentCoral,
                    ),
                  );
                }
                return;
              }
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
                await PremiumService.trackAiScanConsumed();
              } catch (e) {
                debugPrint("Zivo Nutrient Ingestion pipeline failed: $e");
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
                  color: isDark ? const Color(0xFF1C1E1B) : Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  border: Border.all(
                    color: isDark ? const Color(0xFF323530) : const Color(0xFFEADBFF),
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
                      Text(
                        'Zivo Nutrient Logger',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
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
                                    color: isDark ? const Color(0xFF0E0F0C) : AppTheme.obsidianBackground,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: isDark ? const Color(0xFF323530) : AppTheme.glassBorder, width: 1.0),
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
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.bold,
                                                      color: isDark ? Colors.white : AppTheme.textPrimary,
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
                        isDark: isDark,
                        isText: true,
                      ),
                      const SizedBox(height: 12),

                      _buildModalTextField(
                        caloriesController,
                        'Calories',
                        'kcal',
                        Icons.bolt_rounded,
                        AppTheme.accentCyan,
                        isDark: isDark,
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
                              isDark: isDark,
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
                              isDark: isDark,
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
                              isDark: isDark,
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
    bool isDark = false,
    bool isText = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0E0F0C) : AppTheme.obsidianBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? const Color(0xFF323530) : AppTheme.glassBorder, width: 1.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: TextField(
        controller: ctrl,
        keyboardType: isText ? TextInputType.text : TextInputType.number,
        style: TextStyle(
          color: isDark ? Colors.white : AppTheme.textPrimary,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          icon: Icon(icon, color: color, size: 18),
          labelText: label,
          labelStyle: TextStyle(
            color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
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

            final isDark = Theme.of(context).brightness == Brightness.dark;
            final sheetBg = isDark ? const Color(0xFF0E0F0C) : AppTheme.obsidianBackground;
            final glassBg = isDark ? const Color(0xFF1C1E1B) : AppTheme.glassBackground;
            final borderColor = isDark ? const Color(0xFF323530) : AppTheme.glassBorder;
            final textColor = isDark ? Colors.white : AppTheme.textPrimary;

            return Container(
              height: MediaQuery.of(sheetContext).size.height * 0.75,
              decoration: BoxDecoration(
                color: sheetBg,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(30),
                  topRight: Radius.circular(30),
                ),
                border: Border(
                  top: BorderSide(color: borderColor, width: 1.5),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: sheetBg,
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
                          Text(
                            'Notifications & Alerts',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: textColor,
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
                                icon: Icon(Icons.close_rounded, color: textColor),
                                onPressed: () => Navigator.pop(sheetContext),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // List
                      Expanded(
                        child: (displayAura.isEmpty && displaySystem.isEmpty)
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.notifications_off_rounded,
                                      color: textColor.withOpacity(0.15),
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
                                        'ZIVO AI HEALTH INSIGHTS',
                                        style: TextStyle(
                                          color: Color(0xFFD9FF00), // Lime Green color
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ),
                                    ...displayAura.map((notif) {
                                      IconData icon = Icons.lightbulb_rounded;
                                      Color color = AppTheme.accentCyan; // Replaced accentOrange fallback with Cyan

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
                                          color: glassBg,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(color: borderColor, width: 1),
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
                                                            style: TextStyle(
                                                              fontWeight: FontWeight.bold,
                                                              fontSize: 14,
                                                              color: textColor,
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
                                                          style: TextStyle(
                                                            fontWeight: FontWeight.bold,
                                                            fontSize: 14,
                                                            color: textColor,
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
    final parsedDate = DateFormat('yyyy-MM-dd').parse(dateStr);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final isDayEnded = parsedDate.isBefore(today);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF1C1E1B) : Colors.white;
    final dialogBorder = isDark ? const Color(0xFF323530) : const Color(0xFFEADBFF);
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
                    if (isDayEnded)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E2124) : const Color(0xFFF5F7F4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.lock_outline_rounded, color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary, size: 14),
                            const SizedBox(width: 8),
                            Text(
                              "Logs are locked for ended days",
                              style: TextStyle(
                                color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                            onPressed: (isDayEnded || rawHistory.isEmpty)
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
                              enabled: !isDayEnded,
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
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          ),
                          onPressed: isDayEnded
                              ? null
                              : () async {
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

