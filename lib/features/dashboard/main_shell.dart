import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../utils/image_picker_helper.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme.dart';
import '../../models/user_profile.dart';
import '../../models/reminder_setting.dart';
import '../../services/state_providers.dart';
import '../../services/storage_service.dart';
import '../../services/widget_sync_service.dart';
import 'package:intl/intl.dart';
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

class _MainShellState extends ConsumerState<MainShell> with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);

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
      _checkWidgetSync();
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkWidgetSync();
    }
  }

  void _checkWidgetSync() {
    WidgetSyncService.checkAndSyncWidgetLogs((amountSynced) {
      if (mounted) {
        showWebNotification(
          '💧 Water Synced!',
          'Successfully logged ${amountSynced}ml of water from your Home Screen Widget!',
        );
        final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        ref.invalidate(dailyMetricsProvider(todayStr));
      }
    });
    WidgetSyncService.syncToWidget();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSubscription?.cancel();
    _reminderTimer?.cancel();
    super.dispose();
  }

  void _showInAppNotification(String title, String body) {
    late OverlayEntry overlayEntry;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              color: isDark ? const Color(0xFF1C1C1E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFCDF200).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: Color(0xFFCDF200),
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
                        style: TextStyle(
                          color: isDark ? Colors.white : const Color(0xFF0E0F0C),
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        body,
                        style: TextStyle(
                          color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    overlayEntry.remove();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: isDark ? Colors.white70 : const Color(0xFF0E0F0C),
                      size: 14,
                    ),
                  ),
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
    final bgColor = isDark ? const Color(0xFF000000) : AppTheme.obsidianBackground;

    return Scaffold(
      extendBody: false,
      backgroundColor: bgColor,
      body: Container(
        color: bgColor,
        child: IndexedStack(index: currentIndex, children: _screens),
      ),
      bottomNavigationBar: _buildGlassNavigationBar(currentIndex),
    );
  }

  Widget _buildGlassNavigationBar(int currentIndex) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBarBgColor = isDark ? const Color(0xFF131313) : AppTheme.glassBackground;
    final borderColor = isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder;

    return SafeArea(
      child: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color: navBarBgColor,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: borderColor, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(Icons.home_rounded, 'Home', 0, currentIndex),
            _buildNavItem(Icons.fitness_center_rounded, 'Workouts', 1, currentIndex),
            _buildNavItem(Icons.qr_code_scanner_rounded, 'Scan', 2, currentIndex),
            _buildNavItem(Icons.bar_chart_rounded, 'Stats', 3, currentIndex),
            _buildNavItem(Icons.person_rounded, 'Profile', 4, currentIndex),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, int currentIndex) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = currentIndex == index;
    final activeColor = isSelected
        ? const Color(0xFF0E0F0C) // Ink Black text on Neon Lime background
        : (isDark ? const Color(0xFF868685) : AppTheme.textSecondary);

    return GestureDetector(
      onTap: () {
        ref.read(activeTabProvider.notifier).state = index;
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        padding: EdgeInsets.symmetric(
          horizontal: isSelected ? 20.0 : 12.0,
          vertical: 8.0,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? AppTheme.accentCyan // Neon Lime background
              : Colors.transparent,
          borderRadius: BorderRadius.circular(9999), // capsule shape
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: activeColor,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: activeColor,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
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
          content: Text('Profile settings saved!'),
          backgroundColor: AppTheme.accentEmerald,
        ),
      );
    }
  }

  void _showProfilePicturePicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profilePic = ref.read(profilePictureProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: AppTheme.accentCyan),
                title: Text(
                  'Change Photo',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  ImagePickerHelper.pickImage((base64, name, filePath) {
                    ref.read(profilePictureProvider.notifier).state = base64;
                    StorageService.saveProfilePicture(base64);
                  });
                },
              ),
              if (profilePic != null && profilePic.isNotEmpty)
                ListTile(
                  leading: const Icon(Icons.delete_rounded, color: AppTheme.accentCoral),
                  title: const Text(
                    'Remove Photo',
                    style: TextStyle(
                      color: AppTheme.accentCoral,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    ref.read(profilePictureProvider.notifier).state = null;
                    StorageService.saveProfilePicture(null);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                title: Text(
                  'Cancel',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : AppTheme.textSecondary,
                  ),
                ),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSettingsActionTile({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldBg = isDark
        ? AppTheme.obsidianBackground
        : Colors.black.withOpacity(0.015);
    final fieldBorder = isDark ? AppTheme.glassBorder : const Color(0xFFEADBFF);
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: fieldBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: fieldBorder, width: 1.0),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: color,
              size: 20,
            ),
          ],
        ),
      ),
    );
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
                  GestureDetector(
                    onTap: () => _showProfilePicturePicker(context),
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF1C1C1E) : const Color(0xFFE8EBE6),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3), width: 2.0),
                      ),
                      child: () {
                        final profilePic = ref.watch(profilePictureProvider);
                        if (profilePic != null && profilePic.isNotEmpty) {
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
                            debugPrint("Error loading profile pic memory: $e");
                          }
                        }
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.camera_alt_rounded,
                              color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Add Photo',
                              style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textSecondary),
                            ),
                          ],
                        );
                      }(),
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
                  () {
                    final profilePic = ref.watch(profilePictureProvider);
                    final isPhotoActive = profilePic != null && profilePic.isNotEmpty;
                    return _buildSettingsActionTile(
                      label: 'Profile Photo',
                      value: isPhotoActive ? 'Custom photo active' : 'Default icon active',
                      icon: Icons.photo_camera_rounded,
                      color: AppTheme.accentCyan,
                      onTap: () => _showProfilePicturePicker(context),
                    );
                  }(),
                  const SizedBox(height: 12),
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
                        borderRadius: BorderRadius.circular(9999), // pill shape
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
              'Support & Feedback',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _launchWhatsAppSupport,
              child: Container(
                width: double.infinity,
                height: 48,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF25D366), Color(0xFF075E54)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF25D366).withOpacity(0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.chat_bubble_rounded, color: Colors.white, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Help',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                ),
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
    final dialogBg = isDark ? const Color(0xFF1C1E1B) : Colors.white;
    final dialogBorder = isDark ? const Color(0xFF323530) : const Color(0xFFEADBFF);
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

  Future<void> _launchWhatsAppSupport() async {
    final url = Uri.parse('https://wa.me/918639473457?text=Hi%2C%20I%20need%20help%20with%20Zivofit%20App.');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch WhatsApp. Please contact +91 8639473457.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error launching WhatsApp: $e')),
        );
      }
    }
  }
}
