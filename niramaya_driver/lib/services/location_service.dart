import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'supabase_service.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<Position>? _broadcastSub;
  Position? _lastPosition;

  Position? get lastPosition => _lastPosition;
  LatLng? get lastLatLng => _lastPosition == null
      ? null
      : LatLng(_lastPosition!.latitude, _lastPosition!.longitude);

  Future<bool> requestPermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) return false;
    LocationPermission p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) {
      p = await Geolocator.requestPermission();
      if (p == LocationPermission.denied) return false;
    }
    return p != LocationPermission.deniedForever;
  }

  Future<Position?> getCurrentPosition() async {
    try {
      if (!await requestPermission()) return null;
      _lastPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return _lastPosition;
    } catch (_) {
      return null;
    }
  }

  Stream<Position> startPositionStream({int distanceFilter = 10}) {
    final controller = StreamController<Position>.broadcast();
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    ).listen(
      (pos) { _lastPosition = pos; controller.add(pos); },
      onError: controller.addError,
    );
    return controller.stream;
  }

  // ── Live broadcast: every 3 metres, with exponential backoff on failure ──

  int _backoffSeconds = 2;

  void startLocationBroadcast(String driverId) {
    _broadcastSub?.cancel();
    _backoffSeconds = 2;
    _broadcastSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 3,
      ),
    ).listen((pos) async {
      _lastPosition = pos;
      await _writeWithRetry(driverId, pos);
    });
  }

  Future<void> _writeWithRetry(String driverId, Position pos) async {
    int delay = _backoffSeconds;
    for (int attempt = 0; attempt < 4; attempt++) {
      try {
        await SupabaseService.client.from('drivers').update({
          'driver_lat': pos.latitude,
          'driver_lng': pos.longitude,
          'location_updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', driverId);
        _backoffSeconds = 2; // reset on success
        debugPrint('[LocationService] 📍 ${pos.latitude},${pos.longitude}');
        return;
      } catch (e) {
        final isTransient = e is SocketException ||
            e is HandshakeException ||
            e.toString().contains('Connection closed') ||
            e.toString().contains('HandshakeException');
        if (!isTransient) {
          debugPrint('[LocationService] ⚠ Non-transient error: $e');
          return;
        }
        debugPrint('[LocationService] ⚠ Retry $attempt in ${delay}s: $e');
        await Future.delayed(Duration(seconds: delay));
        delay = (delay * 2).clamp(2, 30);
      }
    }
    _backoffSeconds = (_backoffSeconds * 2).clamp(2, 30);
  }

  void stopLocationBroadcast() {
    _broadcastSub?.cancel();
    _broadcastSub = null;
  }

  void stopPositionStream() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  static double distanceKm(LatLng from, LatLng to) {
    const Distance d = Distance();
    return d.as(LengthUnit.Kilometer, from, to);
  }

  static int estimateMinutes(double km, {double avgSpeedKmh = 40.0}) {
    if (km <= 0) return 0;
    return (km / avgSpeedKmh * 60).ceil();
  }

  static String bearingDirection(LatLng from, LatLng to) {
    final dLon = _rad(to.longitude - from.longitude);
    final lat1 = _rad(from.latitude);
    final lat2 = _rad(to.latitude);
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final b = (math.atan2(y, x) * 180 / math.pi + 360) % 360;
    if (b >= 337.5 || b < 22.5) return 'North';
    if (b < 67.5) return 'North-East';
    if (b < 112.5) return 'East';
    if (b < 157.5) return 'South-East';
    if (b < 202.5) return 'South';
    if (b < 247.5) return 'South-West';
    if (b < 292.5) return 'West';
    return 'North-West';
  }

  static double _rad(double d) => d * math.pi / 180;

  void dispose() {
    stopPositionStream();
    stopLocationBroadcast();
  }
}
