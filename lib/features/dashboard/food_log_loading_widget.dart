import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../../core/widgets/zivo_loader.dart';

class FoodLogLoadingWidget extends StatefulWidget {
  const FoodLogLoadingWidget({super.key});

  @override
  State<FoodLogLoadingWidget> createState() => _FoodLogLoadingWidgetState();
}

class _FoodLogLoadingWidgetState extends State<FoodLogLoadingWidget> {
  int _currentStep = 0;
  int _currentFact = 0;
  Timer? _stepTimer;
  Timer? _factTimer;

  final List<String> _steps = [
    "📸 Analyzing meal...",
    "🍽️ Detecting food items...",
    "📏 Estimating portion sizes...",
    "🔥 Calculating calories...",
    "💪 Analyzing protein, carbs & fats...",
    "📊 Preparing nutrition summary...",
  ];

  final List<String> _facts = [
    "Protein helps preserve muscle during weight loss.",
    "Fiber-rich foods may improve satiety.",
    "Portion size is one of the biggest factors affecting calorie intake.",
    "Most people underestimate food portions.",
    "Whole foods are generally more filling than ultra-processed foods.",
  ];

  @override
  void initState() {
    super.initState();
    // Advance progress steps every 1.5 seconds
    _stepTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (mounted) {
        setState(() {
          if (_currentStep < _steps.length - 1) {
            _currentStep++;
          } else {
            _stepTimer?.cancel();
          }
        });
      }
    });

    // Rotate facts every 2.5 seconds
    _factTimer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (mounted) {
        setState(() {
          _currentFact = (_currentFact + 1) % _facts.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _stepTimer?.cancel();
    _factTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 1. Sonar style loader (style: 2)
            const ZivoLoader(
              size: 54,
              style: 2,
              strokeWidth: 2.2,
            ),
            const SizedBox(height: 16),
            
            // 2. Active Step Indicator Card
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              width: 240,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                  width: 1.0,
                ),
              ),
              child: Column(
                children: [
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                      return Stack(
                        alignment: Alignment.center,
                        children: <Widget>[
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    child: SizedBox(
                      key: ValueKey<int>(_currentStep),
                      width: double.infinity,
                      child: Text(
                        _steps[_currentStep],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Progress Bar Indicator
                  Container(
                    width: 180,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 1400),
                          width: 180 * ((_currentStep + 1) / _steps.length),
                          height: 4,
                          decoration: BoxDecoration(
                            color: const Color(0xFFD9FF00),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
  
            // 3. Rotating Facts section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              constraints: const BoxConstraints(minHeight: 40),
              child: Column(
                children: [
                  Text(
                    "DID YOU KNOW?",
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w900,
                      color: isDark ? const Color(0xFFD9FF00) : AppTheme.accentCyan,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    layoutBuilder: (Widget? currentChild, List<Widget> previousChildren) {
                      return Stack(
                        alignment: Alignment.topCenter,
                        children: <Widget>[
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(opacity: animation, child: child);
                    },
                    child: SizedBox(
                      key: ValueKey<int>(_currentFact),
                      width: double.infinity,
                      child: Text(
                        _facts[_currentFact],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: isDark ? Colors.white70 : AppTheme.textSecondary,
                        ),
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
}
