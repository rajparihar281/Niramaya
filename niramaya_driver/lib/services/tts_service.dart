// ── TTS Service — Voice navigation announcements ────────────────────────────

import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';

enum DispatchPhase { toPatient, toHospital }

class TtsService {
  TtsService._();

  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  Timer? _periodicTimer;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized) return;
    await _tts.setLanguage('en-IN');
    await _tts.setSpeechRate(0.82);
    await _tts.setVolume(1.0);
    await _tts.setPitch(0.95);
    _initialized = true;
  }

  Future<void> speak(String text) async {
    if (!_initialized) await init();
    await _tts.speak(text);
  }

  Future<void> stop() async {
    await _tts.stop();
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  /// Announce dispatch phase when map opens
  void announcePhase(DispatchPhase phase, String hospitalName, double distKm) {
    if (phase == DispatchPhase.toPatient) {
      speak(
        'Dispatch assigned. Heading to patient pickup. '
        'Distance ${distKm.toStringAsFixed(1)} kilometers.',
      );
    } else {
      speak(
        'Patient picked up. Now heading to $hospitalName. '
        'Distance ${distKm.toStringAsFixed(1)} kilometers.',
      );
    }
  }

  /// Start periodic bearing/distance announcements every 30 seconds
  void startPeriodicAnnounce(String bearing, double distKm) {
    _periodicTimer?.cancel();
    _periodicTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        speak(
          'Continue for ${distKm.toStringAsFixed(1)} kilometers. '
          'Heading $bearing.',
        );
      },
    );
  }

  void stopPeriodicAnnounce() {
    _periodicTimer?.cancel();
    _periodicTimer = null;
  }

  void dispose() {
    stop();
    _tts.stop();
  }
}
