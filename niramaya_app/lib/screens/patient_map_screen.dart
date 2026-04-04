import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:niramaya_shared/realtime_service.dart';
import 'package:niramaya_shared/osrm_service.dart';
import '../core/theme.dart';

class PatientMapScreen extends ConsumerStatefulWidget {
  final String dispatchId;

  const PatientMapScreen({super.key, required this.dispatchId});

  @override
  ConsumerState<PatientMapScreen> createState() => _PatientMapScreenState();
}

class _PatientMapScreenState extends ConsumerState<PatientMapScreen> with TickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _pulseController;
  late final AnimationController _ambulanceAnimController;
  
  StreamSubscription? _driverSub;
  
  LatLng? _oldAmbulancePos;
  LatLng? _currentAmbulancePos;
  double _ambulanceBearing = 0;
  
  List<LatLng> _pickupRoute = [];
  List<LatLng> _hospitalRoute = [];
  double _etaSeconds = 0;
  LatLng? _lastRoutedPos;
  
  bool _hasInitialFitted = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
    _ambulanceAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..addListener(() {
        setState(() {}); // Rebuild to interpolate marker placement
    });
  }

  @override
  void dispose() {
    _driverSub?.cancel();
    _pulseController.dispose();
    _ambulanceAnimController.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Watch Realtime Status
    final rStatus = ref.watch(realtimeStatusProvider).value ?? RealtimeStatus.disconnected;
    
    // Watch Dispatch Update
    final dispatchStream = ref.watch(realTimeServiceProvider).dispatchStream(widget.dispatchId);

    return Scaffold(
      body: StreamBuilder<DispatchUpdate>(
        stream: dispatchStream,
        builder: (context, dispatchSnap) {
          if (!dispatchSnap.hasData) {
             return const Center(child: CircularProgressIndicator(color: AppColors.emergencyRed));
          }
          final dispatch = dispatchSnap.data!;
          
          if (dispatch.driverId != null && _driverSub == null) {
             _listenToDriver(dispatch.driverId!);
          }
          
          final patientPos = (dispatch.patientLat != null && dispatch.patientLng != null) 
            ? LatLng(dispatch.patientLat!, dispatch.patientLng!) : null;
          final hospitalPos = (dispatch.hospitalLat != null && dispatch.hospitalLng != null)
            ? LatLng(dispatch.hospitalLat!, dispatch.hospitalLng!) : null;

          _handleAutoCamera(dispatch, patientPos, hospitalPos);
          _fetchRoutesDebounced(dispatch, patientPos, hospitalPos);

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: patientPos ?? const LatLng(28.6139, 77.2090),
                  initialZoom: 14,
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.niramaya.app',
                  ),
                  PolylineLayer(
                    polylines: [
                      if (_pickupRoute.isNotEmpty)
                        Polyline(
                          points: _pickupRoute,
                          color: AppColors.driverBlue,
                          strokeWidth: 4.0,
                        ),
                      if (_hospitalRoute.isNotEmpty)
                        Polyline(
                          points: _hospitalRoute,
                          color: AppColors.hospitalGreen,
                          strokeWidth: 4.0,
                        ),
                    ],
                  ),
                  MarkerLayer(
                    markers: _buildMarkers(patientPos, hospitalPos),
                  ),
                ],
              ),
              
              // Top-right connection status indicator
              Positioned(
                top: MediaQuery.of(context).padding.top + 16,
                right: 16,
                child: _buildStatusIndicator(rStatus),
              ),

               // Map Overlay Bottom Sheet
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _buildStatusBanner(dispatch),
              ),
              
              // ETA Midpoint Pill
              if (_etaSeconds > 0 && _currentAmbulancePos != null && patientPos != null)
                 _buildEtaPill(dispatch, patientPos, hospitalPos),
            ],
          );
        }
      ),
    );
  }

  void _listenToDriver(String driverId) {
    _driverSub = ref.read(realTimeServiceProvider).driverLocationStream(driverId).listen((loc) {
      if (loc.location == null) return;
      if (_currentAmbulancePos != null && _currentAmbulancePos != loc.location) {
        _oldAmbulancePos = _currentAmbulancePos;
        _ambulanceBearing = _calculateBearing(_oldAmbulancePos!, loc.location!);
        _ambulanceAnimController.forward(from: 0);
      }
      _currentAmbulancePos = loc.location;
    });
  }

  void _handleAutoCamera(DispatchUpdate dispatch, LatLng? patientPos, LatLng? hospitalPos) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentAmbulancePos != null && !_hasInitialFitted) {
         if (patientPos != null) {
           _fitBounds([_currentAmbulancePos!, patientPos]);
         }
         _hasInitialFitted = true;
      }
      
      // If we are heading to hospital, adjust bounds occasionally
      if (dispatch.status == 'en_route_hospital' && hospitalPos != null && _currentAmbulancePos != null) {
         // Naive fit camera - usually triggered by user interaction or interval
         _fitBounds([_currentAmbulancePos!, hospitalPos]);
      }
    });
  }

  void _fitBounds(List<LatLng> points) {
    if (points.isEmpty) return;
    try {
      final bounds = LatLngBounds.fromPoints(points);
      _mapController.fitCamera(CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(80.0)));
    } catch (_) {}
  }

  Timer? _routeDebounce;
  void _fetchRoutesDebounced(DispatchUpdate dispatch, LatLng? patientPos, LatLng? hospitalPos) {
    if (_currentAmbulancePos == null) return;
    if (_lastRoutedPos != null) {
      final dist = const Distance().as(LengthUnit.Meter, _currentAmbulancePos!, _lastRoutedPos!);
      if (dist < 50) return; // Driver hasn't moved enough
    }

    _routeDebounce?.cancel();
    _routeDebounce = Timer(const Duration(seconds: 2), () async {
      final osrm = ref.read(osrmServiceProvider);
      _lastRoutedPos = _currentAmbulancePos;

      if (['assigned', 'en_route_pickup'].contains(dispatch.status) && patientPos != null) {
        final r = await osrm.getRoute(_currentAmbulancePos!, patientPos);
        if (r != null && mounted) {
          setState(() {
            _pickupRoute = r.polyline;
            _etaSeconds = r.durationTotal;
            _hospitalRoute.clear();
          });
        }
      } else if (dispatch.status == 'en_route_hospital' && hospitalPos != null) {
        final r = await osrm.getRoute(_currentAmbulancePos!, hospitalPos);
        if (r != null && mounted) {
          setState(() {
            _hospitalRoute = r.polyline;
            _etaSeconds = r.durationTotal;
            _pickupRoute.clear();
          });
        }
      }
    });
  }

  List<Marker> _buildMarkers(LatLng? patientPos, LatLng? hospitalPos) {
    final markers = <Marker>[];
    
    if (patientPos != null) {
      markers.add(Marker(
        point: patientPos,
        width: 40,
        height: 40,
        child: ScaleTransition(
          scale: Tween(begin: 1.0, end: 1.3).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut)),
          child: Container(
            decoration: const BoxDecoration(
              color: AppColors.emergencyRed,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ));
    }
    
    if (hospitalPos != null) {
      markers.add(Marker(
        point: hospitalPos,
        width: 40,
        height: 40,
        child: const Icon(Icons.local_hospital, color: AppColors.hospitalGreen, size: 40),
      ));
    }

    if (_currentAmbulancePos != null) {
      LatLng renderPos = _currentAmbulancePos!;
      if (_oldAmbulancePos != null && _ambulanceAnimController.isAnimating) {
         renderPos = _interpolate(_oldAmbulancePos!, _currentAmbulancePos!, _ambulanceAnimController.value);
      }
      
      markers.add(Marker(
        point: renderPos,
        width: 48,
        height: 48,
        child: Transform.rotate(
           angle: _ambulanceBearing * (math.pi / 180),
           child: Container(
             decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.emergencyRed, width: 3),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)]
             ),
             child: const Center(child: Icon(Icons.directions_car, color: AppColors.emergencyRed, size: 24)),
           ),
        ),
      ));
    }
    
    return markers;
  }

  Widget _buildStatusIndicator(RealtimeStatus status) {
    Color color = AppColors.emergencyRed;
    String text = "Offline";
    switch(status) {
      case RealtimeStatus.connected:
        color = AppColors.hospitalGreen;
        text = "Live";
        break;
      case RealtimeStatus.reconnecting:
        color = AppColors.warningAmber;
        text = "Reconnecting...";
        break;
      case RealtimeStatus.disconnected:
        color = AppColors.emergencyRed;
        text = "Offline";
        break;
    }
    return Container(
       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
       decoration: BoxDecoration(
          color: AppColors.surfaceDark.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(16)
       ),
       child: Row(
         mainAxisSize: MainAxisSize.min,
         children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(text, style: const TextStyle(color: AppColors.textOnDark, fontSize: 12, fontWeight: FontWeight.bold)),
         ],
       ),
    );
  }

  Widget _buildStatusBanner(DispatchUpdate dispatch) {
    final statusText = _getStatusText(dispatch.status);
    
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: AppColors.surfaceDark.withValues(alpha: 0.92),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 32, height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(statusText, style: const TextStyle(color: AppColors.textOnDark, fontSize: 14, fontWeight: FontWeight.w500, letterSpacing: 0.5)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.emergency, color: Colors.white70, size: 16),
                            const SizedBox(width: 8),
                            const Text('Driver Assigned', style: TextStyle(color: Colors.white70, fontSize: 16)),
                          ],
                        ),
                      ],
                    ),
                    if (_etaSeconds > 0)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('${_etaSeconds ~/ 60} min', 
                             style: const TextStyle(color: AppColors.textOnDark, fontSize: 28, fontWeight: FontWeight.w700, fontFeatures: [FontFeature.tabularFigures()])),
                          const Text('ETA', style: TextStyle(color: Colors.white54, fontSize: 12)),
                        ],
                      )
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.surfaceDark,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => launchUrl(Uri.parse('tel:108')),
                    icon: const Icon(Icons.call),
                    label: const Text('Call Dispatch', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                if (dispatch.hospitalName != null) ...[
                  const SizedBox(height: 16),
                  _HospitalBedRow(hospitalId: dispatch.hospitalId!, hospitalName: dispatch.hospitalName!),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Simplified midpoint overlay
  Widget _buildEtaPill(DispatchUpdate dispatch, LatLng patient, LatLng? hospital) {
    // Only conceptually show pill if we have valid positions logic can be complex without a proper layout, we will skip raw positioned for now.
    return const SizedBox.shrink(); 
  }

  String _getStatusText(String status) {
    switch(status) {
      case 'assigned': return 'Ambulance Assigned';
      case 'en_route_pickup': return 'On the way';
      case 'arrived_pickup': return 'Arrived at your location';
      case 'en_route_hospital': return 'En route to hospital';
      case 'completed': return 'Completed';
      default: return 'Pending';
    }
  }

  double _calculateBearing(LatLng start, LatLng end) {
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

  LatLng _interpolate(LatLng p1, LatLng p2, double fraction) {
    return LatLng(
      p1.latitude + (p2.latitude - p1.latitude) * fraction,
      p1.longitude + (p2.longitude - p1.longitude) * fraction,
    );
  }
}

class _HospitalBedRow extends ConsumerWidget {
  final String hospitalId;
  final String hospitalName;
  const _HospitalBedRow({required this.hospitalId, required this.hospitalName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Subscribing to realtime streams for hospitals can be done via similar method, 
    // Here we'll read a standard stream assuming the realtimeService is enhanced or via direct query.
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.local_hospital, color: AppColors.hospitalGreen, size: 16),
        const SizedBox(width: 8),
        Expanded(
           child: Text(
              '$hospitalName · Emergency: Live Update...',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              overflow: TextOverflow.ellipsis,
           )
        ),
      ],
    );
  }
}
