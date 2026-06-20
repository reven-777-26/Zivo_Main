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

    // Use absolute layout sizes to prevent glitchy jumps when layout content size fluctuates
    return SizedBox(
      width: 280,
      height: 330,
      child: Center(
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
            const SizedBox(height: 20),

            // 2. Category detected indicator (conditionally shown, keeping space stable)
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              child: categoryHeader.isNotEmpty
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141618) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? const Color(0xFF2C2C2E) : Colors.black.withOpacity(0.06),
                          width: 1.0,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            categoryHeader,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFD9FF00),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            categorySubtitle,
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark ? Colors.white60 : AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),

            // 3. Step Progression Card - match the food log card style exactly (SS1 & SS2)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              width: 260,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141618) : Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isDark ? const Color(0xFF2C2C2E) : Colors.black.withOpacity(0.06),
                  width: 1.0,
                ),
              ),
              child: Column(
                children: [
                  SizedBox(
                    height: 20,
                    child: AnimatedSwitcher(
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
                  ),
                  const SizedBox(height: 8),
                  // Progress Bar
                  Container(
                    width: 200,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white24 : Colors.black12,
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Stack(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 1400),
                          width: 200 * ((_currentStep + 1) / _steps.length),
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
                    const SizedBox(height: 8),
                    Text(
                      widget.progressMessage,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white38 : Colors.black38,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 4. Rotating Facts Section
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                  SizedBox(
                    height: 40,
                    child: AnimatedSwitcher(
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
                        key: ValueKey<String>(activeFactsList[factIndex]),
                        width: double.infinity,
                        child: Text(
                          activeFactsList[factIndex],
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: isDark ? Colors.white70 : AppTheme.textSecondary,
                          ),
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
