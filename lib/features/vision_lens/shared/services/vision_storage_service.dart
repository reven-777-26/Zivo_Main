import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class VisionStorageService {
  static const String foodBoxName = 'vision_food_box';
  static const String supplementBoxName = 'vision_supplement_box';
  static const String skincareBoxName = 'vision_skincare_box';

  static Box? _foodBox;
  static Box? _supplementBox;
  static Box? _skincareBox;

  static Future<void> init() async {
    _foodBox = await Hive.openBox(foodBoxName);
    _supplementBox = await Hive.openBox(supplementBoxName);
    _skincareBox = await Hive.openBox(skincareBoxName);
  }

  static Future<Box> _getBox(String category) async {
    switch (category.toLowerCase()) {
      case 'food':
        if (_foodBox == null || !_foodBox!.isOpen) {
          _foodBox = await Hive.openBox(foodBoxName);
        }
        return _foodBox!;
      case 'supplement':
      case 'supplements':
        if (_supplementBox == null || !_supplementBox!.isOpen) {
          _supplementBox = await Hive.openBox(supplementBoxName);
        }
        return _supplementBox!;
      case 'skincare':
        if (_skincareBox == null || !_skincareBox!.isOpen) {
          _skincareBox = await Hive.openBox(skincareBoxName);
        }
        return _skincareBox!;
      default:
        throw ArgumentError('Invalid category for Vision Storage: $category');
    }
  }

  static Future<void> cacheProduct(String category, String barcode, Map<String, dynamic> data) async {
    final box = await _getBox(category);
    await box.put(barcode, jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> getCachedProduct(String category, String barcode) async {
    final box = await _getBox(category);
    final val = box.get(barcode);
    if (val != null && val is String) {
      try {
        return jsonDecode(val) as Map<String, dynamic>;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getHistory(String category) async {
    final box = await _getBox(category);
    final list = <Map<String, dynamic>>[];
    for (var key in box.keys) {
      final val = box.get(key);
      if (val != null && val is String) {
        try {
          final decoded = jsonDecode(val);
          if (decoded is Map<String, dynamic>) {
            decoded['barcode'] = key.toString();
            list.add(decoded);
          }
        } catch (_) {}
      }
    }
    list.sort((a, b) {
      final aDateStr = a['scanDate'] ?? '';
      final bDateStr = b['scanDate'] ?? '';
      if (aDateStr.isEmpty || bDateStr.isEmpty) return 0;
      return bDateStr.compareTo(aDateStr);
    });
    return list;
  }

  static Future<void> clearHistory(String category) async {
    final box = await _getBox(category);
    await box.clear();
  }
}
