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

  List<LatLng> _route = [];
  double _distanceMeters = 0;
  double _etaSeconds = 0;

  bool _isAutoTracking = true;
  bool _isSatellite = false;
  Timer? _routeTimer;
  // Set to true after pickup confirmed — locks route to hospital
  bool _pickupConfirmed = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initGps();
  }

  void _initGps() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm != LocationPermission.whileInUse && perm != LocationPermission.always) return;

    _gpsSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen((pos) {
      if (!mounted) return;
      final loc = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _currentPos = loc;
        if (pos.heading >= 0) _heading = pos.heading;
      });
      if (_isAutoTracking) {
        _mapController.move(loc, 16.5);
        _mapController.rotate(-_heading); // north-up with heading compensation
      }
      ref.read(voiceNavigationProvider).processLocation(loc);
    });
  }

  @override
  void dispose() {
    _gpsSub?.cancel();
    _routeTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  /// Called when driver taps "Patient Secured · Navigate to Hospital".
  /// Fetches the OSRM route to hospital, shows it on map, then updates status.
  Future<void> _confirmPickupAndRouteToHospital(DispatchUpdate dispatch) async {
    if (_currentPos == null) return;
    final hospitalPos = dispatch.hospitalLat != null
        ? LatLng(dispatch.hospitalLat!, dispatch.hospitalLng!)
        : null;
    if (hospitalPos == null) {
      await _updateStatus('en_route_hospital');
      return;
    }
    // Fetch hospital route immediately
    final r = await ref.read(osrmServiceProvider).getRoute(_currentPos!, hospitalPos);
    if (r != null && mounted) {
      setState(() {
        _route = r.polyline;
        _distanceMeters = r.distanceTotal;
        _etaSeconds = r.durationTotal;
        _pickupConfirmed = true;
      });
      ref.read(voiceNavigationProvider).updateRouteSteps(r.steps);
      // Fit map to show driver + hospital
      try {
        _mapController.fitCamera(
          CameraFit.bounds(
            bounds: LatLngBounds.fromPoints([_currentPos!, hospitalPos]),
            padding: const EdgeInsets.all(80),
          ),
        );
      } catch (_) {}
    }
    await _updateStatus('en_route_hospital');
  }

  void _fetchRoute(DispatchUpdate dispatch, LatLng? target) {
    if (_currentPos == null || target == null || dispatch.status == 'completed') return;
    if (_routeTimer?.isActive ?? false) return;

    _routeTimer = Timer(const Duration(seconds: 3), () async {
      final r = await ref.read(osrmServiceProvider).getRoute(_currentPos!, target);
      if (r != null && mounted) {
        setState(() {
          _route = r.polyline;
          _distanceMeters = r.distanceTotal;
          _etaSeconds = r.durationTotal;
        });
        ref.read(voiceNavigationProvider).updateRouteSteps(r.steps);

        if (r.distanceTotal < 50) {
          if (['assigned', 'en_route_pickup'].contains(dispatch.status)) {
            _updateStatus('arrived_pickup');
            ref.read(voiceNavigationProvider).announcePatientArrival(dispatch.patientId);
          } else if (dispatch.status == 'en_route_hospital') {
            ref.read(voiceNavigationProvider).announceHospitalArrival(
              dispatch.hospitalName ?? 'Hospital', 0, 0,
            );
          }
        }
      }
    });
  }

  Future<void> _updateStatus(String status) async {
    try {
      await Dio().patch(
        'https://api.niramaya-net.in/dispatch/${widget.dispatchId}/status',
        data: {'status': status},
      );
    } catch (e) {
      debugPrint('Status update failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final dispatchStream = ref.watch(realTimeServiceProvider).dispatchStream(widget.dispatchId);

    return Scaffold(
      backgroundColor: Colors.white,
      body: StreamBuilder<DispatchUpdate>(
        stream: dispatchStream,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }
          final dispatch = snap.data!;

          LatLng? target;
          Color routeColor = AppColors.primary;

          if (['assigned', 'en_route_pickup', 'arrived_pickup'].contains(dispatch.status) && !_pickupConfirmed) {
            if (dispatch.patientLat != null) {
              target = LatLng(dispatch.patientLat!, dispatch.patientLng!);
            }
          } else if (dispatch.status == 'en_route_hospital') {
            if (dispatch.hospitalLat != null) {
              target = LatLng(dispatch.hospitalLat!, dispatch.hospitalLng!);
              routeColor = AppColors.hospitalGreen;
            }
          }

          _fetchRoute(dispatch, target);

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _currentPos ?? const LatLng(28.6139, 77.2090),
                  initialZoom: 16.5,
                  onPositionChanged: (_, hasGesture) {
                    if (hasGesture) setState(() => _isAutoTracking = false);
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: _isSatellite
                        ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.niramaya.driver',
                    maxNativeZoom: 19,
                  ),
                  if (_route.isNotEmpty)
                    PolylineLayer(
                      polylines: [
                        Polyline(points: _route, color: routeColor.withValues(alpha: 0.2), strokeWidth: 9),
                        Polyline(points: _route, color: routeColor, strokeWidth: 5),
                      ],
                    ),
                  MarkerLayer(markers: _buildMarkers(dispatch, target)),
                ],
              ),

              // Navigation overlay (top)
              if (_distanceMeters > 0 && target != null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 12,
                  left: 12, right: 12,
                  child: _NavOverlay(
                    distanceMeters: _distanceMeters,
                    etaSeconds: _etaSeconds,
                    phase: dispatch.status == 'en_route_hospital' ? 'To Hospital' : 'To Patient',
                    phaseColor: routeColor,
                  ),
                ),

              // Satellite toggle (bottom-left of nav bar area)
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 12,
                child: dispatch.status == 'en_route_hospital' || _distanceMeters == 0
                    ? _MapBtn(
                        icon: _isSatellite ? Icons.map_outlined : Icons.satellite_alt,
                        onTap: () => setState(() => _isSatellite = !_isSatellite),
                      )
                    : const SizedBox.shrink(),
              ),

              // Right controls
              Positioned(
                right: 12,
                bottom: 260,
                child: Column(
                  children: [
                    _MapBtn(
                      icon: Icons.add,
                      onTap: () => _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom + 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _MapBtn(
                      icon: Icons.remove,
                      onTap: () => _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom - 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _MapBtn(
                      icon: _isSatellite ? Icons.map_outlined : Icons.satellite_alt,
                      onTap: () => setState(() => _isSatellite = !_isSatellite),
                    ),
                  ],
                ),
              ),

              // Recenter FAB
              if (!_isAutoTracking)
                Positioned(
                  bottom: 260, right: 12,
                  child: FloatingActionButton.small(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    elevation: 4,
                    onPressed: () {
                      setState(() => _isAutoTracking = true);
                      if (_currentPos != null) {
                        _mapController.move(_currentPos!, 16.5);
                        _mapController.rotate(-_heading);
                      }
                    },
                    child: const Icon(Icons.my_location),
                  ),
                ),

              // Intake panel
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: IntakePanel(
                  dispatch: dispatch,
                  onConfirmPickup: () => _confirmPickupAndRouteToHospital(dispatch),
                  onConfirmDropoff: () => _updateStatus('completed'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Marker> _buildMarkers(DispatchUpdate dispatch, LatLng? target) {
    final markers = <Marker>[];

    if (target != null) {
      final isHospital = dispatch.status == 'en_route_hospital';
      markers.add(Marker(
        point: target, width: 48, height: 48,
        child: Container(
          decoration: BoxDecoration(
            color: isHospital ? AppColors.hospitalGreen : AppColors.emergencyRed,
            borderRadius: BorderRadius.circular(isHospital ? 10 : 24),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
          ),
          child: Icon(
            isHospital ? Icons.local_hospital : Icons.person_pin,
            color: Colors.white, size: 24,
          ),
        ),
      ));
    }

    if (_currentPos != null) {
      markers.add(Marker(
        point: _currentPos!, width: 52, height: 52,
        child: Transform.rotate(
          angle: _heading * math.pi / 180,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.4),
                  blurRadius: 12, spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.navigation, color: Colors.white, size: 26),
          ),
        ),
      ));
    }

    return markers;
  }
}

// ── Navigation overlay card ───────────────────────────────────────────────────
class _NavOverlay extends StatelessWidget {
  final double distanceMeters;
  final double etaSeconds;
  final String phase;
  final Color phaseColor;

  const _NavOverlay({
    required this.distanceMeters,
    required this.etaSeconds,
    required this.phase,
    required this.phaseColor,
  });

  @override
  Widget build(BuildContext context) {
    final dist = distanceMeters >= 1000
        ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
        : '${distanceMeters.toInt()} m';
    final eta = '${(etaSeconds / 60).ceil()} min';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            width: 4, height: 40,
            decoration: BoxDecoration(color: phaseColor, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(phase, style: TextStyle(fontSize: 11, color: phaseColor, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(dist, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('ETA', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
              Text(eta, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: phaseColor)),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Map button ────────────────────────────────────────────────────────────────
class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _MapBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: Icon(icon, size: 20, color: AppColors.textPrimary),
      ),
    );
  }
}
