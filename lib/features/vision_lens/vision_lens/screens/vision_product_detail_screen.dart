import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../food/screens/food_product_detail_screen.dart';
import '../../supplements/screens/supplement_product_detail_screen.dart';
import '../../skincare/screens/skincare_product_detail_screen.dart';

class VisionProductDetailScreen extends ConsumerWidget {
  final String category;
  final String? barcode;

  const VisionProductDetailScreen({
    super.key,
    required this.category,
    this.barcode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catLower = category.toLowerCase();
    if (catLower == 'food') {
      return FoodProductDetailScreen(barcode: barcode);
    } else if (catLower == 'supplement' || catLower == 'supplements') {
      return SupplementProductDetailScreen(barcode: barcode);
    } else {
      return SkincareProductDetailScreen(barcode: barcode);
    }
  }
}
