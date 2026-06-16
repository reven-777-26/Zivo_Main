import 'package:flutter/services.dart';

class WorkoutNotificationService {
  static const _channel = MethodChannel('com.healthtrack.mvp/workout_notification');

  /// Requests notification permission on Android 13+
  static Future<void> requestPermission() async {
    try {
      await _channel.invokeMethod('requestNotificationPermission');
    } catch (e) {
      print("Error requesting notification permission: $e");
    }
  }

  /// Starts the ongoing chronometer notification with the given start time
  static Future<void> startNotification({
    required String title,
    required String body,
    required int startTimeMillis,
  }) async {
    try {
      await _channel.invokeMethod('startNotification', {
        'title': title,
        'body': body,
        'startTimeMillis': startTimeMillis,
      });
    } catch (e) {
      print("Error starting notification: $e");
    }
  }

  /// Pauses the ongoing chronometer notification and shows status text
  static Future<void> pauseNotification({
    required String title,
    required String body,
  }) async {
    try {
      await _channel.invokeMethod('pauseNotification', {
        'title': title,
        'body': body,
      });
    } catch (e) {
      print("Error pausing notification: $e");
    }
  }

  /// Cancels the ongoing notification
  static Future<void> stopNotification() async {
    try {
      await _channel.invokeMethod('stopNotification');
    } catch (e) {
      print("Error stopping notification: $e");
    }
  }
}
