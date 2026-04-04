// ── Location Service — GPS stream + distance calculations + location broadcast

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'supabase_service.dart';

class LocationService {
  LocationService._();

  static final LocationService instance = LocationService._();

  StreamSubscription<Position>? _positionSub;
  Position? _lastPosition;
  Timer? _broadcastTimer;

  Position? get lastPosition => _lastPosition;

  LatLng? get lastLatLng {
    if (_lastPosition == null) return null;
    return LatLng(_lastPosition!.latitude, _lastPosition!.longitude);
  }

  /// Request location permissions and check service availability.
  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }

    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  /// Get current position once.
  Future<Position?> getCurrentPosition() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) return null;

      _lastPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      return _lastPosition;
    } catch (e) {
      return null;
    }
  }

  /// Start continuous position stream.
  Stream<Position> startPositionStream({
    int distanceFilter = 10,
  }) {
    final controller = StreamController<Position>.broadcast();

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: distanceFilter,
      ),
    ).listen(
      (position) {
        _lastPosition = position;
        controller.add(position);
      },
      onError: (e) {
        controller.addError(e);
      },
    );

    return controller.stream;
  }

  /// Calculate distance between two points in kilometers.
  static double distanceKm(LatLng from, LatLng to) {
    const Distance distance = Distance();
    return distance.as(LengthUnit.Kilometer, from, to);
  }

  /// Calculate estimated time of arrival in minutes.
  /// Assumes average ambulance speed of 40 km/h in city.
  static int estimateMinutes(double distanceKm,
      {double avgSpeedKmh = 40.0}) {
    if (distanceKm <= 0) return 0;
    return (distanceKm / avgSpeedKmh * 60).ceil();
  }

  /// Calculate bearing direction from one point to another.
  static String bearingDirection(LatLng from, LatLng to) {
    final dLon = _toRadians(to.longitude - from.longitude);
    final lat1 = _toRadians(from.latitude);
    final lat2 = _toRadians(to.latitude);

    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    final bearing = (math.atan2(y, x) * 180 / math.pi + 360) % 360;

    if (bearing >= 337.5 || bearing < 22.5) return 'North';
    if (bearing < 67.5) return 'North-East';
    if (bearing < 112.5) return 'East';
    if (bearing < 157.5) return 'South-East';
    if (bearing < 202.5) return 'South';
    if (bearing < 247.5) return 'South-West';
    if (bearing < 292.5) return 'West';
    return 'North-West';
  }

  static double _toRadians(double degrees) => degrees * math.pi / 180;

  void stopPositionStream() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  // ── Task 3: Broadcast driver location to drivers table every 5s ──────────
  void startLocationBroadcast(String driverId) {
    _broadcastTimer?.cancel();
    _broadcastTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final pos = _lastPosition;
      if (pos == null) return;
      try {
        await SupabaseService.client.from('drivers').update({
          'driver_lat': pos.latitude,
          'driver_lng': pos.longitude,
          'location_updated_at': DateTime.now().toUtc().toIso8601String(),
        }).eq('id', driverId);
        debugPrint('[LocationService] 📍 Broadcast: ${pos.latitude},${pos.longitude} for driver=$driverId');
      } catch (e) {
        debugPrint('[LocationService] ⚠ Broadcast failed: $e');
      }
    });
  }

  void stopLocationBroadcast() {
    _broadcastTimer?.cancel();
    _broadcastTimer = null;
  }

  void dispose() {
    stopPositionStream();
    stopLocationBroadcast();
  }
}
