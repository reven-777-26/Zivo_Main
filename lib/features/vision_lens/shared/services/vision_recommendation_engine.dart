import 'package:url_launcher/url_launcher.dart';

class RecommendationStoreLink {
  final String storeName;
  final String searchUrl;

  const RecommendationStoreLink({
    required this.storeName,
    required this.searchUrl,
  });
}

class VisionRecommendationEngine {
  static List<RecommendationStoreLink> getLinksForCategory({
    required String category,
    required String query,
  }) {
    final cleanCategory = category.toLowerCase().trim();
    final encodedQuery = Uri.encodeComponent(query);

    if (cleanCategory == 'skincare') {
      return [
        RecommendationStoreLink(
          storeName: 'Nykaa',
          searchUrl: 'https://www.nykaa.com/search/result/?q=$encodedQuery',
        ),
        RecommendationStoreLink(
          storeName: 'Myntra',
          searchUrl: 'https://www.myntra.com/$encodedQuery',
        ),
        RecommendationStoreLink(
          storeName: 'Amazon',
          searchUrl: 'https://www.amazon.in/s?k=$encodedQuery',
        ),
        RecommendationStoreLink(
          storeName: 'Flipkart',
          searchUrl: 'https://www.flipkart.com/search?q=$encodedQuery',
        ),
      ];
    } else {
      // Food or Supplement
      return [
        RecommendationStoreLink(
          storeName: 'Blinkit',
          searchUrl: 'https://blinkit.com/s/?q=$encodedQuery',
        ),
        RecommendationStoreLink(
          storeName: 'Swiggy Instamart',
          searchUrl: 'https://www.swiggy.com/search?query=$encodedQuery',
        ),
        RecommendationStoreLink(
          storeName: 'Zepto',
          searchUrl: 'https://www.zeptonow.com/search?q=$encodedQuery',
        ),
        RecommendationStoreLink(
          storeName: 'Amazon',
          searchUrl: 'https://www.amazon.in/s?k=$encodedQuery',
        ),
        RecommendationStoreLink(
          storeName: 'Flipkart',
          searchUrl: 'https://www.flipkart.com/search?q=$encodedQuery',
        ),
        RecommendationStoreLink(
          storeName: 'BigBasket',
          searchUrl: 'https://www.bigbasket.com/ps/?q=$encodedQuery',
        ),
        RecommendationStoreLink(
          storeName: 'JioMart',
          searchUrl: 'https://www.jiomart.com/search/$encodedQuery',
        ),
      ];
    }
  }

  static Future<bool> launchSearchLink(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (_) {}
    return false;
  }
}
