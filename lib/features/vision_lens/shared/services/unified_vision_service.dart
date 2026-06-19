import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_functions/cloud_functions.dart';
import '../../../../services/storage_service.dart';

class SugarAnalysis {
  final String impact; // High, Moderate, Low
  final String amount;
  final List<String> hiddenNamesDetected;
  final String verdict;

  SugarAnalysis({
    required this.impact,
    required this.amount,
    required this.hiddenNamesDetected,
    required this.verdict,
  });

  factory SugarAnalysis.fromJson(Map<String, dynamic> json) {
    return SugarAnalysis(
      impact: json['impact']?.toString() ?? 'Low',
      amount: json['amount']?.toString() ?? '0g/serving',
      hiddenNamesDetected: List<String>.from(json['hiddenNamesDetected'] ?? []),
      verdict: json['verdict']?.toString() ?? 'Safe sugar levels.',
    );
  }

  Map<String, dynamic> toJson() => {
        'impact': impact,
        'amount': amount,
        'hiddenNamesDetected': hiddenNamesDetected,
        'verdict': verdict,
      };
}

class CarbsAnalysis {
  final String impact; // High, Moderate, Low
  final String amount;
  final String verdict;

  CarbsAnalysis({
    required this.impact,
    required this.amount,
    required this.verdict,
  });

  factory CarbsAnalysis.fromJson(Map<String, dynamic> json) {
    return CarbsAnalysis(
      impact: json['impact']?.toString() ?? 'Low',
      amount: json['amount']?.toString() ?? '0g/serving',
      verdict: json['verdict']?.toString() ?? 'Safe carb levels.',
    );
  }

  Map<String, dynamic> toJson() => {
        'impact': impact,
        'amount': amount,
        'verdict': verdict,
      };
}

class PalmOilAnalysis {
  final bool present;
  final List<String> ingredientsDetected;
  final String verdict;

  PalmOilAnalysis({
    required this.present,
    required this.ingredientsDetected,
    required this.verdict,
  });

  factory PalmOilAnalysis.fromJson(Map<String, dynamic> json) {
    return PalmOilAnalysis(
      present: json['present'] as bool? ?? false,
      ingredientsDetected: List<String>.from(json['ingredientsDetected'] ?? []),
      verdict: json['verdict']?.toString() ?? 'No palm oil detected.',
    );
  }

  Map<String, dynamic> toJson() => {
        'present': present,
        'ingredientsDetected': ingredientsDetected,
        'verdict': verdict,
      };
}

class DecodedIngredient {
  final String name;
  final String sneakyNameFor; // Sugar, Carbs, Palm Oil, None
  final String meaning;
  final String safety; // Safe, Caution, Avoid
  final String description;

  DecodedIngredient({
    required this.name,
    required this.sneakyNameFor,
    required this.meaning,
    required this.safety,
    required this.description,
  });

  factory DecodedIngredient.fromJson(Map<String, dynamic> json) {
    return DecodedIngredient(
      name: json['name']?.toString() ?? '',
      sneakyNameFor: json['sneakyNameFor']?.toString() ?? 'None',
      meaning: json['meaning']?.toString() ?? '',
      safety: json['safety']?.toString() ?? 'Safe',
      description: json['description']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'sneakyNameFor': sneakyNameFor,
        'meaning': meaning,
        'safety': safety,
        'description': description,
      };
}

class ProductAlternative {
  final String name;
  final String brand;
  final String reason;
  final String healthGrade;

  ProductAlternative({
    required this.name,
    required this.brand,
    required this.reason,
    required this.healthGrade,
  });

  factory ProductAlternative.fromJson(Map<String, dynamic> json) {
    return ProductAlternative(
      name: json['name']?.toString() ?? '',
      brand: json['brand']?.toString() ?? 'Generic',
      reason: json['reason']?.toString() ?? '',
      healthGrade: json['healthGrade']?.toString() ?? 'A',
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        'brand': brand,
        'reason': reason,
        'healthGrade': healthGrade,
      };
}

class UnifiedProductReport {
  final String barcode;
  final String productName;
  final String brand;
  final String? imageUrl;
  final String category; // food, supplement, skincare
  final int zivoScore;
  final String healthGrade; // A, B, C, D, E
  final String verdict;
  final List<String> insights;
  final SugarAnalysis sugarAnalysis;
  final CarbsAnalysis carbsAnalysis;
  final PalmOilAnalysis palmOilAnalysis;
  final List<DecodedIngredient> decodedIngredients;
  final List<ProductAlternative> alternatives;
  final DateTime scanDate;
  final List<String> allergyWarnings;

  UnifiedProductReport({
    required this.barcode,
    required this.productName,
    required this.brand,
    this.imageUrl,
    required this.category,
    required this.zivoScore,
    required this.healthGrade,
    required this.verdict,
    required this.insights,
    required this.sugarAnalysis,
    required this.carbsAnalysis,
    required this.palmOilAnalysis,
    required this.decodedIngredients,
    required this.alternatives,
    required this.scanDate,
    required this.allergyWarnings,
  });

  factory UnifiedProductReport.fromJson(Map<String, dynamic> json) {
    return UnifiedProductReport(
      barcode: json['barcode']?.toString() ?? '',
      productName: json['productName']?.toString() ?? 'Unknown Product',
      brand: json['brand']?.toString() ?? 'Generic',
      imageUrl: json['imageUrl']?.toString(),
      category: json['category']?.toString() ?? 'food',
      zivoScore: json['zivoScore'] as int? ?? 50,
      healthGrade: json['healthGrade']?.toString() ?? 'C',
      verdict: json['verdict']?.toString() ?? '',
      insights: List<String>.from(json['insights'] ?? []),
      sugarAnalysis: SugarAnalysis.fromJson(Map<String, dynamic>.from(json['sugarAnalysis'] ?? {})),
      carbsAnalysis: CarbsAnalysis.fromJson(Map<String, dynamic>.from(json['carbsAnalysis'] ?? {})),
      palmOilAnalysis: PalmOilAnalysis.fromJson(Map<String, dynamic>.from(json['palmOilAnalysis'] ?? {})),
      decodedIngredients: (json['decodedIngredients'] as List?)
              ?.map((e) => DecodedIngredient.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      alternatives: (json['alternatives'] as List?)
              ?.map((e) => ProductAlternative.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      scanDate: json['scanDate'] != null ? DateTime.parse(json['scanDate'].toString()) : DateTime.now(),
      allergyWarnings: List<String>.from(json['allergyWarnings'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
        'barcode': barcode,
        'productName': productName,
        'brand': brand,
        'imageUrl': imageUrl,
        'category': category,
        'zivoScore': zivoScore,
        'healthGrade': healthGrade,
        'verdict': verdict,
        'insights': insights,
        'sugarAnalysis': sugarAnalysis.toJson(),
        'carbsAnalysis': carbsAnalysis.toJson(),
        'palmOilAnalysis': palmOilAnalysis.toJson(),
        'decodedIngredients': decodedIngredients.map((e) => e.toJson()).toList(),
        'alternatives': alternatives.map((e) => e.toJson()).toList(),
        'scanDate': scanDate.toIso8601String(),
        'allergyWarnings': allergyWarnings,
      };
}

class UnifiedVisionService {
  /// Automatic Product Category Detector
  /// Evaluates details using rule-based classification first.
  static String detectCategory(String productName, List<String> ingredients, [String? source]) {
    final cleanName = productName.toLowerCase();
    final cleanIngs = ingredients.map((e) => e.toLowerCase()).toList();
    final combinedText = '$cleanName ${cleanIngs.join(" ")}';

    // 1. Skincare indicators
    final skincareKeywords = [
      'aqua', 'glycerin', 'niacinamide', 'salicylic acid', 'retinol', 'spf', 'serum',
      'moisturizer', 'cleanser', 'hyaluronic', 'ceramide', 'dimethicone', 'paraben',
      'fragrance', 'cosmetic', 'lotion', 'cream', 'skincare', 'shampoo', 'conditioner',
      'face wash', 'sunscreen', 'body lotion', 'toner', 'lip balm'
    ];

    // 2. Supplement indicators
    final supplementKeywords = [
      'whey protein', 'creatine', 'bcaa', 'ashwagandha', 'fish oil', 'multivitamin',
      'supplement', 'capsule', 'tablet', 'softgel', 'gummy', 'biotin', 'collagen peptides',
      'pre-workout', 'mass gainer', 'isolate', 'concentrate', 'protein powder'
    ];
    final supplementUnits = RegExp(r'\b(mg|mcg|iu)\b');

    // 3. Food indicators
    final foodKeywords = [
      'calories', 'protein', 'carbohydrates', 'fat', 'sugar', 'fiber', 'serving size',
      'saturated fat', 'sodium', 'glucose syrup', 'palm oil', 'flour', 'cacao', 'cocoa',
      'biscuit', 'chips', 'chocolate', 'juice', 'snack', 'cereal', 'bread'
    ];

    int skincareMatches = 0;
    int supplementMatches = 0;
    int foodMatches = 0;

    for (var keyword in skincareKeywords) {
      if (combinedText.contains(keyword)) skincareMatches++;
    }

    for (var keyword in supplementKeywords) {
      if (combinedText.contains(keyword)) supplementMatches++;
    }
    if (supplementUnits.hasMatch(combinedText)) {
      supplementMatches += 2; // high weight for dosage units
    }

    for (var keyword in foodKeywords) {
      if (combinedText.contains(keyword)) foodMatches++;
    }

    // Direct OBF overrides
    if (source != null && source.contains('Beauty')) {
      return 'skincare';
    }

    if (skincareMatches > supplementMatches && skincareMatches > foodMatches) {
      return 'skincare';
    }
    if (supplementMatches > skincareMatches && supplementMatches > foodMatches) {
      return 'supplement';
    }
    
    // Default fallback is food
    return 'food';
  }

  /// Sequential API Lookup by barcode:
  /// Queries OpenFoodFacts first, then OpenBeautyFacts.
  static Future<Map<String, dynamic>?> lookupProductApis(String barcode) async {
    final cleanBarcode = barcode.trim();
    if (cleanBarcode.isEmpty) return null;

    // 1. Try OpenFoodFacts API
    try {
      final offUrl = Uri.parse('https://world.openfoodfacts.org/api/v2/product/$cleanBarcode.json');
      final response = await http.get(offUrl).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 1 || data['status'] == 'success' || data['product'] != null) {
          final p = data['product'] ?? {};
          final name = p['product_name'] ?? p['product_name_en'] ?? 'OFF Product ($cleanBarcode)';
          final brand = p['brands'] ?? 'Generic';
          final img = p['image_url'] ?? p['image_front_url'] ?? p['image_small_url'];

          final List<String> ingredients = [];
          final List<dynamic> rawIngs = p['ingredients'] ?? [];
          for (var ing in rawIngs) {
            final t = ing['text']?.toString();
            if (t != null && t.isNotEmpty) {
              ingredients.add(t);
            }
          }
          if (ingredients.isEmpty && p['ingredients_text'] != null) {
            ingredients.addAll((p['ingredients_text'] as String).split(',').map((e) => e.trim()));
          }

          final detectedCat = detectCategory(name, ingredients, 'OpenFoodFacts API');

          return {
            'product_name': name,
            'brand': brand,
            'ingredients': ingredients,
            'image_url': img,
            'category': detectedCat,
            'source': 'OpenFoodFacts API',
            'raw_product': p,
          };
        }
      }
    } catch (e) {
      debugPrint("OpenFoodFacts lookup failed: $e");
    }

    // 2. Try OpenBeautyFacts API
    try {
      final obfUrl = Uri.parse('https://world.openbeautyfacts.org/api/v2/product/$cleanBarcode.json');
      final response = await http.get(obfUrl).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 1 || data['status'] == 'success' || data['product'] != null) {
          final p = data['product'] ?? {};
          final name = p['product_name'] ?? p['product_name_en'] ?? 'OBF Product ($cleanBarcode)';
          final brand = p['brands'] ?? 'Generic';
          final img = p['image_url'] ?? p['image_front_url'] ?? p['image_small_url'];

          final List<String> ingredients = [];
          final List<dynamic> rawIngs = p['ingredients'] ?? [];
          for (var ing in rawIngs) {
            final t = ing['text']?.toString();
            if (t != null && t.isNotEmpty) {
              ingredients.add(t);
            }
          }
          if (ingredients.isEmpty && p['ingredients_text'] != null) {
            ingredients.addAll((p['ingredients_text'] as String).split(',').map((e) => e.trim()));
          }

          final detectedCat = detectCategory(name, ingredients, 'OpenBeautyFacts API');

          return {
            'product_name': name,
            'brand': brand,
            'ingredients': ingredients,
            'image_url': img,
            'category': detectedCat,
            'source': 'OpenBeautyFacts API',
            'raw_product': p,
          };
        }
      }
    } catch (e) {
      debugPrint("OpenBeautyFacts lookup failed: $e");
    }

    return null;
  }

  /// Search product by name in OpenFoodFacts / OpenBeautyFacts
  static Future<Map<String, dynamic>?> lookupProductByName(String name, String category) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) return null;
    final cleanCategory = category.toLowerCase().trim();
    
    // Try both databases — skincare goes to beauty first, rest to food first
    final urls = cleanCategory == 'skincare'
        ? [
            'https://world.openbeautyfacts.org/cgi/search.pl?search_terms=${Uri.encodeComponent(cleanName)}&search_simple=1&action=process&json=1',
            'https://world.openfoodfacts.org/cgi/search.pl?search_terms=${Uri.encodeComponent(cleanName)}&search_simple=1&action=process&json=1',
          ]
        : [
            'https://world.openfoodfacts.org/cgi/search.pl?search_terms=${Uri.encodeComponent(cleanName)}&search_simple=1&action=process&json=1',
            'https://world.openbeautyfacts.org/cgi/search.pl?search_terms=${Uri.encodeComponent(cleanName)}&search_simple=1&action=process&json=1',
          ];

    for (final searchUrl in urls) {
      try {
        final response = await http.get(Uri.parse(searchUrl)).timeout(const Duration(seconds: 5));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final products = data['products'] as List?;
          if (products != null && products.isNotEmpty) {
            final p = products.first;
            final pName = p['product_name'] ?? p['product_name_en'] ?? cleanName;
            final brand = p['brands'] ?? 'Generic';
            final img = p['image_url'] ?? p['image_front_url'];
            final List<String> ingredients = [];
            final List<dynamic> rawIngs = p['ingredients'] ?? [];
            for (var ing in rawIngs) {
              final t = ing['text']?.toString();
              if (t != null && t.isNotEmpty) {
                ingredients.add(t);
              }
            }
            if (ingredients.isEmpty && p['ingredients_text'] != null) {
              ingredients.addAll((p['ingredients_text'] as String).split(',').map((e) => e.trim()));
            }
            
            final detectedCat = detectCategory(pName, ingredients, searchUrl.contains('beauty') ? 'OpenBeautyFacts API' : 'OpenFoodFacts API');
            
            return {
              'product_name': pName,
              'brand': brand,
              'ingredients': ingredients,
              'image_url': img,
              'category': detectedCat,
              'source': searchUrl.contains('beauty') ? 'OpenBeautyFacts API' : 'OpenFoodFacts API',
              'raw_product': p,
            };
          }
        }
      } catch (e) {
        debugPrint("Product name search failed for '$cleanName': $e");
      }
    }
    return null;
  }

  /// STEP 1: Identify product from image using Gemini Vision (via cloud function)
  static Future<Map<String, dynamic>?> identifyProductFromImage(String base64Content) async {
    int retries = 0;
    while (retries < 3) {
      try {
        // Strip data URI prefix if present
        String cleanBase64 = base64Content;
        if (cleanBase64.contains(',')) {
          cleanBase64 = cleanBase64.split(',').last;
        }

        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('identifyProduct');
        final HttpsCallableResult result = await callable.call({
          'imageBase64': cleanBase64,
        });

        if (result.data != null) {
          final data = Map<String, dynamic>.from(result.data as Map);
          debugPrint("identifyProduct cloud function returned: $data");
          return data;
        }
        break;
      } catch (e) {
        retries++;
        debugPrint("identifyProduct cloud function failed (Attempt $retries/3): $e");
        
        final errorString = e.toString().toLowerCase();
        final isBusy = errorString.contains('busy') || 
                       errorString.contains('resource_exhausted') || 
                       errorString.contains('429') || 
                       errorString.contains('503') ||
                       errorString.contains('overloaded') ||
                       errorString.contains('rate limit') ||
                       errorString.contains('unavailable');
                       
        if (isBusy && retries < 3) {
          debugPrint("identifyProduct server busy. Retrying in 2 seconds...");
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        
        if (retries >= 3 && isBusy) {
          throw Exception("Gemini AI server is currently busy. Please try again in a moment.");
        }
        break;
      }
    }
    return null;
  }

  /// STEP 2: Deep AI Analysis via Cloud Function
  /// Sends product data + optional image to Gemini for comprehensive health analysis
  static Future<UnifiedProductReport> analyzeWithGemini({
    required String barcode,
    required String productName,
    required String brand,
    required List<String> ingredients,
    required String category,
    String? imageUrl,
    String? imageBase64,
  }) async {
    final cleanCategory = category.toLowerCase().trim();
    int retries = 0;
    
    while (retries < 3) {
      try {
        final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('analyzeVisionProduct');
        final String categoryKey = cleanCategory == 'skincare'
            ? 'Skincare'
            : (cleanCategory == 'supplement' ? 'Supplement' : 'Food');

        // Strip data URI prefix from image if present
        // Optimization: Only send image base64 if we don't have ingredients text yet (saves input tokens)
        String? cleanImageBase64 = ingredients.isNotEmpty ? null : imageBase64;
        if (cleanImageBase64 != null && cleanImageBase64.contains(',')) {
          cleanImageBase64 = cleanImageBase64.split(',').last;
        }

        final HttpsCallableResult result = await callable.call({
          'category': categoryKey,
          'payload': {
            'product_name': productName,
            'brands': brand,
            'ingredients_text': ingredients.join(', '),
            'image_url': imageUrl,
          },
          'imageBase64': cleanImageBase64,
        });

        if (result.data != null) {
          final Map<String, dynamic> data = Map<String, dynamic>.from(result.data as Map);
          return _buildReportFromAiResponse(
            data: data,
            barcode: barcode,
            fallbackName: productName,
            fallbackBrand: brand,
            fallbackCategory: cleanCategory,
            fallbackImageUrl: imageUrl,
            fallbackIngredients: ingredients,
            userImageBase64: imageBase64,
          );
        }
        break;
      } catch (e) {
        retries++;
        debugPrint("Firebase Functions analyzeVisionProduct failed (Attempt $retries/3): $e");
        
        final errorString = e.toString().toLowerCase();
        final isBusy = errorString.contains('busy') || 
                       errorString.contains('resource_exhausted') || 
                       errorString.contains('429') || 
                       errorString.contains('503') ||
                       errorString.contains('overloaded') ||
                       errorString.contains('rate limit') ||
                       errorString.contains('unavailable');
                       
        if (isBusy && retries < 3) {
          debugPrint("Gemini server busy. Retrying in 2 seconds...");
          await Future.delayed(const Duration(seconds: 2));
          continue;
        }
        
        if (retries >= 3 && isBusy) {
          throw Exception("Gemini AI server is currently busy. Please try again in a moment.");
        }
        break;
      }
    }

    // Fallback: If cloud function fails, run Local Rule Engine
    if (ingredients.isNotEmpty) {
      debugPrint("Falling back to local rule engine for $productName");
      return runLocalRuleEngine(
        barcode: barcode,
        productName: productName,
        brand: brand,
        ingredients: ingredients,
        category: cleanCategory,
        imageUrl: imageUrl,
      );
    }

    // If no ingredients and AI failed, throw error
    throw Exception('Unable to analyze $productName. Gemini AI is currently busy or unavailable. Please try again.');
  }

  /// Build a UnifiedProductReport from Gemini AI cloud function response
  static UnifiedProductReport _buildReportFromAiResponse({
    required Map<String, dynamic> data,
    required String barcode,
    required String fallbackName,
    required String fallbackBrand,
    required String fallbackCategory,
    String? fallbackImageUrl,
    required List<String> fallbackIngredients,
    String? userImageBase64,
  }) {
    final rawName = data['productName'] ?? data['product_name'] ?? fallbackName;
    final rawBrand = data['brand'] ?? data['brands'] ?? fallbackBrand;
    final int score = data['zivoScore'] ?? data['score'] ?? 50;
    final String grade = data['healthGrade'] ?? _scoreToGrade(score);

    // Build insights
    final List<String> insights = [];
    if (data['insights'] != null && data['insights'] is List) {
      insights.addAll((data['insights'] as List).map((e) => e.toString()));
    }
    if (insights.length > 5) {
      insights.removeRange(5, insights.length);
    }

    // Build decoded ingredients from AI response
    final List<DecodedIngredient> decoded = [];
    if (data['decodedIngredients'] != null && data['decodedIngredients'] is List) {
      for (var ing in data['decodedIngredients'] as List) {
        if (ing is Map) {
          decoded.add(DecodedIngredient.fromJson(Map<String, dynamic>.from(ing)));
        }
      }
    }

    // Build alternatives from AI response
    final List<ProductAlternative> alternatives = [];
    if (data['alternatives'] != null && data['alternatives'] is List) {
      for (var alt in data['alternatives'] as List) {
        if (alt is Map) {
          alternatives.add(ProductAlternative(
            name: alt['name']?.toString() ?? 'Alternative',
            brand: alt['brand']?.toString() ?? 'Generic',
            reason: alt['reason']?.toString() ?? '',
            healthGrade: alt['healthGrade']?.toString() ?? 'A',
          ));
        }
      }
    }

    // Build sugar analysis
    SugarAnalysis sugarAnalysis;
    if (data['sugarAnalysis'] != null && data['sugarAnalysis'] is Map) {
      sugarAnalysis = SugarAnalysis.fromJson(Map<String, dynamic>.from(data['sugarAnalysis'] as Map));
    } else {
      sugarAnalysis = SugarAnalysis(impact: 'Low', amount: '0g', hiddenNamesDetected: [], verdict: 'No sneaky sugars detected.');
    }

    // Build palm oil analysis
    PalmOilAnalysis palmOilAnalysis;
    if (data['palmOilAnalysis'] != null && data['palmOilAnalysis'] is Map) {
      palmOilAnalysis = PalmOilAnalysis.fromJson(Map<String, dynamic>.from(data['palmOilAnalysis'] as Map));
    } else {
      palmOilAnalysis = PalmOilAnalysis(present: false, ingredientsDetected: [], verdict: 'No palm oil detected.');
    }

    // Build carbs analysis
    CarbsAnalysis carbsAnalysis;
    if (data['carbsAnalysis'] != null && data['carbsAnalysis'] is Map) {
      carbsAnalysis = CarbsAnalysis.fromJson(Map<String, dynamic>.from(data['carbsAnalysis'] as Map));
    } else {
      carbsAnalysis = CarbsAnalysis(impact: 'Low', amount: '0g', verdict: 'Safe carb levels.');
    }

    // Verdict text
    String verdictText = data['verdict']?.toString() ?? 'Product analyzed successfully.';
    if (fallbackCategory == 'food') {
      final words = verdictText.split(' ');
      if (words.length > 12) {
        verdictText = '${words.take(12).join(' ')}...';
      }
    }

    // Resolve imageUrl: try data['imageUrl'] first, then fallbackImageUrl, then userImageBase64
    String? resolvedImageUrl = data['imageUrl'] ?? data['image_url'] ?? fallbackImageUrl;
    if ((resolvedImageUrl == null || resolvedImageUrl.isEmpty) && userImageBase64 != null && userImageBase64.isNotEmpty) {
      if (userImageBase64.startsWith('data:image/')) {
        resolvedImageUrl = userImageBase64;
      } else {
        resolvedImageUrl = 'data:image/jpeg;base64,$userImageBase64';
      }
    }

    final List<String> allergyWarnings = [];
    if (data['allergyWarnings'] != null && data['allergyWarnings'] is List) {
      allergyWarnings.addAll((data['allergyWarnings'] as List).map((e) => e.toString()));
    }

    return UnifiedProductReport(
      barcode: barcode,
      productName: rawName,
      brand: rawBrand,
      imageUrl: resolvedImageUrl,
      category: fallbackCategory,
      zivoScore: score,
      healthGrade: grade,
      verdict: verdictText,
      insights: insights,
      sugarAnalysis: sugarAnalysis,
      carbsAnalysis: carbsAnalysis,
      palmOilAnalysis: palmOilAnalysis,
      decodedIngredients: decoded,
      alternatives: alternatives,
      scanDate: DateTime.now(),
      allergyWarnings: allergyWarnings,
    );
  }

  /// High-Fidelity Local Rule Engine (Fallback when AI is unavailable)
  static UnifiedProductReport runLocalRuleEngine({
    required String barcode,
    required String productName,
    required String brand,
    required List<String> ingredients,
    required String category,
    String? imageUrl,
    Map<String, dynamic>? rawProduct,
  }) {
    final cleanCategory = category.toLowerCase().trim();
    final p = rawProduct ?? {};
    final nutriments = p['nutriments'] ?? {};

    // 1. Setup default lists
    final List<DecodedIngredient> decoded = [];
    final List<String> insights = [];

    bool hasSneakySugar = false;
    bool hasPalmOil = false;
    bool hasCarbs = false;

    final List<String> sugarList = [];
    final List<String> palmList = [];

    // Parse ingredients to classify them
    for (var ing in ingredients) {
      final lowIng = ing.toLowerCase().trim();
      String sneakyFor = 'None';
      String meaning = 'Standard ingredient';
      String safety = 'Safe';
      String desc = 'Safe to use or consume.';

      // Sugars Check
      if (lowIng.contains('sugar') ||
          lowIng.contains('fructose') ||
          lowIng.contains('sucrose') ||
          lowIng.contains('dextrose') ||
          lowIng.contains('maltodextrin') ||
          lowIng.contains('cane juice') ||
          lowIng.contains('lactose') ||
          lowIng.contains('syrup') ||
          lowIng.contains('caramel')) {
        hasSneakySugar = true;
        sneakyFor = 'Sugar';
        meaning = 'Refined Sweetener';
        safety = 'Caution';
        desc = 'A refined sweetener that spikes blood glucose and insulin levels.';
        sugarList.add(ing);
      }

      // Palm Oil Check
      if (lowIng.contains('palm') ||
          lowIng.contains('palmitate') ||
          lowIng.contains('palmitic') ||
          lowIng.contains('stearin') ||
          lowIng.contains('glycerides') ||
          lowIng.contains('palm stearin')) {
        hasPalmOil = true;
        sneakyFor = 'Palm Oil';
        meaning = 'Processed Saturated Fat';
        safety = 'Avoid';
        desc = 'Palm-based processed fat associated with elevated cardiovascular risk and inflammation.';
        palmList.add(ing);
      }

      // Carbs Check
      if (lowIng.contains('starch') ||
          lowIng.contains('dextrin') ||
          lowIng.contains('flour') ||
          lowIng.contains('carb') ||
          lowIng.contains('maltose')) {
        hasCarbs = true;
        sneakyFor = 'Carbs';
        meaning = 'Processed Carbohydrate';
        safety = 'Caution';
        desc = 'High carbohydrate load that may cause blood sugar fluctuations.';
      }

      // Skincare Specifics
      if (cleanCategory == 'skincare') {
        if (lowIng.contains('alcohol denat') || lowIng.contains('sd alcohol') || lowIng.contains('isopropyl alcohol')) {
          safety = 'Avoid';
          meaning = 'Drying Alcohol';
          desc = 'Harsh cosmetic alcohol that strips the skin barrier and causes irritation.';
        } else if (lowIng.contains('fragrance') || lowIng.contains('parfum') || lowIng.contains('essential oil')) {
          safety = 'Caution';
          meaning = 'Fragrance / Sensitizer';
          desc = 'Synthetic or natural fragrance molecules that can cause contact allergies.';
        } else if (lowIng.contains('salicylic acid') || lowIng.contains('retinol') || lowIng.contains('glycolic')) {
          safety = 'Caution';
          meaning = 'Active Acid / Retinoid';
          desc = 'Potent active ingredient. Use caution and sun protection.';
        } else if (lowIng.contains('niacinamide') || lowIng.contains('glycerin') || lowIng.contains('aqua') || lowIng.contains('ceramide')) {
          safety = 'Safe';
          meaning = 'Skin Nourishing Agent';
          desc = 'Highly beneficial skin-identical or soothing ingredient.';
        }
      }

      // Supplement Specifics
      if (cleanCategory == 'supplement') {
        if (lowIng.contains('sucralose') || lowIng.contains('aspartame') || lowIng.contains('acesulfame')) {
          safety = 'Avoid';
          meaning = 'Artificial Sweetener';
          desc = 'Synthetic sweetener used to sweeten supplements without adding calories.';
        } else if (lowIng.contains('magnesium stearate') || lowIng.contains('silicon dioxide')) {
          safety = 'Caution';
          meaning = 'Filler / Anti-caking Agent';
          desc = 'Standard manufacturing additive used to prevent clumping in capsules.';
        }
      }

      decoded.add(DecodedIngredient(
        name: ing,
        sneakyNameFor: sneakyFor,
        meaning: meaning,
        safety: safety,
        description: desc,
      ));
    }

    int score = 100;
    String grade = 'A';
    String verdict = '';

    // Calculate score & categories
    if (cleanCategory == 'skincare') {
      bool hasAcneTrigger = ingredients.any((e) => e.toLowerCase().contains('myristate') || e.toLowerCase().contains('coconut oil'));
      bool hasHarshAlcohol = ingredients.any((e) => e.toLowerCase().contains('alcohol denat') || e.toLowerCase().contains('sd alcohol'));
      bool hasFragrance = ingredients.any((e) => e.toLowerCase().contains('fragrance') || e.toLowerCase().contains('parfum'));
      bool hasRetinol = ingredients.any((e) => e.toLowerCase().contains('retinol') || e.toLowerCase().contains('retinoid'));
      bool hasSalicylic = ingredients.any((e) => e.toLowerCase().contains('salicylic'));

      if (hasAcneTrigger) { score -= 20; insights.add('⚠ Acne Trigger Risk'); }
      if (hasHarshAlcohol) { score -= 30; insights.add('❌ Harsh Alcohols'); }
      if (hasFragrance) { score -= 15; insights.add('⚠ Contains Fragrance'); }
      if (hasRetinol || hasSalicylic) { insights.add('⚠ Sensitive Skin Caution'); } else { insights.add('✅ Pregnancy Friendly'); }
      if (!hasAcneTrigger && !hasHarshAlcohol) { insights.add('✅ Non-Comedogenic'); }

      score = score.clamp(0, 100);
      grade = _scoreToGrade(score);

      if (score >= 80) {
        verdict = "Gentle, clean formulation suitable for most skin types.";
      } else if (score >= 60) {
        verdict = "Suitable for normal skin with minimal irritation risk.";
      } else {
        verdict = "Fragrance-heavy formula with potential irritation and acne risks.";
      }
    } else if (cleanCategory == 'supplement') {
      bool hasSweetener = ingredients.any((e) => e.toLowerCase().contains('sucralose') || e.toLowerCase().contains('aspartame') || e.toLowerCase().contains('acesulfame'));
      bool hasColors = ingredients.any((e) => e.toLowerCase().contains('red 40') || e.toLowerCase().contains('yellow 5') || e.toLowerCase().contains('blue 1'));
      bool hasFillers = ingredients.any((e) => e.toLowerCase().contains('magnesium stearate') || e.toLowerCase().contains('silicon dioxide'));

      if (hasSweetener) { score -= 20; insights.add('⚠ Contains Sucralose'); }
      if (hasColors) { score -= 25; insights.add('❌ Artificial Coloring'); }
      if (hasFillers) { score -= 15; insights.add('⚠ Contains Binders/Fillers'); }
      if (!hasSweetener && !hasColors) { insights.add('✅ High Purity'); }
      if (productName.toLowerCase().contains('whey') || productName.toLowerCase().contains('creatine')) {
        insights.add('✅ Quality Active Ingredients');
      }

      score = score.clamp(0, 100);
      grade = _scoreToGrade(score);

      if (score >= 80) {
        verdict = "High-purity formula with minimal fillers and zero artificial sweeteners.";
      } else if (score >= 60) {
        verdict = "Good active profile but contains fillers or artificial sweeteners.";
      } else {
        verdict = "Contains multiple fillers and artificial coloring. Choose pure alternatives.";
      }
    } else {
      // Food calculations (Max 12-word verdict!)
      final double sugarG = double.tryParse(nutriments['sugars_100g']?.toString() ?? '') ?? 0.0;
      final double sodiumG = double.tryParse(nutriments['sodium_100g']?.toString() ?? '') ?? 0.0;
      final double satFatG = double.tryParse(nutriments['saturated-fat_100g']?.toString() ?? '') ?? 0.0;
      final double proteinG = double.tryParse(nutriments['proteins_100g']?.toString() ?? '') ?? 0.0;
      final double fiberG = double.tryParse(nutriments['fiber_100g']?.toString() ?? '') ?? 0.0;
      final int novaGroup = int.tryParse(p['nova_group']?.toString() ?? '') ?? 0;
      final String nsGrade = (p['nutrition_grades'] ?? p['nutriscore_grade'] ?? '').toString().toLowerCase();

      if (nsGrade == 'a') score += 10;
      if (nsGrade == 'b') score += 5;
      if (nsGrade == 'd') score -= 20;
      if (nsGrade == 'e') score -= 35;

      if (novaGroup == 4) { score -= 30; insights.add('❌ Ultra Processed'); }
      if (hasPalmOil) { score -= 25; insights.add('❌ Palm Oil Present'); }
      if (sugarG > 15.0 || hasSneakySugar) { score -= 20; insights.add('❌ High Sugar'); }
      if (sodiumG > 0.5) { score -= 15; insights.add('⚠ High Sodium'); }
      if (satFatG > 5.0) score -= 10;
      if (proteinG > 10.0) { score += 10; insights.add('✅ High Protein'); }
      if (fiberG > 4.0) { score += 5; insights.add('✅ High Fiber'); }

      final additivesCount = p['additives_n'] as int? ?? 0;
      if (additivesCount > 3) {
        score -= 10;
        insights.add('⚠ Multiple Additives');
      }

      score = score.clamp(0, 100);
      grade = _scoreToGrade(score);

      if (score >= 80) {
        verdict = "Clean ingredient profile. Excellent for daily consumption.";
      } else if (score >= 65) {
        verdict = "Good overall choice. Contains minimal processing.";
      } else if (score >= 50) {
        verdict = "Moderate choice. Watch sugar and processing levels.";
      } else if (score >= 35) {
        verdict = "Highly processed food. Better alternatives exist.";
      } else {
        verdict = "Ultra-processed snack. Avoid regular consumption.";
      }
    }

    // Trim insights list to max 5
    if (insights.length > 5) {
      insights.removeRange(5, insights.length);
    }

    final List<String> allergyWarnings = [];
    for (var ing in ingredients) {
      final lowIng = ing.toLowerCase().trim();
      if (lowIng.contains('peanut') || lowIng.contains('almond') || lowIng.contains('cashew') || lowIng.contains('nut')) {
        if (!allergyWarnings.contains('Contains Nuts')) allergyWarnings.add('Contains Nuts');
      }
      if (lowIng.contains('milk') || lowIng.contains('dairy') || lowIng.contains('whey') || lowIng.contains('casein') || lowIng.contains('lactose')) {
        if (!allergyWarnings.contains('Contains Dairy')) allergyWarnings.add('Contains Dairy');
      }
      if (lowIng.contains('wheat') || lowIng.contains('gluten') || lowIng.contains('barley') || lowIng.contains('rye')) {
        if (!allergyWarnings.contains('Contains Gluten')) allergyWarnings.add('Contains Gluten');
      }
      if (lowIng.contains('soy')) {
        if (!allergyWarnings.contains('Contains Soy')) allergyWarnings.add('Contains Soy');
      }
      if (lowIng.contains('egg')) {
        if (!allergyWarnings.contains('Contains Egg')) allergyWarnings.add('Contains Egg');
      }
    }

    return UnifiedProductReport(
      barcode: barcode,
      productName: productName,
      brand: brand,
      imageUrl: imageUrl,
      category: cleanCategory,
      zivoScore: score,
      healthGrade: grade,
      verdict: verdict,
      insights: insights,
      sugarAnalysis: SugarAnalysis(
        impact: hasSneakySugar ? 'High' : 'Low',
        amount: nutriments['sugars_serving'] != null ? '${nutriments['sugars_serving']}g/serving' : (hasSneakySugar ? '14g/serving' : '0g/serving'),
        hiddenNamesDetected: sugarList,
        verdict: hasSneakySugar ? 'Contains sneaky sugars.' : 'No sneaky sugars detected.',
      ),
      carbsAnalysis: CarbsAnalysis(
        impact: hasCarbs ? 'High' : 'Low',
        amount: nutriments['carbohydrates_serving'] != null ? '${nutriments['carbohydrates_serving']}g/serving' : (hasCarbs ? '25g/serving' : '0g/serving'),
        verdict: hasCarbs ? 'Contains processed carbohydrates.' : 'Low carb impact.',
      ),
      palmOilAnalysis: PalmOilAnalysis(
        present: hasPalmOil,
        ingredientsDetected: palmList,
        verdict: hasPalmOil ? 'Contains palm-based processed oils.' : 'No palm oil detected.',
      ),
      decodedIngredients: decoded,
      alternatives: [],
      scanDate: DateTime.now(),
      allergyWarnings: allergyWarnings,
    );
  }

  static String _scoreToGrade(int score) {
    if (score >= 80) return 'A';
    if (score >= 65) return 'B';
    if (score >= 50) return 'C';
    if (score >= 35) return 'D';
    return 'E';
  }
}
