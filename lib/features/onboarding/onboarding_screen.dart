import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme.dart';
import '../../core/health_math.dart';
import '../../core/logo_widget.dart';
import '../../models/user_profile.dart';
import '../../services/state_providers.dart';

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

  // Text Editing Controllers for Direct Typing
  late TextEditingController _ageController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;

  // Summary Targets (calculated on activity complete)
  HealthTargets? _calculatedTargets;
  bool _calculating = false;

  @override
  void initState() {
    super.initState();
    _ageController = TextEditingController(text: _age.toString());
    _heightController = TextEditingController(text: _height.round().toString());
    _weightController = TextEditingController(text: _weight.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _ageController.dispose();
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

    await ref.read(profileProvider.notifier).saveProfile(profile);
    if (mounted) {
      context.go('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.obsidianBackground,
      body: Container(
        color: AppTheme.obsidianBackground,
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
                        icon: const Icon(
                          Icons.arrow_back_ios_rounded,
                          color: AppTheme.textSecondary,
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
                                  color: AppTheme.accentCyan,
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
                        child: const Text(
                          'Skip',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
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
          // Zivo circular-Z logo
          const ZivoLogoWidget(size: 96)
              .animate()
              .scale(duration: 800.ms, curve: Curves.elasticOut),
          const SizedBox(height: 28),
          
          // App Title (ZivoFit) in Heavy Display Weight
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                fontFamily: 'Outfit',
                letterSpacing: -0.8,
              ),
              children: [
                TextSpan(
                  text: 'Zivo',
                  style: TextStyle(color: isDark ? const Color(0xFFE8EBE6) : AppTheme.textPrimary),
                ),
                TextSpan(
                  text: 'Fit',
                  style: const TextStyle(color: Color(0xFFB2D300)),
                ),
              ],
            ),
          )
          .animate()
          .fadeIn(delay: 200.ms, duration: 600.ms)
          .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
          const SizedBox(height: 16),
          
          const Text(
            'Welcome to ZivoFit. Log exercises with rapid gym presets, configure calorie splits, and track nutrient balances in an immersive dark theme.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          )
          .animate()
          .fadeIn(delay: 400.ms, duration: 600.ms)
          .slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
          const Spacer(),
          // Begin button
          GestureDetector(
            onTap: _nextPage,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                color: AppTheme.accentCyan,
                borderRadius: BorderRadius.circular(24), // rounded.xl (24px)
              ),
              child: const Center(
                child: Text(
                  'Start Setup',
                  style: TextStyle(
                    color: Color(0xFF0E0F0C), // Ink Black
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

  // Step 2: Goal Selection
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
                : AppTheme.glassBackground,
            borderRadius: BorderRadius.circular(24), // rounded.xl (24px)
            border: Border.all(
              color: isSelected ? AppTheme.accentCyan : (isDark ? const Color(0xFF323530) : AppTheme.glassBorder),
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
                      ? AppTheme.accentCyan.withOpacity(0.24)
                      : (isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFF0F2EE)),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? (isDark ? AppTheme.accentCyan : const Color(0xFF163300))
                      : AppTheme.textSecondary,
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
                            : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.accentCyan,
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
          const Text(
            'Select Primary Goal',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'We will calibrate calories and macronutrient splits based on your focus.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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

  // Step 3: Gender Selection [NEW]
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
                : AppTheme.glassBackground,
            borderRadius: BorderRadius.circular(24), // rounded.xl (24px)
            border: Border.all(
              color: isSelected ? AppTheme.accentCyan : (isDark ? const Color(0xFF323530) : AppTheme.glassBorder),
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
                      ? AppTheme.accentCyan.withOpacity(0.12)
                      : Colors.white.withOpacity(0.04),
                ),
                child: Icon(
                  icon,
                  color: isSelected
                      ? AppTheme.accentCyan
                      : AppTheme.textSecondary,
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
                      : AppTheme.textPrimary,
                ),
              ),
              const Spacer(),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.accentCyan,
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
          const Text(
            'Select Gender',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Gender is used for metabolic and baseline BMR equations.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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

  // Step 4: Age Input
  Widget _buildAgeStep() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'How Old Are You?',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Age is used to compute basal metabolic rate (BMR).',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const Spacer(),
          Center(
            child: GlassCard(
              width: 260,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
              child: Column(
                children: [
                  const Text(
                    'YEARS',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Direct keyboard typing synced
                  Container(
                    width: 120,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.black.withOpacity(0.4) : const Color(0xFFF0F2EE),
                      borderRadius: BorderRadius.circular(12), // rounded.md (12px)
                      border: Border.all(
                        color: isDark ? const Color(0xFF323530) : AppTheme.glassBorder,
                        width: 1.2,
                      ),
                    ),
                    child: TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w900,
                        color: isDark ? AppTheme.accentCyan : const Color(0xFF163300),
                      ),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 4),
                      ),
                      onChanged: (text) {
                        final val = int.tryParse(text);
                        if (val != null && val >= 10 && val <= 100) {
                          setState(() {
                            _age = val;
                          });
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Quick selectors
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildRoundAdjuster(Icons.remove, () {
                        if (_age > 10) {
                          setState(() {
                            _age--;
                            _ageController.text = _age.toString();
                          });
                        }
                      }),
                      _buildRoundAdjuster(Icons.add, () {
                        if (_age < 100) {
                          setState(() {
                            _age++;
                            _ageController.text = _age.toString();
                          });
                        }
                      }),
                    ],
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
          const Text(
            'Set Your Height',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Enter your height in centimeters.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
                    color: isDark ? Colors.black.withOpacity(0.4) : const Color(0xFFF0F2EE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF323530) : AppTheme.glassBorder, width: 1.0),
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
                const Text(
                  'cm',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
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
              activeTrackColor: AppTheme.accentCyan,
              inactiveTrackColor: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFD2D2D7),
              thumbColor: AppTheme.accentCyan,
              overlayColor: AppTheme.accentCyan.withOpacity(0.12),
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
          const Text(
            'Specify Your Weight',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'This establishes protein targets and TDEE calculation.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
                    color: isDark ? Colors.black.withOpacity(0.4) : const Color(0xFFF0F2EE),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? const Color(0xFF323530) : AppTheme.glassBorder, width: 1.0),
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
                const Text(
                  'kg',
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary,
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
              activeTrackColor: AppTheme.accentCyan,
              inactiveTrackColor: isDark ? Colors.white.withOpacity(0.04) : const Color(0xFFD2D2D7),
              thumbColor: AppTheme.accentCyan,
              overlayColor: AppTheme.accentCyan.withOpacity(0.12),
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
                : AppTheme.glassBackground,
            borderRadius: BorderRadius.circular(24), // rounded.xl (24px)
            border: Border.all(
              color: isSelected ? AppTheme.accentCyan : (isDark ? const Color(0xFF323530) : AppTheme.glassBorder),
              width: isSelected ? 2.0 : 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: isSelected
                    ? AppTheme.accentCyan
                    : AppTheme.textSecondary,
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
                            : AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.accentCyan,
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
          const Text(
            'Activity Multiplier',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Calibrates active calories burnt based on weekly energy levels.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
            const SizedBox(
              width: 56,
              height: 56,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'INTEGRATING PERFORMANCE SYSTEM',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
                color: AppTheme.accentCyan,
              ),
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms),
            const SizedBox(height: 8),
            const Text(
              'Computing calories, water indices, and sets arrays...',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
          const Text(
            'Calibration Integrated',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text(
            'Your metabolic baseline has been integrated successfully.',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
                color: AppTheme.accentCyan,
                borderRadius: BorderRadius.circular(24), // rounded.xl (24px)
              ),
              child: const Center(
                child: Text(
                  'Launch Workspace',
                  style: TextStyle(
                    color: Color(0xFF0E0F0C), // Ink Black
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
          color: AppTheme.accentCyan,
          borderRadius: BorderRadius.circular(24), // rounded.xl (24px)
        ),
        child: const Center(
          child: Text(
            'Continue Integration',
            style: TextStyle(
              color: Color(0xFF0E0F0C), // Ink Black
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
          border: Border.all(color: isDark ? const Color(0xFF323530) : AppTheme.glassBorder, width: 1.0),
        ),
        child: Icon(icon, color: AppTheme.textPrimary, size: 20),
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
    return GlassCard(
      width: double.infinity,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.08),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.02) : const Color(0xFFF0F2EE),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: isDark ? const Color(0xFF323530) : AppTheme.glassBorder, width: 1),
            ),
            child: Text(
              subvalue,
              style: TextStyle(
                color: color == AppTheme.accentCyan ? (isDark ? AppTheme.accentCyan : const Color(0xFF163300)) : color,
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
