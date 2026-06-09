import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';
import '../../shared/services/vision_storage_service.dart';
import '../../shared/services/vision_firebase_service.dart';
import '../../shared/services/country_regulation_engine.dart';
import '../models/food_product.dart';

class FoodApiService {
  static const String categoryKey = 'Food';

  static Future<List<Map<String, dynamic>>> searchProducts(String query) async {
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
      debugPrint("Open Food Facts search error: $e");
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
      debugPrint("Open Food Facts fetch error: $e");
    }
    return null;
  }

  static FoodProduct estimateLocally(
    String barcode,
    String name,
    List<String> rawIngredients, {
    String fitnessGoal = 'maintain',
  }) {
    int score = 100;
    final warnings = <String>[];
    final insights = <String>[];
    final ingredientsList = rawIngredients.isNotEmpty
        ? rawIngredients
        : ['Water', 'Sugar', 'Artificial Color', 'Preservative', 'Palm Oil'];

    bool hasSugar = false;
    bool hasPalmOil = false;
    bool hasArtificialSweetener = false;
    bool hasArtificialColors = false;
    bool hasPreservative = false;

    for (var ing in ingredientsList) {
      final lowIng = ing.toLowerCase();
      if (lowIng.contains('sugar') || lowIng.contains('fructose') || lowIng.contains('sucrose') || lowIng.contains('dextrose')) {
        hasSugar = true;
      }
      if (lowIng.contains('palm oil') || lowIng.contains('palmitate')) {
        hasPalmOil = true;
      }
      if (lowIng.contains('aspartame') || lowIng.contains('sucralose') || lowIng.contains('stevia') || lowIng.contains('saccharin')) {
        hasArtificialSweetener = true;
      }
      if (lowIng.contains('color') || lowIng.contains('yellow') || lowIng.contains('red') || lowIng.contains('blue') || lowIng.contains('e1')) {
        hasArtificialColors = true;
      }
      if (lowIng.contains('benzoate') || lowIng.contains('sorbate') || lowIng.contains('sulfite') || lowIng.contains('preservative')) {
        hasPreservative = true;
      }
    }

    if (hasSugar) {
      score -= 15;
      warnings.add('High Sugar Detected: Contains added sugars/syrups.');
      insights.add('Slightly high sugar load might lead to glycemic spikes.');
    }
    if (hasPalmOil) {
      score -= 10;
      warnings.add('Palm Oil Detected: Environmental and saturated fat concerns.');
    }
    if (hasArtificialSweetener) {
      score -= 15;
      warnings.add('Artificial Sweetener Detected: Avoid for optimal gut health.');
    }
    if (hasArtificialColors) {
      score -= 10;
      warnings.add('Artificial Colors: Associated with hyperactivity or additives.');
    }
    if (hasPreservative) {
      score -= 10;
      warnings.add('Chemical Preservatives Present.');
    }

    // Personalization alignment check
    if (fitnessGoal == 'lose') {
      score -= 10;
      warnings.add('Weight Loss Penalty: Calorie dense or sweet profiles are discouraged.');
      insights.add('Opt for lower carb/sugar alternatives to align with your weight loss goal.');
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

    return FoodProduct(
      barcode: barcode,
      productName: name.isNotEmpty ? name : 'Offline Estimated Product',
      brand: 'Generic / Local Check',
      zivoScore: score,
      nutriScore: score >= 80 ? 'A' : (score >= 60 ? 'B' : (score >= 40 ? 'C' : 'D')),
      novaGroup: (score < 50) ? '4' : '3',
      calories: 210,
      protein: 4,
      carbs: 28,
      fat: 8,
      sugar: hasSugar ? 14 : 2,
      fiber: 2,
      sodium: 320,
      ingredients: ingredientsList,
      veganStatus: 'Maybe',
      vegetarianStatus: 'Yes',
      palmOil: hasPalmOil,
      artificialSweeteners: hasArtificialSweetener,
      artificialColors: hasArtificialColors,
      preservatives: hasPreservative,
      allergens: ['Gluten'],
      warnings: warnings.isEmpty ? ['None detected (offline estimate)'] : warnings,
      insights: insights.isEmpty ? ['Try connecting to internet for full AI verification'] : insights,
      alternatives: [
        FoodAlternative(
          name: 'Organic Mixed Seeds & Nuts',
          brand: 'Zivo Healthy Choice',
          reason: 'Rich in fiber and natural proteins without added sugars.',
        ),
      ],
      scanDate: DateTime.now(),
    );
  }

  static Future<FoodProduct> analyzeProduct({
    String? barcode,
    String? searchName,
    Map<String, dynamic>? rawDetails,
    String? imageBase64,
    String fitnessGoal = 'maintain',
  }) async {
    final cleanBarcode = barcode ?? rawDetails?['_id']?.toString() ?? rawDetails?['code']?.toString() ?? 'unknown_${DateTime.now().millisecondsSinceEpoch}';

    try {
      final cached = await VisionStorageService.getCachedProduct(categoryKey, cleanBarcode);
      if (cached != null) {
        return FoodProduct.fromJson(cached, barcode: cleanBarcode);
      }
    } catch (_) {}

    try {
      final cachedFirestore = await VisionFirebaseService.getProductFromFirestore(categoryKey, cleanBarcode);
      if (cachedFirestore != null) {
        await VisionStorageService.cacheProduct(categoryKey, cleanBarcode, cachedFirestore);
        return FoodProduct.fromJson(cachedFirestore, barcode: cleanBarcode);
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
        'product_name': searchName ?? 'Searched Product',
        'ingredients_text': 'Sugar, water, citric acid, sodium benzoate, artificial food color',
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
        
        // Personalization adjustment for AI result
        int finalScore = responseData['zivoScore'] ?? 70;
        final warnings = List<String>.from(responseData['warnings'] ?? []);
        final insights = List<String>.from(responseData['insights'] ?? []);
        if (fitnessGoal == 'lose') {
          finalScore = (finalScore - 10).clamp(0, 100);
          warnings.add('Weight Loss Goal Penalty: Calories or high glycemic carbs are restricted.');
          insights.add('This food does not align perfectly with your Weight Loss program.');
        }

        final dataToStore = {
          ...responseData,
          'zivoScore': finalScore,
          'warnings': warnings,
          'insights': insights,
          'scanDate': DateTime.now().toIso8601String(),
        };

        await VisionStorageService.cacheProduct(categoryKey, cleanBarcode, dataToStore);
        await VisionFirebaseService.saveProductToFirestore(categoryKey, cleanBarcode, dataToStore);

        return FoodProduct.fromJson(dataToStore, barcode: cleanBarcode);
      }
    } catch (e) {
      debugPrint("Cloud function analysis failed: $e");
    }

    final fallbackName = searchName ?? payload['product_name']?.toString() ?? 'Estimated Product';
    final fallbackIngredients = <String>[];
    final String? ingredientsText = payload['ingredients_text']?.toString() ?? payload['ingredients_text_en']?.toString();
    if (ingredientsText != null && ingredientsText.isNotEmpty) {
      fallbackIngredients.addAll(ingredientsText.split(',').map((e) => e.trim()));
    }

    final fallbackProduct = estimateLocally(cleanBarcode, fallbackName, fallbackIngredients, fitnessGoal: fitnessGoal);

    try {
      await VisionStorageService.cacheProduct(categoryKey, cleanBarcode, fallbackProduct.toJson());
    } catch (_) {}

    return fallbackProduct;
  }
}
