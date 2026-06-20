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
import '../../core/health_math.dart';
import '../../services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/widgets/zivo_loader.dart';
import '../../services/audio_service.dart';

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
        AudioService.playNotification();
      }
    });

    _startReminderEngine();



    WidgetsBinding.instance.addPostFrameCallback((_) async {
      AudioService.playAppOpen();
      _checkWidgetSync();
      
      // Perform a one-time sync on launch to catch any offline edits from the previous session
      if (FirebaseService.isLoggedIn) {
        await FirebaseService.syncLocalToCloud();
      }
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

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    _reminderTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
              color: isDark ? const Color(0xFF121214) : Colors.white,
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
                    color: const Color(0xFFD9FF00).withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.notifications_active_rounded,
                    color: Color(0xFFD9FF00),
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

    // Auto-remove after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
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
    final customBgStr = ref.watch(customBackgroundProvider);
    final hasBg = customBgStr != null && customBgStr.isNotEmpty;

    DecorationImage? bgImage;
    if (hasBg) {
      try {
        String cleaned = customBgStr;
        final commaIndex = cleaned.indexOf(',');
        if (commaIndex != -1) {
          cleaned = cleaned.substring(commaIndex + 1);
        }
        cleaned = cleaned.replaceAll(RegExp(r'\s+'), '');
        final bytes = base64Decode(cleaned);
        bgImage = DecorationImage(
          image: MemoryImage(bytes),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(
            Colors.black.withOpacity(isDark ? 0.85 : 0.6),
            BlendMode.darken,
          ),
        );
      } catch (e) {
        debugPrint("Error loading custom background: $e");
      }
    }

    return Scaffold(
      extendBody: true,
      backgroundColor: bgColor,
      body: Container(
        decoration: BoxDecoration(
          color: bgColor,
          image: bgImage,
        ),
        child: IndexedStack(index: currentIndex, children: _screens),
      ),
      bottomNavigationBar: _buildGlassNavigationBar(currentIndex),
    );
  }

  Widget _buildGlassNavigationBar(int currentIndex) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final navBarBgColor = isDark ? const Color(0xFF131313) : AppTheme.glassBackground;
    final borderColor = isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder;
    final accentColor = ref.watch(accentColorProvider);

    return SafeArea(
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // The main navbar container with custom painted notched curve
          Container(
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 24, top: 16),
            height: 104, // Increased from 88 to make top and bottom size even larger
            child: CustomPaint(
              painter: NotchedNavbarPainter(
                bgColor: navBarBgColor,
                borderColor: borderColor,
                borderWidth: 1.2,
              ),
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Container(
                  height: 76, // Taller flat height of the capsule body
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildNavItem(Icons.home_rounded, 'Home', 0, currentIndex),
                      _buildNavItem(Icons.fitness_center_rounded, 'Workouts', 1, currentIndex),
                      
                      // Balanced placeholder space for the middle Scan button
                      Expanded(
                        child: GestureDetector(
                          onTap: () {
                            ref.read(activeTabProvider.notifier).state = 2;
                          },
                          behavior: HitTestBehavior.opaque,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const SizedBox(height: 32), // Perfectly balances text label with adjacent tabs
                              AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 250),
                                curve: Curves.easeOutCubic,
                                style: TextStyle(
                                  color: currentIndex == 2
                                      ? accentColor
                                      : (isDark ? const Color(0xFF868685) : AppTheme.textSecondary),
                                  fontSize: currentIndex == 2 ? 10.5 : 9.5,
                                  fontWeight: currentIndex == 2 ? FontWeight.w900 : FontWeight.w500,
                                ),
                                child: const Text('Scan'),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      _buildNavItem(Icons.bar_chart_rounded, 'Stats', 3, currentIndex),
                      _buildNavItem(Icons.person_rounded, 'Profile', 4, currentIndex),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          Positioned(
            top: 24, // Positioned slightly lower to sit better in the notched bulge
            left: 0,
            right: 0,
            child: Align(
              alignment: Alignment.topCenter,
              child: GestureDetector(
                onTap: () {
                  ref.read(activeTabProvider.notifier).state = 2;
                },
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.qr_code_scanner_rounded,
                      color: Color(0xFF0E0F0C),
                      size: 28, // Reduced for a cleaner look
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index, int currentIndex) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = currentIndex == index;
    final accentColor = ref.watch(accentColorProvider);
    
    final iconColor = isSelected
        ? const Color(0xFF0E0F0C) // Black icon inside selected capsule
        : (isDark ? const Color(0xFF868685) : AppTheme.textSecondary);
        
    final textColor = isSelected
        ? accentColor
        : (isDark ? const Color(0xFF868685) : AppTheme.textSecondary);

    final double scale = isSelected ? 1.12 : 1.0;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref.read(activeTabProvider.notifier).state = index;
        },
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedScale(
              scale: scale,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16.0,
                  vertical: 6.0,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? accentColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              style: TextStyle(
                color: textColor,
                fontSize: isSelected ? 10.5 : 9.5,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

class NotchedNavbarPainter extends CustomPainter {
  final Color bgColor;
  final Color borderColor;
  final double borderWidth;

  NotchedNavbarPainter({
    required this.bgColor,
    required this.borderColor,
    this.borderWidth = 1.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = bgColor
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = borderWidth
      ..style = PaintingStyle.stroke;

    final double width = size.width;
    final double height = size.height;
    
    // Layout baseline settings for upward convex bulge
    final double baselineY = 28.0; // Straight top line starts at y=28 (leaving 28px top padding)
    final double radius = (height - baselineY) / 2; // Perfect capsule radius for the 76px body
    final double bulgeHeight = 22.0; // Bulges UP by 22px from baselineY to y=6
    final double center = width / 2;
    
    // Width of the convex bulge
    final double bulgeWidth = 84.0;
    final double halfWidth = bulgeWidth / 2;

    final path = Path()
      ..moveTo(radius, baselineY)
      // Top-left straight edge
      ..lineTo(center - halfWidth, baselineY)
      // Convex curve arching UP and over the button
      ..cubicTo(
        center - halfWidth * 0.45, baselineY, // CP1 (flat entry)
        center - halfWidth * 0.55, baselineY - bulgeHeight, // CP2 (flat top peak)
        center, baselineY - bulgeHeight, // Peak of bulge (y = 0)
      )
      ..cubicTo(
        center + halfWidth * 0.55, baselineY - bulgeHeight, // CP1 (flat top peak)
        center + halfWidth * 0.45, baselineY, // CP2 (flat entry)
        center + halfWidth, baselineY, // End of bulge
      )
      // Top-right straight edge
      ..lineTo(width - radius, baselineY)
      // Top-right corner
      ..arcToPoint(Offset(width, baselineY + radius), radius: Radius.circular(radius))
      // Right edge
      ..lineTo(width, height - radius)
      // Bottom-right corner
      ..arcToPoint(Offset(width - radius, height), radius: Radius.circular(radius))
      // Bottom edge
      ..lineTo(radius, height)
      // Bottom-left corner
      ..arcToPoint(Offset(0, height - radius), radius: Radius.circular(radius))
      // Left edge
      ..lineTo(0, baselineY + radius)
      // Top-left corner
      ..arcToPoint(Offset(radius, baselineY), radius: Radius.circular(radius))
      ..close();

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
  final _carbsController = TextEditingController();
  final _fatsController = TextEditingController();
  final _watController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _nameController = TextEditingController();
  String _selectedSkinType = 'Normal';
  String _selectedGoal = 'maintain';
  String _selectedGender = 'male';
  String _selectedActivityLevel = 'moderate';
  bool _auraNotificationsEnabled = true;
  bool _systemNotificationsEnabled = true;
  String? _healthCheckResult;
  bool _isLoadingHealthCheck = false;
  bool _fakeDataEnabled = false;
  int _selectedLoader = 0; // 0=Morph, 1=EKG, 2=Arc
  Timer? _debounceTimer;

  void _onSettingsChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _saveProfileDataSilent();
    });
  }

  Future<void> _saveProfileDataSilent() async {
    final nameInput = _nameController.text.trim();
    final user = FirebaseService.currentUser;
    if (user != null && nameInput.isNotEmpty && nameInput != user.displayName) {
      try {
        await user.updateDisplayName(nameInput);
        await user.reload();
        await FirebaseService.firestore.collection('users').doc(user.uid).set({
          'displayName': nameInput,
        }, SetOptions(merge: true));
        if (mounted) {
          setState(() {});
        }
      } catch (e) {
        debugPrint("Error updating display name: $e");
      }
    }

    final calorieInput = int.tryParse(_calController.text);
    final proteinInput = int.tryParse(_protController.text);
    final carbsInput = int.tryParse(_carbsController.text);
    final fatsInput = int.tryParse(_fatsController.text);
    final waterLtrInput = double.tryParse(_watController.text);
    final ageInput = int.tryParse(_ageController.text);
    final weightInput = double.tryParse(_weightController.text);
    final heightInput = double.tryParse(_heightController.text);

    if (calorieInput == null || calorieInput <= 0 ||
        proteinInput == null || proteinInput <= 0 ||
        carbsInput == null || carbsInput <= 0 ||
        fatsInput == null || fatsInput <= 0 ||
        waterLtrInput == null || waterLtrInput <= 0 ||
        ageInput == null || ageInput <= 0 ||
        weightInput == null || weightInput <= 0 ||
        heightInput == null || heightInput <= 0) {
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

    await StorageService.saveCarbsGoal(carbsInput);
    await StorageService.saveFatsGoal(fatsInput);
    FirebaseService.saveSettingsCloud();

    await ref.read(profileProvider.notifier).saveProfile(updatedProfile);
    ref.invalidate(profileProvider); // force invalidate to refresh dashboard targets
  }

  void _autoRecalculateTargets() {
    final age = int.tryParse(_ageController.text);
    final weight = double.tryParse(_weightController.text);
    final height = double.tryParse(_heightController.text);

    if (age != null && age > 0 && weight != null && weight > 0 && height != null && height > 0) {
      final targets = HealthMath.calculateTargets(
        goal: _selectedGoal,
        age: age,
        weight: weight,
        height: height,
        activityLevel: _selectedActivityLevel,
        gender: _selectedGender,
      );

      setState(() {
        _calController.text = targets.calorieGoal.toString();
        _protController.text = targets.proteinGoal.toString();
        _carbsController.text = targets.carbGoal.toString();
        _fatsController.text = targets.fatGoal.toString();

        double ltr = targets.waterGoal / 1000.0;
        String formatted = ltr.toStringAsFixed(2);
        if (formatted.endsWith('.00')) {
          formatted = formatted.substring(0, formatted.length - 3);
        } else if (formatted.endsWith('0')) {
          formatted = formatted.substring(0, formatted.length - 1);
        }
        _watController.text = formatted;
      });
    }
  }

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
      _weightController.text = profile.weight.round().toString();
      _heightController.text = profile.height.round().toString();
      _selectedGoal = profile.goal.toLowerCase();
      _selectedGender = profile.gender.toLowerCase();
      _selectedActivityLevel = profile.activityLevel.toLowerCase();
    }

    _carbsController.text = StorageService.getCarbsGoal().toString();
    _fatsController.text = StorageService.getFatsGoal().toString();
    _nameController.text = FirebaseService.currentUser?.displayName ?? '';

    _auraNotificationsEnabled = StorageService.getAuraNotificationsEnabled();
    _systemNotificationsEnabled = StorageService.getSystemNotificationsEnabled();
    _fakeDataEnabled = StorageService.getFakeDataEnabled();

    // Listen to profile inputs to trigger automatic targets calculation
    _ageController.addListener(_autoRecalculateTargets);
    _weightController.addListener(_autoRecalculateTargets);
    _heightController.addListener(_autoRecalculateTargets);

    // Listen to settings updates for automatic background saving
    _calController.addListener(_onSettingsChanged);
    _protController.addListener(_onSettingsChanged);
    _carbsController.addListener(_onSettingsChanged);
    _fatsController.addListener(_onSettingsChanged);
    _watController.addListener(_onSettingsChanged);
    _ageController.addListener(_onSettingsChanged);
    _weightController.addListener(_onSettingsChanged);
    _heightController.addListener(_onSettingsChanged);
    _nameController.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _ageController.removeListener(_autoRecalculateTargets);
    _weightController.removeListener(_autoRecalculateTargets);
    _heightController.removeListener(_autoRecalculateTargets);

    _calController.removeListener(_onSettingsChanged);
    _protController.removeListener(_onSettingsChanged);
    _carbsController.removeListener(_onSettingsChanged);
    _fatsController.removeListener(_onSettingsChanged);
    _watController.removeListener(_onSettingsChanged);
    _ageController.removeListener(_onSettingsChanged);
    _weightController.removeListener(_onSettingsChanged);
    _heightController.removeListener(_onSettingsChanged);
    _nameController.removeListener(_onSettingsChanged);

    _calController.dispose();
    _protController.dispose();
    _carbsController.dispose();
    _fatsController.dispose();
    _watController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    _heightController.dispose();
    _nameController.dispose();

    _debounceTimer?.cancel();

    super.dispose();
  }



  void _showProfilePicturePicker(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final profilePic = ref.read(profilePictureProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF121214) : Colors.white,
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
                  ImagePickerHelper.pickImage((base64, name, filePath) async {
                    ref.read(profilePictureProvider.notifier).state = base64;
                    StorageService.saveProfilePicture(base64);
                    await FirebaseService.saveProfilePictureCloud(base64);
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
                    FirebaseService.saveProfilePictureCloud(null);
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
        ? const Color(0xFF141618)
        : Colors.black.withOpacity(0.015);
    final fieldBorder = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEADBFF);
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

  final Map<String, bool> _expandedSections = {
    'profile': true,
    'goals': false,
    'reminders': false,
    'notifications': false,
    'appearance': false,
    'developer': false,
    'loader': false,
    'support': false,
    'account': false,
  };

  Widget _buildAccordionSection({
    required String title,
    required String sectionKey,
    required Widget content,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isExpanded = _expandedSections[sectionKey] ?? false;
    final accentColor = ref.watch(accentColorProvider);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        width: double.infinity,
        padding: EdgeInsets.zero,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  _expandedSections[sectionKey] = !isExpanded;
                });
              },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isDark ? Colors.white : AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Icon(
                      isExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: accentColor,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: content,
              ),
              crossFadeState: isExpanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 200),
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
    final accentColor = ref.watch(accentColorProvider);

    final int currentWeight = (profile?.weight ?? 78.5).round();
    final int currentHeight = (profile?.height ?? 182.0).round();
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
                        color: isDark ? const Color(0xFF121214) : const Color(0xFFE8EBE6),
                        shape: BoxShape.circle,
                        border: Border.all(color: accentColor.withOpacity(0.3), width: 2.0),
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
                  GestureDetector(
                    onTap: () => _showRenameNameDialog(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          () {
                            final user = FirebaseService.currentUser;
                            if (user == null) return 'Zivo User';
                            if (user.displayName != null && user.displayName!.isNotEmpty) {
                              return user.displayName!;
                            }
                            if (user.isAnonymous) return 'Guest User';
                            final email = user.email ?? '';
                            if (email.contains('@')) {
                              return email.split('@').first;
                            }
                            return email.isNotEmpty ? email : 'Zivo Member';
                          }(),
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.edit_rounded,
                          color: Colors.white.withOpacity(0.6),
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Elite Form • Premium Member',
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

            // Combined Personal Metrics Bento Grid (Unified 2x2 Layout, no chevrons)
            GlassCard(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              customBgColor: isDark ? const Color(0xFF141618) : AppTheme.glassBackground,
              customBorder: Border.all(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder, width: 1.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BODY PROFILE SUMMARY',
                    style: TextStyle(
                      color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Weight
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.scale_rounded,
                                color: accentColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'WEIGHT',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$currentWeight kg',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : AppTheme.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Height
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.straighten_rounded,
                                color: accentColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'HEIGHT',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$currentHeight cm',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : AppTheme.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
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
                  const SizedBox(height: 16),
                  const Divider(color: AppTheme.glassBorder, height: 1),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Age
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.cake_rounded,
                                color: accentColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'AGE',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$currentAge Years',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : AppTheme.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Gender
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: accentColor.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.person_outline_rounded,
                                color: accentColor,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'GENDER',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    currentGender,
                                    style: TextStyle(
                                      color: isDark ? Colors.white : AppTheme.textPrimary,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
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
                ],
              ),
            ),
            const SizedBox(height: 28),

            // ── 1. PROFILE & BODY ACCORDION ──
            _buildAccordionSection(
              title: '👤  Profile & Body',
              sectionKey: 'profile',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  () {
                    final profilePic = ref.watch(profilePictureProvider);
                    final isPhotoActive = profilePic != null && profilePic.isNotEmpty;
                    return _buildSettingsActionTile(
                      label: 'Profile Photo',
                      value: isPhotoActive ? 'Custom photo active' : 'Default icon active',
                      icon: Icons.photo_camera_rounded,
                      color: accentColor,
                      onTap: () => _showProfilePicturePicker(context),
                    );
                  }(),
                  const SizedBox(height: 12),
                  _buildEditorField(
                    _nameController,
                    'Name',
                    '',
                    Icons.person_rounded,
                    accentColor,
                    keyboardType: TextInputType.name,
                  ),
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
                    color: accentColor,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedGender = val;
                          _autoRecalculateTargets();
                          _onSettingsChanged();
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
                    accentColor,
                  ),
                  const SizedBox(height: 12),
                  _buildEditorField(
                    _heightController,
                    'Height',
                    'cm',
                    Icons.straighten_rounded,
                    accentColor,
                  ),
                ],
              ),
            ),

            // ── 2. GOALS & TARGETS ACCORDION ──
            _buildAccordionSection(
              title: '🎯  Goals & Targets',
              sectionKey: 'goals',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                          _autoRecalculateTargets();
                          _onSettingsChanged();
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
                    color: accentColor,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedActivityLevel = val;
                          _autoRecalculateTargets();
                          _onSettingsChanged();
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
                    accentColor,
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
                    _carbsController,
                    'Carbohydrate Goal',
                    'g',
                    Icons.bakery_dining_rounded,
                    accentColor,
                  ),
                  const SizedBox(height: 12),
                  _buildEditorField(
                    _fatsController,
                    'Fat Goal',
                    'g',
                    Icons.opacity_rounded,
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
                    color: accentColor,
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedSkinType = val;
                          _onSettingsChanged();
                        });
                      }
                    },
                  ),
                ],
              ),
            ),

            // ── 3. REMINDERS ACCORDION ──
            _buildAccordionSection(
              title: '⏰  Reminders',
              sectionKey: 'reminders',
              content: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _showAddReminderDialog(context),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: accentColor.withOpacity(0.3),
                          width: 1.0,
                          style: BorderStyle.solid,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_alarm_rounded, color: accentColor, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'Add Custom Reminder',
                            style: TextStyle(
                              color: accentColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── 4. NOTIFICATIONS ACCORDION ──
            _buildAccordionSection(
              title: '🔔  Notifications',
              sectionKey: 'notifications',
              content: Column(
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
                          StorageService.setAuraNotificationsEnabled(val);
                          FirebaseService.saveSettingsCloud();
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
                        activeColor: accentColor,
                        onChanged: (val) {
                          setState(() {
                            _systemNotificationsEnabled = val;
                          });
                          StorageService.setSystemNotificationsEnabled(val);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ── 6. DEVELOPER ACCORDION ──
            _buildAccordionSection(
              title: '🛠  Developer',
              sectionKey: 'developer',
              content: Column(
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
                        color: accentColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withOpacity(0.15),
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
                                      AlwaysStoppedAnimation<Color>(Colors.black),
                                ),
                              )
                            : const Text(
                                'Run healthCheckAI()',
                                style: TextStyle(
                                  color: Colors.black,
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
                        style: TextStyle(
                          color: accentColor,
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const Divider(color: AppTheme.glassBorder, height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Mock / Fake Data',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Enable to seed mock logs & workout trends',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      Switch(
                        value: _fakeDataEnabled,
                        activeColor: accentColor,
                        onChanged: (val) async {
                          setState(() {
                            _fakeDataEnabled = val;
                          });
                          await StorageService.saveFakeDataEnabled(val);
                          if (val) {
                            await StorageService.seedDummyData();
                            ref.invalidate(workoutHistoryProvider);
                            ref.invalidate(profileProvider);
                            ref.invalidate(dailyMetricsProvider);
                            final selectedDate = ref.read(selectedDateProvider);
                            ref.invalidate(dailyMetricsProvider(selectedDate));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Fake mock data generated successfully!'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          } else {
                            await StorageService.clearMockDataOnly();
                            await FirebaseService.clearMockDataCloud();
                            ref.invalidate(workoutHistoryProvider);
                            ref.invalidate(profileProvider);
                            final selectedDate = ref.read(selectedDateProvider);
                            ref.invalidate(dailyMetricsProvider(selectedDate));
                            ref.invalidate(dailyMetricsProvider);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Mock logs and history cleared.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),



            // ── 8. SUPPORT ACCORDION ──
            _buildAccordionSection(
              title: '💬  Support',
              sectionKey: 'support',
              content: GestureDetector(
                onTap: _launchWhatsAppSupport,
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    color: accentColor, // dynamic accent color
                    borderRadius: BorderRadius.circular(9999),
                    border: Border.all(
                      color: accentColor,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withOpacity(0.25),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.chat_bubble_rounded, color: Color(0xFF0E0F0C), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Help',
                          style: TextStyle(
                            color: Color(0xFF0E0F0C), // Black text
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── 8. ACCOUNT ACCORDION ──
            _buildAccordionSection(
              title: '🚪  Account',
              sectionKey: 'account',
              content: Column(
                children: [
                  // 0. Cloud Sync Button
                  GestureDetector(
                    onTap: () async {
                      if (!FirebaseService.isLoggedIn) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please sign in or create an account first to sync with cloud.'),
                            backgroundColor: AppTheme.accentOrange,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(
                            color: AppTheme.accentCyan,
                          ),
                        ),
                      );
                      try {
                        await FirebaseService.syncLocalToCloud(context: context);
                        if (mounted) {
                          Navigator.pop(context); // Dismiss loader
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Cloud Sync completed successfully!'),
                              backgroundColor: AppTheme.accentEmerald,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (mounted) {
                          Navigator.pop(context); // Dismiss loader
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Sync failed: $e'),
                              backgroundColor: AppTheme.accentCoral,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: accentColor.withOpacity(0.3),
                          width: 1.0,
                        ),
                      ),
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.cloud_sync_rounded,
                              color: accentColor,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Sync to Cloud',
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 1. Sign Out Button
                  GestureDetector(
                    onTap: () {
                      _showSignOutDialog(context, ref);
                    },
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.accentCyan.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.accentCyan.withOpacity(0.3),
                          width: 1.0,
                        ),
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              color: AppTheme.accentCyan,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Sign Out',
                              style: TextStyle(
                                color: AppTheme.accentCyan,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Wipe Local Logs Button
                  GestureDetector(
                    onTap: () {
                      _showWipeLogsDialog(context, ref);
                    },
                    child: Container(
                      width: double.infinity,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.accentOrange.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppTheme.accentOrange.withOpacity(0.3),
                          width: 1.0,
                        ),
                      ),
                      child: const Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.delete_sweep_rounded,
                              color: AppTheme.accentOrange,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Wipe Local Logs',
                              style: TextStyle(
                                color: AppTheme.accentOrange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Delete Account Forever Button
                  GestureDetector(
                    onTap: () {
                      _showDeleteAccountDialog(context, ref);
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
                              Icons.delete_forever_rounded,
                              color: AppTheme.accentCoral,
                              size: 18,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Delete Account Forever',
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
            const SizedBox(height: 24),
            Center(
              child: Text(
                'Beta version 1.0',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDark ? const Color(0xFF868685) : AppTheme.textSecondary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  void _showRenameNameDialog(BuildContext context) {
    final controller = TextEditingController(text: FirebaseService.currentUser?.displayName ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF141618) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder, width: 1),
        ),
        title: Text(
          'Edit Profile Name',
          style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter name...',
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: ref.read(accentColorProvider))),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ref.read(accentColorProvider),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                _nameController.text = newName;
                _saveProfileDataSilent();
              }
              Navigator.pop(ctx);
            },
          ),
        ],
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

  void _showRenameReminderDialog(BuildContext context, String key, String currentLabel) {
    final controller = TextEditingController(text: currentLabel);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF141618) : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder, width: 1),
        ),
        title: Text(
          'Rename Reminder',
          style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: TextField(
          controller: controller,
          style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Enter new name...',
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: ref.read(accentColorProvider))),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
            onPressed: () => Navigator.pop(ctx),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: ref.read(accentColorProvider),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                ref.read(remindersProvider.notifier).updateReminder(key, label: newName);
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showAddReminderDialog(BuildContext context) {
    final controller = TextEditingController(text: 'New Reminder');
    TimeOfDay selectedTime = const TimeOfDay(hour: 8, minute: 0);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) {
          final timeStr = _formatTimeOfDay(selectedTime);
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF141618) : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder, width: 1),
            ),
            title: Text(
              'Add Custom Reminder',
              style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Reminder Name',
                    labelStyle: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: ref.read(accentColorProvider))),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Daily Reminder Time',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: selectedTime,
                    );
                    if (picked != null) {
                      setDialogState(() {
                        selectedTime = picked;
                      });
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black26 : Colors.black.withOpacity(0.02),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: ref.read(accentColorProvider).withOpacity(0.2)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time_rounded, size: 16, color: Colors.white70),
                        const SizedBox(width: 8),
                        Text(
                          timeStr,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary)),
                onPressed: () => Navigator.pop(ctx),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ref.read(accentColorProvider),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Add', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
                onPressed: () {
                  final label = controller.text.trim();
                  if (label.isNotEmpty) {
                    ref.read(remindersProvider.notifier).addCustomReminder(label, timeStr);
                  }
                  Navigator.pop(ctx);
                },
              ),
            ],
          );
        },
      ),
    );
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
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => _showRenameReminderDialog(context, key, reminder.label),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    reminder.label,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(Icons.edit_rounded, color: Colors.white.withOpacity(0.4), size: 12),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            ref.read(remindersProvider.notifier).deleteReminder(key);
                          },
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: AppTheme.accentCoral,
                            size: 16,
                          ),
                        ),
                      ],
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
    Color color, {
    TextInputType keyboardType = TextInputType.number,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fieldBg = isDark
        ? const Color(0xFF141618)
        : Colors.black.withOpacity(0.015);
    final fieldBorder = isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder;
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
        keyboardType: keyboardType,
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
        ? const Color(0xFF141618)
        : Colors.black.withOpacity(0.015);
    final fieldBorder = isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;

    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          decoration: BoxDecoration(
            color: fieldBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: fieldBorder, width: 1.0),
          ),
          child: MenuAnchor(
            style: MenuStyle(
              backgroundColor: WidgetStateProperty.all(isDark ? const Color(0xFF141618) : Colors.white),
              surfaceTintColor: WidgetStateProperty.all(Colors.transparent),
              elevation: WidgetStateProperty.all(8),
              shadowColor: WidgetStateProperty.all(Colors.black.withOpacity(isDark ? 0.5 : 0.15)),
              shape: WidgetStateProperty.all(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: fieldBorder, width: 1.0),
                ),
              ),
              minimumSize: WidgetStateProperty.all(Size(constraints.maxWidth, 0)),
              maximumSize: WidgetStateProperty.all(Size(constraints.maxWidth, 400)),
            ),
            builder: (context, controller, child) {
              IconData? itemIcon;
              final normalized = selectedVal.toLowerCase();
              if (normalized == 'lose') {
                itemIcon = Icons.trending_down_rounded;
              } else if (normalized == 'gain') {
                itemIcon = Icons.fitness_center_rounded;
              } else if (normalized == 'maintain') {
                itemIcon = Icons.balance_rounded;
              } else if (normalized == 'sedentary') {
                itemIcon = Icons.chair_rounded;
              } else if (normalized == 'light') {
                itemIcon = Icons.directions_walk_rounded;
              } else if (normalized == 'moderate') {
                itemIcon = Icons.fitness_center_rounded;
              } else if (normalized == 'very') {
                itemIcon = Icons.bolt_rounded;
              } else if (normalized == 'male') {
                itemIcon = Icons.male_rounded;
              } else if (normalized == 'female') {
                itemIcon = Icons.female_rounded;
              } else if (normalized == 'other') {
                itemIcon = Icons.transgender_rounded;
              }

              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (controller.isOpen) {
                    controller.close();
                  } else {
                    controller.open();
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Icon(icon, color: color, size: 18),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              label,
                              style: const TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                if (itemIcon != null) ...[
                                  Icon(itemIcon, color: color, size: 16),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  selectedVal.toUpperCase(),
                                  style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        controller.isOpen ? Icons.arrow_drop_up_rounded : Icons.arrow_drop_down_rounded,
                        color: textColor.withOpacity(0.6),
                      ),
                    ],
                  ),
                ),
              );
            },
            menuChildren: items.map((type) {
              IconData? itemIcon;
              final normalized = type.toLowerCase();
              if (normalized == 'lose') {
                itemIcon = Icons.trending_down_rounded;
              } else if (normalized == 'gain') {
                itemIcon = Icons.fitness_center_rounded;
              } else if (normalized == 'maintain') {
                itemIcon = Icons.balance_rounded;
              } else if (normalized == 'sedentary') {
                itemIcon = Icons.chair_rounded;
              } else if (normalized == 'light') {
                itemIcon = Icons.directions_walk_rounded;
              } else if (normalized == 'moderate') {
                itemIcon = Icons.fitness_center_rounded;
              } else if (normalized == 'very') {
                itemIcon = Icons.bolt_rounded;
              } else if (normalized == 'male') {
                itemIcon = Icons.male_rounded;
              } else if (normalized == 'female') {
                itemIcon = Icons.female_rounded;
              } else if (normalized == 'other') {
                itemIcon = Icons.transgender_rounded;
              }

              return MenuItemButton(
                onPressed: () {
                  onChanged(type);
                },
                leadingIcon: itemIcon != null ? Icon(itemIcon, color: color, size: 16) : null,
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(const EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
                ),
                child: Text(
                  type.toUpperCase(),
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }

  Widget _buildAccentColorPicker() {
    final colors = [
      const Color(0xFFD9FF00), // Neon Lime (Default)
      const Color(0xFF00E5FF), // Cyan
      const Color(0xFFB026FF), // Purple
      const Color(0xFFFF9100), // Orange
      const Color(0xFFFF4081), // Pink
      const Color(0xFF2979FF), // Blue
      const Color(0xFFFF1744), // Red
    ];
    final colorNames = [
      'Neon Lime',
      'Cyan',
      'Purple',
      'Orange',
      'Pink',
      'Blue',
      'Red',
    ];
    final selectedIdx = ref.watch(accentColorIndexProvider);

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: colors.length,
        itemBuilder: (context, index) {
          final isSelected = selectedIdx == index;
          final color = colors[index];
          return GestureDetector(
            onTap: () {
              ref.read(accentColorIndexProvider.notifier).state = index;
              StorageService.saveAccentColorIndex(index);
              FirebaseService.saveSettingsCloud();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Accent color changed to ${colorNames[index]} (Preview)'),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: isSelected
                    ? Border.all(
                        color: Colors.white,
                        width: 3.0,
                      )
                    : Border.all(
                        color: Colors.white.withOpacity(0.2),
                        width: 1.0,
                      ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: color.withOpacity(0.6),
                          blurRadius: 8,
                          spreadRadius: 2,
                        )
                      ]
                    : null,
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.black,
                      size: 18,
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 16, bottom: 4),
      child: Text(
        title,
        style: TextStyle(
          color: isDark ? Colors.white : AppTheme.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w900,
          letterSpacing: -0.3,
        ),
      ),
    );
  }


  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF141618) : Colors.white;
    final dialogBorder = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEADBFF);
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
          'Sign Out?',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'You will be signed out of your account. Your health logs are saved in the cloud and will be restored when you sign in again.',
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
              backgroundColor: AppTheme.accentCyan,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Sign Out',
              style: TextStyle(
                color: Color(0xFF0E0F0C),
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (ctx.mounted) {
                ctx.go('/auth');
              }
              await ref.read(profileProvider.notifier).clearProfile();
              _calController.clear();
              _protController.clear();
              _watController.clear();
            },
          ),
        ],
      ),
    );
  }

  void _showWipeLogsDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF141618) : Colors.white;
    final dialogBorder = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEADBFF);
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
          'Wipe Local Logs?',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'This will permanently delete your locally stored user profile, daily metrics, and workouts cache. It will not delete your cloud account.',
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
              backgroundColor: AppTheme.accentOrange,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Wipe Logs',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (ctx.mounted) {
                ctx.go('/auth');
              }
              // Wipe local data without signing out of Firebase
              await StorageService.clearAllData();
              ref.invalidate(profileProvider);
              ref.invalidate(workoutHistoryProvider);
              ref.invalidate(pinnedWidgetsProvider);
              ref.invalidate(remindersProvider);
              ref.invalidate(profilePictureProvider);
              ref.invalidate(customBackgroundProvider);

              _calController.clear();
              _protController.clear();
              _watController.clear();
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF141618) : Colors.white;
    final dialogBorder = isDark ? const Color(0xFF2C2C2E) : const Color(0xFFEADBFF);
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
          'Delete Account Forever?',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        content: const Text(
          'WARNING: This action is permanent and cannot be undone. All your profile settings, workout history, and cloud logs will be deleted forever.',
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
              'Delete Forever',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            onPressed: () async {
              Navigator.of(ctx).pop();
              if (ctx.mounted) {
                ctx.go('/auth');
              }
              try {
                await FirebaseService.deleteUserAccountForever();
                ref.invalidate(profileProvider);
                ref.invalidate(workoutHistoryProvider);
                ref.invalidate(pinnedWidgetsProvider);
                ref.invalidate(remindersProvider);
                ref.invalidate(profilePictureProvider);
                ref.invalidate(customBackgroundProvider);

                _calController.clear();
                _protController.clear();
                _watController.clear();
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Failed to delete account: $e')),
                  );
                }
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

