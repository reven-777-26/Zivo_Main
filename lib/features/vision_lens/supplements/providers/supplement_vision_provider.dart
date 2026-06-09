import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/supplement_product.dart';
import '../services/supplement_service.dart';
import '../../shared/services/vision_storage_service.dart';

class SupplementVisionState {
  final AsyncValue<SupplementProduct?> currentProduct;
  final List<SupplementProduct> history;
  final bool isScanning;

  SupplementVisionState({
    required this.currentProduct,
    required this.history,
    this.isScanning = false,
  });

  SupplementVisionState copyWith({
    AsyncValue<SupplementProduct?>? currentProduct,
    List<SupplementProduct>? history,
    bool? isScanning,
  }) {
    return SupplementVisionState(
      currentProduct: currentProduct ?? this.currentProduct,
      history: history ?? this.history,
      isScanning: isScanning ?? this.isScanning,
    );
  }
}

class SupplementVisionNotifier extends StateNotifier<SupplementVisionState> {
  SupplementVisionNotifier()
      : super(SupplementVisionState(
          currentProduct: const AsyncValue.data(null),
          history: [],
        )) {
    loadHistory();
  }

  Future<void> loadHistory() async {
    try {
      final cachedList = await VisionStorageService.getHistory(SupplementService.categoryKey);
      final products = cachedList.map((e) => SupplementProduct.fromJson(e)).toList();
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

    try {
      final product = await SupplementService.analyzeSupplement(
        barcode: barcode,
        searchName: searchName,
        rawDetails: rawDetails,
        imageBase64: imageBase64,
      );

      final historyList = await VisionStorageService.getHistory(SupplementService.categoryKey);
      final updatedHistory = historyList.map((e) => SupplementProduct.fromJson(e)).toList();

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
    await VisionStorageService.clearHistory(SupplementService.categoryKey);
    state = state.copyWith(history: []);
  }

  void resetCurrentProduct() {
    state = state.copyWith(currentProduct: const AsyncValue.data(null));
  }
}

final supplementVisionProvider = StateNotifierProvider<SupplementVisionNotifier, SupplementVisionState>((ref) {
  return SupplementVisionNotifier();
});
