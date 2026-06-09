import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/state_providers.dart';
import '../models/skincare_product.dart';
import '../services/skincare_api_service.dart';
import '../../shared/services/vision_storage_service.dart';

class SkincareVisionState {
  final AsyncValue<SkincareProduct?> currentProduct;
  final List<SkincareProduct> history;
  final bool isScanning;

  SkincareVisionState({
    required this.currentProduct,
    required this.history,
    this.isScanning = false,
  });

  SkincareVisionState copyWith({
    AsyncValue<SkincareProduct?>? currentProduct,
    List<SkincareProduct>? history,
    bool? isScanning,
  }) {
    return SkincareVisionState(
      currentProduct: currentProduct ?? this.currentProduct,
      history: history ?? this.history,
      isScanning: isScanning ?? this.isScanning,
    );
  }
}

class SkincareVisionNotifier extends StateNotifier<SkincareVisionState> {
  final Ref _ref;

  SkincareVisionNotifier(this._ref)
      : super(SkincareVisionState(
          currentProduct: const AsyncValue.data(null),
          history: [],
        )) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    try {
      final cachedList = await VisionStorageService.getHistory(SkincareApiService.categoryKey);
      final products = cachedList.map((e) => SkincareProduct.fromJson(e)).toList();
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

    final profile = _ref.read(profileProvider);
    final userSkinType = profile?.skinType ?? 'Normal';

    try {
      final product = await SkincareApiService.analyzeSkincare(
        barcode: barcode,
        searchName: searchName,
        rawDetails: rawDetails,
        imageBase64: imageBase64,
        userSkinType: userSkinType,
      );

      final historyList = await VisionStorageService.getHistory(SkincareApiService.categoryKey);
      final updatedHistory = historyList.map((e) => SkincareProduct.fromJson(e)).toList();

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
    await VisionStorageService.clearHistory(SkincareApiService.categoryKey);
    state = state.copyWith(history: []);
  }

  void resetCurrentProduct() {
    state = state.copyWith(currentProduct: const AsyncValue.data(null));
  }
}

final skincareVisionProvider = StateNotifierProvider<SkincareVisionNotifier, SkincareVisionState>((ref) {
  return SkincareVisionNotifier(ref);
});
