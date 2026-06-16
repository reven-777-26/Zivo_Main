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
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 84,
                            height: 84,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder, width: 1.5),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _buildProductImage(report.imageUrl, report.category),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
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
                                  '${report.brand} • ${report.category.toUpperCase()}',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary.withOpacity(0.8),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: gradeColor, width: 1.5), // hairline
                              color: gradeColor.withOpacity(0.08),
                            ),
                            child: Center(
                              child: Text(
                                report.healthGrade,
                                style: TextStyle(
                                  color: gradeColor,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900, // heavy
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'VERDICT',
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  report.verdict,
                                  style: TextStyle(
                                    color: isDark ? Colors.white : AppTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    height: 1.35,
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCoral.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(24), // rounded.xl
                      border: Border.all(color: AppTheme.accentCoral.withOpacity(0.2), width: 1.0), // hairline
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.accentCoral,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ALLERGY WARNINGS',
                                style: TextStyle(
                                  color: AppTheme.accentCoral,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.5,
                                ),
                              ),
                              const SizedBox(height: 6),
                              ...report.allergyWarnings.map((warning) => Padding(
                                    padding: const EdgeInsets.only(bottom: 4),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('• ', style: TextStyle(color: isDark ? Colors.white : AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
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
                    ),
                  ),
                ],

                // SECTION 2: Key Insights (Max 5 items)
                if (report.insights.isNotEmpty) ...[
                  const Text(
                    'KEY INSIGHTS',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
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
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(24), // rounded.xl
                          border: Border.all(color: color.withOpacity(0.15), width: 1.0), // hairline
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (emoji != null) ...[
                              Text(
                                emoji,
                                style: const TextStyle(fontSize: 14),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                cleanText,
                                style: TextStyle(
                                  color: isDark ? color : (color == accentColor ? const Color(0xFF054D28) : color),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),
                ],

                // SECTION 3: Healthier Alternatives (Top 3 large cards)
                const Text(
                  'HEALTHIER ALTERNATIVES',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                if (report.alternatives.isEmpty)
                  GlassCard(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 24),
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
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedAlternativeIndex = index;
                            });
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? (isDark ? const Color(0xFF1C1E1B) : AppTheme.glassBackground)
                                  : (isDark ? Colors.white.withOpacity(0.02) : AppTheme.glassBackground.withOpacity(0.4)),
                              borderRadius: BorderRadius.circular(24), // rounded.xl
                              border: Border.all(
                                color: isSelected
                                    ? (isDark ? accentColor : const Color(0xFF054D28))
                                    : (isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                                width: 1.0, // Hairline
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                                      color: isSelected
                                          ? (isDark ? accentColor : const Color(0xFF054D28))
                                          : AppTheme.textSecondary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        alt.name,
                                        style: TextStyle(
                                          color: isDark ? Colors.white : AppTheme.textPrimary,
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isDark ? altGradeColor.withOpacity(0.12) : const Color(0xFFE2F6D5),
                                        borderRadius: BorderRadius.circular(9999), // pill shape
                                        border: Border.all(color: isDark ? altGradeColor.withOpacity(0.3) : const Color(0xFFC5EDAB)),
                                      ),
                                      child: Text(
                                        'Grade ${alt.healthGrade}',
                                        style: TextStyle(
                                          color: isDark ? altGradeColor : const Color(0xFF054D28),
                                          fontSize: 10,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.only(left: 30.0),
                                  child: Text(
                                    alt.brand,
                                    style: TextStyle(
                                      color: AppTheme.textSecondary.withOpacity(0.8),
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Padding(
                                  padding: const EdgeInsets.only(left: 30.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: alt.reason
                                        .split('\n')
                                        .where((line) => line.trim().isNotEmpty)
                                        .map((bullet) => Padding(
                                              padding: const EdgeInsets.only(bottom: 4.0),
                                              child: Text(
                                                bullet,
                                                style: TextStyle(
                                                  color: isDark ? Colors.white : AppTheme.textPrimary,
                                                  fontSize: 12.5,
                                                  height: 1.3,
                                                ),
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
                  Text(
                    'BUY ${report.alternatives[_selectedAlternativeIndex].name.toUpperCase()} ON:',
                    style: TextStyle(
                      color: isDark ? accentColor : const Color(0xFF054D28),
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: storeLinks.map((link) {
                      return InkWell(
                        onTap: () => VisionRecommendationEngine.launchSearchLink(link.searchUrl),
                        borderRadius: BorderRadius.circular(9999), // pill shape
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? accentColor.withOpacity(0.12) : const Color(0xFFE2F6D5),
                            borderRadius: BorderRadius.circular(9999), // pill shape
                            border: Border.all(
                              color: isDark ? accentColor.withOpacity(0.3) : const Color(0xFFC5EDAB),
                              width: 1.0, // hairline
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildBrandLogo(link.storeName),
                              const SizedBox(width: 8),
                              Text(
                                link.storeName,
                                style: TextStyle(
                                  color: isDark ? accentColor : const Color(0xFF054D28),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600, // semibold
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
                      color: isDark ? AppTheme.glassBackground.withOpacity(0.05) : AppTheme.glassBackground,
                      borderRadius: BorderRadius.circular(24), // rounded.xl
                      border: Border.all(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder, width: 1.0), // hairline
                    ),
                    child: ExpansionTile(
                      title: Text(
                        'View Full Analysis',
                        style: TextStyle(
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                      iconColor: isDark ? Colors.white : AppTheme.textPrimary,
                      collapsedIconColor: isDark ? Colors.white : AppTheme.textPrimary,
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      children: [
                        Divider(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder, height: 1),
                        const SizedBox(height: 16),

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
                                    const SizedBox(height: 10),
                                    _buildBentoCard(
                                      title: 'Palm Oil',
                                      status: report.palmOilAnalysis.present ? 'Present' : 'Clean',
                                      description: report.palmOilAnalysis.present ? '❌ Avoid palm oil usage' : '✅ Safe (No palm oil)',
                                      accentColor: _getStatusColor(report.palmOilAnalysis.present ? 'present' : 'clean', isDark),
                                      icon: Icons.eco_outlined,
                                      isDark: isDark,
                                    ),
                                    const SizedBox(height: 10),
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
                                        const SizedBox(width: 10),
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
                                    const SizedBox(height: 10),
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
                          const SizedBox(height: 20),
                        ],

                        // Decoded Ingredient List
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'DECODED INGREDIENTS',
                            style: TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

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
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1C1E1B) : AppTheme.obsidianBackground.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
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
                                      height: 20,
                                      decoration: BoxDecoration(
                                        color: safetyColor,
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                    ),
                                    title: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            ing.name,
                                            style: TextStyle(
                                              color: isDark ? Colors.white : AppTheme.textPrimary,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        if (ing.sneakyNameFor != 'None')
                                          Container(
                                            margin: const EdgeInsets.only(left: 6),
                                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                            decoration: BoxDecoration(
                                              color: AppTheme.accentCoral.withOpacity(0.12),
                                              borderRadius: BorderRadius.circular(9999), // pill shape
                                            ),
                                            child: Text(
                                              'Sneaky ${ing.sneakyNameFor}',
                                              style: const TextStyle(color: AppTheme.accentCoral, fontSize: 8, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                      ],
                                    ),
                                    subtitle: Text(
                                      ing.meaning,
                                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11),
                                    ),
                                    trailing: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: safetyColor.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(9999), // pill shape
                                        border: Border.all(color: safetyColor.withOpacity(0.2)),
                                      ),
                                      child: Text(
                                        ing.safety.toUpperCase(),
                                        style: TextStyle(color: safetyColor, fontSize: 8, fontWeight: FontWeight.w900),
                                      ),
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            ing.description,
                                            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 11.5, height: 1.35),
                                          ),
                                        ),
                                      )
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),

                        const SizedBox(height: 16),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1E1B) : AppTheme.glassBackground,
        borderRadius: BorderRadius.circular(24), // rounded.xl (24px)
        border: Border.all(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder, width: 1.0),
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
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                ),
              ),
              Icon(
                icon,
                color: accentColor.withOpacity(0.6),
                size: 16,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            status,
            style: TextStyle(
              color: accentColor,
              fontSize: 14,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              color: isDark ? Colors.white70 : AppTheme.textSecondary,
              fontSize: 11.5,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}
