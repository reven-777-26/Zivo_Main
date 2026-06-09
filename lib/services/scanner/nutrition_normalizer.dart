import 'package:flutter/material.dart';
import '../../core/theme.dart';
import '../storage_service.dart';
import '../../models/user_profile.dart';

class ScannedProduct {
  final String name;
  final String rating; // 'Good', 'Moderate', 'Avoid' or 'Safe Match', 'Caution', 'Avoid'
  final Color ratingColor;
  final IconData imageIcon;
  final String calories;
  final String macros;
  final String proteinQuality;
  final List<String> ingredients;
  final List<String> warnings;
  final String acneScore;
  final String source;
  final String confidence; // 'HIGH', 'MEDIUM', 'LOW'
  final String method; // 'Barcode Decoded', 'OCR Extraction', 'Multimodal Estimation'
  final String servingSize;
  final String category;
  final List<Map<String, dynamic>> alternatives;
  final List<Map<String, String>> retailLinks;

  ScannedProduct({
    required this.name,
    required this.rating,
    required this.ratingColor,
    required this.imageIcon,
    required this.calories,
    required this.macros,
    required this.proteinQuality,
    required this.ingredients,
    required this.warnings,
    required this.acneScore,
    required this.source,
    required this.confidence,
    required this.method,
    required this.servingSize,
    required this.category,
    this.alternatives = const [],
    this.retailLinks = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'rating': rating,
      'ratingColorValue': ratingColor.value,
      'imageIconCode': imageIcon.codePoint,
      'calories': calories,
      'macros': macros,
      'proteinQuality': proteinQuality,
      'ingredients': ingredients,
      'warnings': warnings,
      'acneScore': acneScore,
      'source': source,
      'confidence': confidence,
      'method': method,
      'servingSize': servingSize,
      'category': category,
      'alternatives': alternatives,
      'retailLinks': retailLinks,
    };
  }

  factory ScannedProduct.fromJson(Map<String, dynamic> json) {
    Color color = AppTheme.textSecondary;
    if (json['ratingColor'] is Color) {
      color = json['ratingColor'] as Color;
    } else if (json['ratingColorValue'] is int) {
      color = Color(json['ratingColorValue'] as int);
    }

    IconData icon = Icons.fastfood_rounded;
    if (json['imageIcon'] is IconData) {
      icon = json['imageIcon'] as IconData;
    } else if (json['imageIconCode'] is int) {
      icon = IconData(json['imageIconCode'] as int, fontFamily: 'MaterialIcons');
    }

    return ScannedProduct(
      name: json['name'] ?? '',
      rating: json['rating'] ?? '',
      ratingColor: color,
      imageIcon: icon,
      calories: json['calories'] ?? '',
      macros: json['macros'] ?? '',
      proteinQuality: json['proteinQuality'] ?? '',
      ingredients: List<String>.from(json['ingredients'] ?? []),
      warnings: List<String>.from(json['warnings'] ?? []),
      acneScore: json['acneScore'] ?? '',
      source: json['source'] ?? '',
      confidence: json['confidence'] ?? '',
      method: json['method'] ?? '',
      servingSize: json['servingSize'] ?? '',
      category: json['category'] ?? '',
      alternatives: (json['alternatives'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
      retailLinks: (json['retailLinks'] as List?)
              ?.map((e) => Map<String, String>.from(e))
              .toList() ??
          [],
    );
  }
}

class IngredientInfo {
  final String type;
  final String risk;
  final String effect;
  final String category;
  final List<String> badFor;

  IngredientInfo({
    required this.type,
    required this.risk,
    required this.effect,
    required this.category,
    this.badFor = const [],
  });
}

class NutritionNormalizer {
  static final Map<String, IngredientInfo> ingredientLibrary = {
    'e621': IngredientInfo(type: 'Excitotoxin', risk: 'HIGH', effect: 'MSG. Triggers overeating & headaches.', category: 'food'),
    'msg': IngredientInfo(type: 'Excitotoxin', risk: 'HIGH', effect: 'MSG. Triggers overeating & headaches.', category: 'food'),
    'monosodium glutamate': IngredientInfo(type: 'Excitotoxin', risk: 'HIGH', effect: 'MSG. Triggers overeating & headaches.', category: 'food'),
    'high fructose': IngredientInfo(type: 'Sweetener', risk: 'CRITICAL', effect: 'Direct liver fat accumulation.', category: 'food'),
    'hydrogenated': IngredientInfo(type: 'Trans Fat', risk: 'CRITICAL', effect: 'Permanent arterial damage.', category: 'food'),
    'soybean oil': IngredientInfo(type: 'Inflammatory Fat', risk: 'MED', effect: 'High Omega-6. Systemic inflammation.', category: 'food'),
    'carrageenan': IngredientInfo(type: 'Thickener', risk: 'HIGH', effect: 'Gut inflammation & bloating.', category: 'food'),
    'e250': IngredientInfo(type: 'Preservative', risk: 'CRITICAL', effect: 'Sodium Nitrite. Carcinogen.', category: 'food'),
    'red 40': IngredientInfo(type: 'Synthetic Dye', risk: 'HIGH', effect: 'Neurotoxin link / Hyperactivity.', category: 'food'),
    'paraben': IngredientInfo(type: 'Endocrine Disruptor', risk: 'HIGH', effect: 'Mimics estrogen. Hormonal imbalance.', category: 'skin', badFor: ['All']),
    'fragrance': IngredientInfo(type: 'Allergen', risk: 'HIGH', effect: 'Leading cause of dermatitis.', category: 'skin', badFor: ['Sensitive', 'Acne']),
    'alcohol denat': IngredientInfo(type: 'Solvent', risk: 'HIGH', effect: 'Destroys lipid barrier. Pro-aging.', category: 'skin', badFor: ['Dry', 'Sensitive']),
    'coconut oil': IngredientInfo(type: 'Pore Clogger', risk: 'HIGH', effect: 'Comedogenic Lvl 4. Cystic acne risk.', category: 'skin', badFor: ['Oily', 'Acne']),
  };

  /// Normalizes ingredients, serving sizes, and raw macro units from any database or OCR output.
  static ScannedProduct normalize({
    required String name,
    required dynamic rawCalories,
    required dynamic rawProtein,
    required dynamic rawCarbs,
    required dynamic rawFat,
    required List<String> rawIngredients,
    required List<String> rawWarnings,
    required String category, // 'Food', 'Supplement', 'Skincare'
    required String source,
    required String confidence,
    required String method,
    String? rawServingSize,
    String? rawAcneScore,
    String? skinType,
    dynamic rawSodium,
    List<Map<String, dynamic>>? alternatives,
    List<Map<String, String>>? retailLinks,
  }) {
    // 1. Fetch current UserProfile from Hive to run offline custom normalization loops
    final UserProfile? userProfile = StorageService.getUserProfile();
    final double userCalorieGoal = (userProfile?.calorieGoal ?? 2200).toDouble();
    final double userProteinGoal = (userProfile?.proteinGoal ?? 150).toDouble();
    final String userGoal = userProfile?.goal ?? 'maintain';
    final int userAge = userProfile?.age ?? 26;
    final String activeSkinType = skinType ?? userProfile?.skinType ?? 'Normal';
    
    // 2. Normalize Calories
    String calStr = 'N/A';
    double calVal = 0.0;
    if (rawCalories != null) {
      final String calRaw = rawCalories.toString().toLowerCase();
      if (calRaw != 'n/a' && calRaw.isNotEmpty) {
        final double? val = double.tryParse(calRaw.replaceAll(RegExp(r'[^0-9\.]'), ''));
        if (val != null) {
          calVal = val;
          calStr = '${val.round()} kcal';
        } else {
          calStr = calRaw.contains('kcal') ? calRaw : '$calRaw kcal';
        }
      }
    }

    // 3. Normalize serving size
    String serving = rawServingSize?.trim() ?? '1 serving';
    if (serving.isEmpty || serving.toLowerCase() == 'null') {
      serving = '1 serving';
    }

    // 4. Normalize macro grams
    double pVal = _parseGramValue(rawProtein);
    double cVal = _parseGramValue(rawCarbs);
    double fVal = _parseGramValue(rawFat);
    double sodVal = _parseGramValue(rawSodium);

    String macrosStr = 'N/A';
    if (pVal > 0 || cVal > 0 || fVal > 0 || sodVal > 0) {
      macrosStr = 'P: ${pVal.toStringAsFixed(1)}g  C: ${cVal.toStringAsFixed(1)}g  F: ${fVal.toStringAsFixed(1)}g  Na: ${sodVal.round()}mg';
    }

    // 5. Calculate dynamic protein quality score if applicable
    String proteinQuality = 'N/A';
    if (category == 'Food' || category == 'Supplement') {
      if (pVal > 0) {
        final double totalMacros = pVal + cVal + fVal;
        double ratio = totalMacros > 0 ? (pVal / totalMacros) : 0.0;
        int rating = (ratio * 100).round().clamp(10, 98);
        if (category == 'Supplement' && pVal > 20) {
          rating = rating.clamp(85, 98);
        }
        proteinQuality = '$rating/100 (Biological Quality Score)';
      } else {
        proteinQuality = '0/100 (No protein detected)';
      }
    }

    // 6. Clean ingredients list
    List<String> ingredients = rawIngredients
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty && e.toLowerCase() != 'null')
        .toList();
    if (ingredients.isEmpty) {
      ingredients = ['Ingredients not listed'];
    }

    // 7. OFFLINE DETERMINISTIC CALCULATIONS based on Hive's UserProfile
    int score = 100;
    final List<String> warnings = [];
    final String ingredientsText = ingredients.join(', ').toLowerCase();

    if (category == 'Food' || category == 'Supplement') {
      // Caloric Load warning relative to UserProfile calorie budget
      if (calVal > 0.25 * userCalorieGoal) {
        score -= 15;
        warnings.add("High Calorie: Single serving exceeds 25% of daily goal (${(0.25 * userCalorieGoal).round()} kcal)");
      }

      // Protein Profile checks mapping to UserProfile muscle gain target
      if (userGoal == 'gain' && pVal < 0.1 * userProteinGoal && calVal > 300) {
        score -= 10;
        warnings.add("Low Protein: Not optimal for Muscle Gain target (under ${(0.1 * userProteinGoal).round()}g/serving)");
      }

      // Weight Loss target adjustments mapping against fat limits
      if (userGoal == 'lose' && fVal > 15.0) {
        score -= 15;
        warnings.add("Weight Loss Warning: Fat is high for a lose target (>15g)");
      }

      // Strict, offline Sodium check (FDA low-sodium threshold is 140mg)
      if (sodVal > 400.0) {
        score -= 20;
        warnings.add("High Sodium: Elevated blood pressure risk (>400mg)");
      } else if (sodVal > 140.0) {
        score -= 10;
        warnings.add("Moderate Sodium: Caution advised (>140mg)");
      }

      // Age-Sensitive warning for high sodium in older users
      if (userAge > 50 && sodVal > 140.0) {
        score -= 10;
        warnings.add("Age-Sensitive Alert: High sodium is a cardiovascular risk at age $userAge");
      }

      // Macro-based carbohydrate spike warning
      if (cVal > 40.0) {
        score -= 15;
        warnings.add("High Carbohydrates: Glucose spike risk (>40g)");
      }

      // Ingredient Library scanning loop (Food Additives)
      ingredientLibrary.forEach((k, info) {
        if (info.category == 'food' && ingredientsText.contains(k)) {
          warnings.add("${k.toUpperCase()} [${info.type}]: ${info.effect} (Risk: ${info.risk})");
          score -= info.risk == 'CRITICAL' ? 30 : 15;
        }
      });
    } else {
      // Skincare Mode
      ingredientLibrary.forEach((k, info) {
        if (info.category == 'skin' && ingredientsText.contains(k)) {
          String risk = info.risk;
          String warn = info.effect;

          final bool isBadForAll = info.badFor.contains('All');
          final bool isBadForUser = info.badFor.any((type) => type.toLowerCase() == activeSkinType.toLowerCase());

          if (isBadForAll || isBadForUser) {
            risk = "CRITICAL";
            warn = "⚠️ BAD FOR ${activeSkinType.toUpperCase()} SKIN: ${info.effect}";
            score -= 30;
          } else {
            score -= 10;
          }
          warnings.add("${k.toUpperCase()} [${info.type}]: $warn (Risk: $risk)");
        }
      });
    }

    score = score.clamp(0, 100);

    // 8. Dynamic acne score calculations
    String acneScore = 'N/A';
    int comScore = 0;
    if (ingredientsText.contains('coconut oil') || ingredientsText.contains('isopropyl myristate')) {
      comScore = 5;
    } else if (ingredientsText.contains('palm oil') || ingredientsText.contains('mineral oil') || ingredientsText.contains('parafinum')) {
      comScore = 3;
    }
    
    if (category == 'Skincare') {
      acneScore = '$comScore/5 (${comScore >= 3 ? "Highly Comedogenic" : (comScore >= 1 ? "Moderate Caution" : "Completely Safe - Non-comedogenic")})';
    } else if (category == 'Food' || category == 'Supplement') {
      acneScore = '$comScore/5 (${comScore >= 3 ? "High Glycemic Trigger" : "Low Acne Risk"})';
    }

    if (rawAcneScore != null && rawAcneScore.isNotEmpty && rawAcneScore != 'N/A') {
      acneScore = rawAcneScore;
    }

    // 9. Deterministic Offline color rating and icon verdicts
    String rating = 'Moderate';
    Color ratingColor = AppTheme.accentOrange;
    IconData imageIcon = Icons.bolt_rounded;

    if (category == 'Skincare') {
      if (score > 80) {
        rating = 'Safe Match';
        ratingColor = AppTheme.accentEmerald;
        imageIcon = Icons.clean_hands_rounded;
      } else if (score > 50) {
        rating = 'Caution';
        ratingColor = AppTheme.accentOrange;
        imageIcon = Icons.warning_amber_rounded;
      } else {
        rating = 'Avoid';
        ratingColor = AppTheme.accentCoral;
        imageIcon = Icons.warning_amber_rounded;
      }
    } else {
      if (score > 75) {
        rating = 'Healthy';
        ratingColor = AppTheme.accentEmerald;
        imageIcon = category == 'Food' ? Icons.restaurant_menu_rounded : Icons.health_and_safety_rounded;
      } else if (score > 40) {
        rating = 'Processed';
        ratingColor = AppTheme.accentOrange;
        imageIcon = Icons.cookie_rounded;
      } else {
        rating = 'Ultra-Processed';
        ratingColor = AppTheme.accentCoral;
        imageIcon = Icons.warning_amber_rounded;
      }
    }

    return ScannedProduct(
      name: name,
      rating: rating,
      ratingColor: ratingColor,
      imageIcon: imageIcon,
      calories: calStr,
      macros: macrosStr,
      proteinQuality: proteinQuality,
      ingredients: ingredients,
      warnings: warnings.isEmpty ? rawWarnings : warnings,
      acneScore: acneScore,
      source: source,
      confidence: confidence,
      method: method,
      servingSize: serving,
      category: category,
      alternatives: alternatives ?? const [],
      retailLinks: retailLinks ?? const [],
    );
  }

  static double _parseGramValue(dynamic rawVal) {
    if (rawVal == null) return 0.0;
    final String clean = rawVal.toString().toLowerCase().replaceAll('g', '').replaceAll('mg', '').trim();
    if (clean == 'n/a' || clean.isEmpty) return 0.0;
    return double.tryParse(clean) ?? 0.0;
  }
}
