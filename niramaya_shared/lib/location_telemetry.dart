import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Service responsible for gathering GPS updates and sending them to the backend.
/// Runs resiliently with a foreground task on Android to ensure consistent connection.
class LocationTelemetryService {
  final SupabaseClient _client;
  
  String? _currentDriverId;
  StreamSubscription<Position>? _positionSub;
  bool _isRunning = false;
  
  // Rate limiting & Debouncing
  DateTime? _lastSendTime;
  Position? _pendingPosition;
  Timer? _debounceTimer;

  // Retry mechanisms
  Position? _failedPosition; 
  Timer? _retryTimer;
  int _retryBackoff = 1; // exponential backoff in seconds

  LocationTelemetryService(this._client);

  bool get isRunning => _isRunning;

  /// Start the telemetry loop for the given driver.
  Future<void> start(String driverId) async {
    if (_isRunning) return;
    _currentDriverId = driverId;
    _isRunning = true;
    _retryBackoff = 1;

    // Platform-specific Foreground Task init (mainly Android)
    if (!kIsWeb) {
      FlutterForegroundTask.startService(
        notificationTitle: 'Niramaya-Net: Active Dispatch',
        notificationText: 'Live GPS telemetry is active.',
      );
    }

    LocationPermission perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      perm = await Geolocator.requestPermission();
    }

    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
      debugPrint('[Telemetry] Location denied. Cannot start loop.');
      stop();
      return;
    }

    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Must move at least 10m
      ),
    ).listen(
      _handleNewPosition,
      onError: (e) {
        debugPrint('[Telemetry] GPS Stream Error: $e');
      },
    );
  }

  void _handleNewPosition(Position position) {
    // 1-second debounce/rate-limit
    if (_lastSendTime != null && DateTime.now().difference(_lastSendTime!) < const Duration(seconds: 1)) {
      _pendingPosition = position;
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(seconds: 1), () {
        if (_pendingPosition != null) {
          _sendPosition(_pendingPosition!);
          _pendingPosition = null;
        }
      });
      return;
    }

    _sendPosition(position);
  }

  Future<void> _sendPosition(Position position) async {
    _lastSendTime = DateTime.now();
    try {
      // Direct REST Update to avoid real-time channel latency for writes
      // Using PostgREST ST_MakePoint syntax to directly write into geography(Point, 4326)
      await _client.from('drivers').update({
        'last_location': 'SRID=4326;POINT(${position.longitude} ${position.latitude})',
        'last_location_updated_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', _currentDriverId!);

      // If successful, reset backoff and clear failed state
      _retryBackoff = 1;
      _failedPosition = null;
      _retryTimer?.cancel();
      
    } catch (e) {
      debugPrint('[Telemetry] Update failed: $e');
      // Overwrite failed position with latest, we only care to sync the newest
      _failedPosition = position;
      _scheduleRetry();
    }
  }

  void _scheduleRetry() {
    if (_retryTimer != null && _retryTimer!.isActive) return;
    
    _retryTimer = Timer(Duration(seconds: _retryBackoff), () async {
      if (_failedPosition == null || !_isRunning) return;
      
      final positionToRetry = _failedPosition!;
      _failedPosition = null;
      
      try {
        await _client.from('drivers').update({
          'last_location': 'SRID=4326;POINT(${positionToRetry.longitude} ${positionToRetry.latitude})',
          'last_location_updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', _currentDriverId!);
        
        _retryBackoff = 1;
      } catch (e) {
        _failedPosition = positionToRetry;
        if (_retryBackoff < 30) {
          _retryBackoff *= 2; 
        }
        _scheduleRetry();
      }
    });
  }

  /// Stops telemetry and the foreground service
  void stop() {
    _isRunning = false;
    _currentDriverId = null;
    _positionSub?.cancel();
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _failedPosition = null;
    
    if (!kIsWeb) {
      FlutterForegroundTask.stopService();
    }
  }
}

// ─── Riverpod Provider ───────────────────────────────────────────────────────

final locationTelemetryProvider = Provider<LocationTelemetryService>((ref) {
  final service = LocationTelemetryService(Supabase.instance.client);
  ref.onDispose(() => service.stop());
  return service;
});
