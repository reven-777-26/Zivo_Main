import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme.dart';
import '../../../../services/state_providers.dart';
import '../../shared/providers/unified_vision_provider.dart';
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

  // ─────────────────── Color helpers ───────────────────

  Color _getGradeColor(String grade, bool isDark) {
    switch (grade.toUpperCase()) {
      case 'A':
      case 'B':
        return isDark ? AppTheme.accentEmerald : const Color(0xFF054D28);
      case 'C':
      case 'D':
        return isDark ? const Color(0xFFFF9F0A) : const Color(0xFFD87000);
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

  // ─────────────────── Image helper ───────────────────

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
    if (url == null || url.isEmpty) return placeholder;
    if (url.startsWith('data:image/') || url.contains(';base64,')) {
      try {
        String clean = url;
        final commaIndex = url.indexOf(',');
        if (commaIndex != -1) clean = url.substring(commaIndex + 1);
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

  // ─────────────────── Brand Logo ───────────────────

  Color _getBrandBgColor(String storeName) {
    switch (storeName.toLowerCase()) {
      case 'amazon':       return const Color(0xFFFF9900);
      case 'flipkart':     return const Color(0xFF2874F0);
      case 'blinkit':      return const Color(0xFFF7CB15);
      case 'zepto':        return const Color(0xFF702A82);
      case 'swiggy instamart':
      case 'swiggy':       return const Color(0xFFFF5200);
      case 'nykaa':        return const Color(0xFFFC2779);
      case 'myntra':       return const Color(0xFFE71C56);
      case 'bigbasket':    return const Color(0xFF689F38);
      case 'jiomart':      return const Color(0xFF0C529C);
      default:             return const Color(0xFF1E293B);
    }
  }

  String _getBrandDomain(String storeName) {
    switch (storeName.toLowerCase()) {
      case 'blinkit':            return 'blinkit.com';
      case 'swiggy instamart':
      case 'swiggy':             return 'swiggy.com';
      case 'zepto':              return 'zeptonow.com';
      case 'amazon':             return 'amazon.in';
      case 'nykaa':              return 'nykaa.com';
      case 'myntra':             return 'myntra.com';
      case 'flipkart':           return 'flipkart.com';
      case 'bigbasket':          return 'bigbasket.com';
      case 'jiomart':            return 'jiomart.com';
      default:                   return '';
    }
  }

  Widget _buildBrandLogo(String storeName) {
    final logoDomain = _getBrandDomain(storeName);
    final fallbackBg = _getBrandBgColor(storeName);
    if (logoDomain.isEmpty) {
      return Container(
        width: 18, height: 18,
        decoration: BoxDecoration(shape: BoxShape.circle, color: fallbackBg),
        child: const Icon(Icons.storefront_rounded, size: 10, color: Colors.white),
      );
    }
    return Container(
      width: 18, height: 18,
      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
      clipBehavior: Clip.antiAlias,
      child: Image.network(
        'https://logo.clearbit.com/$logoDomain',
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: fallbackBg,
          child: Center(
            child: Text(
              storeName.substring(0, 1).toUpperCase(),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 9),
            ),
          ),
        ),
      ),
    );
  }

  // ─────────────────── Shared UI helpers ───────────────────

  /// Unified section header: small overline label + bold title
  Widget _buildSectionHeader(String overline, String title, Color accentColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          overline,
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.4,
            color: accentColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          title,
          style: TextStyle(
            color: isDark ? Colors.white : AppTheme.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }

  /// Standard card decoration used by every card in this screen
  BoxDecoration _cardDecoration(bool isDark, {Color? borderColor, Color? bgColor}) {
    return BoxDecoration(
      color: bgColor ?? (isDark ? const Color(0xFF141618) : Colors.white),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(
        color: borderColor ?? (isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
        width: 1.0,
      ),
    );
  }

  // ─────────────────── Main build ───────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final visionState = ref.watch(unifiedVisionProvider);
    final accentColor = ref.watch(accentColorProvider);

    return visionState.currentReport.when(
      data: (report) {
        if (report == null) {
          return Scaffold(
            backgroundColor: isDark ? const Color(0xFF0E0F0C) : AppTheme.obsidianBackground,
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded,
                    color: isDark ? Colors.white : AppTheme.textPrimary),
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
        if (_selectedAlternativeIndex >= report.alternatives.length) {
          _selectedAlternativeIndex = 0;
        }

        final String searchTarget = report.alternatives.isNotEmpty
            ? '${report.alternatives[_selectedAlternativeIndex].brand} ${report.alternatives[_selectedAlternativeIndex].name}'
            : '${report.brand} ${report.productName}';
        final storeLinks = VisionRecommendationEngine.getLinksForCategory(
          category: report.category,
          query: searchTarget,
        );

        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0E0F0C) : AppTheme.obsidianBackground,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded,
                  color: isDark ? Colors.white : AppTheme.textPrimary),
              onPressed: () {
                ref.read(unifiedVisionProvider.notifier).resetCurrentReport();
                Navigator.pop(context);
              },
            ),
            title: Row(
              children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor,
                    boxShadow: [BoxShadow(color: accentColor.withOpacity(0.5), blurRadius: 6, spreadRadius: 1)],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ZIVO ANALYSER',
                  style: TextStyle(
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ══════════════ SECTION 1: Product Hero Card ══════════════
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: _cardDecoration(isDark),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product image + name header
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
                                width: 1.5,
                              ),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _buildProductImage(report.imageUrl, report.category),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Category pill
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accentCyan.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(9999),
                                    border: Border.all(color: AppTheme.accentCyan.withOpacity(0.25), width: 1.0),
                                  ),
                                  child: Text(
                                    report.category.toUpperCase(),
                                    style: const TextStyle(
                                      color: AppTheme.accentCyan,
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
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  report.brand,
                                  style: const TextStyle(
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

                      const SizedBox(height: 16),
                      Divider(height: 1, color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6)),
                      const SizedBox(height: 16),

                      // Verdict row
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder, width: 1.0),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 52,
                              height: 52,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: gradeColor.withOpacity(0.08),
                                border: Border.all(color: gradeColor.withOpacity(0.3), width: 1.5),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                report.healthGrade,
                                style: TextStyle(
                                  color: gradeColor,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'HEALTH VERDICT',
                                    style: TextStyle(
                                      color: gradeColor,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 1.4,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    report.verdict,
                                    style: TextStyle(
                                      color: isDark ? Colors.white.withOpacity(0.9) : AppTheme.textPrimary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      height: 1.4,
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
                ),
                const SizedBox(height: 20),

                // ══════════════ SECTION 1.5: Allergy Warnings ══════════════
                if (report.allergyWarnings.isNotEmpty) ...[
                  _buildSectionHeader('HEALTH ALERT', 'Allergy Warnings', AppTheme.accentCoral, isDark),
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF141618) : Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder, width: 1.0),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: report.allergyWarnings.map((warning) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF121214) : Colors.black.withOpacity(0.02),
                          borderRadius: BorderRadius.circular(12),
                          border: Border(
                            left: BorderSide(
                              color: AppTheme.accentCoral,
                              width: 3.5,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                warning,
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppTheme.textPrimary,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // ══════════════ SECTION 2: Key Insights ══════════════
                if (report.insights.isNotEmpty) ...[
                  _buildSectionHeader('AI ANALYSIS', 'Key Insights', accentColor, isDark),
                  const SizedBox(height: 14),
                  ...report.insights.map((insight) {
                    Color color = accentColor;
                    if (insight.contains('❌')) color = AppTheme.accentCoral;
                    else if (insight.contains('⚠') || insight.contains('⚠️')) color = AppTheme.accentOrange;
                    else if (insight.contains('✅')) color = AppTheme.accentEmerald;

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
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141618) : Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder, width: 1.0),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (emoji != null) ...[
                            Container(
                              width: 34, height: 34,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.08),
                                shape: BoxShape.circle,
                                border: Border.all(color: color.withOpacity(0.2), width: 1.0),
                              ),
                              alignment: Alignment.center,
                              child: Text(emoji, style: const TextStyle(fontSize: 15)),
                            ),
                            const SizedBox(width: 12),
                          ],
                          Expanded(
                            child: Text(
                              cleanText,
                              style: TextStyle(
                                color: isDark ? Colors.white.withOpacity(0.9) : AppTheme.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                ],

                // ══════════════ SECTION 3: Product Analysis Bento Cards ══════════════
                _buildSectionHeader('BREAKDOWN', 'Product Analysis', accentColor, isDark),
                const SizedBox(height: 14),

                if (report.category.toLowerCase() != 'skincare') ...[
                  Column(
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
                              description: report.palmOilAnalysis.present
                                  ? 'Contains palm oil — consider alternatives'
                                  : 'No palm oil detected',
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
                  ),
                  const SizedBox(height: 24),
                ],

                // ══════════════ SECTION 3b: Decoded Ingredients ══════════════
                _buildSectionHeader('TRANSPARENCY', 'Decoded Ingredients', accentColor, isDark),
                const SizedBox(height: 14),

                if (report.decodedIngredients.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: _cardDecoration(isDark),
                    child: const Center(
                      child: Text(
                        'No ingredients list found in database.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ...report.decodedIngredients.map((ing) {
                    final safetyColor = _getSafetyColor(ing.safety, isDark);
                    final isExpanded = _expandedIngredients.contains(ing.name);

                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF141618) : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isExpanded
                              ? safetyColor.withOpacity(0.5)
                              : (isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                          width: isExpanded ? 1.5 : 1.0,
                        ),
                      ),
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedIngredients.remove(ing.name);
                            } else {
                              _expandedIngredients.add(ing.name);
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  // Safety initial badge
                                  Container(
                                    width: 34, height: 34,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: safetyColor.withOpacity(0.12),
                                      border: Border.all(color: safetyColor.withOpacity(0.35), width: 1.5),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      ing.safety.substring(0, 1).toUpperCase(),
                                      style: TextStyle(
                                        color: safetyColor,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
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
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.accentCoral.withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(9999),
                                                  border: Border.all(color: AppTheme.accentCoral.withOpacity(0.25), width: 1.0),
                                                ),
                                                child: Text(
                                                  'SNEAKY ${ing.sneakyNameFor.toUpperCase()}',
                                                  style: const TextStyle(
                                                    color: AppTheme.accentCoral,
                                                    fontSize: 7.5,
                                                    fontWeight: FontWeight.w900,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          ing.meaning,
                                          style: TextStyle(
                                            color: isDark ? Colors.white.withOpacity(0.45) : AppTheme.textSecondary,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  AnimatedRotation(
                                    turns: isExpanded ? 0.5 : 0.0,
                                    duration: const Duration(milliseconds: 200),
                                    child: Icon(
                                      Icons.keyboard_arrow_down_rounded,
                                      color: isDark ? Colors.white54 : AppTheme.textSecondary,
                                      size: 20,
                                    ),
                                  ),
                                ],
                              ),
                              if (isExpanded) ...[
                                const SizedBox(height: 12),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.black.withOpacity(0.25) : const Color(0xFFF5F5F5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    ing.description,
                                    style: TextStyle(
                                      color: isDark ? Colors.white.withOpacity(0.75) : AppTheme.textSecondary,
                                      fontSize: 12.5,
                                      height: 1.5,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 24),

                // ══════════════ SECTION 4: Healthier Alternatives ══════════════
                _buildSectionHeader('SMART SWAP', 'Healthier Alternatives', AppTheme.accentCyan, isDark),
                const SizedBox(height: 14),

                if (report.alternatives.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                    decoration: _cardDecoration(isDark),
                    child: const Center(
                      child: Text(
                        'No healthier alternatives found for this category.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                  )
                else
                  ...List.generate(report.alternatives.length, (index) {
                    final alt = report.alternatives[index];
                    final isSelected = _selectedAlternativeIndex == index;
                    final altGradeColor = _getGradeColor(alt.healthGrade, isDark);

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => setState(() => _selectedAlternativeIndex = index),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppTheme.accentCyan.withOpacity(0.05)
                                : (isDark ? const Color(0xFF141618) : Colors.white),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? AppTheme.accentCyan
                                  : (isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder),
                              width: isSelected ? 1.8 : 1.0,
                            ),
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
                                      color: isSelected ? AppTheme.accentCyan : AppTheme.textSecondary.withOpacity(0.4),
                                      size: 20,
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
                                            fontSize: 15,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -0.3,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          alt.brand,
                                          style: TextStyle(
                                            color: AppTheme.textSecondary.withOpacity(0.7),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: altGradeColor.withOpacity(0.12),
                                      borderRadius: BorderRadius.circular(9999),
                                      border: Border.all(color: altGradeColor.withOpacity(0.3), width: 1.0),
                                    ),
                                    child: Text(
                                      'Grade ${alt.healthGrade}',
                                      style: TextStyle(
                                        color: altGradeColor,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (isSelected && alt.reason.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Divider(height: 1, color: isDark ? const Color(0xFF2C2C2E) : const Color(0xFFE8EBE6)),
                                const SizedBox(height: 12),
                                ...alt.reason
                                    .split('\n')
                                    .where((line) => line.trim().isNotEmpty)
                                    .map((bullet) => Padding(
                                          padding: const EdgeInsets.only(bottom: 6.0),
                                          child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                margin: const EdgeInsets.only(top: 3),
                                                width: 14, height: 14,
                                                decoration: BoxDecoration(
                                                  color: AppTheme.accentCyan.withOpacity(0.12),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(Icons.check_rounded, color: AppTheme.accentCyan, size: 9),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  bullet,
                                                  style: TextStyle(
                                                    color: isDark ? Colors.white.withOpacity(0.8) : AppTheme.textPrimary,
                                                    fontSize: 12.5,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        )),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                const SizedBox(height: 24),

                // ══════════════ SECTION 5: Buy Links ══════════════
                if (report.alternatives.isNotEmpty && storeLinks.isNotEmpty) ...[
                  _buildSectionHeader(
                    'SHOP NOW',
                    'Buy ${report.alternatives[_selectedAlternativeIndex].name}',
                    AppTheme.accentCyan,
                    isDark,
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: storeLinks.map((link) {
                      final brandBg = _getBrandBgColor(link.storeName);
                      return InkWell(
                        onTap: () => VisionRecommendationEngine.launchSearchLink(link.searchUrl),
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isDark ? const Color(0xFF141618) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 7, height: 7,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: brandBg),
                              ),
                              const SizedBox(width: 8),
                              _buildBrandLogo(link.storeName),
                              const SizedBox(width: 7),
                              Text(
                                link.storeName,
                                style: TextStyle(
                                  color: isDark ? Colors.white : AppTheme.textPrimary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.open_in_new_rounded,
                                  size: 11,
                                  color: isDark ? Colors.white38 : AppTheme.textSecondary),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                ],

              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: isDark ? const Color(0xFF0E0F0C) : AppTheme.obsidianBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(accentColor)),
              const SizedBox(height: 16),
              const Text(
                'Analyzing with AI Health Decision Engine...',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: isDark ? const Color(0xFF0E0F0C) : AppTheme.obsidianBackground,
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
                  style: TextStyle(
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accentColor,
                    foregroundColor: AppTheme.textPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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

  // ─────────────────── Bento metric card ───────────────────

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
        color: isDark ? const Color(0xFF141618) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2C2C2E) : AppTheme.glassBorder,
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + title row
          Row(
            children: [
              Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppTheme.accentCyan.withOpacity(0.18), width: 1.0),
                ),
                child: Icon(icon, color: AppTheme.accentCyan, size: 16),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    color: isDark ? Colors.white.withOpacity(0.55) : AppTheme.textSecondary,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: accentColor.withOpacity(0.2), width: 1.0),
            ),
            child: Text(
              status.toUpperCase(),
              style: TextStyle(
                color: accentColor,
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              color: isDark ? Colors.white.withOpacity(0.65) : AppTheme.textSecondary,
              fontSize: 12,
              height: 1.45,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
