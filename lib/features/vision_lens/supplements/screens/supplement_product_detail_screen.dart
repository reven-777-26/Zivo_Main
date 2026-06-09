import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme.dart';
import '../../shared/ui/vision_alternatives_list.dart';
import '../../shared/services/country_regulation_engine.dart';
import '../providers/supplement_vision_provider.dart';

class SupplementProductDetailScreen extends ConsumerWidget {
  final String? barcode;

  const SupplementProductDetailScreen({
    super.key,
    required this.barcode,
  });

  String _getGrade(int score) {
    if (score >= 80) return 'A';
    if (score >= 70) return 'B';
    if (score >= 50) return 'C';
    if (score >= 35) return 'D';
    return 'E';
  }

  String _getGradeLabel(String grade) {
    switch (grade) {
      case 'A': return 'Premium Purity';
      case 'B': return 'Good Formulation';
      case 'C': return 'Moderate Quality';
      case 'D': return 'Avoid Regular Use';
      case 'E': return 'Avoid Regular Use';
      default: return 'Unknown Choice';
    }
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A':
      case 'B': return AppTheme.accentEmerald;
      case 'C':
      case 'D': return AppTheme.accentOrange;
      case 'E': return AppTheme.accentCoral;
      default: return AppTheme.textSecondary;
    }
  }

  String _getGradeBullet(String grade) {
    switch (grade) {
      case 'A':
      case 'B': return '🟢';
      case 'C':
      case 'D': return '🟡';
      case 'E': return '🔴';
      default: return '⚪';
    }
  }

  String _getQuickVerdict(dynamic product) {
    if (product.zivoScore >= 80) {
      return "Optimized active ingredients with clean capsules. Highly recommended for goal alignment.";
    }
    
    final List<String> warnList = List<String>.from(product.warnings);
    if (warnList.isNotEmpty) {
      final first = warnList.first;
      if (first.contains(':')) {
        return first.split(':').last.trim();
      }
      return first;
    }
    if (product.overdosed) {
      return "Contains high active dosages. Consult a healthcare provider before regular consumption.";
    }
    if (product.fillers) {
      return "Contains artificial fillers or binding agents. Choose clean alternatives for pure absorption.";
    }
    return "Standard formulation. Contains typical binding agents and sweeteners.";
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final supplementState = ref.watch(supplementVisionProvider);

    return supplementState.currentProduct.when(
      data: (product) {
        if (product == null) {
          return Scaffold(
            backgroundColor: AppTheme.obsidianBackground,
            body: const Center(child: Text('No details loaded.', style: TextStyle(color: Colors.white))),
          );
        }

        final grade = _getGrade(product.zivoScore);
        final gradeColor = _getGradeColor(grade);
        final gradeBullet = _getGradeBullet(grade);
        final gradeLabel = _getGradeLabel(grade);
        final verdict = _getQuickVerdict(product);

        final listAlts = product.alternatives;
        final formattedAlts = listAlts.map((e) => AlternativeItem(
              name: e.name,
              brand: e.brand,
              reason: e.reason,
            )).toList();

        return Scaffold(
          backgroundColor: isDark ? AppTheme.obsidianBackground : const Color(0xFFF1F5F9),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
              onPressed: () {
                ref.read(supplementVisionProvider.notifier).resetCurrentProduct();
                Navigator.pop(context);
              },
            ),
            title: const Text('AI Health Report', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // SECTION 1: Header Section
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.accentPurple.withOpacity(0.1),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.accentPurple.withOpacity(0.3), width: 1.5),
                      ),
                      child: const Center(
                        child: Text('💊', style: TextStyle(fontSize: 28)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.productName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${product.brand} • SUPPLEMENT LENS',
                            style: const TextStyle(
                              color: AppTheme.accentPurple,
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // SECTION 2: Big Grade Card & Quick Verdict
                GlassCard(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SUPPLEMENT TRUST GRADE',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            '$gradeBullet $grade',
                            style: TextStyle(
                              color: gradeColor,
                              fontSize: 48,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Text(
                              gradeLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppTheme.glassBorder, height: 1),
                      const SizedBox(height: 16),
                      Text(
                        verdict,
                        style: const TextStyle(
                          color: AppTheme.textPrimary,
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // SECTION 3: AI Health Analysis Grid Cards
                const Text(
                  'FORMULATION METRICS',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.4,
                  children: [
                    // Active Dosage
                    _buildMetricCard(
                      title: 'Active Dosage',
                      value: product.overdosed
                          ? '🔴 Overdosed'
                          : (product.underdosed ? '🔴 Underdosed' : '🟢 Optimized'),
                      subtitle: product.dosage.isNotEmpty ? product.dosage : 'Standard levels',
                    ),
                    // Filler Content
                    _buildMetricCard(
                      title: 'Fillers & Binders',
                      value: product.fillers ? '🔴 Present' : '🟢 None',
                      subtitle: product.fillers ? 'Magnesium Stearate / Silicas' : 'Zero artificial binders',
                    ),
                    // Sweeteners
                    _buildMetricCard(
                      title: 'Sweeteners',
                      value: product.sweeteners ? '🔴 Sweetened' : '🟢 Unsweetened',
                      subtitle: product.sweeteners ? 'Sucralose / Aspartame' : 'Pure natural state',
                    ),
                    // Capsule Type
                    _buildMetricCard(
                      title: 'Capsule Shell',
                      value: product.veganCapsule ? '🟢 Vegan HPMC' : '🔴 Gelatin Capsule',
                      subtitle: 'Shell material source',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // EVIDENCE NOTES
                if (product.evidenceNotes.isNotEmpty) ...[
                  const Text(
                    'CLINICAL EVIDENCE Strength',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  GlassCard(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.psychology_alt_rounded, color: AppTheme.accentPurple, size: 20),
                            const SizedBox(width: 8),
                            const Text(
                              'Scientific Verification',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppTheme.accentCyan.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'Verified',
                                style: TextStyle(color: AppTheme.accentCyan, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          product.evidenceNotes,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // SECTION 4: Country Compliance Matrix
                _buildCountryComplianceSection(product.ingredients),
                const SizedBox(height: 28),

                // SECTION 5: Better Alternatives Section
                VisionAlternativesList(
                  alternatives: formattedAlts,
                  category: 'Supplement',
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: AppTheme.obsidianBackground,
        body: const Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation(AppTheme.accentCyan)),
        ),
      ),
      error: (err, _) => Scaffold(
        backgroundColor: AppTheme.obsidianBackground,
        body: Center(
          child: Text(
            'Error: $err',
            style: const TextStyle(color: AppTheme.accentCoral),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountryComplianceSection(List<String> ingredients) {
    final regulations = CountryRegulationEngine.analyzeIngredientsList(ingredients);

    Widget buildCountryRow(String country, String flag) {
      final match = regulations.where((r) => r.countryStatuses.containsKey(country)).toList();
      final isBanned = match.any((r) => r.countryStatuses[country]!.status == 'Banned');
      final isRestricted = match.any((r) => r.countryStatuses[country]!.status == 'Restricted');

      String statusText = '🟢 Allowed';
      Color statusColor = AppTheme.accentEmerald;
      String detail = 'Ingredients comply with local regulatory limits.';

      if (isBanned) {
        statusText = '🔴 Banned';
        statusColor = AppTheme.accentCoral;
        final firstBanned = match.firstWhere((r) => r.countryStatuses[country]!.status == 'Banned');
        detail = '${firstBanned.ingredientName} is prohibited: ${firstBanned.countryStatuses[country]!.reason}';
      } else if (isRestricted) {
        statusText = '🟡 Restricted';
        statusColor = AppTheme.accentOrange;
        final firstRestr = match.firstWhere((r) => r.countryStatuses[country]!.status == 'Restricted');
        detail = '${firstRestr.ingredientName} usage is restricted: ${firstRestr.countryStatuses[country]!.reason}';
      }

      return Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(flag, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 10),
                Text(
                  country.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'COUNTRY COMPLIANCE REPORT',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              buildCountryRow('India', '🇮🇳'),
              const Divider(color: AppTheme.glassBorder, height: 24),
              buildCountryRow('UK', '🇬🇧'),
              const Divider(color: AppTheme.glassBorder, height: 24),
              buildCountryRow('USA', '🇺🇸'),
            ],
          ),
        ),
      ],
    );
  }
}
