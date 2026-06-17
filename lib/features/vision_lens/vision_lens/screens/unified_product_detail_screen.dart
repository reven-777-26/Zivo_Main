import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme.dart';
import '../../../../services/state_providers.dart';
import '../../shared/providers/unified_vision_provider.dart';
import '../../shared/services/unified_vision_service.dart';
import '../../shared/services/vision_recommendation_engine.dart';

class UnifiedProductDetailScreen extends ConsumerStatefulWidget {
  final String? barcode;

  const UnifiedProductDetailScreen({
    super.key,
    required this.barcode,
  });

  @override
  ConsumerState<UnifiedProductDetailScreen> createState() => _UnifiedProductDetailScreenState();
}

class _UnifiedProductDetailScreenState extends ConsumerState<UnifiedProductDetailScreen> {
  int _selectedAlternativeIndex = 0;
  final Set<String> _expandedIngredients = {};

  Color _getGradeColor(String grade, bool isDark) {
    switch (grade.toUpperCase()) {
      case 'A':
      case 'B':
        return isDark ? AppTheme.accentEmerald : const Color(0xFF054D28);
      case 'C':
      case 'D':
        return isDark ? const Color(0xFFFFC091) : const Color(0xFFB86700);
      case 'E':
        return AppTheme.accentCoral;
      default:
        return AppTheme.textSecondary;
    }
  }

  Color _getSafetyColor(String safety, bool isDark) {
    switch (safety.toLowerCase()) {
      case 'safe':
        return isDark ? AppTheme.accentEmerald : const Color(0xFF054D28);
      case 'caution':
        return isDark ? const Color(0xFFFFC091) : const Color(0xFFB86700);
      case 'avoid':
        return AppTheme.accentCoral;
      default:
        return AppTheme.textSecondary;
    }
  }

  Widget _buildProductImage(String? url, String category) {
    final placeholder = Container(
      color: Colors.black.withOpacity(0.3),
      child: Center(
        child: Text(
          category.toLowerCase() == 'skincare' ? '🧴' : (category.toLowerCase() == 'supplement' ? '💊' : '🍔'),
          style: const TextStyle(fontSize: 40),
        ),
      ),
    );

    if (url == null || url.isEmpty) {
      return placeholder;
    }

    if (url.startsWith('data:image/') || url.contains(';base64,')) {
      try {
        String clean = url;
        final commaIndex = url.indexOf(',');
        if (commaIndex != -1) {
          clean = url.substring(commaIndex + 1);
        }
        final bytes = base64Decode(clean.replaceAll(RegExp(r'\s+'), ''));
        return Image.memory(bytes, fit: BoxFit.cover);
      } catch (_) {
        return placeholder;
      }
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => placeholder,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Center(
          child: CircularProgressIndicator(
            value: progress.expectedTotalBytes != null
                ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                : null,
            strokeWidth: 2,
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
          ),
        );
      },
    );
  }

  Widget _buildBrandLogo(String storeName) {
    String logoDomain = '';
    Color fallbackBg = Colors.grey;

    switch (storeName.toLowerCase()) {
      case 'blinkit':
        logoDomain = 'blinkit.com';
        fallbackBg = const Color(0xFFF7CB15);
        break;
      case 'swiggy instamart':
      case 'swiggy':
        logoDomain = 'swiggy.com';
        fallbackBg = const Color(0xFFFF5200);
        break;
      case 'zepto':
        logoDomain = 'zeptonow.com';
        fallbackBg = const Color(0xFF702A82);
        break;
      case 'amazon':
        logoDomain = 'amazon.in';
        fallbackBg = const Color(0xFF232F3E);
        break;
      case 'nykaa':
        logoDomain = 'nykaa.com';
        fallbackBg = const Color(0xFFFC2779);
        break;
      case 'myntra':
        logoDomain = 'myntra.com';
        fallbackBg = const Color(0xFFE71C56);
        break;
      case 'flipkart':
        logoDomain = 'flipkart.com';
        fallbackBg = const Color(0xFF2874F0);
        break;
      case 'bigbasket':
        logoDomain = 'bigbasket.com';
        fallbackBg = const Color(0xFF81C784);
        break;
      case 'jiomart':
        logoDomain = 'jiomart.com';
        fallbackBg = const Color(0xFF003399);
        break;
      default:
        logoDomain = '';
        fallbackBg = Colors.blueGrey;
    }

    if (logoDomain.isEmpty) {
      return Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(shape: BoxShape.circle, color: fallbackBg),
        child: const Icon(Icons.storefront_rounded, size: 12, color: Colors.white),
      );
    }

    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        'https://logo.clearbit.com/$logoDomain',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: fallbackBg,
          child: Center(
            child: Text(
              storeName.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
            ),
          ),
        ),
      ),
    );
  }

  Color _getBrandBgColor(String storeName) {
    switch (storeName.toLowerCase()) {
      case 'amazon':
        return const Color(0xFFFF9900);
      case 'flipkart':
        return const Color(0xFF2874F0);
      case 'blinkit':
        return const Color(0xFFF7CB15);
      case 'zepto':
        return const Color(0xFF702A82);
      case 'swiggy instamart':
        return const Color(0xFFFF5200);
      case 'nykaa':
        return const Color(0xFFFC2779);
      case 'myntra':
        return const Color(0xFFE71C56);
      case 'bigbasket':
        return const Color(0xFF689F38);
      case 'jiomart':
        return const Color(0xFF0C529C);
      default:
        return const Color(0xFF1E293B);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visionState = ref.watch(unifiedVisionProvider);
    final accentColor = ref.watch(accentColorProvider);

    return visionState.currentReport.when(
      data: (report) {
        if (report == null) {
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF000000) : AppTheme.obsidianBackground,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppTheme.textPrimary),
                onPressed: () => Navigator.pop(context),
              ),
            ),
            body: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
              ),
            ),
          );
        }
        final gradeColor = _getGradeColor(report.healthGrade, isDark);

        // Safely bounds-check selected alternative
        if (_selectedAlternativeIndex >= report.alternatives.length) {
          _selectedAlternativeIndex = 0;
        }

        // Get dynamic links for the selected alternative (or current product if none available)
        final String searchTarget = report.alternatives.isNotEmpty
            ? '${report.alternatives[_selectedAlternativeIndex].brand} ${report.alternatives[_selectedAlternativeIndex].name}'
            : '${report.brand} ${report.productName}';
        final storeLinks = VisionRecommendationEngine.getLinksForCategory(
          category: report.category,
          query: searchTarget,
        );

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF000000) : AppTheme.obsidianBackground,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: isDark ? Colors.white : AppTheme.textPrimary),
              onPressed: () {
                ref.read(unifiedVisionProvider.notifier).resetCurrentReport();
                Navigator.pop(context);
              },
            ),
            title: Text(
              'ZIVO ANALYSER',
              style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimary, fontWeight: FontWeight.w900, fontSize: 15, letterSpacing: 1.5),
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SECTION 1: Product Header Display + Grade & Verdict
                GlassCard(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _buildProductImage(report.imageUrl, report.category),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isDark ? AppTheme.accentCyan : const Color(0xFF0E0F0C)).withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(9999),
                                    border: Border.all(
                                      color: (isDark ? AppTheme.accentCyan : const Color(0xFF0E0F0C)).withOpacity(0.15),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Text(
                                    report.category.toUpperCase(),
                                    style: TextStyle(
                                      color: isDark ? AppTheme.accentCyan : const Color(0xFF0E0F0C),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  report.productName,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppTheme.textPrimary,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  report.brand,
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Container(
                        height: 1,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppTheme.glassBorder.withOpacity(0.1),
                              isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
                              AppTheme.glassBorder.withOpacity(0.1),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 78,
                                height: 78,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: gradeColor.withOpacity(0.06),
                                  boxShadow: [
                                    BoxShadow(
                                      color: gradeColor.withOpacity(0.2),
                                      blurRadius: 24,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 78,
                                height: 78,
                                child: CircularProgressIndicator(
                                  value: () {
                                    switch (report.healthGrade.toUpperCase()) {
                                      case 'A': return 1.0;
                                      case 'B': return 0.8;
                                      case 'C': return 0.6;
                                      case 'D': return 0.4;
                                      case 'E': return 0.2;
                                      default: return 0.0;
                                    }
                                  }(),
                                  strokeWidth: 4,
                                  backgroundColor: isDark ? const Color(0xFF1C1C1E) : Colors.black.withOpacity(0.05),
                                  valueColor: AlwaysStoppedAnimation<Color>(gradeColor),
                                ),
                              ),
                              Text(
                                report.healthGrade,
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppTheme.textPrimary,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  shadows: [
                                    Shadow(
                                      color: gradeColor.withOpacity(0.4),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: gradeColor,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'VERDICT',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  report.verdict,
                                  style: TextStyle(
                                    color: isDark ? Colors.white.withOpacity(0.9) : AppTheme.textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    height: 1.4,
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
                const SizedBox(height: 24),

                // SECTION 1.5: Allergy Warnings Banner
                if (report.allergyWarnings.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 24),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCoral.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppTheme.accentCoral.withOpacity(0.25),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.accentCoral.withOpacity(0.02),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppTheme.accentCoral.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: AppTheme.accentCoral,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            const Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ALLERGY WARNINGS',
                                    style: TextStyle(
                                      color: AppTheme.accentCoral,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Potential allergens detected in this product',
                                    style: TextStyle(
                                      color: AppTheme.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        ...report.allergyWarnings.map((warning) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: (isDark ? Colors.white : AppTheme.textPrimary).withOpacity(0.03),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: (isDark ? Colors.white : AppTheme.textPrimary).withOpacity(0.05),
                                  width: 1.0,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: AppTheme.accentCoral,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      warning,
                                      style: TextStyle(
                                        color: isDark ? Colors.white : AppTheme.textPrimary,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ],

                // SECTION 2: Key Insights (Max 5 items)
                if (report.insights.isNotEmpty) ...[
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 12,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'KEY INSIGHTS',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: report.insights.map((insight) {
                      Color color = accentColor;
                      if (insight.contains('❌')) {
                        color = AppTheme.accentCoral;
                      } else if (insight.contains('⚠') || insight.contains('⚠️')) {
                        color = AppTheme.accentOrange;
                      } else if (insight.contains('✅')) {
                        color = AppTheme.accentEmerald;
                      }

                      final emojiRegex = RegExp(r'^([❌⚠️⚠✅])\s*');
                      final match = emojiRegex.firstMatch(insight);
                      String cleanText = insight;
                      String? emoji;
                      if (match != null) {
                        emoji = match.group(1);
                        cleanText = insight.substring(match.end);
                      }

                      return Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(
                            color: color.withOpacity(0.15),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: color.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (emoji != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: color.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: color.withOpacity(0.15),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    emoji,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                                const SizedBox(width: 14),
                              ],
                              Expanded(
                                child: Text(
                                  cleanText,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppTheme.textPrimary,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),
                ],

                // SECTION 3: Healthier Alternatives (Top 3 large cards)
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: AppTheme.accentCyan,
                        borderRadius: BorderRadius.all(Radius.circular(2)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'HEALTHIER ALTERNATIVES',
                      style: TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (report.alternatives.isEmpty)
                  GlassCard(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28),
                    child: Center(
                      child: Text(
                        'No healthier alternatives found for this category.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  )
                else
                  Column(
                    children: List.generate(report.alternatives.length, (index) {
                      final alt = report.alternatives[index];
                      final isSelected = _selectedAlternativeIndex == index;
                      final altGradeColor = _getGradeColor(alt.healthGrade, isDark);

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedAlternativeIndex = index;
                            });
                          },
                          borderRadius: BorderRadius.circular(26),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? const Color(0xFF14171A) : Colors.white)
                                  : (isDark ? Colors.white.withOpacity(0.02) : Colors.black.withOpacity(0.012)),
                              borderRadius: BorderRadius.circular(26),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.accentCyan
                                    : (isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                                width: isSelected ? 1.8 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.accentCyan.withOpacity(0.12),
                                        blurRadius: 20,
                                        spreadRadius: 1,
                                      )
                                    ]
                                  : null,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    AnimatedScale(
                                      scale: isSelected ? 1.1 : 1.0,
                                      duration: const Duration(milliseconds: 150),
                                      child: Icon(
                                        isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                                        color: isSelected
                                            ? AppTheme.accentCyan
                                            : AppTheme.textSecondary.withOpacity(0.6),
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            alt.name,
                                            style: TextStyle(
                                              color: isDark ? Colors.white : AppTheme.textPrimary,
                                              fontSize: 16,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            alt.brand,
                                            style: TextStyle(
                                              color: AppTheme.textSecondary.withOpacity(0.7),
                                              fontSize: 11,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: altGradeColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(9999),
                                        border: Border.all(
                                          color: altGradeColor.withOpacity(0.25),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Text(
                                        alt.healthGrade,
                                        style: TextStyle(
                                          color: altGradeColor,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Padding(
                                  padding: const EdgeInsets.only(left: 34.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: alt.reason
                                        .split('\n')
                                        .where((line) => line.trim().isNotEmpty)
                                        .map((bullet) => Padding(
                                              padding: const EdgeInsets.only(bottom: 8.0),
                                              child: Row(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Container(
                                                    margin: const EdgeInsets.only(top: 2),
                                                    padding: const EdgeInsets.all(2),
                                                    decoration: BoxDecoration(
                                                      color: AppTheme.accentCyan.withOpacity(0.12),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: const Icon(
                                                      Icons.check_rounded,
                                                      color: AppTheme.accentCyan,
                                                      size: 10,
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      bullet,
                                                      style: TextStyle(
                                                        color: isDark ? Colors.white.withOpacity(0.85) : AppTheme.textPrimary,
                                                        fontSize: 13,
                                                        height: 1.35,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ))
                                        .toList(),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                const SizedBox(height: 24),

                // SECTION 4: Buy Better Alternatives (Dynamic platform links)
                if (report.alternatives.isNotEmpty) ...[
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isDark ? accentColor : const Color(0xFF054D28),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'BUY ${report.alternatives[_selectedAlternativeIndex].name.toUpperCase()} ON:',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: storeLinks.map((link) {
                      final brandBgColor = _getBrandBgColor(link.storeName);
                      return InkWell(
                        onTap: () => VisionRecommendationEngine.launchSearchLink(link.searchUrl),
                        borderRadius: BorderRadius.circular(9999),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF141618) : Colors.white,
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: brandBgColor.withOpacity(0.06),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: brandBgColor,
                                  boxShadow: [
                                    BoxShadow(
                                      color: brandBgColor.withOpacity(0.6),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              _buildBrandLogo(link.storeName),
                              const SizedBox(width: 8),
                              Text(
                                link.storeName,
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                ],

                // SECTION 5: Collapsed Accordion (View Full Analysis)
                Theme(
                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.glassBackground.withOpacity(0.04) : AppTheme.glassBackground,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ExpansionTile(
                      title: Row(
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            color: isDark ? Colors.white70 : AppTheme.textPrimary,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            'View Full Analysis',
                            style: TextStyle(
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                      iconColor: isDark ? Colors.white70 : AppTheme.textPrimary,
                      collapsedIconColor: isDark ? Colors.white70 : AppTheme.textPrimary,
                      childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      children: [
                        Container(
                          margin: const EdgeInsets.only(bottom: 20),
                          height: 1,
                          color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
                        ),

                        // Bento Metrics for food/supplement
                        if (report.category.toLowerCase() != 'skincare') ...[
                          LayoutBuilder(
                            builder: (context, constraints) {
                              final isMobile = constraints.maxWidth < 450;
                              if (isMobile) {
                                return Column(
                                  children: [
                                    _buildBentoCard(
                                      title: 'Added Sugars',
                                      status: report.sugarAnalysis.impact,
                                      description: report.sugarAnalysis.amount,
                                      accentColor: _getStatusColor(report.sugarAnalysis.impact, isDark),
                                      icon: Icons.cookie_outlined,
                                      isDark: isDark,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildBentoCard(
                                      title: 'Palm Oil',
                                      status: report.palmOilAnalysis.present ? 'Present' : 'Clean',
                                      description: report.palmOilAnalysis.present ? '❌ Avoid palm oil usage' : '✅ Safe (No palm oil)',
                                      accentColor: _getStatusColor(report.palmOilAnalysis.present ? 'present' : 'clean', isDark),
                                      icon: Icons.eco_outlined,
                                      isDark: isDark,
                                    ),
                                    const SizedBox(height: 12),
                                    _buildBentoCard(
                                      title: 'Carbohydrate Level',
                                      status: report.carbsAnalysis.impact,
                                      description: report.carbsAnalysis.verdict,
                                      accentColor: _getStatusColor(report.carbsAnalysis.impact, isDark),
                                      icon: Icons.donut_large_rounded,
                                      isDark: isDark,
                                    ),
                                  ],
                                );
                              } else {
                                return Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _buildBentoCard(
                                            title: 'Added Sugars',
                                            status: report.sugarAnalysis.impact,
                                            description: report.sugarAnalysis.amount,
                                            accentColor: _getStatusColor(report.sugarAnalysis.impact, isDark),
                                            icon: Icons.cookie_outlined,
                                            isDark: isDark,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildBentoCard(
                                            title: 'Palm Oil',
                                            status: report.palmOilAnalysis.present ? 'Present' : 'Clean',
                                            description: report.palmOilAnalysis.present ? '❌ Avoid palm oil usage' : '✅ Safe (No palm oil)',
                                            accentColor: _getStatusColor(report.palmOilAnalysis.present ? 'present' : 'clean', isDark),
                                            icon: Icons.eco_outlined,
                                            isDark: isDark,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    _buildBentoCard(
                                      title: 'Carbohydrate Level',
                                      status: report.carbsAnalysis.impact,
                                      description: report.carbsAnalysis.verdict,
                                      accentColor: _getStatusColor(report.carbsAnalysis.impact, isDark),
                                      icon: Icons.donut_large_rounded,
                                      isDark: isDark,
                                    ),
                                  ],
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 24),
                        ],

                        // Decoded Ingredient List
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 10,
                              decoration: BoxDecoration(
                                color: isDark ? accentColor : const Color(0xFF054D28),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'DECODED INGREDIENTS',
                              style: TextStyle(
                                color: AppTheme.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (report.decodedIngredients.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16.0),
                            child: Text(
                              'No ingredients list found in database.',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                            ),
                          )
                        else
                          Column(
                            children: report.decodedIngredients.map((ing) {
                              final safetyColor = _getSafetyColor(ing.safety, isDark);
                              final isExpanded = _expandedIngredients.contains(ing.name);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF16181A) : Colors.black.withOpacity(0.015),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
                                    width: 1.0,
                                  ),
                                ),
                                child: Theme(
                                  data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                                  child: ExpansionTile(
                                    key: PageStorageKey(ing.name),
                                    initiallyExpanded: isExpanded,
                                    onExpansionChanged: (expanded) {
                                      setState(() {
                                        if (expanded) {
                                          _expandedIngredients.add(ing.name);
                                        } else {
                                          _expandedIngredients.remove(ing.name);
                                        }
                                      });
                                    },
                                    leading: Container(
                                      width: 6,
                                      height: 22,
                                      decoration: BoxDecoration(
                                        color: safetyColor,
                                        borderRadius: BorderRadius.circular(3),
                                        boxShadow: [
                                          BoxShadow(
                                            color: safetyColor.withOpacity(0.4),
                                            blurRadius: 6,
                                          ),
                                        ],
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            ing.name,
                                            style: TextStyle(
                                              color: isDark ? Colors.white : AppTheme.textPrimary,
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                        if (ing.sneakyNameFor != 'None')
                                          Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppTheme.accentCoral.withOpacity(0.08),
                                              borderRadius: BorderRadius.circular(9999),
                                              border: Border.all(
                                                color: AppTheme.accentCoral.withOpacity(0.2),
                                                width: 1.0,
                                              ),
                                            ),
                                            child: Text(
                                              'Sneaky ${ing.sneakyNameFor}',
                                              style: const TextStyle(
                                                color: AppTheme.accentCoral,
                                                fontSize: 8,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      ing.meaning,
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: safetyColor.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(9999),
                                        border: Border.all(
                                          color: safetyColor.withOpacity(0.25),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Text(
                                        ing.safety.toUpperCase(),
                                        style: TextStyle(
                                          color: safetyColor,
                                          fontSize: 9,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            ing.description,
                                            style: TextStyle(
                                              color: isDark ? Colors.white70 : AppTheme.textSecondary,
                                              fontSize: 12,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : AppTheme.obsidianBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(accentColor)),
              const SizedBox(height: 16),
              const Text(
                'Analyzing with AI Health Decision Engine...',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
              )
            ],
          ),
        ),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: isDark ? const Color(0xFF000000) : AppTheme.obsidianBackground,
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline_rounded, color: AppTheme.accentCoral, size: 48),
                const SizedBox(height: 16),
                Text(
                  err.toString(),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: AppTheme.textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () {
                    ref.read(unifiedVisionProvider.notifier).resetCurrentReport();
                    Navigator.pop(context);
                  },
                  child: const Text('Back to Scanner', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String statusText, bool isDark) {
    final lower = statusText.toLowerCase();
    if (lower.contains('high') || lower.contains('present') || lower.contains('avoid')) {
      return AppTheme.accentCoral;
    } else if (lower.contains('moderate') || lower.contains('caution') || lower.contains('warning')) {
      return isDark ? const Color(0xFFFFC091) : const Color(0xFFB86700);
    } else {
      return isDark ? AppTheme.accentEmerald : const Color(0xFF054D28);
    }
  }

  Widget _buildBentoCard({
    required String title,
    required String status,
    required String description,
    required Color accentColor,
    required IconData icon,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16181A) : AppTheme.glassBackground,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: accentColor,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            status,
            style: TextStyle(
              color: accentColor,
              fontSize: 16,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              color: isDark ? Colors.white70 : AppTheme.textSecondary,
              fontSize: 12,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
