import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:latlong2/latlong.dart';
import 'osrm_service.dart';

class VoiceNavigationService {
  final FlutterTts _tts;
  
  OsrmStep? _nextStep;
  final Set<int> _announcedDistances = {};
  String _language = 'en-US';

  VoiceNavigationService(this._tts);

  Future<void> init() async {
    await _tts.setLanguage(_language);
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
  }

  Future<void> toggleLanguage() async {
    _language = _language == 'en-US' ? 'hi-IN' : 'en-US';
    await _tts.setLanguage(_language);
  }

  String get currentLanguage => _language;

  /// Call this when a new OSRM route is fetched
  void updateRouteSteps(List<OsrmStep> steps) {
    if (steps.isEmpty) return;
    
    // Find the next actionable step (ignore departure step)
    final next = steps.firstWhere(
      (s) => s.distance > 0 && s.type != 'depart' && s.type != 'arrive',
      orElse: () => steps.first,
    );

    // If the step changed (we passed it and got a new one), reset announcements
    if (_nextStep?.location.latitude != next.location.latitude ||
        _nextStep?.location.longitude != next.location.longitude) {
      _nextStep = next;
      _announcedDistances.clear();
    }
  }

  /// Call this on every GPS update to trigger proximity announcements
  void processLocation(LatLng currentLoc) {
    if (_nextStep == null) return;

    final dist = const Distance().as(LengthUnit.Meter, currentLoc, _nextStep!.location);

    if (dist <= 500 && dist > 200 && !_announcedDistances.contains(500)) {
      _announceManeuver(_nextStep!, 500);
      _announcedDistances.add(500);
    } else if (dist <= 200 && dist > 50 && !_announcedDistances.contains(200)) {
      _announceManeuver(_nextStep!, 200);
      _announcedDistances.add(200);
    } else if (dist <= 50 && !_announcedDistances.contains(0)) {
      _announceManeuver(_nextStep!, 0);
      _announcedDistances.add(0);
    }
  }

  Future<void> _announceManeuver(OsrmStep step, int distanceToTurn) async {
    String direction = step.modifier?.replaceAll('-', ' ') ?? 'turn';
    String text;

    if (_language == 'hi-IN') {
      // Basic Hindi translations for common directions (could be expanded)
      direction = direction
          .replaceAll('left', 'baayen')
          .replaceAll('right', 'daayen')
          .replaceAll('straight', 'seedhe')
          .replaceAll('slight', 'thoda');
          
      if (distanceToTurn > 0) {
        text = '$distanceToTurn meter mein, $direction muden';
      } else {
        text = 'Ab $direction muden';
      }
      if (step.roadName != null && step.roadName!.isNotEmpty) {
        text += ' ${step.roadName} par';
      }
    } else {
      // English
      if (distanceToTurn > 0) {
        text = 'In $distanceToTurn meters, $direction';
      } else {
        text = 'Now $direction';
      }
      if (step.roadName != null && step.roadName!.isNotEmpty) {
        text += ' onto ${step.roadName}';
      }
    }

    await _tts.speak(text);
  }

  Future<void> announcePatientArrival(String? patientName) async {
    final name = patientName ?? 'the patient';
    if (_language == 'hi-IN') {
      await _tts.speak('Aap mareez ke sthan par pahunch gaye hain. Mareez ka naam: $name hai. Kripya pickup confirm karein.');
    } else {
      await _tts.speak('You have arrived at the patient location. Patient name: $name. Confirm pickup.');
    }
  }

  Future<void> announceHospitalArrival(String hospitalName, int emBeds, int icuBeds) async {
    if (_language == 'hi-IN') {
      await _tts.speak('Aap $hospitalName pahunch gaye hain. Yahan $emBeds emergency aur $icuBeds ICU beds uplabdh hain.');
    } else {
      await _tts.speak('You have arrived at $hospitalName. $emBeds emergency beds and $icuBeds ICU beds are available.');
    }
  }

  void dispose() {
    _tts.stop();
  }
}

// ─── Riverpod Provider ───────────────────────────────────────────────────────

final voiceNavigationProvider = Provider<VoiceNavigationService>((ref) {
  final service = VoiceNavigationService(FlutterTts());
  service.init();
  ref.onDispose(() => service.dispose());
  return service;
});
