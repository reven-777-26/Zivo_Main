import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';
import '../../shared/services/vision_storage_service.dart';
import '../../shared/services/vision_firebase_service.dart';
import '../../shared/services/country_regulation_engine.dart';
import '../models/supplement_product.dart';

class SupplementService {
  static const String categoryKey = 'Supplement';

  static Future<List<Map<String, dynamic>>> searchSupplements(String query) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) return [];

    final url = Uri.parse(
      'https://world.openfoodfacts.org/cgi/search.pl?action=process&search_terms=${Uri.encodeComponent(cleanQuery)}&json=1&page_size=10',
    );

    try {
      final response = await http.get(url).timeout(const Duration(seconds: 6));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> products = data['products'] ?? [];
        return products.map((p) => p as Map<String, dynamic>).toList();
      }
    } catch (e) {
      debugPrint("Open Food Facts supplement search error: $e");
    }
    return [];
  }

  static Future<Map<String, dynamic>?> fetchRawBarcode(String barcode) async {
    final url = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$barcode.json');
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'success' || data['status'] == 1 || data['product'] != null) {
          return data['product'] as Map<String, dynamic>?;
        }
      }
    } catch (e) {
      debugPrint("Supplement OFF fetch error: $e");
    }
    return null;
  }

  static SupplementProduct estimateLocally(String barcode, String name, List<String> rawIngredients) {
    int score = 100;
    final warnings = <String>[];
    final insights = <String>[];
    final ingredientsList = rawIngredients.isNotEmpty
        ? rawIngredients
        : ['Gelatin', 'Magnesium Stearate', 'Titanium Dioxide', 'Vitamin C'];

    bool hasFillers = false;
    bool hasArtificialColors = false;
    bool hasSweeteners = false;
    bool isVeganCapsule = true;

    for (var ing in ingredientsList) {
      final lowIng = ing.toLowerCase();
      if (lowIng.contains('stearate') ||
          lowIng.contains('cellulose') ||
          lowIng.contains('silicon dioxide') ||
          lowIng.contains('filler')) {
        hasFillers = true;
      }
      if (lowIng.contains('gelatin') || lowIng.contains('bovine')) {
        isVeganCapsule = false;
      }
      if (lowIng.contains('sucralose') ||
          lowIng.contains('aspartame') ||
          lowIng.contains('stevia') ||
          lowIng.contains('sorbitol')) {
        hasSweeteners = true;
      }
      if (lowIng.contains('titanium dioxide') ||
          lowIng.contains('color') ||
          lowIng.contains('dye') ||
          lowIng.contains('lake')) {
        hasArtificialColors = true;
      }
    }

    if (hasFillers) {
      score -= 15;
      warnings.add('Contains Artificial Fillers (e.g. Magnesium Stearate).');
    }
    if (!isVeganCapsule) {
      score -= 15;
      warnings.add('Gelatin Capsule Detected: Non-vegan/vegetarian capsule shell.');
    }
    if (hasSweeteners) {
      score -= 10;
      warnings.add('Sweeteners detected.');
    }
    if (hasArtificialColors) {
      score -= 10;
      warnings.add('Synthetic coloring agents detected.');
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

    return SupplementProduct(
      barcode: barcode,
      productName: name.isNotEmpty ? name : 'Offline Estimated Supplement',
      brand: 'Generic / Local Check',
      zivoScore: score,
      servingSize: '1 Capsule',
      dosage: 'Daily dosage estimated',
      underdosed: false,
      overdosed: false,
      fillers: hasFillers,
      artificialColors: hasArtificialColors,
      sweeteners: hasSweeteners,
      veganCapsule: isVeganCapsule,
      evidenceNotes: 'Tested locally via offline rules. Connect to network for full research verification.',
      warnings: warnings.isEmpty ? ['None detected (offline estimate)'] : warnings,
      ingredients: ingredientsList,
      insights: insights.isEmpty ? ['Ensure checking dosage relative to age targets'] : insights,
      alternatives: [
        SupplementAlternative(
          name: 'Premium Organic Plant Protein / Multi',
          brand: 'Zivo Pure Choice',
          reason: 'Clean label formulation using vegan capsules and zero fillers.',
        ),
      ],
      scanDate: DateTime.now(),
    );
  }

  static Future<SupplementProduct> analyzeSupplement({
    String? barcode,
    String? searchName,
    Map<String, dynamic>? rawDetails,
    String? imageBase64,
  }) async {
    final cleanBarcode = barcode ?? rawDetails?['_id']?.toString() ?? rawDetails?['code']?.toString() ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final cached = await VisionStorageService.getCachedProduct(categoryKey, cleanBarcode);
      if (cached != null) {
        return SupplementProduct.fromJson(cached, barcode: cleanBarcode);
      }
    } catch (_) {}

    try {
      final cachedFirestore = await VisionFirebaseService.getProductFromFirestore(categoryKey, cleanBarcode);
      if (cachedFirestore != null) {
        await VisionStorageService.cacheProduct(categoryKey, cleanBarcode, cachedFirestore);
        return SupplementProduct.fromJson(cachedFirestore, barcode: cleanBarcode);
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
        'product_name': searchName ?? 'Searched Supplement',
        'ingredients_text': 'Gelatin, Microcrystalline Cellulose, Vitamin D3, Magnesium Stearate',
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
        
        final dataToStore = {
          ...responseData,
          'scanDate': DateTime.now().toIso8601String(),
        };

        await VisionStorageService.cacheProduct(categoryKey, cleanBarcode, dataToStore);
        await VisionFirebaseService.saveProductToFirestore(categoryKey, cleanBarcode, dataToStore);

        return SupplementProduct.fromJson(dataToStore, barcode: cleanBarcode);
      }
    } catch (e) {
      debugPrint("Supplement Cloud Function analysis failed: $e");
    }

    final fallbackName = searchName ?? payload['product_name']?.toString() ?? 'Estimated Supplement';
    final fallbackIngredients = <String>[];
    final String? ingredientsText = payload['ingredients_text']?.toString() ?? payload['ingredients_text_en']?.toString();
    if (ingredientsText != null && ingredientsText.isNotEmpty) {
      fallbackIngredients.addAll(ingredientsText.split(',').map((e) => e.trim()));
    }

    final fallbackProduct = estimateLocally(cleanBarcode, fallbackName, fallbackIngredients);

    try {
      await VisionStorageService.cacheProduct(categoryKey, cleanBarcode, fallbackProduct.toJson());
    } catch (_) {}

    return fallbackProduct;
  }
}
