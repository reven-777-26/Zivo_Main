import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../utils/image_picker_helper.dart';
import '../services/vision_storage_service.dart';
import '../services/unified_vision_service.dart';
import '../../../../services/firebase_service.dart';
import '../../../../services/premium_service.dart';

class UnifiedVisionState {
  final AsyncValue<UnifiedProductReport?> currentReport;
  final List<UnifiedProductReport> history;
  final bool isScanning;
  final String progressMessage;

  UnifiedVisionState({
    required this.currentReport,
    required this.history,
    this.isScanning = false,
    this.progressMessage = '',
  });

  UnifiedVisionState copyWith({
    AsyncValue<UnifiedProductReport?>? currentReport,
    List<UnifiedProductReport>? history,
    bool? isScanning,
    String? progressMessage,
  }) {
    return UnifiedVisionState(
      currentReport: currentReport ?? this.currentReport,
      history: history ?? this.history,
      isScanning: isScanning ?? this.isScanning,
      progressMessage: progressMessage ?? this.progressMessage,
    );
  }
}

class UnifiedVisionNotifier extends StateNotifier<UnifiedVisionState> {
  UnifiedVisionNotifier()
      : super(UnifiedVisionState(
          currentReport: const AsyncValue.data(null),
          history: [],
        )) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    try {
      final List<Map<String, dynamic>> combinedRaw = [];

      try {
        final foodRaw = await VisionStorageService.getHistory('food');
        combinedRaw.addAll(foodRaw);
      } catch (_) {}

      try {
        final suppRaw = await VisionStorageService.getHistory('supplement');
        combinedRaw.addAll(suppRaw);
      } catch (_) {}

      try {
        final skinRaw = await VisionStorageService.getHistory('skincare');
        combinedRaw.addAll(skinRaw);
      } catch (_) {}

      combinedRaw.sort((a, b) {
        final aDateStr = a['scanDate'] ?? '';
        final bDateStr = b['scanDate'] ?? '';
        return bDateStr.compareTo(aDateStr);
      });

      final List<UnifiedProductReport> reports = [];
      for (var raw in combinedRaw) {
        try {
          if (raw.containsKey('decodedIngredients') || raw.containsKey('zivoScore')) {
            reports.add(UnifiedProductReport.fromJson(raw));
          }
        } catch (_) {}
      }

      state = state.copyWith(history: reports);
    } catch (_) {}
  }

  String _generateImageHash(String base64Content) {
    int hash = 0;
    for (int i = 0; i < base64Content.length; i++) {
      hash = (31 * hash + base64Content.codeUnitAt(i)) & 0xFFFFFFFF;
    }
    return 'img_hash_${base64Content.length}_$hash';
  }

  /// BARCODE FLOW:
  /// 1. Check local cache
  /// 2. Lookup OpenFoodFacts/OpenBeautyFacts by barcode
  /// 3. Auto-detect category from registry data
  /// 4. Send registry data to Gemini AI for analysis
  /// 5. Display AI-analyzed report
  Future<void> scanBarcodeAndAnalyze({
    required String barcode,
    String? preferredCategory,
  }) async {
    state = state.copyWith(
      isScanning: true,
      progressMessage: 'Checking local cache...',
      currentReport: const AsyncValue.loading(),
    );

    final cleanBarcode = barcode.trim();

    // 1. Check local Hive caches across categories
    for (var cat in ['food', 'supplement', 'skincare']) {
      try {
        final cached = await VisionStorageService.getCachedProduct(cat, cleanBarcode);
        if (cached != null) {
          final report = UnifiedProductReport.fromJson(cached);
          state = state.copyWith(
            isScanning: false,
            currentReport: AsyncValue.data(report),
          );
          _addToLocalHistoryList(report);
          return;
        }
      } catch (_) {}
    }

    // 2. Query open database registries sequentially (OpenFoodFacts, then OpenBeautyFacts)
    state = state.copyWith(progressMessage: 'Searching product databases...');
    
    // Check daily scan limits before calling network APIs
    if (!PremiumService.canPerformAiScan()) {
      state = state.copyWith(
        isScanning: false,
        currentReport: AsyncValue.error(
          PremiumService.isPremiumNotifier.value
              ? 'Daily limit of 50 AI scans reached to prevent abuse. Try again tomorrow!'
              : 'Trial daily limit of 20 AI scans reached. Upgrade to Zivofit Premium for more!',
          StackTrace.current,
        ),
      );
      return;
    }

    final registryData = await UnifiedVisionService.lookupProductApis(cleanBarcode);

    if (registryData == null) {
      // Barcode not found in any database — fallback to asking Gemini to identify/estimate it
      state = state.copyWith(progressMessage: 'Product not in database. Asking AI to identify...');
      try {
        final report = await UnifiedVisionService.analyzeWithGemini(
          barcode: cleanBarcode,
          productName: 'Product (Barcode: $cleanBarcode)',
          brand: 'Unknown',
          ingredients: [],
          category: preferredCategory?.toLowerCase() ?? 'food',
        );

        await VisionStorageService.cacheProduct(report.category, cleanBarcode, report.toJson());
        FirebaseService.saveVisionHistoryCloud(report.category, cleanBarcode, report.toJson());
        await PremiumService.trackAiScanConsumed();
        state = state.copyWith(
          isScanning: false,
          currentReport: AsyncValue.data(report),
        );
        _addToLocalHistoryList(report);
      } catch (e, stack) {
        state = state.copyWith(
          isScanning: false,
          currentReport: AsyncValue.error('Product not found in any database. Try uploading a product photo instead.', stack),
        );
      }
      return;
    }

    // 3. Registry data found — extract fields
    final String name = registryData['product_name'] ?? 'Product';
    final String brand = registryData['brand'] ?? 'Generic';
    final List<String> ingredients = List<String>.from(registryData['ingredients'] ?? []);
    final String category = registryData['category'] ?? 'food'; // Auto-detected!
    final String? imgUrl = registryData['image_url'];

    // 4. Always send to Gemini AI for deep analysis
    state = state.copyWith(progressMessage: 'AI is analyzing $name...');
    
    try {
      final report = await UnifiedVisionService.analyzeWithGemini(
        barcode: cleanBarcode,
        productName: name,
        brand: brand,
        ingredients: ingredients,
        category: category,
        imageUrl: imgUrl,
      );

      await VisionStorageService.cacheProduct(category, cleanBarcode, report.toJson());
      FirebaseService.saveVisionHistoryCloud(category, cleanBarcode, report.toJson());
      await PremiumService.trackAiScanConsumed();
      state = state.copyWith(
        isScanning: false,
        currentReport: AsyncValue.data(report),
      );
      _addToLocalHistoryList(report);
    } catch (e, stack) {
      // Fallback: If Gemini API fails, run Local Rule Engine
      debugPrint("Gemini Analysis failed, running local rule engine fallback: $e");
      try {
        final report = UnifiedVisionService.runLocalRuleEngine(
          barcode: cleanBarcode,
          productName: name,
          brand: brand,
          ingredients: ingredients,
          category: category,
          imageUrl: imgUrl,
          rawProduct: registryData['raw_product'],
        );

        await VisionStorageService.cacheProduct(category, cleanBarcode, report.toJson());
        FirebaseService.saveVisionHistoryCloud(category, cleanBarcode, report.toJson());
        await PremiumService.trackAiScanConsumed();
        state = state.copyWith(
          isScanning: false,
          currentReport: AsyncValue.data(report),
        );
        _addToLocalHistoryList(report);
      } catch (err) {
        state = state.copyWith(
          isScanning: false,
          currentReport: AsyncValue.error(e, stack),
        );
      }
    }
  }

  /// IMAGE UPLOAD FLOW (the critical one that was broken):
  /// 1. Try to extract barcode from image locally
  /// 2. If barcode found → run barcode flow
  /// 3. If no barcode → Send image to AI to IDENTIFY the product
  /// 4. Use identified name → search databases for real data
  /// 5. Send real data + image → AI for deep analysis
  /// 6. Display AI-analyzed report
  Future<void> analyzeFromImage({
    required String base64Content,
    required String fileName,
    bool isIngredientLabel = false,
  }) async {
    state = state.copyWith(
      isScanning: true,
      progressMessage: 'Compressing image...',
      currentReport: const AsyncValue.loading(),
    );

    // Yield control to let the UI update and render the 'Compressing image...' state
    await Future.delayed(const Duration(milliseconds: 100));

    // Optimize visual image size immediately in a background isolate to keep UI completely smooth
    final String optimizedBase64 = await compute(AiAnalysisService.optimizeImage, base64Content);

    state = state.copyWith(
      progressMessage: isIngredientLabel
          ? 'Analyzing ingredients label...'
          : 'Scanning image for barcode...',
    );

    // Yield control briefly to let the UI show the new progress message
    await Future.delayed(const Duration(milliseconds: 50));

    // 1. Try to extract EAN barcode from image locally (only if not scanning ingredient label directly)
    if (!isIngredientLabel) {
      final barcode = await ImagePickerHelper.scanBarcode(base64Content, filePath: null);
      if (barcode.isNotEmpty && !barcode.startsWith('ERROR')) {
        // Found a barcode in the image — use the barcode flow
        await scanBarcodeAndAnalyze(barcode: barcode);
        return;
      }
    }

    // Generate deterministic hash key for image caching
    final imgHashKey = _generateImageHash(optimizedBase64);

    // 2. Check local image hash cache to avoid redundant vision calls
    for (var cat in ['food', 'supplement', 'skincare']) {
      try {
        final cached = await VisionStorageService.getCachedProduct(cat, imgHashKey);
        if (cached != null) {
          debugPrint("Local Image Cache Hit for $imgHashKey!");
          final report = UnifiedProductReport.fromJson(cached);
          state = state.copyWith(
            isScanning: false,
            currentReport: AsyncValue.data(report),
          );
          _addToLocalHistoryList(report);
          return;
        }
      } catch (_) {}
    }

    // Check daily scan limits before calling network APIs
    if (!PremiumService.canPerformAiScan()) {
      state = state.copyWith(
        isScanning: false,
        currentReport: AsyncValue.error(
          PremiumService.isPremiumNotifier.value
              ? 'Daily limit of 50 AI scans reached to prevent abuse. Try again tomorrow!'
              : 'Trial daily limit of 20 AI scans reached. Upgrade to Zivofit Premium for more!',
          StackTrace.current,
        ),
      );
      return;
    }

    // 3. Use AI to identify the product from the image
    state = state.copyWith(
      progressMessage: isIngredientLabel
          ? 'AI is extracting ingredients...'
          : 'AI is identifying the product...',
    );

    try {
      // Step A: Call identifyProduct cloud function to get product name, brand, category
      final identifiedProduct = await UnifiedVisionService.identifyProductFromImage(optimizedBase64);
      
      String productName = identifiedProduct?['productName'] ?? identifiedProduct?['name'] ?? fileName.split('.').first;
      String brand = identifiedProduct?['brand'] ?? 'Unknown';
      String category = identifiedProduct?['category'] ?? 'food';
      List<String> imageIngredients = [];
      
      // If AI found ingredients in the image, use them
      if (identifiedProduct?['ingredients'] != null && identifiedProduct!['ingredients'] is List) {
        imageIngredients = List<String>.from(identifiedProduct['ingredients']);
      }

      debugPrint("AI identified: $productName by $brand (category: $category)");

      // Check cache by slug key before running Call #2
      final String initialSlug = '${productName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${brand.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
      final String initialSlugKey = 'slug_$initialSlug';

      Map<String, dynamic>? cachedData;
      try {
        cachedData = await VisionStorageService.getCachedProduct(category, initialSlugKey);
      } catch (_) {}

      if (cachedData != null) {
        debugPrint("Local Slug Cache Hit for $initialSlugKey!");
        final report = UnifiedProductReport.fromJson(cachedData);
        // Link this image hash to the cached report as well
        await VisionStorageService.cacheProduct(category, imgHashKey, report.toJson());
        
        state = state.copyWith(
          isScanning: false,
          currentReport: AsyncValue.data(report),
        );
        _addToLocalHistoryList(report);
        return;
      }

      List<String> ingredients = imageIngredients;
      String? imageUrl;
      
      // Step B: Search databases for this product to get real ingredient data (skip if scanning ingredients label directly)
      if (!isIngredientLabel) {
        state = state.copyWith(progressMessage: 'Searching databases for $productName...');
        final registryData = await UnifiedVisionService.lookupProductByName(productName, category);
        
        if (registryData != null) {
          // Found in database — use real data
          debugPrint("Found $productName in database!");
          productName = registryData['product_name'] ?? productName;
          brand = registryData['brand'] ?? brand;
          ingredients = List<String>.from(registryData['ingredients'] ?? imageIngredients);
          imageUrl = registryData['image_url'];
          category = registryData['category'] ?? category;

          // Check cache again with the refined slug key from the database match
          final String refinedSlug = '${productName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${brand.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
          final String refinedSlugKey = 'slug_$refinedSlug';

          Map<String, dynamic>? refinedCachedData;
          try {
            refinedCachedData = await VisionStorageService.getCachedProduct(category, refinedSlugKey);
          } catch (_) {}

          if (refinedCachedData != null) {
            debugPrint("Local Refined Slug Cache Hit for $refinedSlugKey!");
            final report = UnifiedProductReport.fromJson(refinedCachedData);
            await VisionStorageService.cacheProduct(category, imgHashKey, report.toJson());
            
            state = state.copyWith(
              isScanning: false,
              currentReport: AsyncValue.data(report),
            );
            _addToLocalHistoryList(report);
            return;
          }
        }
      }

      final String finalSlug = '${productName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${brand.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
      final String finalSlugKey = 'slug_$finalSlug';

      // Step C: Send everything to Gemini AI for deep health analysis
      state = state.copyWith(
        progressMessage: isIngredientLabel
            ? 'AI is analyzing ingredients...'
            : 'AI is analyzing $productName...',
      );
      
      final report = await UnifiedVisionService.analyzeWithGemini(
        barcode: imgHashKey,
        productName: productName,
        brand: brand,
        ingredients: ingredients,
        category: category,
        imageUrl: imageUrl,
        imageBase64: optimizedBase64,
      );

      // Cache the result under the image hash AND the slug key
      await VisionStorageService.cacheProduct(report.category, imgHashKey, report.toJson());
      await VisionStorageService.cacheProduct(report.category, finalSlugKey, report.toJson());
      FirebaseService.saveVisionHistoryCloud(report.category, imgHashKey, report.toJson());
      await PremiumService.trackAiScanConsumed();

      state = state.copyWith(
        isScanning: false,
        currentReport: AsyncValue.data(report),
      );
      _addToLocalHistoryList(report);
    } catch (e, stack) {
      debugPrint("Image analysis pipeline failed: $e");
      state = state.copyWith(
        isScanning: false,
        currentReport: AsyncValue.error('Failed to analyze product image. Please try again.', stack),
      );
    }
  }

  /// Triggers detailed Gemini health analysis/interpretation on demand
  Future<void> forceAiAnalysisForCurrent() async {
    final currentVal = state.currentReport.value;
    if (currentVal == null) return;

    state = state.copyWith(
      isScanning: true,
      progressMessage: 'Re-analyzing with Gemini AI...',
      currentReport: const AsyncValue.loading(),
    );

    try {
      final report = await UnifiedVisionService.analyzeWithGemini(
        barcode: currentVal.barcode,
        productName: currentVal.productName,
        brand: currentVal.brand,
        ingredients: currentVal.decodedIngredients.map((e) => e.name).toList(),
        category: currentVal.category,
        imageUrl: currentVal.imageUrl,
      );

      await VisionStorageService.cacheProduct(report.category, currentVal.barcode, report.toJson());
      FirebaseService.saveVisionHistoryCloud(report.category, currentVal.barcode, report.toJson());

      state = state.copyWith(
        isScanning: false,
        currentReport: AsyncValue.data(report),
      );

      _addToLocalHistoryList(report);
    } catch (e, stack) {
      state = state.copyWith(
        isScanning: false,
        currentReport: AsyncValue.data(currentVal),
      );
      debugPrint("Force AI interpretation failed: $e\n$stack");
    }
  }

  void _addToLocalHistoryList(UnifiedProductReport report) {
    final updatedHistory = List<UnifiedProductReport>.from(state.history);
    updatedHistory.removeWhere((item) => item.barcode == report.barcode);
    updatedHistory.insert(0, report);
    state = state.copyWith(history: updatedHistory);
  }

  Future<void> clearHistory() async {
    await VisionStorageService.clearHistory('food');
    await VisionStorageService.clearHistory('supplement');
    await VisionStorageService.clearHistory('skincare');
    state = state.copyWith(history: []);
  }

  void resetCurrentReport() {
    state = state.copyWith(currentReport: const AsyncValue.data(null));
  }
}

final unifiedVisionProvider = StateNotifierProvider<UnifiedVisionNotifier, UnifiedVisionState>((ref) {
  return UnifiedVisionNotifier();
});
