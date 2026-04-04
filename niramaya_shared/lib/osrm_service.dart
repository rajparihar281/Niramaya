import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

// ─── Data Models ─────────────────────────────────────────────────────────────

class OsrmStep {
  final String type; // e.g., 'turn', 'new name', 'arrive'
  final String? modifier; // e.g., 'left', 'right', 'slight right'
  final String? roadName; // e.g., 'Main St'
  final double distance; // Distance in meters to the NEXT turn
  final LatLng location; // Coordinate of this maneuver

  OsrmStep({
    required this.type,
    this.modifier,
    this.roadName,
    required this.distance,
    required this.location,
  });
}

class OsrmRoute {
  final List<LatLng> polyline;
  final double distanceTotal; // meters
  final double durationTotal; // seconds
  final List<OsrmStep> steps;

  OsrmRoute({
    required this.polyline,
    required this.distanceTotal,
    required this.durationTotal,
    required this.steps,
  });
}

// ─── Service ─────────────────────────────────────────────────────────────────

class OsrmService {
  final Dio _dio;

  OsrmService(this._dio);

  /// Fetches an OSRM route between two coordinates.
  /// Uses geometries=geojson to skip traditional polyline decoding.
  Future<OsrmRoute?> getRoute(LatLng start, LatLng end) async {
    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${start.longitude},${start.latitude};'
          '${end.longitude},${end.latitude}';

      final response = await _dio.get(url, queryParameters: {
        'geometries': 'geojson',
        'steps': 'true',
        'overview': 'full',
      });

      if (response.statusCode == 200 && response.data['code'] == 'Ok') {
        final route = response.data['routes'][0];
        
        // Parse geometry
        final coordsList = route['geometry']['coordinates'] as List;
        final List<LatLng> polyline = coordsList.map((c) {
          return LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble());
        }).toList();

        // Parse steps from the first leg
        final legs = route['legs'] as List;
        final List<OsrmStep> steps = [];
        
        if (legs.isNotEmpty) {
          final leg = legs[0];
          final stepsArray = leg['steps'] as List;
          
          for (var s in stepsArray) {
            final maneuver = s['maneuver'];
            final loc = maneuver['location'] as List;
            steps.add(OsrmStep(
              type: maneuver['type'] as String,
              modifier: maneuver['modifier'] as String?,
              roadName: s['name'] as String?,
              distance: (s['distance'] as num).toDouble(),
              location: LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
            ));
          }
        }

        return OsrmRoute(
          polyline: polyline,
          distanceTotal: (route['distance'] as num).toDouble(),
          durationTotal: (route['duration'] as num).toDouble(),
          steps: steps,
        );
      }
    } catch (e) {
      debugPrint('[OsrmService] Failed to fetch route: $e');
    }
    return null;
  }
}

// ─── Riverpod Provider ───────────────────────────────────────────────────────

final osrmServiceProvider = Provider<OsrmService>((ref) {
  return OsrmService(Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  )));
});
