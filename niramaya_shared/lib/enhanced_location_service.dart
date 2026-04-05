import 'dart:async';
import 'dart:math' as math;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

class EnhancedLocationService {
  static final EnhancedLocationService _instance = EnhancedLocationService._internal();
  factory EnhancedLocationService() => _instance;
  EnhancedLocationService._internal();

  StreamController<LatLng>? _locationController;
  StreamSubscription<Position>? _positionSubscription;
  LatLng? _lastKnownLocation;
  bool _isTracking = false;

  Stream<LatLng> get locationStream {
    _locationController ??= StreamController<LatLng>.broadcast();
    return _locationController!.stream;
  }

  LatLng? get lastKnownLocation => _lastKnownLocation;
  bool get isTracking => _isTracking;

  Future<bool> requestPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      
      return permission == LocationPermission.whileInUse || 
             permission == LocationPermission.always;
    } catch (e) {
      print('Location permission error: $e');
      return false;
    }
  }

  Future<LatLng?> getCurrentLocation() async {
    try {
      final hasPermission = await requestPermission();
      if (!hasPermission) return null;

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      final location = LatLng(position.latitude, position.longitude);
      _lastKnownLocation = location;
      return location;
    } catch (e) {
      print('Get current location error: $e');
      return null;
    }
  }

  Future<void> startTracking({
    LocationAccuracy accuracy = LocationAccuracy.high,
    int distanceFilter = 10,
  }) async {
    if (_isTracking) return;

    final hasPermission = await requestPermission();
    if (!hasPermission) return;

    _isTracking = true;
    _locationController ??= StreamController<LatLng>.broadcast();

    _positionSubscription = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: accuracy,
        distanceFilter: distanceFilter,
      ),
    ).listen(
      (position) {
        final location = LatLng(position.latitude, position.longitude);
        _lastKnownLocation = location;
        _locationController?.add(location);
      },
      onError: (error) {
        print('Location tracking error: $error');
      },
    );
  }

  void stopTracking() {
    _isTracking = false;
    _positionSubscription?.cancel();
    _positionSubscription = null;
  }

  void dispose() {
    stopTracking();
    _locationController?.close();
    _locationController = null;
  }

  // Utility methods
  static double calculateDistance(LatLng point1, LatLng point2) {
    return Geolocator.distanceBetween(
      point1.latitude,
      point1.longitude,
      point2.latitude,
      point2.longitude,
    );
  }

  static double calculateBearing(LatLng start, LatLng end) {
    final lat1 = start.latitude * math.pi / 180;
    final lng1 = start.longitude * math.pi / 180;
    final lat2 = end.latitude * math.pi / 180;
    final lng2 = end.longitude * math.pi / 180;
    final dLon = lng2 - lng1;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    double brng = math.atan2(y, x);
    return (brng * 180 / math.pi + 360) % 360;
  }

  static String getBearingDirection(double bearing) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((bearing + 22.5) / 45).floor() % 8;
    return directions[index];
  }

  static int estimateETA(double distanceKm, {double averageSpeedKmh = 40}) {
    return (distanceKm / averageSpeedKmh * 60).ceil();
  }

  static LatLng interpolatePosition(LatLng start, LatLng end, double fraction) {
    return LatLng(
      start.latitude + (end.latitude - start.latitude) * fraction,
      start.longitude + (end.longitude - start.longitude) * fraction,
    );
  }
}