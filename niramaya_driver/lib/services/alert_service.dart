// ── Alert Service — Sound + Vibration for dispatch alerts ───────────────────

import 'dart:async';
import 'package:vibration/vibration.dart';
import 'tts_service.dart';

class AlertService {
  AlertService._();

  static final AlertService instance = AlertService._();

  bool _isPlaying = false;
  Timer? _repeatTimer;

  /// Trigger dispatch alert: vibration burst + repeating TTS alert.
  Future<void> triggerAlert() async {
    if (_isPlaying) return;
    _isPlaying = true;

    try {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator) {
        Vibration.vibrate(pattern: [0, 600, 200, 600, 200, 600]);
      }
    } catch (_) {}

    Future<void> announce() async {
      await TtsService.instance.speak('New dispatch alert. Please respond.');
    }

    await announce();
    _repeatTimer = Timer.periodic(const Duration(seconds: 8), (_) => announce());
  }

  /// Stop all alert outputs.
  Future<void> stopAlert() async {
    _isPlaying = false;
    _repeatTimer?.cancel();
    _repeatTimer = null;
    try {
      await TtsService.instance.stop();
    } catch (_) {}
    try {
      Vibration.cancel();
    } catch (_) {}
  }

  void dispose() {
    stopAlert();
  }
}
