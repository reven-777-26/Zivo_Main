import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';
import '../../shared/services/vision_storage_service.dart';
import '../../shared/services/vision_firebase_service.dart';
import '../../shared/services/country_regulation_engine.dart';
import '../models/skincare_product.dart';

class SkincareApiService {
  static const String categoryKey = 'Skincare';

  static Future<List<Map<String, dynamic>>> searchSkincare(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final url = Uri.parse(
      'https://world.openbeautyfacts.org/cgi/search.pl?action=process&search_terms=${Uri.encodeComponent(cleanQuery)}&json=1&page_size=10',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> products = data['products'] ?? [];
        return products.map((p) => p as Map<String, dynamic>).toList();
      }
    } catch (e) {
      debugPrint("Open Beauty Facts search error: $e");
    }
    return [];
  }

  static Future<Map<String, dynamic>?> fetchRawBarcode(String barcode) async {
    final url = Uri.parse('https://world.openbeautyfacts.org/api/v2/product/$barcode.json');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' || data['status'] == 1 || data['product'] != null) {
          return data['product'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      debugPrint("Open Beauty Facts fetch error: $e");
    }
    return null;
  }

  static SkincareProduct estimateLocally(
    String barcode,
    String name,
    List<String> rawIngredients,
    String userSkinType,
  ) {
    int score = 100;
    final warnings = <String>[];
    final ingredientsList = rawIngredients.isNotEmpty
        ? rawIngredients
        : ['Water', 'Glycerin', 'Methylparaben', 'Alcohol Denat', 'Fragrance'];

    bool hasFragrance = false;
    bool hasParabens = false;
    bool hasSulfates = false;
    bool hasDryingAlcohols = false;
    bool hasEssentialOils = false;
    int comedogenic = 0;
    String acneRisk = 'Low';
    String sensitiveRisk = 'Low';
    String pregnancyWarning = 'None';

    for (var ing in ingredientsList) {
      final lowIng = ing.toLowerCase();
      if (lowIng.contains('fragrance') || lowIng.contains('perfume') || lowIng.contains('parfum')) {
        hasFragrance = true;
      }
      if (lowIng.contains('paraben')) {
        hasParabens = true;
      }
      if (lowIng.contains('sulfate') || lowIng.contains('sls') || lowIng.contains('sles')) {
        hasSulfates = true;
      }
      if (lowIng.contains('alcohol denat') ||
          lowIng.contains('isopropyl alcohol') ||
          lowIng.contains('ethanol') ||
          lowIng.contains('sd alcohol')) {
        hasDryingAlcohols = true;
      }
      if (lowIng.contains('lavender oil') ||
          lowIng.contains('citrus') ||
          lowIng.contains('lemon oil') ||
          lowIng.contains('essential oil')) {
        hasEssentialOils = true;
      }
      if (lowIng.contains('coconut oil') ||
          lowIng.contains('cocoa butter') ||
          lowIng.contains('isopropyl myristate') ||
          lowIng.contains('myristyl myristate')) {
        comedogenic = 4;
        acneRisk = 'High';
      }
      if (lowIng.contains('retinol') ||
          lowIng.contains('retinyl') ||
          lowIng.contains('salicylic acid') ||
          lowIng.contains('hydroquinone')) {
        pregnancyWarning = 'Consult Doctor (contains Retinoids/Salicylic Acid)';
      }
    }

    if (hasFragrance) {
      score -= 10;
      if (userSkinType == 'Sensitive') {
        score -= 10;
        sensitiveRisk = 'High';
        warnings.add('Fragrance Detected: High irritation risk for your Sensitive skin type.');
      } else {
        warnings.add('Fragrance Detected.');
      }
    }

    if (hasParabens) {
      score -= 15;
      warnings.add('Parabens Present: Endocrine disruption and skin sensitivity concerns.');
    }

    if (hasSulfates) {
      score -= 15;
      warnings.add('Sulfates (SLS/SLES) Present: Can strip skin barriers and cause dryness.');
    }

    if (hasDryingAlcohols) {
      score -= 15;
      if (userSkinType == 'Dry' || userSkinType == 'Sensitive') {
        score -= 10;
        warnings.add('Drying Alcohol present: Highly dehydrating for your Dry/Sensitive skin.');
      } else {
        warnings.add('Drying Alcohol detected.');
      }
    }

    if (hasEssentialOils) {
      score -= 10;
      warnings.add('Essential Oils detected: Possible allergen triggers.');
    }

    if (comedogenic >= 3) {
      if (userSkinType == 'Acne' || userSkinType == 'Oily') {
        score -= 20;
        warnings.add('High Comedogenic Ingredients: Likely to clog pores on your Oily/Acne skin.');
      } else {
        warnings.add('Mild Comedogenic ingredients present.');
      }
    }

    if (pregnancyWarning != 'None') {
      warnings.add('Pregnancy Alert: $pregnancyWarning.');
    }

    score = score.clamp(0, 100);

    final matchedRegulations = CountryRegulationEngine.analyzeIngredientsList(ingredientsList);
    for (var reg in matchedRegulations) {
      final ukStatus = reg.countryStatuses['UK']?.status ?? 'Allowed';
      final inStatus = reg.countryStatuses['India']?.status ?? 'Allowed';
      if (ukStatus == 'Banned' || inStatus == 'Banned') {
        warnings.add('${reg.ingredientName} is banned in UK/India.');
        score -= 20;
      }
    }
    score = score.clamp(0, 100);

    return SkincareProduct(
      barcode: barcode,
      productName: name.isNotEmpty ? name : 'Offline Estimated Skincare Product',
      brand: 'Generic / Local Check',
      zivoScore: score,
      acneRisk: acneRisk,
      comedogenicRating: comedogenic,
      irritationRisk: hasFragrance || hasDryingAlcohols ? 'Medium' : 'Low',
      fragrance: hasFragrance,
      parabens: hasParabens,
      sulfates: hasSulfates,
      dryingAlcohols: hasDryingAlcohols,
      essentialOils: hasEssentialOils,
      sensitiveSkinRisk: sensitiveRisk,
      pregnancyWarning: pregnancyWarning,
      warnings: warnings.isEmpty ? ['None detected (offline estimate)'] : warnings,
      ingredients: ingredientsList,
      alternatives: [
        SkincareAlternative(
          name: 'Fragrance-Free Ultra Hydrating Cream',
          brand: 'Zivo Pure Skin Choice',
          reason: 'Formulated with organic aloe, glycerin, and zero parabens, fragrances or drying alcohols.',
        ),
      ],
      scanDate: DateTime.now(),
    );
  }

  static Future<SkincareProduct> analyzeSkincare({
    String? barcode,
    String? searchName,
    Map<String, dynamic>? rawDetails,
    String? imageBase64,
    required String userSkinType,
  }) async {
    final cleanBarcode = barcode ?? rawDetails?['_id']?.toString() ?? rawDetails?['code']?.toString() ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final cached = await VisionStorageService.getCachedProduct(categoryKey, cleanBarcode);
      if (cached != null) {
        return SkincareProduct.fromJson(cached, barcode: cleanBarcode);
      }
    } catch (_) {}

    try {
      final cachedFirestore = await VisionFirebaseService.getProductFromFirestore(categoryKey, cleanBarcode);
      if (cachedFirestore != null) {
        await VisionStorageService.cacheProduct(categoryKey, cleanBarcode, cachedFirestore);
        return SkincareProduct.fromJson(cachedFirestore, barcode: cleanBarcode);
      }
    } catch (_) {}

    Map<String, dynamic> payload = rawDetails ?? {};
    if (payload.isEmpty && barcode != null && barcode.isNotEmpty && imageBase64 == null) {
      final fetched = await fetchRawBarcode(barcode);
      if (fetched != null) {
        payload = fetched;
      }
    }

    if (payload.isEmpty && imageBase64 == null) {
      payload = {
        'product_name': searchName ?? 'Searched Skincare',
        'ingredients_text': 'Water, Glycerin, Alcohol Denat, Fragrance, Propylparaben',
      };
    }

    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('analyzeVisionProduct');
      final HttpsCallableResult result = await callable.call({
        'category': categoryKey,
        'payload': payload,
        'imageBase64': imageBase64,
      });

      if (result.data != null) {
        final Map<String, dynamic> responseData = Map<String, dynamic>.from(result.data as Map);
        
        int finalScore = responseData['zivoScore'] ?? 70;
        final warnings = List<String>.from(responseData['warnings'] ?? []);
        final isComedogenic = (responseData['comedogenicRating'] ?? 0) >= 3;
        final hasFragranceOrAlcohols = (responseData['fragrance'] ?? false) || (responseData['dryingAlcohols'] ?? false);

        if (isComedogenic && (userSkinType == 'Acne' || userSkinType == 'Oily')) {
          finalScore = (finalScore - 20).clamp(0, 100);
          warnings.add('Skin Type Warning: Comedogenic ingredients are highly pore-clogging for your Oily/Acne skin.');
        }
        if (hasFragranceOrAlcohols && (userSkinType == 'Dry' || userSkinType == 'Sensitive')) {
          finalScore = (finalScore - 15).clamp(0, 100);
          warnings.add('Skin Type Warning: Fragrances or drying alcohols will aggravate your Sensitive/Dry skin.');
        }

        final dataToStore = {
          ...responseData,
          'zivoScore': finalScore,
          'warnings': warnings,
          'scanDate': DateTime.now().toIso8601String(),
        };

        await VisionStorageService.cacheProduct(categoryKey, cleanBarcode, dataToStore);
        await VisionFirebaseService.saveProductToFirestore(categoryKey, cleanBarcode, dataToStore);

        return SkincareProduct.fromJson(dataToStore, barcode: cleanBarcode);
      }
    } catch (e) {
      debugPrint("Skincare Cloud Function analysis failed: $e");
    }

    final fallbackName = searchName ?? payload['product_name']?.toString() ?? 'Estimated Skincare';
    final fallbackIngredients = <String>[];
    final String? ingredientsText = payload['ingredients_text']?.toString() ?? payload['ingredients_text_en']?.toString();
    if (ingredientsText != null && ingredientsText.isNotEmpty) {
      fallbackIngredients.addAll(ingredientsText.split(',').map((e) => e.trim()));
    }

    final fallbackProduct = estimateLocally(cleanBarcode, fallbackName, fallbackIngredients, userSkinType);

    try {
      await VisionStorageService.cacheProduct(categoryKey, cleanBarcode, fallbackProduct.toJson());
    } catch (_) {}

    return fallbackProduct;
  }
}
