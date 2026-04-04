import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';

import 'package:niramaya_shared/realtime_service.dart';
import 'package:niramaya_shared/osrm_service.dart';
import 'package:niramaya_shared/voice_navigation_service.dart';
import '../core/theme.dart';
import '../widgets/intake_panel.dart';

class DriverMapScreen extends ConsumerStatefulWidget {
  final String dispatchId;

  const DriverMapScreen({super.key, required this.dispatchId});

  @override
  ConsumerState<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends ConsumerState<DriverMapScreen> {
  late final MapController _mapController;
  StreamSubscription<Position>? _gpsSub;
  
  LatLng? _currentPos;
  double _heading = 0;
  
  List<LatLng> _activeRoute = [];
  double _distanceRemaining = 0;
  double _etaSeconds = 0;
  
  bool _isAutoTracking = true;
  Timer? _routeDebounce;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initGps();
  }

  void _initGps() async {
    final perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
       _gpsSub = Geolocator.getPositionStream(
         locationSettings: const LocationSettings(
           accuracy: LocationAccuracy.bestForNavigation,
         )
       ).listen((Position pos) {
          if (!mounted) return;
          final newLoc = LatLng(pos.latitude, pos.longitude);
          
          setState(() {
            _currentPos = newLoc;
            if (pos.heading >= 0) _heading = pos.heading;
          });

          if (_isAutoTracking) {
             _mapController.move(newLoc, 16.5);
             // flutter_map v6 supports map rotation via controller
             _mapController.rotate(_heading);
          }
          
          ref.read(voiceNavigationProvider).processLocation(newLoc);
       });
    }
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _routeDebounce?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  void _fetchRouteIfNeeded(DispatchUpdate dispatch, LatLng? targetPos) {
    if (_currentPos == null || targetPos == null || dispatch.status == 'completed') return;
    
    // Simple throttle to avoid spamming OSRM
    if (_routeDebounce?.isActive ?? false) return;
    
    _routeDebounce = Timer(const Duration(seconds: 4), () async {
      final osrm = ref.read(osrmServiceProvider);
      final r = await osrm.getRoute(_currentPos!, targetPos);
      
      if (r != null && mounted) {
        setState(() {
          _activeRoute = r.polyline;
          _distanceRemaining = r.distanceTotal;
          _etaSeconds = r.durationTotal;
        });

        ref.read(voiceNavigationProvider).updateRouteSteps(r.steps);

        // Emit arrival announcements if close enough
        if (r.distanceTotal < 50) {
           if (['assigned', 'en_route_pickup'].contains(dispatch.status)) {
              if (dispatch.status != 'arrived_pickup') {
                 // Trigger arrived
                 _updateDispatchStatus('arrived_pickup');
                 ref.read(voiceNavigationProvider).announcePatientArrival(dispatch.patientId);
              }
           } else if (dispatch.status == 'en_route_hospital') {
              // Trigger hospital arrival
              ref.read(voiceNavigationProvider).announceHospitalArrival(
                dispatch.hospitalName ?? 'Hospital', 0, 0 // Real counts go here
              );
           }
        }
      }
    });
  }

  Future<void> _updateDispatchStatus(String status) async {
    try {
      final dio = Dio();
      await dio.patch(
        'https://api.niramaya-net.in/dispatch/${widget.dispatchId}/status',
        data: {'status': status}
      );
    } catch(e) {
      debugPrint('Status update failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dispatchStream = ref.watch(realTimeServiceProvider).dispatchStream(widget.dispatchId);

    return Scaffold(
      body: StreamBuilder<DispatchUpdate>(
        stream: dispatchStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final dispatch = snapshot.data!;
          
          LatLng? targetPos;
          Color routeColor = AppColors.emergencyRed; // default pickup Phase
          
          if (['assigned', 'en_route_pickup', 'arrived_pickup'].contains(dispatch.status)) {
             targetPos = (dispatch.patientLat != null) ? LatLng(dispatch.patientLat!, dispatch.patientLng!) : null;
          } else if (dispatch.status == 'en_route_hospital') {
             targetPos = (dispatch.hospitalLat != null) ? LatLng(dispatch.hospitalLat!, dispatch.hospitalLng!) : null;
             routeColor = AppColors.hospitalGreen; // Dropoff Phase
          }

          _fetchRouteIfNeeded(dispatch, targetPos);

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentPos ?? const LatLng(28.6139, 77.2090),
                  initialZoom: 16.5,
                  onPositionChanged: (pos, hasGesture) {
                    if (hasGesture) setState(() => _isAutoTracking = false);
                  }
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.niramaya.driver',
                  ),
                  PolylineLayer(
                    polylines: [
                      if (_activeRoute.isNotEmpty)
                        Polyline(points: _activeRoute, color: routeColor, strokeWidth: 5.0),
                    ]
                  ),
                  MarkerLayer(
                    markers: _buildMarkers(dispatch, targetPos),
                  )
                ],
              ),
              
              // Top Overlay Card for Distance & ETA
              if (_distanceRemaining > 0 && targetPos != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16, right: 16,
                  child: _buildNavigationOverlay(),
                ),
              
              // Recenter Button
              if (!_isAutoTracking)
                Positioned(
                  bottom: 250, right: 16,
                  child: FloatingActionButton(
                    backgroundColor: Colors.white,
                    child: const Icon(Icons.my_location, color: AppColors.driverBlue),
                    onPressed: () {
                       setState(() => _isAutoTracking = true);
                       if (_currentPos != null) {
                          _mapController.move(_currentPos!, 16.5);
                          _mapController.rotate(_heading);
                       }
                    },
                  )
                ),

              // Intake Panel / Action Bottom Sheet
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: IntakePanel(
                   dispatch: dispatch,
                   onConfirmPickup: () => _updateDispatchStatus('en_route_hospital'),
                   onConfirmDropoff: () => _updateDispatchStatus('completed'),
                )
              )
            ],
          );
        }
      ),
    );
  }

  List<Marker> _buildMarkers(DispatchUpdate dispatch, LatLng? targetPos) {
    final markers = <Marker>[];
    
    // Target Marker
    if (targetPos != null) {
      if (dispatch.status == 'en_route_hospital') {
        markers.add(Marker(
           point: targetPos, width: 40, height: 40,
           child: const Icon(Icons.location_city, color: AppColors.hospitalGreen, size: 40),
        ));
      } else {
        markers.add(Marker(
           point: targetPos, width: 40, height: 40,
           child: const Icon(Icons.person_pin_circle, color: AppColors.emergencyRed, size: 40),
        ));
      }
    }

    // Driver Marker
    if (_currentPos != null) {
        markers.add(Marker(
          point: _currentPos!,
          width: 50, height: 50,
          child: Transform.rotate(
            angle: _heading * (math.pi / 180),
            child: const Icon(Icons.navigation, color: AppColors.driverBlue, size: 48),
          )
        ));
    }
    
    return markers;
  }

  Widget _buildNavigationOverlay() {
    return Container(
       padding: const EdgeInsets.all(16),
       decoration: BoxDecoration(
         color: AppColors.surfaceDark.withValues(alpha: 0.92),
         borderRadius: BorderRadius.circular(12),
       ),
       child: Row(
         mainAxisAlignment: MainAxisAlignment.spaceBetween,
         children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text('${(_distanceRemaining/1000).toStringAsFixed(1)} km', 
                      style: const TextStyle(color: AppColors.textOnDark, fontSize: 24, fontWeight: FontWeight.bold)),
                 const Text('Distance', style: TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                 Text('${_etaSeconds ~/ 60} min', 
                      style: const TextStyle(color: AppColors.textOnDark, fontSize: 24, fontWeight: FontWeight.bold)),
                 const Text('ETA', style: TextStyle(color: Colors.white54, fontSize: 13)),
              ],
            )
         ],
       )
    );
  }
}
