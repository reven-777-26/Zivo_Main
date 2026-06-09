import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme.dart';
import '../../models/user_profile.dart';
import '../../models/reminder_setting.dart';
import '../../services/state_providers.dart';
import '../../services/storage_service.dart';
import 'dashboard_screen.dart';
import 'workout_screen.dart';
import '../vision_lens/vision_lens/screens/vision_lens_home_screen.dart';
import 'progress_screen.dart';
import '../../services/ai_backend_service.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  final List<Widget> _screens = [
    const DashboardScreen(),
    const WorkoutScreen(),
    const VisionLensHomeScreen(),
    const ProgressScreen(),
    const ProfilePlaceholderScreen(),
  ];

  StreamSubscription? _notificationSubscription;
  Timer? _reminderTimer;
  int _lastCheckedMinute = -1;

  @override
  void initState() {
    super.initState();

    // Listen for global notification triggers and display a premium custom overlay alert card
    _notificationSubscription = NotificationManager.controller.stream.listen((notif) {
      if (mounted) {
        final title = notif['title'] ?? 'Notification';
        final body = notif['body'] ?? '';
        _showInAppNotification(title, body);
        ref.read(notificationsProvider.notifier).addSystemNotification(title, body);
      }
    });

    _startReminderEngine();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      showWebNotification(
        '💪 Zivo Active & Ready!',
        'Push reminders and notification systems are fully integrated. Stay on track!',
      );
    });
  }

  void _startReminderEngine() {
    _reminderTimer?.cancel();
    _reminderTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      final now = DateTime.now();
      if (now.minute == _lastCheckedMinute) return;
      _lastCheckedMinute = now.minute;

      final hourOfPeriod = now.hour % 12 == 0 ? 12 : now.hour % 12;
      final minuteStr = now.minute.toString().padLeft(2, '0');
      final periodStr = now.hour >= 12 ? 'PM' : 'AM';
      final hourStr = hourOfPeriod.toString().padLeft(2, '0');
      final currentTimeStr = '$hourStr:$minuteStr $periodStr';

      final reminders = ref.read(remindersProvider);
      reminders.forEach((key, reminder) {
        if (reminder.isEnabled) {
          final rTime = reminder.time.replaceAll(' ', '').toUpperCase();
          final cTime = currentTimeStr.replaceAll(' ', '').toUpperCase();

          if (rTime == cTime) {
            showWebNotification(
              '🔔 ${reminder.label} Reminder!',
              'Time to log your daily ${reminder.label.toLowerCase()} metrics and stay consistent!',
            );
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _reminderTimer?.cancel();
    super.dispose();
  }

  void _showInAppNotification(String title, String body) {
    late OverlayEntry overlayEntry;
    overlayEntry = OverlayEntry(
      builder: (overlayContext) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.glassBackground.withOpacity(0.98),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.accentCyan.withOpacity(0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentCyan.withOpacity(0.25),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: AppTheme.accentCyan,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                  onPressed: () {
                    overlayEntry.remove();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlayEntry);

    // Auto-remove after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      if (overlayEntry.mounted) {
        overlayEntry.remove();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentIndex = ref.watch(activeTabProvider);
    final bgColor = isDark ? AppTheme.obsidianBackground : const Color(0xFFF1F5F9);

    return Scaffold(
      extendBody: true, // Show floating glassmorphism behind the navbar
      backgroundColor: bgColor,
      body: Container(
        color: bgColor,
        child: IndexedStack(index: currentIndex, children: _screens),
      ),
      bottomNavigationBar: _buildGlassNavigationBar(currentIndex),
    );
  }

  Widget _buildGlassNavigationBar(int currentIndex) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12, bottom: 20),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        borderRadius: BorderRadius.circular(28),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_rounded, 'Home', 0, currentIndex),
            _buildNavItem(Icons.fitness_center_rounded, 'Workout', 1, currentIndex),
            _buildNavItem(Icons.qr_code_scanner_rounded, 'Scan', 2, currentIndex),
            _buildNavItem(Icons.analytics_rounded, 'Progress', 3, currentIndex),
            _buildNavItem(Icons.person_rounded, 'Profile', 4, currentIndex),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, int currentIndex) {
    final isSelected = currentIndex == index;
    final activeColor = isSelected
        ? AppTheme.accentCyan
        : AppTheme.textSecondary;

    return GestureDetector(
      onTap: () {
        ref.read(activeTabProvider.notifier).state = index;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentPurple.withOpacity(0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: activeColor, size: 22)
                .animate(target: isSelected ? 1 : 0)
                .scale(
                  begin: const Offset(1, 1),
                  end: const Offset(1.15, 1.15),
                  duration: 200.ms,
                ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: activeColor,
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// PROFILE SCREEN (Equipped with Direct Budget Settings & Reminders Config)
// =========================================================================
class ProfilePlaceholderScreen extends ConsumerStatefulWidget {
  const ProfilePlaceholderScreen({super.key});

  @override
  ConsumerState<ProfilePlaceholderScreen> createState() =>
      _ProfilePlaceholderScreenState();
}

class _ProfilePlaceholderScreenState
    extends ConsumerState<ProfilePlaceholderScreen> {
  final _calController = TextEditingController();
  final _protController = TextEditingController();
  final _watController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  String _selectedSkinType = 'Normal';
  String _selectedGoal = 'maintain';
  String _selectedGender = 'male';
  String _selectedActivityLevel = 'moderate';
  bool _auraNotificationsEnabled = true;
  bool _systemNotificationsEnabled = true;
  String? _healthCheckResult;
  bool _isLoadingHealthCheck = false;



  @override
  void initState() {
    super.initState();
    final profile = ref.read(profileProvider);
    if (profile != null) {
      _calController.text = profile.calorieGoal.toString();
      _protController.text = profile.proteinGoal.toString();
      _selectedSkinType = profile.skinType;

      double ltr = profile.waterGoal / 1000.0;
      String formatted = ltr.toStringAsFixed(2);
      if (formatted.endsWith('.00')) {
        formatted = formatted.substring(0, formatted.length - 3);
      } else if (formatted.endsWith('0')) {
        formatted = formatted.substring(0, formatted.length - 1);
      }
      _watController.text = formatted;

      _ageController.text = profile.age.toString();
      _weightController.text = profile.weight.toString();
      _heightController.text = profile.height.toString();
      _selectedGoal = profile.goal.toLowerCase();
      _selectedGender = profile.gender.toLowerCase();
      _selectedActivityLevel = profile.activityLevel.toLowerCase();
    }

    _auraNotificationsEnabled = StorageService.getAuraNotificationsEnabled();
    _systemNotificationsEnabled = StorageService.getSystemNotificationsEnabled();


  }

  @override
  void dispose() {
    _calController.dispose();
    _protController.dispose();
    _watController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();

    super.dispose();
  }

  Future<void> _saveManualTargets() async {
    final calorieInput = int.tryParse(_calController.text);
    final proteinInput = int.tryParse(_protController.text);
    final waterLtrInput = double.tryParse(_watController.text);
    final ageInput = int.tryParse(_ageController.text);
    final weightInput = double.tryParse(_weightController.text);
    final heightInput = double.tryParse(_heightController.text);

    if (calorieInput == null ||
        proteinInput == null ||
        waterLtrInput == null ||
        ageInput == null ||
        weightInput == null ||
        heightInput == null ||
        calorieInput <= 0 ||
        proteinInput <= 0 ||
        waterLtrInput <= 0 ||
        ageInput <= 0 ||
        weightInput <= 0 ||
        heightInput <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter valid, positive numeric targets.'),
        ),
      );
      return;
    }

    final waterInput = (waterLtrInput * 1000).round();

    final updatedProfile = UserProfile(
      goal: _selectedGoal,
      gender: _selectedGender,
      age: ageInput,
      weight: weightInput,
      height: heightInput,
      activityLevel: _selectedActivityLevel,
      calorieGoal: calorieInput,
      proteinGoal: proteinInput,
      waterGoal: waterInput,
      skinType: _selectedSkinType,
    );

    await ref.read(profileProvider.notifier).saveProfile(updatedProfile);
    await StorageService.setAuraNotificationsEnabled(_auraNotificationsEnabled);
    await StorageService.setSystemNotificationsEnabled(_systemNotificationsEnabled);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Profile settings and calibration targets saved!'),
          backgroundColor: AppTheme.accentEmerald,
        ),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(profileProvider);
    final reminders = ref.watch(remindersProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;



    final double currentWeight = profile?.weight ?? 78.5;
    final double currentHeight = profile?.height ?? 182.0;
    final int currentAge = profile?.age ?? 28;
    final String currentGender = profile?.gender ?? 'Male';

    return SafeArea(
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
            // Profile Header Section (Stitch layout banner)
            Center(
              child: Column(
                children: [
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3), width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentCyan.withOpacity(0.15),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.network(
                        'https://lh3.googleusercontent.com/aida-public/AB6AXuCoqjP7BFZ5G58JZ9dWkY7i2nuxlXG22yw4_kp_tZDq9_LFlGpDXZN7CW3mbIisWHeikqi3HAtRW3GIE3Yv25gBdC20K-f5kYqQWbCYwr59BI8F9VS5Px2JuUIN1vtuKG2z93p-pIAb6Ea3-53UcUQzDXCzvR9Ar7P2inSnzRzOu5DHjU442uippjL0VveOFZ3BBk_TEVeMPIfcupH3xh7AswuFV2aHm9hmqFljLzwDutvFMQRHy3SZzrRekzi82S15S4nTDmbypbM',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Alex Morgan',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Elite Athlete • Premium Member',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Personal Metrics Bento Grid
            Row(
              children: [
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.accentCyan.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.scale_rounded,
                            color: AppTheme.accentCyan,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'WEIGHT',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${currentWeight.toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppTheme.accentPurple.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.straighten_rounded,
                            color: AppTheme.accentPurple,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'HEIGHT',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${currentHeight.round()} cm',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GlassCard(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppTheme.accentOrange.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.cake_rounded,
                      color: AppTheme.accentOrange,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'AGE & GENDER',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$currentAge Years • $currentGender',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: AppTheme.textSecondary,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Zivo Vision Lens Launch Card
            const Text(
              'AI Product Intelligence',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => context.push('/vision_lens'),
              child: GlassCard(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.center_focus_strong_rounded,
                        color: AppTheme.accentCyan,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Zivo Vision Lens',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Scan and analyze ingredients of food, supplements, and skincare products using AI.',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.accentCyan,
                      size: 24,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Target budgets editor
            const Text(
              'Edit Profile & Targets',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildEditorField(
                    _ageController,
                    'Age',
                    'yrs',
                    Icons.cake_rounded,
                    AppTheme.accentOrange,
                  ),
                  const SizedBox(height: 12),
                  _buildDropdownField(
                    value: _selectedGender,
                    items: const ['male', 'female', 'other'],
                    label: 'Gender',
                    icon: Icons.person_outline_rounded,
                    color: AppTheme.accentCyan,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedGender = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildEditorField(
                    _weightController,
                    'Weight',
                    'kg',
                    Icons.scale_rounded,
                    AppTheme.accentCyan,
                  ),
                  const SizedBox(height: 12),
                  _buildEditorField(
                    _heightController,
                    'Height',
                    'cm',
                    Icons.straighten_rounded,
                    AppTheme.accentPurple,
                  ),
                  const SizedBox(height: 12),
                  _buildDropdownField(
                    value: _selectedGoal,
                    items: const ['lose', 'gain', 'maintain'],
                    label: 'Fitness Goal',
                    icon: Icons.track_changes_rounded,
                    color: AppTheme.accentOrange,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedGoal = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildDropdownField(
                    value: _selectedActivityLevel,
                    items: const ['sedentary', 'light', 'moderate', 'very'],
                    label: 'Activity Level',
                    icon: Icons.directions_run_rounded,
                    color: AppTheme.accentPurple,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedActivityLevel = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: AppTheme.glassBorder, height: 24),
                  _buildEditorField(
                    _calController,
                    'Calorie Goal',
                    'kcal',
                    Icons.bolt_rounded,
                    AppTheme.accentCyan,
                  ),
                  const SizedBox(height: 12),
                  _buildEditorField(
                    _protController,
                    'Protein Goal',
                    'g',
                    Icons.fitness_center_rounded,
                    AppTheme.accentOrange,
                  ),
                  const SizedBox(height: 12),
                  _buildEditorField(
                    _watController,
                    'Hydration Goal',
                    'ltr',
                    Icons.local_drink_rounded,
                    Colors.blueAccent,
                  ),
                  const SizedBox(height: 12),
                  _buildDropdownField(
                    value: _selectedSkinType,
                    items: const ['Dry', 'Oily', 'Sensitive', 'Acne', 'Normal'],
                    label: 'Skincare Skin Type',
                    icon: Icons.face_retouching_natural_rounded,
                    color: AppTheme.accentPurple,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedSkinType = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _saveManualTargets,
                    child: Container(
                      width: double.infinity,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentCyan.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Text(
                          'Save Profile Settings',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Reminders Section
            const Text(
              'Daily Reminders',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            if (reminders.isEmpty)
              const GlassCard(
                width: double.infinity,
                padding: EdgeInsets.all(20.0),
                child: Center(
                  child: Text(
                    'No configured reminders.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              )
            else
              ...reminders.entries.map((entry) {
                return _buildReminderAlarmTile(entry.key, entry.value);
              }),
            const SizedBox(height: 24),

            // Notification Settings
            const Text(
              'Notification Settings',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              width: double.infinity,
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Zivo AI Alerts',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Receive AI coaching and health insights',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _auraNotificationsEnabled,
                        activeColor: AppTheme.accentOrange,
                        onChanged: (val) {
                          setState(() {
                            _auraNotificationsEnabled = val;
                          });
                        },
                      ),
                    ],
                  ),
                  const Divider(color: AppTheme.glassBorder, height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'System Alerts',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Receive reminders and log updates',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _systemNotificationsEnabled,
                        activeColor: AppTheme.accentCyan,
                        onChanged: (val) {
                          setState(() {
                            _systemNotificationsEnabled = val;
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // App Style theme toggle
            GlassCard(
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Obsidian Dark Mode',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Premium velvet midnight aesthetic',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Switch(
                    value: isDark,
                    activeColor: AppTheme.accentPurple,
                    onChanged: (val) {
                      ref.read(themeModeProvider.notifier).state =
                          val ? ThemeMode.dark : ThemeMode.light;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text(
              'AI Backend Integration',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            GlassCard(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Verification test for Flutter ↔ Firebase Cloud Functions connection using Secure Secret Manager.',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: _isLoadingHealthCheck
                        ? null
                        : () async {
                            setState(() {
                              _isLoadingHealthCheck = true;
                              _healthCheckResult = null;
                            });
                            final result = await AIBackendService.healthCheckAI();
                            if (mounted) {
                              setState(() {
                                _isLoadingHealthCheck = false;
                                _healthCheckResult = result.toString();
                              });
                            }
                          },
                    child: Container(
                      width: double.infinity,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.accentCyan.withOpacity(0.15),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isLoadingHealthCheck
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'Run healthCheckAI()',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ),
                  if (_healthCheckResult != null) ...[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppTheme.glassBorder,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        _healthCheckResult!,
                        style: const TextStyle(
                          color: AppTheme.accentCyan,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Database Reset Wiping Button (Sign Out style)
            GestureDetector(
              onTap: () {
                _showResetDialog(context, ref);
              },
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  color: AppTheme.accentCoral.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppTheme.accentCoral.withOpacity(0.3),
                    width: 1.0,
                  ),
                ),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        color: AppTheme.accentCoral,
                        size: 18,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Sign Out & Reset Logs',
                        style: TextStyle(
                          color: AppTheme.accentCoral,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  String _formatTimeOfDay(TimeOfDay tod) {
    final hour = tod.hourOfPeriod == 0 ? 12 : tod.hourOfPeriod;
    final minute = tod.minute.toString().padLeft(2, '0');
    final period = tod.period == DayPeriod.am ? 'AM' : 'PM';
    final hourStr = hour.toString().padLeft(2, '0');
    return '$hourStr:$minute $period'; // e.g. "08:30 AM"
  }

  Widget _buildReminderAlarmTile(String key, ReminderSetting reminder) {
    IconData icon = Icons.notifications_rounded;
    Color color = AppTheme.accentCyan;

    if (key == 'water') {
      icon = Icons.water_drop_rounded;
      color = AppTheme.accentCyan;
    } else if (key == 'meal') {
      icon = Icons.restaurant_rounded;
      color = AppTheme.accentOrange;
    } else if (key == 'workout') {
      icon = Icons.fitness_center_rounded;
      color = AppTheme.accentPurple;
    } else if (key == 'supplement') {
      icon = Icons.medication_rounded;
      color = AppTheme.accentOrange;
    } else if (key == 'sleep') {
      icon = Icons.bedtime_rounded;
      color = AppTheme.accentPurple;
    }

    final bool isEnabled = reminder.isEnabled;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isEnabled ? 1.0 : 0.55,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          borderRadius: BorderRadius.circular(20),
          child: Row(
            children: [
              // Icon with circular container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(icon, color: color, size: 22),
                ),
              ),
              const SizedBox(width: 16),

              // Title and Digital clock time picker trigger
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.label,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () async {
                        final parts = reminder.time.split(' ');
                        final hm = parts[0].split(':');
                        int hour = int.parse(hm[0]);
                        final int minute = int.parse(hm[1]);
                        if (parts.length > 1 && parts[1] == 'PM' && hour < 12) {
                          hour += 12;
                        } else if (parts.length > 1 && parts[1] == 'AM' && hour == 12) {
                          hour = 0;
                        }

                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay(hour: hour, minute: minute),
                        );

                        if (picked != null) {
                          final formattedTime = _formatTimeOfDay(picked);
                          await ref
                              .read(remindersProvider.notifier)
                              .updateReminder(key, time: formattedTime);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: color.withOpacity(0.2), width: 1.0),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              size: 14,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              reminder.time,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Toggle switch
              Switch(
                value: isEnabled,
                activeColor: color,
                onChanged: (val) {
                  ref
                      .read(remindersProvider.notifier)
                      .updateReminder(key, isEnabled: val);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditorField(
    TextEditingController ctrl,
    String label,
    String suffix,
    IconData icon,
    Color color,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldBg = isDark
        ? AppTheme.obsidianBackground
        : Colors.black.withOpacity(0.015);
    final fieldBorder = isDark ? AppTheme.glassBorder : const Color(0xFFEADBFF);
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;

    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fieldBorder, width: 1.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
      child: TextField(
        controller: ctrl,
        keyboardType: TextInputType.number,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          icon: Icon(icon, color: color, size: 18),
          labelText: label,
          labelStyle: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
          ),
          suffixText: suffix,
          suffixStyle: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String value,
    required List<String> items,
    required String label,
    required IconData icon,
    required Color color,
    required ValueChanged<String?> onChanged,
  }) {
    String selectedVal = value;
    if (!items.contains(selectedVal)) {
      selectedVal = items.firstWhere(
        (item) => item.toLowerCase() == value.toLowerCase(),
        orElse: () => items.first,
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldBg = isDark
        ? AppTheme.obsidianBackground
        : Colors.black.withOpacity(0.015);
    final fieldBorder = isDark ? AppTheme.glassBorder : const Color(0xFFEADBFF);
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;

    return Container(
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: fieldBorder, width: 1.0),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: DropdownButtonFormField<String>(
        value: selectedVal,
        dropdownColor: isDark ? AppTheme.obsidianBackground : Colors.white,
        decoration: InputDecoration(
          icon: Icon(icon, color: color, size: 18),
          labelText: label,
          labelStyle: const TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
          ),
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
        items: items.map((type) {
          return DropdownMenuItem<String>(
            value: type,
            child: Text(type),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }


  void _showResetDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? AppTheme.glassBackground : Colors.white;
    final dialogBorder = isDark ? AppTheme.glassBorder : const Color(0xFFEADBFF);
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: dialogBorder, width: 1.0),
        ),
        title: Text(
          'Wipe Stored Health Logs?',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'This will permanently delete your stored user profile settings, daily nutrition logs, water counts, and logged gym history. You will return to the setup guide.',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 13,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCoral,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Wipe Stored Logs',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await ref.read(profileProvider.notifier).clearProfile();
              _calController.clear();
              _protController.clear();
              _watController.clear();
              if (ctx.mounted) {
                ctx.go('/');
              }
            },
          ),
        ],
      ),
    );
  }
}
