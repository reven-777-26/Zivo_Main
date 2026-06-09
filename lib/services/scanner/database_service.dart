import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../storage_service.dart';
import '../firebase_service.dart';
import 'nutrition_normalizer.dart';

class DatabaseService {
  /// Queries global registries sequentially: OpenFoodFacts -> OpenBeautyFacts -> USDA -> UPCItemDB
  /// Returns a ScannedProduct if found, or null if no registry has the barcode.
  static Future<ScannedProduct?> lookupBarcode({
    required String barcode,
    required String preferredCategory, // 'Food', 'Supplement', 'Skincare'
    required Function(String step) onProgress,
  }) async {
    // 0. Check Hive local cache first
    onProgress("Searching Hive local cache...");
    final cachedHive = StorageService.getCachedBarcode(barcode);
    if (cachedHive != null) {
      await Future.delayed(const Duration(milliseconds: 200));
      onProgress("Match found in Hive Cache!");
      await StorageService.addRecentScan(cachedHive);
      return ScannedProduct.fromJson(cachedHive);
    }

    // 0.5 Check Firebase cloud cache
    onProgress("Searching Firebase cloud cache...");
    final cachedCloud = await FirebaseService.getScanFromCloud(barcode, preferredCategory);
    if (cachedCloud != null) {
      onProgress("Match found in Firebase Cache!");
      await StorageService.saveCachedBarcode(barcode, cachedCloud);
      await StorageService.addRecentScan(cachedCloud);
      return ScannedProduct.fromJson(cachedCloud);
    }

    // 1. Check Local High-Fidelity Database First
    onProgress("Searching local high-fidelity database...");
    final localProduct = _lookupLocalDatabase(barcode, preferredCategory);
    if (localProduct != null) {
      await Future.delayed(const Duration(milliseconds: 350)); // Smooth UX transition
      onProgress("Match found in local database!");
      
      final category = localProduct.category;
      final alternatives = getAlternatives(localProduct.name, category);
      final retailLinks = generateRetailLinks(localProduct.name, category);

      final finalLocalProduct = ScannedProduct(
        name: localProduct.name,
        rating: localProduct.rating,
        ratingColor: localProduct.ratingColor,
        imageIcon: localProduct.imageIcon,
        calories: localProduct.calories,
        macros: localProduct.macros,
        proteinQuality: localProduct.proteinQuality,
        ingredients: localProduct.ingredients,
        warnings: localProduct.warnings,
        acneScore: localProduct.acneScore,
        source: localProduct.source,
        confidence: localProduct.confidence,
        method: localProduct.method,
        servingSize: localProduct.servingSize,
        category: category,
        alternatives: alternatives,
        retailLinks: retailLinks,
      );

      final productMap = finalLocalProduct.toJson();
      await StorageService.saveCachedBarcode(barcode, productMap);
      await FirebaseService.saveScanToCloud(barcode, preferredCategory, productMap);
      await StorageService.addRecentScan(productMap);

      return finalLocalProduct;
    }

    ScannedProduct? finalProduct;

    // 2. OpenFoodFacts
    onProgress("Querying OpenFoodFacts API...");
    try {
      final offProduct = await _queryOpenFoodFacts(barcode);
      if (offProduct != null) {
        onProgress("Match found in OpenFoodFacts Database!");
        finalProduct = offProduct;
      }
    } catch (e) {
      debugPrint("OpenFoodFacts lookup error: $e");
    }

    // 3. OpenBeautyFacts
    if (finalProduct == null) {
      onProgress("Querying OpenBeautyFacts (Skincare) API...");
      try {
        final obfProduct = await _queryOpenBeautyFacts(barcode);
        if (obfProduct != null) {
          onProgress("Match found in OpenBeautyFacts Database!");
          finalProduct = obfProduct;
        }
      } catch (e) {
        debugPrint("OpenBeautyFacts lookup error: $e");
      }
    }

    // 4. USDA FoodData Central
    if (finalProduct == null) {
      onProgress("Querying USDA FoodData Central...");
      try {
        final usdaProduct = await _queryUSDA(barcode, preferredCategory);
        if (usdaProduct != null) {
          onProgress("Match found in USDA FoodData Central!");
          finalProduct = usdaProduct;
        }
      } catch (e) {
        debugPrint("USDA lookup error: $e");
      }
    }

    // 5. UPCItemDB
    if (finalProduct == null) {
      onProgress("Querying UPCItemDB API...");
      try {
        final upcProduct = await _queryUPCItemDB(barcode, preferredCategory);
        if (upcProduct != null) {
          onProgress("Match found in UPCItemDB!");
          finalProduct = upcProduct;
        }
      } catch (e) {
        debugPrint("UPCItemDB lookup error: $e");
      }
    }

    if (finalProduct != null) {
      final category = finalProduct.category;
      final alternatives = getAlternatives(finalProduct.name, category);
      final retailLinks = generateRetailLinks(finalProduct.name, category);
      
      final productWithData = ScannedProduct(
        name: finalProduct.name,
        rating: finalProduct.rating,
        ratingColor: finalProduct.ratingColor,
        imageIcon: finalProduct.imageIcon,
        calories: finalProduct.calories,
        macros: finalProduct.macros,
        proteinQuality: finalProduct.proteinQuality,
        ingredients: finalProduct.ingredients,
        warnings: finalProduct.warnings,
        acneScore: finalProduct.acneScore,
        source: finalProduct.source,
        confidence: finalProduct.confidence,
        method: finalProduct.method,
        servingSize: finalProduct.servingSize,
        category: category,
        alternatives: alternatives,
        retailLinks: retailLinks,
      );

      final productMap = productWithData.toJson();
      await StorageService.saveCachedBarcode(barcode, productMap);
      await FirebaseService.saveScanToCloud(barcode, preferredCategory, productMap);
      await StorageService.addRecentScan(productMap);

      return productWithData;
    }

    onProgress("No registry match. Moving to next scanning stage...");
    return null;
  }

  /// Searches global registry (OpenFoodFacts or OpenBeautyFacts) using cgi/search.pl API.
  /// Returns a ScannedProduct if a match is found.
  static Future<ScannedProduct?> searchProduct({
    required String queryText,
    required String category, // 'Food', 'Supplement', 'Skincare'
    required Function(String step) onProgress,
  }) async {
    final cleanQuery = queryText.trim();
    if (cleanQuery.isEmpty) return null;

    // 0. Check Hive search cache first
    onProgress("Checking local search cache...");
    final cachedSearch = StorageService.getCachedProductSearch(cleanQuery);
    if (cachedSearch != null) {
      await Future.delayed(const Duration(milliseconds: 200));
      onProgress("Match found in local search cache!");
      await StorageService.addRecentScan(cachedSearch);
      return ScannedProduct.fromJson(cachedSearch);
    }

    // 1. Determine correct registry and endpoint
    final isBeauty = category == 'Skincare';
    final baseUrl = isBeauty ? 'https://world.openbeautyfacts.org' : 'https://world.openfoodfacts.org';
    final url = Uri.parse('$baseUrl/cgi/search.pl?action=process&search_terms=${Uri.encodeComponent(cleanQuery)}&json=1');

    onProgress("Searching registry via search API...");
    try {
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> products = data['products'] ?? [];
        if (products.isNotEmpty) {
          final p = products.first;
          final String name = p['product_name'] ?? '$cleanQuery (Registry Search)';
          
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

          final nut = p['nutriments'] ?? {};
          final double calories = (nut['energy-kcal_val'] ?? nut['energy-kcal'] ?? nut['energy_value'] ?? 0.0).toDouble();
          final double protein = (nut['proteins_val'] ?? nut['proteins'] ?? 0.0).toDouble();
          final double carbs = (nut['carbohydrates_val'] ?? nut['carbohydrates'] ?? 0.0).toDouble();
          final double fat = (nut['fat_val'] ?? nut['fat'] ?? 0.0).toDouble();
          final String servingSize = p['serving_size']?.toString() ?? '100g';

          final normalized = NutritionNormalizer.normalize(
            name: name,
            rawCalories: calories > 0 ? calories : null,
            rawProtein: protein,
            rawCarbs: carbs,
            rawFat: fat,
            rawIngredients: ingredients,
            rawWarnings: [],
            category: category == 'Skincare' ? 'Skincare' : 'Food',
            source: isBeauty ? 'OpenBeautyFacts Search' : 'OpenFoodFacts Search',
            confidence: 'HIGH',
            method: 'Structured Search Match',
            rawServingSize: servingSize,
          );

          // Attach alternatives & retail links
          final alternatives = getAlternatives(normalized.name, category);
          final retailLinks = generateRetailLinks(normalized.name, category);

          final finalProduct = ScannedProduct(
            name: normalized.name,
            rating: normalized.rating,
            ratingColor: normalized.ratingColor,
            imageIcon: normalized.imageIcon,
            calories: normalized.calories,
            macros: normalized.macros,
            proteinQuality: normalized.proteinQuality,
            ingredients: normalized.ingredients,
            warnings: normalized.warnings,
            acneScore: normalized.acneScore,
            source: normalized.source,
            confidence: normalized.confidence,
            method: normalized.method,
            servingSize: normalized.servingSize,
            category: category,
            alternatives: alternatives,
            retailLinks: retailLinks,
          );

          final productMap = finalProduct.toJson();
          // Save to search cache & scan history
          await StorageService.saveCachedProductSearch(cleanQuery, productMap);
          await StorageService.addRecentScan(productMap);

          return finalProduct;
        }
      }
    } catch (e) {
      debugPrint("Registry product search error: $e");
    }

    onProgress("No registry search match found.");
    return null;
  }

  static Future<ScannedProduct?> _queryOpenFoodFacts(String barcode) async {
    final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json');
    final response = await http.get(url).timeout(const Duration(seconds: 4));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 1 && data['product'] != null) {
        final p = data['product'];
        final String name = p['product_name'] ?? 'OFF Product ($barcode)';
        
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

        final nut = p['nutriments'] ?? {};
        final double calories = (nut['energy-kcal_val'] ?? nut['energy-kcal'] ?? nut['energy_value'] ?? 0.0).toDouble();
        final double protein = (nut['proteins_val'] ?? nut['proteins'] ?? 0.0).toDouble();
        final double carbs = (nut['carbohydrates_val'] ?? nut['carbohydrates'] ?? 0.0).toDouble();
        final double fat = (nut['fat_val'] ?? nut['fat'] ?? 0.0).toDouble();
        final String servingSize = p['serving_size']?.toString() ?? '100g';

        return NutritionNormalizer.normalize(
          name: name,
          rawCalories: calories > 0 ? calories : null,
          rawProtein: protein,
          rawCarbs: carbs,
          rawFat: fat,
          rawIngredients: ingredients,
          rawWarnings: [],
          category: 'Food',
          source: 'OpenFoodFacts Database',
          confidence: 'HIGH',
          method: 'Barcode Decoded',
          rawServingSize: servingSize,
        );
      }
    }
    return null;
  }

  static Future<ScannedProduct?> _queryOpenBeautyFacts(String barcode) async {
    final url = Uri.parse('https://world.openbeautyfacts.org/api/v0/product/$barcode.json');
    final response = await http.get(url).timeout(const Duration(seconds: 4));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 1 && data['product'] != null) {
        final p = data['product'];
        final String name = p['product_name'] ?? 'OBF Beauty Product ($barcode)';
        
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

        return NutritionNormalizer.normalize(
          name: name,
          rawCalories: null,
          rawProtein: null,
          rawCarbs: null,
          rawFat: null,
          rawIngredients: ingredients,
          rawWarnings: [],
          category: 'Skincare',
          source: 'OpenBeautyFacts Database',
          confidence: 'HIGH',
          method: 'Barcode Decoded',
          rawServingSize: '1 unit',
        );
      }
    }
    return null;
  }

  static Future<ScannedProduct?> _queryUSDA(String barcode, String preferredCategory) async {
    final url = Uri.parse('https://api.nal.usda.gov/fdc/v1/foods/search?query=$barcode&api_key=DEMO_KEY');
    final response = await http.get(url).timeout(const Duration(seconds: 4));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> foods = data['foods'] ?? [];
      if (foods.isNotEmpty) {
        final f = foods.first;
        final String name = f['description'] ?? 'USDA Product ($barcode)';
        
        final String rawIngredientsText = f['ingredients'] ?? '';
        final List<String> ingredients = rawIngredientsText.isNotEmpty 
            ? rawIngredientsText.split(',').map((e) => e.trim()).toList() 
            : [];

        double? calories;
        double? protein;
        double? carbs;
        double? fat;

        final List<dynamic> nutrients = f['foodNutrients'] ?? [];
        for (var n in nutrients) {
          final nameLower = (n['nutrientName'] ?? '').toString().toLowerCase();
          final val = (n['value'] ?? 0.0).toDouble();
          if (nameLower.contains('energy') || nameLower.contains('calorie')) {
            calories = val;
          } else if (nameLower.contains('protein')) {
            protein = val;
          } else if (nameLower.contains('carbohydrate')) {
            carbs = val;
          } else if (nameLower.contains('fat') && !nameLower.contains('saturated') && !nameLower.contains('fatty')) {
            fat = val;
          }
        }

        final String servingSize = f['servingSize'] != null 
            ? '${f['servingSize']} ${f['servingSizeUnit'] ?? 'g'}' 
            : '100g';

        return NutritionNormalizer.normalize(
          name: name,
          rawCalories: calories,
          rawProtein: protein,
          rawCarbs: carbs,
          rawFat: fat,
          rawIngredients: ingredients,
          rawWarnings: [],
          category: preferredCategory == 'Skincare' ? 'Food' : preferredCategory,
          source: 'USDA FoodData Central',
          confidence: 'HIGH',
          method: 'Barcode Decoded',
          rawServingSize: servingSize,
        );
      }
    }
    return null;
  }

  static Future<ScannedProduct?> _queryUPCItemDB(String barcode, String preferredCategory) async {
    final url = Uri.parse('https://api.upcitemdb.com/prod/trial/lookup?upc=$barcode');
    final response = await http.get(url).timeout(const Duration(seconds: 4));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List<dynamic> items = data['items'] ?? [];
      if (items.isNotEmpty) {
        final it = items.first;
        final String name = it['title'] ?? 'UPC Product ($barcode)';
        final String description = it['description'] ?? '';
        final String brand = it['brand'] ?? '';
        final String category = it['category'] ?? preferredCategory;
        
        // Parse ingredients from description using broad regex triggers
        List<String> ingredients = [];
        final RegExp ingRegex = RegExp(r'(?:ingredients|contains):\s*([^.]+)', caseSensitive: false);
        final match = ingRegex.firstMatch(description);
        if (match != null) {
          ingredients = match.group(1)!.split(',').map((e) => e.trim()).toList();
        } else {
          ingredients = [brand.isNotEmpty ? 'Brand: $brand' : 'Product Registry Entry'];
        }

        String matchedCategory = preferredCategory;
        if (category.toLowerCase().contains('beauty') || category.toLowerCase().contains('skin') || category.toLowerCase().contains('cosmetic')) {
          matchedCategory = 'Skincare';
        } else if (category.toLowerCase().contains('supplement') || category.toLowerCase().contains('vitamin')) {
          matchedCategory = 'Supplement';
        } else if (category.toLowerCase().contains('food') || category.toLowerCase().contains('beverage') || category.toLowerCase().contains('grocery')) {
          matchedCategory = 'Food';
        }

        return NutritionNormalizer.normalize(
          name: name,
          rawCalories: null,
          rawProtein: null,
          rawCarbs: null,
          rawFat: null,
          rawIngredients: ingredients,
          rawWarnings: [],
          category: matchedCategory,
          source: 'UPCItemDB Registry',
          confidence: 'HIGH',
          method: 'Barcode Decoded',
          rawServingSize: '1 unit',
        );
      }
    }
    return null;
  }

  static List<Map<String, String>> generateRetailLinks(String productName, String category) {
    final encodedName = Uri.encodeComponent(productName);
    final List<Map<String, String>> links = [];

    if (category == 'Skincare') {
      links.add({'name': 'Myntra', 'url': 'https://www.myntra.com/$encodedName'});
      links.add({'name': 'Nykaa', 'url': 'https://www.nykaa.com/search/result/?q=$encodedName'});
    }

    links.add({'name': 'Amazon', 'url': 'https://www.amazon.in/s?k=$encodedName'});
    links.add({'name': 'Flipkart', 'url': 'https://www.flipkart.com/search?q=$encodedName'});
    links.add({'name': 'Blinkit', 'url': 'https://blinkit.com/s/?q=$encodedName'});
    links.add({'name': 'Zepto', 'url': 'https://www.zeptonow.com/search?query=$encodedName'});
    links.add({'name': 'Swiggy Instamart', 'url': 'https://www.swiggy.com/instamart/search?custom_back=true&query=$encodedName'});
    links.add({'name': 'JioMart', 'url': 'https://www.jiomart.com/search/$encodedName'});

    return links;
  }

  static List<Map<String, dynamic>> getAlternatives(String productName, String category) {
    final lower = productName.toLowerCase();
    if (category == 'Food') {
      if (lower.contains('nutella') || lower.contains('chocolate spread') || lower.contains('hazelnut')) {
        return [
          {
            'name': 'Organic Crunchy Peanut Butter',
            'rating': 'Healthy',
            'ratingColorValue': 0xFF00C853,
            'calories': '190 kcal',
            'macros': 'P: 8g  C: 6g  F: 16g',
            'ingredients': ['Organic Roasted Peanuts', 'Sea Salt'],
            'acneScore': '0/5 (Low Glycemic Index)'
          },
          {
            'name': 'Raw Stoneground Almond Butter',
            'rating': 'Healthy',
            'ratingColorValue': 0xFF00C853,
            'calories': '180 kcal',
            'macros': 'P: 7g  C: 5g  F: 15g',
            'ingredients': ['Raw Almonds'],
            'acneScore': '0/5 (Low Glycemic Index)'
          }
        ];
      }
      if (lower.contains('chip') || lower.contains('nacho') || lower.contains('crisp') || lower.contains('biscuit') || lower.contains('parle')) {
        return [
          {
            'name': 'Organic Roasted Chickpeas',
            'rating': 'Healthy',
            'ratingColorValue': 0xFF00C853,
            'calories': '120 kcal',
            'macros': 'P: 6g  C: 18g  F: 2g',
            'ingredients': ['Organic Chickpeas', 'Olive Oil', 'Sea Salt'],
            'acneScore': '0/5 (Anti-inflammatory)'
          },
          {
            'name': 'Dehydrated Organic Kale Chips',
            'rating': 'Healthy',
            'ratingColorValue': 0xFF00C853,
            'calories': '80 kcal',
            'macros': 'P: 4g  C: 8g  F: 3g',
            'ingredients': ['Organic Curly Kale', 'Nutritional Yeast', 'Olive Oil'],
            'acneScore': '0/5 (Rich in Zinc and Vitamin A)'
          }
        ];
      }
      if (lower.contains('cola') || lower.contains('coke') || lower.contains('soda') || lower.contains('pepsi') || lower.contains('fanta') || lower.contains('sprite')) {
        return [
          {
            'name': 'Organic Lemon Kombucha',
            'rating': 'Healthy',
            'ratingColorValue': 0xFF00C853,
            'calories': '30 kcal',
            'macros': 'P: 0g  C: 7g  F: 0g',
            'ingredients': ['Filtered Water', 'Organic Black Tea', 'Kombucha Culture', 'Organic Lemon'],
            'acneScore': '0/5 (Gut-friendly probiotics)'
          },
          {
            'name': 'Sparkling Mineral Water',
            'rating': 'Healthy',
            'ratingColorValue': 0xFF00C853,
            'calories': '0 kcal',
            'macros': 'P: 0g  C: 0g  F: 0g',
            'ingredients': ['Natural Carbonated Water'],
            'acneScore': '0/5 (No sugar or sweeteners)'
          }
        ];
      }
      return [
        {
          'name': 'Organic Rolled Oats & Berries',
          'rating': 'Healthy',
          'ratingColorValue': 0xFF00C853,
          'calories': '150 kcal',
          'macros': 'P: 6g  C: 27g  F: 2.5g',
          'ingredients': ['Whole Rolled Oats', 'Freeze-dried Raspberries'],
          'acneScore': '0/5'
        }
      ];
    } else if (category == 'Supplement') {
      if (lower.contains('pre-workout') || lower.contains('preworkout') || lower.contains('nitro') || lower.contains('caffeine')) {
        return [
          {
            'name': 'Organic Ceremonial Matcha Green Tea',
            'rating': 'Healthy',
            'ratingColorValue': 0xFF00C853,
            'calories': '5 kcal',
            'macros': 'P: 0.5g  C: 1g  F: 0g',
            'ingredients': ['Pure Stoneground Matcha Leaf'],
            'acneScore': '0/5 (Rich in EGCG Antioxidants)'
          },
          {
            'name': '100% Pure Creatine Monohydrate',
            'rating': 'Healthy',
            'ratingColorValue': 0xFF00C853,
            'calories': '0 kcal',
            'macros': 'P: 0g  C: 0g  F: 0g',
            'ingredients': ['Creatine Monohydrate (Creapure)'],
            'acneScore': '0/5 (Unflavored, clean)'
          }
        ];
      }
      return [
        {
          'name': 'Hydrolyzed Grass-Fed Whey Isolate',
          'rating': 'Healthy',
          'ratingColorValue': 0xFF00C853,
          'calories': '110 kcal',
          'macros': 'P: 25g  C: 0g  F: 0g',
          'ingredients': ['Grass-Fed Whey Protein Isolate', 'Sunflower Lecithin'],
          'acneScore': '1/5'
        }
      ];
    } else {
      if (lower.contains('cream') || lower.contains('comedo') || lower.contains('fragrant') || lower.contains('paraben') || lower.contains('isopropyl')) {
        return [
          {
            'name': 'Niacinamide 10% + Zinc 1% Serum',
            'rating': 'Safe Match',
            'ratingColorValue': 0xFF00C853,
            'ingredients': ['Aqua', 'Niacinamide', 'Zinc PCA', 'Phenoxyethanol'],
            'acneScore': '0/5 (Regulates sebum and reduces acne)'
          },
          {
            'name': 'Cerave Hydrating Facial Cleanser',
            'rating': 'Safe Match',
            'ratingColorValue': 0xFF00C853,
            'ingredients': ['Aqua', 'Glycerin', 'Ceramide NP', 'Ceramide AP', 'Hyaluronic Acid'],
            'acneScore': '0/5 (Restores skin lipid barrier)'
          }
        ];
      }
      return [
        {
          'name': 'Pure Centella Asiatica Calming Gel',
          'rating': 'Safe Match',
          'ratingColorValue': 0xFF00C853,
          'ingredients': ['Centella Asiatica Extract', 'Glycerin', 'Allantoin'],
          'acneScore': '0/5 (Deeply soothing and non-comedogenic)'
        }
      ];
    }
  }

  /// Looks up product details in a local high-fidelity database for test barcodes
  static ScannedProduct? _lookupLocalDatabase(String barcode, String category) {
    final cleanBarcode = barcode.trim();
    
    // Nittoh Royal Milk Tea (EAN-13: 4901058851335, cropped: 901058851335)
    if (cleanBarcode == '4901058851335' || cleanBarcode == '901058851335') {
      return NutritionNormalizer.normalize(
        name: 'Nittoh Royal Milk Tea (Japanese Blend)',
        rawCalories: 59,
        rawProtein: 0.9,
        rawCarbs: 11.6,
        rawFat: 1.8,
        rawIngredients: [
          'Sugar',
          'Lactose',
          'Skimmed Milk Powder',
          'Dextrin',
          'Vegetable Oil',
          'Black Tea Extract',
          'Whole Milk Powder',
          'Butter Oil',
          'Milk Protein',
          'Sweetened Condensed Milk',
          'Salt',
          'Emulsifier',
          'Flavor'
        ],
        rawWarnings: [
          'Contains dairy and lactose allergens.',
          'Contains refined sugar (glycemic acne trigger).'
        ],
        category: 'Food',
        source: 'Aura Smart Lens Database',
        confidence: 'HIGH',
        method: 'Barcode Decoded',
        rawServingSize: '1 sachet (14g)',
        rawAcneScore: '3/5 (Refined sugars and dairy can cause insulin spikes)',
      );
    }
    
    // Nutella Hazelnut Spread (EAN-13: 3017620422003 or 3017622042203)
    if (cleanBarcode == '3017620422003' || cleanBarcode == '3017622042203') {
      return NutritionNormalizer.normalize(
        name: 'Nutella Hazelnut Spread',
        rawCalories: 80,
        rawProtein: 1.0,
        rawCarbs: 8.6,
        rawFat: 4.6,
        rawIngredients: [
          'Sugar',
          'Palm Oil',
          'Hazelnuts (13%)',
          'Skimmed Milk Powder (8.7%)',
          'Fat-Reduced Cocoa (7.4%)',
          'Lecithins (Soya)',
          'Vanillin'
        ],
        rawWarnings: [
          'High refined sugar content.',
          'Contains palm oil (environment & skin trigger).',
          'Allergen Info: Contains hazelnuts, milk, and soy.'
        ],
        category: 'Food',
        source: 'Aura Smart Lens Database',
        confidence: 'HIGH',
        method: 'Barcode Decoded',
        rawServingSize: '1 tbsp (15g)',
        rawAcneScore: '4/5 (High glycemic index + dairy + palm oil acne trigger)',
      );
    }

    // Parle-G Biscuits (EAN-13: 202203170454 or 2022031704540)
    if (cleanBarcode == '202203170454' || cleanBarcode == '2022031704540') {
      return NutritionNormalizer.normalize(
        name: 'Parle-G Original Glucose Biscuits',
        rawCalories: 450,
        rawProtein: 6.5,
        rawCarbs: 78.0,
        rawFat: 12.5,
        rawIngredients: [
          'Wheat Flour (Refined)',
          'Sugar',
          'Invert Sugar Syrup',
          'Refined Palm Oil',
          'Glucose Powder',
          'Milk Solids',
          'Raising Agents'
        ],
        rawWarnings: [
          'Contains refined palm oil and high sugar levels.',
          'Allergen Info: Contains gluten and wheat.'
        ],
        category: 'Food',
        source: 'Aura Smart Lens Database',
        confidence: 'HIGH',
        method: 'Barcode Decoded',
        rawServingSize: '1 pack (100g)',
        rawAcneScore: '3/5 (High Glycemic Index - Sugary Carb Trigger)',
      );
    }

    return null;
  }
}
