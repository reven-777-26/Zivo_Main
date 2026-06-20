import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  static final AudioPlayer _appOpenPlayer = AudioPlayer();
  static bool _isConfigured = false;

  static Future<void> _ensureConfigured() async {
    if (_isConfigured) return;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.assistanceSonification,
          ),
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.ambient,
            options: const {
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
        ),
      );
      _isConfigured = true;
    } catch (e) {
      debugPrint("Error setting global audio context: $e");
    }
  }

  static Future<void> playAppOpen() async {
    try {
      await _ensureConfigured();
      await _appOpenPlayer.play(AssetSource('ui_sfx/app_open.mp3'));
    } catch (e) {
      debugPrint("Error playing app open sound: $e");
    }
  }

  static Future<void> playNotification() async {
    try {
      await _ensureConfigured();
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
      await _ensureConfigured();
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
