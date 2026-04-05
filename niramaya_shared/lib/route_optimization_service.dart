import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:latlong2/latlong.dart';

enum RouteProfile {
  driving,
  walking,
  cycling,
}

enum RoutePreference {
  fastest,
  shortest,
  avoidTolls,
  avoidHighways,
}

class RouteInfo {
  final List<LatLng> polyline;
  final double distanceKm;
  final int durationMinutes;
  final String instructions;
  final List<RouteStep> steps;

  RouteInfo({
    required this.polyline,
    required this.distanceKm,
    required this.durationMinutes,
    required this.instructions,
    required this.steps,
  });
}

class RouteStep {
  final String instruction;
  final double distanceM;
  final int durationS;
  final LatLng location;

  RouteStep({
    required this.instruction,
    required this.distanceM,
    required this.durationS,
    required this.location,
  });
}

class RouteOptimizationService {
  static final RouteOptimizationService _instance = RouteOptimizationService._internal();
  factory RouteOptimizationService() => _instance;
  RouteOptimizationService._internal();

  final _client = RetryClient(http.Client());
  final Map<String, RouteInfo> _routeCache = {};

  Future<RouteInfo?> getOptimizedRoute(
    LatLng start,
    LatLng end, {
    RouteProfile profile = RouteProfile.driving,
    RoutePreference preference = RoutePreference.fastest,
    List<LatLng> waypoints = const [],
  }) async {
    final cacheKey = _generateCacheKey(start, end, profile, preference, waypoints);
    
    if (_routeCache.containsKey(cacheKey)) {
      return _routeCache[cacheKey];
    }

    try {
      final route = await _fetchRoute(start, end, profile, preference, waypoints);
      if (route != null) {
        _routeCache[cacheKey] = route;
        _cleanupCache();
      }
      return route;
    } catch (e) {
      print('Route optimization error: $e');
      return null;
    }
  }

  Future<List<RouteInfo>> getAlternativeRoutes(
    LatLng start,
    LatLng end, {
    RouteProfile profile = RouteProfile.driving,
    int maxAlternatives = 3,
  }) async {
    try {
      final url = _buildOSRMUrl(start, end, profile, alternatives: true);
      final response = await _client.get(Uri.parse(url)).timeout(
        const Duration(seconds: 15),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final routes = data['routes'] as List?;
        
        if (routes != null) {
          return routes.take(maxAlternatives).map((route) {
            return _parseRouteFromOSRM(route);
          }).toList();
        }
      }
    } catch (e) {
      print('Alternative routes error: $e');
    }
    
    return [];
  }

  Future<RouteInfo?> _fetchRoute(
    LatLng start,
    LatLng end,
    RouteProfile profile,
    RoutePreference preference,
    List<LatLng> waypoints,
  ) async {
    final url = _buildOSRMUrl(start, end, profile, waypoints: waypoints);
    
    final response = await _client.get(Uri.parse(url)).timeout(
      const Duration(seconds: 10),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final routes = data['routes'] as List?;
      
      if (routes != null && routes.isNotEmpty) {
        return _parseRouteFromOSRM(routes[0]);
      }
    }
    
    return null;
  }

  String _buildOSRMUrl(
    LatLng start,
    LatLng end,
    RouteProfile profile, {
    List<LatLng> waypoints = const [],
    bool alternatives = false,
  }) {
    final profileStr = profile.name;
    final coordinates = [start, ...waypoints, end]
        .map((point) => '${point.longitude},${point.latitude}')
        .join(';');
    
    final params = [
      'overview=full',
      'geometries=geojson',
      'steps=true',
      if (alternatives) 'alternatives=true',
    ].join('&');
    
    return 'https://router.project-osrm.org/route/v1/$profileStr/$coordinates?$params';
  }

  RouteInfo _parseRouteFromOSRM(Map<String, dynamic> route) {
    final geometry = route['geometry']['coordinates'] as List;
    final polyline = geometry.map((coord) => 
      LatLng(coord[1].toDouble(), coord[0].toDouble())
    ).toList();
    
    final distanceM = (route['distance'] as num).toDouble();
    final durationS = (route['duration'] as num).toDouble();
    
    final legs = route['legs'] as List? ?? [];
    final steps = <RouteStep>[];
    String instructions = '';
    
    for (final leg in legs) {
      final legSteps = leg['steps'] as List? ?? [];
      for (final step in legSteps) {
        final maneuver = step['maneuver'];
        final instruction = step['name'] ?? 'Continue';
        final stepDistance = (step['distance'] as num).toDouble();
        final stepDuration = (step['duration'] as num).toDouble();
        final location = maneuver['location'];
        
        steps.add(RouteStep(
          instruction: instruction,
          distanceM: stepDistance,
          durationS: stepDuration.toInt(),
          location: LatLng(location[1].toDouble(), location[0].toDouble()),
        ));
        
        instructions += '$instruction (${(stepDistance / 1000).toStringAsFixed(1)}km)\n';
      }
    }
    
    return RouteInfo(
      polyline: polyline,
      distanceKm: distanceM / 1000,
      durationMinutes: (durationS / 60).ceil(),
      instructions: instructions.trim(),
      steps: steps,
    );
  }

  String _generateCacheKey(
    LatLng start,
    LatLng end,
    RouteProfile profile,
    RoutePreference preference,
    List<LatLng> waypoints,
  ) {
    return '${start.latitude},${start.longitude}-${end.latitude},${end.longitude}-${profile.name}-${preference.name}-${waypoints.length}';
  }

  void _cleanupCache() {
    if (_routeCache.length > 50) {
      final keys = _routeCache.keys.toList();
      for (int i = 0; i < 25; i++) {
        _routeCache.remove(keys[i]);
      }
    }
  }

  void clearCache() {
    _routeCache.clear();
  }

  void dispose() {
    _client.close();
    _routeCache.clear();
  }
}