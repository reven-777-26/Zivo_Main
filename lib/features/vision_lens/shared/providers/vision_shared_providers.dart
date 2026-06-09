import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider to manage the selected category tab (0 = Food, 1 = Supplements, 2 = Skincare)
final visionActiveTabProvider = StateProvider<int>((ref) => 0);
