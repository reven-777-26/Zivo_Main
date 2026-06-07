import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class AIBackendService {
  static final FirebaseFunctions _functions = FirebaseFunctions.instance;

  /// Calls the deployed healthCheckAI Firebase Function.
  static Future<Map<String, dynamic>> healthCheckAI() async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('healthCheckAI');
      final HttpsCallableResult result = await callable.call();

      if (result.data is Map) {
        return Map<String, dynamic>.from(result.data as Map);
      }
      return {'response': result.data?.toString() ?? ''};
    } catch (e) {
      debugPrint("Error calling healthCheckAI: $e");
      return {'error': e.toString()};
    }
  }

  /// Calls the deployed analyzeMeal Firebase Function.
  static Future<Map<String, dynamic>> analyzeMeal({
    required String type,
    required String content,
  }) async {
    try {
      final HttpsCallable callable = _functions.httpsCallable('analyzeMeal');
      final HttpsCallableResult result = await callable.call({
        'type': type,
        'content': content,
      });

      if (result.data is Map) {
        return Map<String, dynamic>.from(result.data as Map);
      }
      return {'response': result.data?.toString() ?? ''};
    } catch (e) {
      debugPrint("Error calling analyzeMeal: $e");
      return {'error': e.toString()};
    }
  }
}
