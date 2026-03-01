import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'dart:async';

class SoundService {
  static final AudioPlayer _player = AudioPlayer();
  static String? _currentSource;
  static Timer? _fallbackTimer; // Timer for system sound loop

  // Robust URLs
  static const String _alertSoundUrl = "https://actions.google.com/sounds/v1/alarms/digital_watch_alarm_long.ogg"; 
  static const String _sosSoundUrl = "https://actions.google.com/sounds/v1/emergency/emergency_siren_short_burst.ogg"; 

  /// 1. Unlock Audio Context (Must be called on user interaction)
  static Future<void> initializeAudio() async {
    // print("SoundService: Attempting to unlock audio context...");
    try {
      // Just setting the mode is often enough to 'wake' the engine on some platforms
      await _player.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      print("SoundService: Error unlocking audio: $e");
    }
  }

  // 🔹 SOS: Siren Loop
  static Future<void> playSOSLoop() async {
    _cancelFallback();
    try {
      if (_player.state == PlayerState.playing && 
          _player.releaseMode == ReleaseMode.loop &&
          _currentSource == _sosSoundUrl) {
          return;
      }
      
      print("SoundService: Starting SOS Loop");
      await _player.stop();
      _currentSource = _sosSoundUrl;
      await _player.setVolume(1.0);
      await _player.setReleaseMode(ReleaseMode.loop);
      await _player.play(UrlSource(_sosSoundUrl));
      
      HapticFeedback.heavyImpact();
    } catch (e) {
      print("SoundService: Error playing SOS loop: $e");
      _startFallbackSystemSound(isEmergency: true);
    }
  }

  // 🔹 SOS: Play exactly X times
  static Future<void> playSOSXTimes(int times) async {
    _cancelFallback();
    try {
      await _player.stop();
      _currentSource = null; 
      await _player.setReleaseMode(ReleaseMode.stop);
      
      int count = 0;
      StreamSubscription? sub;
      
      sub = _player.onPlayerComplete.listen((_) async {
        count++;
        if (count < times) {
           await _player.play(UrlSource(_sosSoundUrl));
        } else {
           sub?.cancel();
        }
      });

      await _player.play(UrlSource(_sosSoundUrl));
    } catch (e) {
      print("SoundService: Error playing SOS X times: $e");
      SystemSound.play(SystemSoundType.alert);
    }
  }

  // 🔹 QUEUE: Gentle Loop (CRITICAL FIX)
  static Future<void> playQueueLoop() async {
     // Check if already playing correct sound
     if (_player.state == PlayerState.playing && 
         _player.releaseMode == ReleaseMode.loop &&
         _currentSource == _alertSoundUrl) {
         // Even if looping, ensure volume is MAX
         await _player.setVolume(1.0);
         return; 
     }

     _cancelFallback();
     
     print("SoundService: Attempting to start Queue Loop...");
     try {
       await _player.stop(); // Ensure clear state
       _currentSource = _alertSoundUrl;
       
       // FORCE Volume to max for audibility (EXPLICIT 1.0)
       await _player.setVolume(1.0); 
       await _player.setReleaseMode(ReleaseMode.loop);
       
       // Play
       await _player.play(UrlSource(_alertSoundUrl));
       print("SoundService: Queue Loop successfully started at MAX VOLUME");
     } catch (e) {
       print("SoundService: CRITICAL ERROR playing Queue loop: $e");
       print("SoundService: Activating System Sound Fallback Loop");
       _startFallbackSystemSound(isEmergency: false);
     }
  }

  static Future<void> stopLoop() async {
    _cancelFallback();
    try {
      print("SoundService: Stopping all sounds");
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop); 
      _currentSource = null;
    } catch (e) {
      print("SoundService: Error stopping sound: $e");
    }
  }

  // Single alert
  static Future<void> playGeneralAlert() async {
    _cancelFallback();
    try {
      await _player.stop();
      await _player.setReleaseMode(ReleaseMode.stop); 
      await _player.play(UrlSource(_alertSoundUrl));
      HapticFeedback.mediumImpact();
    } catch (e) {
      SystemSound.play(SystemSoundType.alert);
    }
  }

  static Future<void> vibrate() async {
    await HapticFeedback.vibrate();
  }

  // --- Fallback Mechanism ---
  static void _startFallbackSystemSound({required bool isEmergency}) {
     _cancelFallback();
     // Play immediately
     SystemSound.play(SystemSoundType.alert);
     if (isEmergency) HapticFeedback.heavyImpact();

     // Loop every 2 seconds
     _fallbackTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
        print("SoundService: Playing Fallback System Sound...");
        SystemSound.play(SystemSoundType.alert);
        if (isEmergency) HapticFeedback.heavyImpact();
     });
  }

  static void _cancelFallback() {
    if (_fallbackTimer != null) {
      print("SoundService: Cancelling Fallback Timer");
      _fallbackTimer!.cancel();
      _fallbackTimer = null;
    }
  }
}
