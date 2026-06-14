import 'package:flutter/material.dart';
import '../../../../core/theme.dart';
import '../services/vision_recommendation_engine.dart';

class AlternativeItem {
  final String name;
  final String brand;
  final String reason;

  AlternativeItem({
    required this.name,
    required this.brand,
    required this.reason,
  });
}

class VisionAlternativesList extends StatelessWidget {
  final List<AlternativeItem> alternatives;
  final String category;

  const VisionAlternativesList({
    super.key,
    required this.alternatives,
    required this.category,
  });

  List<RecommendationStoreLink> _getLinksForCategory(String query) {
    return VisionRecommendationEngine.getLinksForCategory(
      category: category,
      query: query,
    );
  }

  String _getCategoryEmoji() {
    switch (category.toLowerCase()) {
      case 'food':
        return '🍔';
      case 'supplement':
      case 'supplements':
        return '💊';
      case 'skincare':
        return '🧴';
      default:
        return '📦';
    }
  }

  Color _getCategoryColor() {
    switch (category.toLowerCase()) {
      case 'food':
        return AppTheme.accentCyan;
      case 'supplement':
      case 'supplements':
        return AppTheme.accentPurple;
      case 'skincare':
        return AppTheme.accentOrange;
      default:
        return AppTheme.accentEmerald;
    }
  }

  String _getDefaultPrice() {
    switch (category.toLowerCase()) {
      case 'food':
        return '₹129 - ₹199';
      case 'supplement':
      case 'supplements':
        return '₹699 - ₹999';
      case 'skincare':
        return '₹349 - ₹499';
      default:
        return '₹299';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (alternatives.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1C1E1B) : Colors.white;
    final categoryColor = _getCategoryColor();
    final emoji = _getCategoryEmoji();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: Text(
            'HEALTHIER ALTERNATIVES',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...alternatives.map((alt) {
          final query = '${alt.brand} ${alt.name}';
          final links = _getLinksForCategory(query);
          final price = _getDefaultPrice();

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(18), // rounded.lg
              border: Border.all(
                color: isDark ? const Color(0xFF323530) : Colors.black.withOpacity(0.06),
                width: 1.0, // hairline
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Row: Image, Name, Grade & Price
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Premium Emoji/Icon Circle
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: categoryColor.withOpacity(0.2), width: 1.0),
                      ),
                      child: Center(
                        child: Text(
                          emoji,
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // Product Info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            alt.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            alt.brand.isNotEmpty ? alt.brand : 'Premium Choice',
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Grade and Price Column
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.accentEmerald.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.accentEmerald.withOpacity(0.3), width: 1.0),
                          ),
                          child: const Text(
                            '🟢 A',
                            style: TextStyle(
                              color: AppTheme.accentEmerald,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          price,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Middle: Why Better Verdict
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(isDark ? 0.2 : 0.02),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isDark ? AppTheme.glassBorder : Colors.transparent, width: 1.0),
                  ),
                  child: Text(
                    alt.reason,
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(color: AppTheme.glassBorder, height: 1),
                const SizedBox(height: 12),
                // Buy Section
                Row(
                  children: [
                    const Text(
                      '⚡ BUY INSTANTLY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.accentCyan,
                        letterSpacing: 1.0,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${links.length} store links',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: links.map((link) {
                    final iconData = _getBrandIcon(link.storeName);

                    return InkWell(
                      onTap: () => VisionRecommendationEngine.launchSearchLink(link.searchUrl),
                      borderRadius: BorderRadius.circular(9999), // pill shape
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.accentCyan.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(9999), // pill shape
                          border: Border.all(
                            color: AppTheme.accentCyan.withOpacity(0.2),
                            width: 1.0, // hairline
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              iconData,
                              size: 13,
                              color: AppTheme.accentCyan,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              link.storeName,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.accentCyan,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        }).toList(),
      ],
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
      case 'instamart':
        return const Color(0xFFFF5200);
      case 'jiomart':
        return const Color(0xFF003087);
      case 'bigbasket':
        return const Color(0xFF84C225);
      case 'nykaa':
        return const Color(0xFFFC2779);
      case 'myntra':
        return const Color(0xFFE71C56);
      case 'tira':
      case 'tira beauty':
        return const Color(0xFF92795B);
      case 'healthkart':
        return const Color(0xFF00A2E8);
      case 'hyugalife':
        return const Color(0xFF03C0A8);
      default:
        return const Color(0xFF1E293B);
    }
  }

  Color _getBrandTextColor(String storeName) {
    switch (storeName.toLowerCase()) {
      case 'blinkit':
        return Colors.black;
      default:
        return Colors.white;
    }
  }

  IconData _getBrandIcon(String storeName) {
    switch (storeName.toLowerCase()) {
      case 'amazon':
      case 'flipkart':
      case 'blinkit':
      case 'zepto':
      case 'swiggy instamart':
      case 'instamart':
      case 'jiomart':
      case 'bigbasket':
        return Icons.shopping_basket_rounded;
      case 'nykaa':
      case 'myntra':
      case 'tira':
      case 'tira beauty':
        return Icons.shopping_bag_rounded;
      default:
        return Icons.shopping_cart_rounded;
    }
  }
}
