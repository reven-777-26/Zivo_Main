import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter/cupertino.dart';
import '../../core/theme.dart';
import '../../core/health_math.dart';
import '../../core/logo_widget.dart';
import '../../models/user_profile.dart';
import '../../services/state_providers.dart';
import '../../services/storage_service.dart';


class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;
  final int _totalSteps =
      8; // Welcome, Goal, Gender, Age, Height, Weight, Activity, Finish

  // Onboarding Form State
  String _selectedGoal = 'lose'; // 'lose', 'gain', 'maintain'
  String _gender = 'male'; // 'male', 'female', 'other'
  int _age = 25;
  double _height = 175.0; // cm
  double _weight = 70.0; // kg
  String _selectedActivity =
      'moderate'; // 'sedentary', 'light', 'moderate', 'very'

  bool get isDark => Theme.of(context).brightness == Brightness.dark;
  Color get textColor => isDark ? Colors.white : AppTheme.textPrimary;
  Color get textMutedColor => isDark ? Colors.white70 : const Color(0xFF575856);
  Color get bgColor => isDark ? const Color(0xFF0E0F0C) : AppTheme.obsidianBackground;

  Color getEffectiveColor(Color inputColor) {
    if (isDark) return inputColor;
    if (inputColor == AppTheme.accentCyan) return const Color(0xFF5C9E00); // Mapped Lime Green
    if (inputColor == AppTheme.accentOrange) return const Color(0xFFC75A00); // Mapped Orange
    if (inputColor == AppTheme.accentCoral) return const Color(0xFFB31B20); // Mapped Coral Red
    return inputColor;
  }

  // Text Editing Controllers for Direct Typing
  late TextEditingController _dayController;
  late TextEditingController _monthController;
  late TextEditingController _yearController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;

  DateTime _selectedDob = DateTime(2000, 1, 1);

  // Summary Targets (calculated on activity complete)
  HealthTargets? _calculatedTargets;
  bool _calculating = false;

  @override
  void initState() {
    super.initState();
    _dayController = TextEditingController(text: '01');
    _monthController = TextEditingController(text: '01');
    _yearController = TextEditingController(text: '2000');
    _heightController = TextEditingController(text: _height.round().toString());
    _weightController = TextEditingController(text: _weight.toStringAsFixed(0));
    _age = 26; // Default computed age for Jan 1, 2000 in 2026
  }

  @override
  void dispose() {
    _dayController.dispose();
    _monthController.dispose();
    _yearController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _pageController.dispose();
    super.dispose();
  }



  void _nextPage() {
    if (_currentStep < _totalSteps - 1) {
      if (_currentStep == 6) {
        _runCalculations();
      }

      setState(() {
        _currentStep++;
      });
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutQuad,
      );
    }
  }

  void _prevPage() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
      });
      _pageController.previousPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutQuad,
      );
    }
  }

  Future<void> _runCalculations() async {
    setState(() {
      _calculating = true;
    });

    await Future.delayed(const Duration(milliseconds: 1200));

    final targets = HealthMath.calculateTargets(
      goal: _selectedGoal,
      age: _age,
      weight: _weight,
      height: _height,
      activityLevel: _selectedActivity,
      gender: _gender,
    );

    setState(() {
      _calculatedTargets = targets;
      _calculating = false;
    });
  }

  Future<void> _finishOnboarding() async {
    if (_calculatedTargets == null) return;

    final profile = UserProfile(
      goal: _selectedGoal,
      age: _age,
      weight: _weight,
      height: _height,
      activityLevel: _selectedActivity,
      calorieGoal: _calculatedTargets!.calorieGoal,
      proteinGoal: _calculatedTargets!.proteinGoal,
      waterGoal: _calculatedTargets!.waterGoal,
      gender: _gender,
    );

    // Save DOB string to StorageService
    final dobStr = "${_dayController.text.padLeft(2, '0')}/${_monthController.text.padLeft(2, '0')}/${_yearController.text}";
    await StorageService.saveDob(dobStr);

    await StorageService.saveCarbsGoal(_calculatedTargets!.carbGoal);
    await StorageService.saveFatsGoal(_calculatedTargets!.fatGoal);
    await ref.read(profileProvider.notifier).saveProfile(profile);
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Container(
        color: bgColor,
        child: SafeArea(
          child: Column(
            children: [
              // Top Navigation / Progress Indicator
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_currentStep > 0 && _currentStep < _totalSteps - 1)
                      IconButton(
                        icon: Icon(
                          Icons.arrow_back_ios_rounded,
                          color: isDark ? AppTheme.textSecondary : const Color(0xFF575856),
                        ),
                        onPressed: _prevPage,
                      )
                    else
                      const SizedBox(width: 48, height: 48),

                    // Linear Progress Indicator
                    if (_currentStep > 0)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Stack(
                            children: [
                              Container(
                                height: 6,
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withOpacity(0.12) : const Color(0xFFD2D2D7),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                height: 6,
                                width:
                                    MediaQuery.of(context).size.width *
                                    ((_currentStep) / (_totalSteps - 1)) *
                                    0.65,
                                decoration: BoxDecoration(
                                  color: isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    if (_currentStep > 0 && _currentStep < _totalSteps - 1)
                      TextButton(
                        onPressed: _nextPage,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: isDark ? AppTheme.textSecondary : const Color(0xFF575856),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 48, height: 48),
                  ],
                ),
              ),

              // Page Content
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildWelcomeStep(),
                    _buildGoalStep(),
                    _buildGenderStep(),
                    _buildAgeStep(),
                    _buildHeightStep(),
                    _buildWeightStep(),
                    _buildActivityStep(),
                    _buildFinishStep(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==========================================
  // STEP BUILDERS
  // ==========================================

  // Step 1: Welcome Screen
  Widget _buildWelcomeStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          // SVG Logo from assets
          SvgPicture.asset(
            'assets/Logo.svg',
            width: 140,
            height: 140,
          )
          .animate()
          .scale(duration: 800.ms, curve: Curves.elasticOut),
          const SizedBox(height: 36),
          
          Text(
            'Welcome. Track Smarter. Live Better.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: textMutedColor,
              height: 1.5,
            ),
          )
          .animate()
          .fadeIn(delay: 300.ms, duration: 600.ms)
          .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
          const Spacer(),
          // Begin button
          GestureDetector(
            onTap: _nextPage,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00),
                borderRadius: BorderRadius.circular(24), // rounded.xl (24px)
              ),
              child: Center(
                child: Text(
                  'Start Setup',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF0E0F0C) : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildGoalStep() {
    Widget buildGoalCard(
      String title,
      String goalKey,
      String desc,
      IconData icon,
    ) {
      final isSelected = _selectedGoal == goalKey;
      return GestureDetector(
        onTap: () {
          setState(() {
            _selectedGoal = goalKey;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark
                ? (isSelected ? const Color(0xFF272C24) : const Color(0xFF1C1E1B))
                : (isSelected ? const Color(0xFFF4FAD2) : AppTheme.glassBackground),
            borderRadius: BorderRadius.circular(24), // rounded.xl (24px)
            border: Border.all(
              color: isSelected 
                  ? (isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00)) 
                  : (isDark ? const Color(0xFF323530) : const Color(0xFFD2D2D7)),
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? (isDark ? AppTheme.accentCyan.withOpacity(0.24) : const Color(0xFFE2F6D5))
                      : (isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF0F2EE)),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? (isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00))
                      : textMutedColor,
                  size: 24,
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? (isDark ? AppTheme.accentCyan : const Color(0xFF163300))
                            : textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 12,
                        color: textMutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00),
                  size: 24,
                ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Primary Goal',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textColor),
          ),
          const SizedBox(height: 6),
          Text(
            'We will calibrate calories and macronutrient splits based on your focus.',
            style: TextStyle(color: textMutedColor, fontSize: 14),
          ),
          const SizedBox(height: 28),
          buildGoalCard(
            'Fat Loss',
            'lose',
            'Calorie deficit with high protein retention.',
            Icons.trending_down_rounded,
          ),
          buildGoalCard(
            'Muscle Gain',
            'gain',
            'Calorie surplus with high volume weight logs.',
            Icons.fitness_center_rounded,
          ),
          buildGoalCard(
            'Maintenance',
            'maintain',
            'Balance calorie expenditure perfectly.',
            Icons.balance_rounded,
          ),
          const Spacer(),
          _buildNextButton(),
        ],
      ),
    );
  }

  Widget _buildGenderStep() {
    Widget buildGenderCard(String label, String key, IconData icon) {
      final isSelected = _gender == key;
      return GestureDetector(
        onTap: () {
          setState(() {
            _gender = key;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: isDark
                ? (isSelected ? const Color(0xFF272C24) : const Color(0xFF1C1E1B))
                : (isSelected ? const Color(0xFFF4FAD2) : AppTheme.glassBackground),
            borderRadius: BorderRadius.circular(24), // rounded.xl (24px)
            border: Border.all(
              color: isSelected 
                  ? (isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00)) 
                  : (isDark ? const Color(0xFF323530) : const Color(0xFFD2D2D7)),
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? (isDark ? AppTheme.accentCyan.withOpacity(0.12) : const Color(0xFFE2F6D5))
                      : (isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF0F2EE)),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? (isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00))
                      : textMutedColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? (isDark ? AppTheme.accentCyan : const Color(0xFF163300))
                      : textColor,
                ),
              ),
              const Spacer(),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00),
                  size: 24,
                ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Gender',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textColor),
          ),
          const SizedBox(height: 6),
          Text(
            'Gender is used for metabolic and baseline BMR equations.',
            style: TextStyle(color: textMutedColor, fontSize: 14),
          ),
          const SizedBox(height: 28),
          buildGenderCard('Male', 'male', Icons.male_rounded),
          buildGenderCard('Female', 'female', Icons.female_rounded),
          buildGenderCard('Other', 'other', Icons.transgender_rounded),
          const Spacer(),
          _buildNextButton(),
        ],
      ),
    );
  }

  // Step 4: Age Input (Calculated from Date of Birth Scroller)
  Widget _buildAgeStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'When is Your Birthday?',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textColor),
          ),
          const SizedBox(height: 6),
          Text(
            'We use your date of birth to calculate your age and BMR.',
            style: TextStyle(color: textMutedColor, fontSize: 14),
          ),
          const Spacer(),
          Center(
            child: GlassCard(
              width: 320,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'DATE OF BIRTH',
                        style: TextStyle(
                          color: textMutedColor,
                          fontSize: 11,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  CupertinoTheme(
                    data: CupertinoThemeData(
                      brightness: isDark ? Brightness.dark : Brightness.light,
                      textTheme: CupertinoTextThemeData(
                        dateTimePickerTextStyle: TextStyle(
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    child: SizedBox(
                      height: 160,
                      child: CupertinoDatePicker(
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: _selectedDob,
                        minimumDate: DateTime(1920),
                        maximumDate: DateTime.now(),
                        onDateTimeChanged: (DateTime newDate) {
                          setState(() {
                            _selectedDob = newDate;
                            _age = DateTime.now().year - newDate.year;
                            if (DateTime.now().month < newDate.month ||
                                (DateTime.now().month == newDate.month && DateTime.now().day < newDate.day)) {
                              _age--;
                            }
                            _dayController.text = newDate.day.toString().padLeft(2, '0');
                            _monthController.text = newDate.month.toString().padLeft(2, '0');
                            _yearController.text = newDate.year.toString();
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Calculated Age Display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: (isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00)).withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: (isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00)).withOpacity(0.2),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Calculated Age: ',
                          style: TextStyle(fontSize: 13, color: textMutedColor, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '$_age years',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Spacer(),
          _buildNextButton(),
        ],
      ),
    );
  }

  // Step 5: Height Input
  Widget _buildHeightStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Set Your Height',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textColor),
          ),
          const SizedBox(height: 6),
          Text(
            'Enter your height in centimeters.',
            style: TextStyle(color: textMutedColor, fontSize: 14),
          ),
          const Spacer(),

          // Dual Typing Card
          GlassCard(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.height_rounded,
                  color: AppTheme.accentCyan,
                  size: 28,
                ),
                const SizedBox(width: 12),

                // Typing TextField
                Container(
                  width: 90,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withOpacity(0.4) : const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF323530) : const Color(0xFFC4C6C2), width: 1.0),
                  ),
                  child: TextField(
                    controller: _heightController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? AppTheme.accentCyan : const Color(0xFF163300),
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                    ),
                    onChanged: (text) {
                      final val = double.tryParse(text);
                      if (val != null && val >= 100.0 && val <= 230.0) {
                        setState(() {
                          _height = val;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'cm',
                  style: TextStyle(
                    fontSize: 16,
                    color: textMutedColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Synced slider
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00),
              inactiveTrackColor: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFD2D2D7),
              thumbColor: isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00),
              overlayColor: (isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00)).withOpacity(0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              trackHeight: 4,
            ),
            child: Slider(
              value: _height,
              min: 100.0,
              max: 230.0,
              onChanged: (val) {
                setState(() {
                  _height = val;
                  _heightController.text = _height.round().toString();
                });
              },
            ),
          ),
          const Spacer(),
          _buildNextButton(),
        ],
      ),
    );
  }

  // Step 6: Weight Input
  Widget _buildWeightStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Specify Your Weight',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textColor),
          ),
          const SizedBox(height: 6),
          Text(
            'This establishes protein targets and TDEE calculation.',
            style: TextStyle(color: textMutedColor, fontSize: 14),
          ),
          const Spacer(),

          // Dual Typing Card
          GlassCard(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.scale_rounded,
                  color: AppTheme.accentCyan,
                  size: 28,
                ),
                const SizedBox(width: 12),

                // Typing TextField
                Container(
                  width: 90,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.black.withOpacity(0.4) : const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF323530) : const Color(0xFFC4C6C2), width: 1.0),
                  ),
                  child: TextField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isDark ? AppTheme.accentCyan : const Color(0xFF163300),
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 4),
                    ),
                    onChanged: (text) {
                      final val = double.tryParse(text);
                      if (val != null && val >= 30.0 && val <= 180.0) {
                        setState(() {
                          _weight = val;
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'kg',
                  style: TextStyle(
                    fontSize: 16,
                    color: textMutedColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Synced weight slider
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00),
              inactiveTrackColor: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFD2D2D7),
              thumbColor: isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00),
              overlayColor: (isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00)).withOpacity(0.12),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
              trackHeight: 4,
            ),
            child: Slider(
              value: _weight,
              min: 30.0,
              max: 180.0,
              onChanged: (val) {
                setState(() {
                  _weight = val;
                  _weightController.text = _weight.round().toString();
                });
              },
            ),
          ),
          const Spacer(),
          _buildNextButton(),
        ],
      ),
    );
  }

  // Step 7: Activity Selection
  Widget _buildActivityStep() {
    Widget buildActivityCard(
      String title,
      String activityKey,
      String desc,
      IconData icon,
    ) {
      final isSelected = _selectedActivity == activityKey;
      return GestureDetector(
        onTap: () {
          setState(() {
            _selectedActivity = activityKey;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? (isSelected ? const Color(0xFF272C24) : const Color(0xFF1C1E1B))
                : (isSelected ? const Color(0xFFF4FAD2) : AppTheme.glassBackground),
            borderRadius: BorderRadius.circular(24), // rounded.xl (24px)
            border: Border.all(
              color: isSelected 
                  ? (isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00)) 
                  : (isDark ? const Color(0xFF323530) : const Color(0xFFD2D2D7)),
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? (isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00))
                    : textMutedColor,
                size: 22,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? (isDark ? AppTheme.accentCyan : const Color(0xFF163300))
                            : textColor,
                      ),
                    ),
                    Text(
                      desc,
                      style: TextStyle(
                        fontSize: 11,
                        color: textMutedColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(
                  Icons.check_circle_rounded,
                  color: isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00),
                  size: 20,
                ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Activity Multiplier',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textColor),
          ),
          const SizedBox(height: 6),
          Text(
            'Calibrates active calories burnt based on weekly energy levels.',
            style: TextStyle(color: textMutedColor, fontSize: 14),
          ),
          const SizedBox(height: 20),
          buildActivityCard(
            'Sedentary',
            'sedentary',
            'Office work, little to no gym logging.',
            Icons.chair_rounded,
          ),
          buildActivityCard(
            'Light Activity',
            'light',
            'Gym session 1-2 times weekly.',
            Icons.directions_walk_rounded,
          ),
          buildActivityCard(
            'Moderate Volume',
            'moderate',
            'Gym session 3-5 times weekly.',
            Icons.fitness_center_rounded,
          ),
          buildActivityCard(
            'Highly Active',
            'very',
            'Heavy lifting / athletes 6+ times weekly.',
            Icons.bolt_rounded,
          ),
          const Spacer(),
          _buildNextButton(),
        ],
      ),
    );
  }

  // Step 8: Calculation Summary Screen
  Widget _buildFinishStep() {
    if (_calculating) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00)),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'INTEGRATING PERFORMANCE SYSTEM',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00),
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms),
            const SizedBox(height: 8),
            Text(
              'Computing calories, water indices, and sets arrays...',
              style: TextStyle(color: textMutedColor, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final targets =
        _calculatedTargets ??
        HealthTargets(
          bmr: 1800,
          tdee: 2200,
          calorieGoal: 2000,
          proteinGoal: 130,
          carbGoal: 220,
          fatGoal: 65,
          waterGoal: 2500,
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Calibration Integrated',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: textColor),
          ),
          const SizedBox(height: 6),
          Text(
            'Your metabolic baseline has been integrated successfully.',
            style: TextStyle(color: textMutedColor, fontSize: 14),
          ),
          const SizedBox(height: 24),

          // Calorie target Card
          _buildDetailTargetCard(
            'Daily Calorie Budget',
            '${targets.calorieGoal} kcal',
            '${_selectedGoal.toUpperCase()} FOCUS',
            Icons.bolt_rounded,
            AppTheme.accentCoral,
          ),
          const SizedBox(height: 14),

          // Protein Target Card
          _buildDetailTargetCard(
            'Daily Protein Target',
            '${targets.proteinGoal} grams',
            '${(targets.proteinGoal * 4).round()} kcal focus',
            Icons.fitness_center_rounded,
            AppTheme.accentOrange,
          ),
          const SizedBox(height: 14),

          // Water Target Card
          _buildDetailTargetCard(
            'Daily Hydration Target',
            '${(targets.waterGoal / 1000).toStringAsFixed(1)} Liters',
            '${(targets.waterGoal / 1000.0).toStringAsFixed(1)} ltr',
            Icons.local_drink_rounded,
            AppTheme.accentCyan,
          ),

          const Spacer(),

          // Finish button
          GestureDetector(
            onTap: _finishOnboarding,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00),
                borderRadius: BorderRadius.circular(24), // rounded.xl (24px)
              ),
              child: Center(
                child: Text(
                  'Launch Workspace',
                  style: TextStyle(
                    color: isDark ? const Color(0xFF0E0F0C) : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ==========================================
  // SHARED ONBOARDING COMPONENTS
  // ==========================================

  Widget _buildNextButton() {
    return GestureDetector(
      onTap: _nextPage,
      child: Container(
        width: double.infinity,
        height: 54,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.accentCyan : const Color(0xFF5C9E00),
          borderRadius: BorderRadius.circular(24), // rounded.xl (24px)
        ),
        child: Center(
          child: Text(
            'Continue Integration',
            style: TextStyle(
              color: isDark ? const Color(0xFF0E0F0C) : Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoundAdjuster(IconData icon, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFFFFFFF),
          border: Border.all(color: isDark ? const Color(0xFF323530) : const Color(0xFFC4C6C2), width: 1.0),
        ),
        child: Icon(icon, color: textColor, size: 20),
      ),
    );
  }

  Widget _buildDetailTargetCard(
    String title,
    String value,
    String subvalue,
    IconData icon,
    Color color,
  ) {
    final displayColor = getEffectiveColor(color);
    return GlassCard(
      width: double.infinity,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: displayColor.withOpacity(isDark ? 0.08 : 0.12),
            ),
            child: Icon(icon, color: displayColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: textMutedColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.02) : displayColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isDark ? const Color(0xFF323530) : displayColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Text(
              subvalue,
              style: TextStyle(
                color: displayColor,
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
