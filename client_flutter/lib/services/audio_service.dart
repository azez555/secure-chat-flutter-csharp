import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class AudioService {
  final AudioPlayer _ringtonePlayer = AudioPlayer();
  final AudioPlayer _ringbackPlayer = AudioPlayer();

  AudioService() {
    _ringtonePlayer.setReleaseMode(ReleaseMode.loop);
    _ringbackPlayer.setReleaseMode(ReleaseMode.loop);
  }

  Future<void> playIncomingRingtone() async {
    try {
      await _ringtonePlayer.play(AssetSource('audio/incoming_ringtone.mp3'));
      debugPrint("Playing incoming ringtone...");
    } catch (e) {
      debugPrint("Error playing incoming ringtone: $e");
    }
  }

  Future<void> playOutgoingRingback() async {
    try {
      await _ringbackPlayer.play(AssetSource('audio/outgoing_ringback.mp3'));
      debugPrint("Playing outgoing ringback...");
    } catch (e) {
      debugPrint("Error playing outgoing ringback: $e");
    }
  }

  Future<void> stopAllSounds() async {
    try {
      if (_ringtonePlayer.state == PlayerState.playing) {
        await _ringtonePlayer.stop();
        debugPrint("Stopped incoming ringtone.");
      }
      if (_ringbackPlayer.state == PlayerState.playing) {
        await _ringbackPlayer.stop();
        debugPrint("Stopped outgoing ringback.");
      }
    } catch (e) {
      debugPrint("Error stopping sounds: $e");
    }
  }

  void dispose() {
    _ringtonePlayer.dispose();
    _ringbackPlayer.dispose();
  }
}
