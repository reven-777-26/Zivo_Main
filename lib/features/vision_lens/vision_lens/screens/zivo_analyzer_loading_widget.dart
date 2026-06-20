import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../../../../core/widgets/zivo_loader.dart';

class ZivoAnalyzerLoadingWidget extends StatefulWidget {
  final String progressMessage;
  const ZivoAnalyzerLoadingWidget({
    super.key,
    required this.progressMessage,
  });

  @override
  State<ZivoAnalyzerLoadingWidget> createState() => _ZivoAnalyzerLoadingWidgetState();
}

class _ZivoAnalyzerLoadingWidgetState extends State<ZivoAnalyzerLoadingWidget> {
  int _currentStep = 0;
  int _currentFact = 0;
  Timer? _stepTimer;
  Timer? _factTimer;

  final List<String> _steps = [
    "🔍 Identifying product...",
    "📋 Reading ingredient list...",
    "🧪 Analyzing ingredients...",
    "⚠️ Checking for controversial additives...",
    "🌎 Comparing international regulations...",
    "🧠 Generating Zivo Health Score...",
    "📊 Preparing recommendations...",
  ];

  // Rotating facts based on detected category
  final List<String> _generalFacts = [
    "Zivo Analyzer scans labels to flag controversial ingredients instantly.",
    "Different countries have different regulations for food and cosmetic ingredients.",
    "Zivo scores are based on scientific evidence and international safety data.",
    "Always check the active ingredients list over front-of-package marketing claims.",
  ];

  final List<String> _foodFacts = [
    "Ingredients are listed by quantity.",
    "Added sugars can appear under dozens of different names.",
    "The first 3 ingredients often reveal product quality.",
    "Marketing claims can be misleading.",
  ];

  final List<String> _supplementFacts = [
    "More ingredients does not always mean a better supplement.",
    "Proprietary blends may hide exact ingredient amounts.",
    "Third-party testing can be a strong quality indicator.",
    "Dosage matters more than ingredient count.",
  ];

  final List<String> _skincareFacts = [
    "Ingredients are listed in descending concentration order.",
    "Active ingredients matter more than packaging claims.",
    "Fragrance may contain multiple undisclosed compounds.",
    "Patch testing can help identify sensitivities.",
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
          _currentFact++;
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

  String _detectCategory() {
    final msg = widget.progressMessage.toLowerCase();
    if (msg.contains("food") || msg.contains("snack") || msg.contains("drink") || msg.contains("eat") || msg.contains("sugar")) {
      return "food";
    }
    if (msg.contains("supplement") || msg.contains("vitamin") || msg.contains("pill") || msg.contains("tablet") || msg.contains("capsule")) {
      return "supplement";
    }
    if (msg.contains("skincare") || msg.contains("cosmetic") || msg.contains("cream") || msg.contains("lotion") || msg.contains("serum") || msg.contains("shampoo")) {
      return "skincare";
    }
    return "general";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final category = _detectCategory();

    List<String> activeFactsList;
    String categoryHeader = "";
    String categorySubtitle = "";

    if (category == "food") {
      activeFactsList = _foodFacts;
      categoryHeader = "🍎 Food detected";
      categorySubtitle = "Checking sugars, additives and processing level...";
    } else if (category == "supplement") {
      activeFactsList = _supplementFacts;
      categoryHeader = "💊 Supplement detected";
      categorySubtitle = "Checking ingredient quality and transparency...";
    } else if (category == "skincare") {
      activeFactsList = _skincareFacts;
      categoryHeader = "🧴 Skincare detected";
      categorySubtitle = "Checking active ingredients and potential irritants...";
    } else {
      activeFactsList = _generalFacts;
    }

    final factIndex = _currentFact % activeFactsList.length;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. Sonar style loader (style: 2)
          const ZivoLoader(
            size: 76,
            style: 2,
            strokeWidth: 2.5,
          ),
          const SizedBox(height: 32),

          // 2. Category detected indicator (conditionally shown)
          if (categoryHeader.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: const Color(0xFFD9FF00).withOpacity(0.10),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(
                  color: const Color(0xFFD9FF00).withOpacity(0.3),
                  width: 1.0,
                ),
              ),
              child: Column(
                children: [
                  Text(
                    categoryHeader,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFD9FF00),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    categorySubtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // 3. Step Progression Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            width: 280,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withOpacity(0.04) : Colors.black.withOpacity(0.02),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.white.withOpacity(0.06) : Colors.black.withOpacity(0.04),
                width: 1.0,
              ),
            ),
            child: Column(
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: Text(
                    _steps[_currentStep],
                    key: ValueKey<int>(_currentStep),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : AppTheme.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Progress Bar
                Container(
                  width: 220,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : Colors.black12,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: Stack(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 1400),
                        width: 220 * ((_currentStep + 1) / _steps.length),
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFFD9FF00),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
                if (widget.progressMessage.isNotEmpty && !widget.progressMessage.startsWith("AI is analyzing")) ...[
                  const SizedBox(height: 10),
                  Text(
                    widget.progressMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 36),

          // 4. Rotating Facts Section
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            constraints: const BoxConstraints(minHeight: 48),
            child: Column(
              children: [
                Text(
                  "ZIVO INSIGHTS",
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w900,
                    color: isDark ? const Color(0xFFD9FF00) : AppTheme.accentCyan,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: Text(
                    activeFactsList[factIndex],
                    key: ValueKey<String>(activeFactsList[factIndex]),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: isDark ? Colors.white70 : AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
