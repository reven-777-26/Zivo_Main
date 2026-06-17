import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class VisionFirebaseService {
  static String _getCollectionPath(String category) {
    switch (category.toLowerCase()) {
      case 'food':
        return 'global_vision_food_scans';
      case 'supplement':
      case 'supplements':
        return 'global_vision_supplement_scans';
      case 'skincare':
        return 'global_vision_skincare_scans';
      default:
        throw ArgumentError('Invalid category for Firebase Vision sync: $category');
    }
  }

  static Future<void> saveProductToFirestore(
    String category,
    String barcode,
    Map<String, dynamic> data,
  ) async {
    try {
      final path = _getCollectionPath(category);
      await FirebaseFirestore.instance.collection(path).doc(barcode).set({
        ...data,
        'syncedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> getProductFromFirestore(
    String category,
    String barcode,
  ) async {
    try {
      final path = _getCollectionPath(category);
      final doc = await FirebaseFirestore.instance.collection(path).doc(barcode).get();
      if (doc.exists && doc.data() != null) {
        return doc.data();
      }
    } catch (_) {}
    return null;
  }

  static Future<List<Map<String, dynamic>>> getHistoryFromFirestore(
    String category,
  ) async {
    try {
      final path = _getCollectionPath(category);
      final snapshot = await FirebaseFirestore.instance
          .collection(path)
          .orderBy('scanDate', descending: true)
          .limit(50)
          .get();
      return snapshot.docs.map((doc) {
        final d = doc.data();
        d['barcode'] = doc.id;
        return d;
      }).toList();
    } catch (_) {}
    return [];
  }
}
