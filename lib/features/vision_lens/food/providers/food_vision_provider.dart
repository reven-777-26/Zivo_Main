import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/state_providers.dart';
import '../models/food_product.dart';
import '../services/food_api_service.dart';
import '../../shared/services/vision_storage_service.dart';

class FoodVisionState {
  final AsyncValue<FoodProduct?> currentProduct;
  final List<FoodProduct> history;
  final bool isScanning;

  FoodVisionState({
    required this.currentProduct,
    required this.history,
    this.isScanning = false,
  });

  FoodVisionState copyWith({
    AsyncValue<FoodProduct?>? currentProduct,
    List<FoodProduct>? history,
    bool? isScanning,
  }) {
    return FoodVisionState(
      currentProduct: currentProduct ?? this.currentProduct,
      history: history ?? this.history,
      isScanning: isScanning ?? this.isScanning,
    );
  }
}

class FoodVisionNotifier extends StateNotifier<FoodVisionState> {
  final Ref _ref;

  FoodVisionNotifier(this._ref)
      : super(FoodVisionState(
          currentProduct: const AsyncValue.data(null),
          history: [],
        )) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    try {
      final cachedList = await VisionStorageService.getHistory(FoodApiService.categoryKey);
      final products = cachedList.map((e) => FoodProduct.fromJson(e)).toList();
      state = state.copyWith(history: products);
    } catch (_) {}
  }

  Future<void> scanAndAnalyze({
    String? barcode,
    String? searchName,
    Map<String, dynamic>? rawDetails,
    String? imageBase64,
  }) async {
    state = state.copyWith(
      isScanning: true,
      currentProduct: const AsyncValue.loading(),
    );

    // Personalization: Read goal targets
    final profile = _ref.read(profileProvider);
    final fitnessGoal = profile?.goal.toLowerCase() ?? 'maintain';

    try {
      final product = await FoodApiService.analyzeProduct(
        barcode: barcode,
        searchName: searchName,
        rawDetails: rawDetails,
        imageBase64: imageBase64,
        fitnessGoal: fitnessGoal,
      );

      final historyList = await VisionStorageService.getHistory(FoodApiService.categoryKey);
      final updatedHistory = historyList.map((e) => FoodProduct.fromJson(e)).toList();

      state = state.copyWith(
        isScanning: false,
        currentProduct: AsyncValue.data(product),
        history: updatedHistory,
      );
    } catch (e, stack) {
      state = state.copyWith(
        isScanning: false,
        currentProduct: AsyncValue.error(e, stack),
      );
    }
  }

  Future<void> clearHistory() async {
    await VisionStorageService.clearHistory(FoodApiService.categoryKey);
    state = state.copyWith(history: []);
  }

  void resetCurrentProduct() {
    state = state.copyWith(currentProduct: const AsyncValue.data(null));
  }
}

final foodVisionProvider = StateNotifierProvider<FoodVisionNotifier, FoodVisionState>((ref) {
  return FoodVisionNotifier(ref);
});
