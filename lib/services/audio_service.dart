import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioPlayer _appOpenPlayer = AudioPlayer();

  static Future<void> playAppOpen() async {
    try {
      await _appOpenPlayer.play(AssetSource('ui_sfx/app_open.mp3'));
    } catch (e) {
      debugPrint("Error playing app open sound: $e");
    }
  }

  static Future<void> playNotification() async {
    try {
      // Use a new instance to support concurrent notification triggers
      final player = AudioPlayer();
      await player.play(AssetSource('ui_sfx/ui_1.mp3'));
      player.onPlayerComplete.listen((_) {
        player.dispose();
      });
    } catch (e) {
      debugPrint("Error playing notification sound: $e");
    }
  }

  static Future<void> playAiOutput() async {
    try {
      final player = AudioPlayer();
      await player.play(AssetSource('ui_sfx/zivo_output.mp3'));
      player.onPlayerComplete.listen((_) {
        player.dispose();
      });
    } catch (e) {
      debugPrint("Error playing AI output sound: $e");
    }
  }
}
