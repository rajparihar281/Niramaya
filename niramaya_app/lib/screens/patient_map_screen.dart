import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibration/vibration.dart';

import 'package:niramaya_shared/realtime_service.dart';
import 'package:niramaya_shared/osrm_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/theme.dart';

class PatientMapScreen extends ConsumerStatefulWidget {
  final String dispatchId;
  const PatientMapScreen({super.key, required this.dispatchId});

  @override
  ConsumerState<PatientMapScreen> createState() => _PatientMapScreenState();
}

class _PatientMapScreenState extends ConsumerState<PatientMapScreen>
    with TickerProviderStateMixin {
  late final MapController _mapController;
  late final AnimationController _pulseCtrl;
  late final AnimationController _ambulanceAnimCtrl;

  StreamSubscription? _driverSub;
  StreamSubscription? _locationSub;

  LatLng? _oldAmbulancePos;
  LatLng? _ambulancePos;
  LatLng? _userLocation;
  double _ambulanceBearing = 0;

  List<LatLng> _route = [];
  double _etaSeconds = 0;
  double _distanceMeters = 0;
  LatLng? _lastRoutedPos;

  bool _hasInitialFit = false;
  bool _isSatellite = false;

  // Track previous status to detect transitions for vibration
  String _lastStatus = '';

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _ambulanceAnimCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..addListener(() => setState(() {}));

    _initLocation();
  }

  Future<void> _initLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
      _locationSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).listen((p) {
        if (mounted) setState(() => _userLocation = LatLng(p.latitude, p.longitude));
      });
    }
  }

  @override
  void dispose() {
    _driverSub?.cancel();
    _locationSub?.cancel();
    _pulseCtrl.dispose();
    _ambulanceAnimCtrl.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _listenToDriver(String driverId) {
    _driverSub?.cancel();
    _driverSub = ref.read(realTimeServiceProvider).driverLocationStream(driverId).listen((loc) {
      if (loc.location == null || !mounted) return;
      if (_ambulancePos != null && _ambulancePos != loc.location) {
        _oldAmbulancePos = _ambulancePos;
        _ambulanceBearing = _bearing(_oldAmbulancePos!, loc.location!);
        _ambulanceAnimCtrl.forward(from: 0);
      }
      setState(() => _ambulancePos = loc.location);
      // Once ambulance GPS is known, switch to live ambulance-based routing
      // (overrides the patient-based route with the real driving path)
    });
  }

  Timer? _routeTimer;

  // Fetch the patient→target OSRM route.
  // Uses patientPos as origin (not ambulance) so the route is always visible
  // regardless of whether the driver has broadcast a GPS fix yet.
  void _fetchPatientRoute(LatLng? patientPos, LatLng? hospitalPos, bool toHospital, {bool force = false}) {
    final from = patientPos;
    final to = toHospital ? hospitalPos : patientPos;
    if (from == null || to == null || from == to) return;
    if (!force && _route.isNotEmpty) return;

    _routeTimer?.cancel();
    _routeTimer = Timer(const Duration(milliseconds: 500), () async {
      final r = await ref.read(osrmServiceProvider).getRoute(from, to);
      if (r != null && mounted) {
        setState(() {
          _route = r.polyline;
          _etaSeconds = r.durationTotal;
          _distanceMeters = r.distanceTotal;
        });
        if (!_hasInitialFit) {
          _fitBounds([from, to]);
          _hasInitialFit = true;
        }
      }
    });
  }

  // Keep the ambulance-based route fetch for live tracking updates
  void _fetchAmbulanceRoute(DispatchUpdate dispatch, LatLng? patientPos, LatLng? hospitalPos, {bool force = false}) {
    if (_ambulancePos == null) return;
    if (!force && _lastRoutedPos != null) {
      final d = const Distance().as(LengthUnit.Meter, _ambulancePos!, _lastRoutedPos!);
      if (d < 30) return;
    }
    _routeTimer?.cancel();
    _routeTimer = Timer(const Duration(seconds: 1), () async {
      final osrm = ref.read(osrmServiceProvider);
      _lastRoutedPos = _ambulancePos;

      final toHospital = ['arrived', 'picked_up', 'en_route_hospital']
          .contains(dispatch.status);
      final target = !toHospital ? patientPos : hospitalPos;
      if (target == null) return;

      final r = await osrm.getRoute(_ambulancePos!, target);
      if (r != null && mounted) {
        setState(() {
          _route = r.polyline;
          _etaSeconds = r.durationTotal;
          _distanceMeters = r.distanceTotal;
        });
        if (!_hasInitialFit) {
          _fitBounds([_ambulancePos!, target]);
          _hasInitialFit = true;
        }
      }
    });
  }

  void _handleStatusChange(String newStatus, DispatchUpdate dispatch, LatLng? patientPos, LatLng? hospitalPos) {
    if (newStatus == _lastStatus) return;
    _lastStatus = newStatus;

    if (newStatus == 'assigned' || newStatus == 'en_route_pickup') {
      _vibrate([0, 200, 100, 200]);
      _route = [];
      _fetchPatientRoute(patientPos, hospitalPos, false, force: true);
    } else if (newStatus == 'arrived') {
      _vibrate([0, 400, 100, 400]);
      _route = [];
      _lastRoutedPos = null;
      _fetchPatientRoute(patientPos, hospitalPos, true, force: true);
    } else if (newStatus == 'picked_up' || newStatus == 'en_route_hospital') {
      _vibrate([0, 300, 100, 300]);
      _route = [];
      _lastRoutedPos = null;
      _fetchPatientRoute(patientPos, hospitalPos, true, force: true);
    }
  }

  Future<void> _vibrate(List<int> pattern) async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: pattern);
    }
  }

  void _fitBounds(List<LatLng> pts) {
    if (pts.length < 2) return;
    try {
      final bounds = LatLngBounds.fromPoints(pts);
      _mapController.fitCamera(
        CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(72)),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final rStatus = ref.watch(realtimeStatusProvider).value ?? RealtimeStatus.disconnected;
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

          // Start listening to driver
          if (dispatch.driverId != null && _driverSub == null) {
            _listenToDriver(dispatch.driverId!);
          }

          final patientPos = (dispatch.patientLat != null && dispatch.patientLng != null)
              ? LatLng(dispatch.patientLat!, dispatch.patientLng!)
              : null;
          final hospitalPos = (dispatch.hospitalLat != null && dispatch.hospitalLng != null)
              ? LatLng(dispatch.hospitalLat!, dispatch.hospitalLng!)
              : null;

          // Handle status transitions
          _handleStatusChange(dispatch.status, dispatch, patientPos, hospitalPos);

          // Route phase — declared here so postFrameCallback and polylines share it
          final toHospital = ['arrived', 'picked_up', 'en_route_hospital']
              .contains(dispatch.status);
          final routeColor = toHospital ? AppColors.hospitalGreen : AppColors.primary;

          // Always fetch patient→hospital route immediately on first load
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!_hasInitialFit && patientPos != null && hospitalPos != null) {
              _fitBounds([patientPos, hospitalPos]);
            }
            _fetchPatientRoute(patientPos, hospitalPos, toHospital);
            _fetchAmbulanceRoute(dispatch, patientPos, hospitalPos);
          });

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
                    urlTemplate: _isSatellite
                        ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                        : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    userAgentPackageName: 'com.niramaya.app',
                    maxNativeZoom: 19,
                  ),
                  PolylineLayer(polylines: [
                    // OSRM route shadow
                    if (_route.isNotEmpty)
                      Polyline(
                        points: _route,
                        color: routeColor.withValues(alpha: 0.2),
                        strokeWidth: 9,
                      ),
                    // OSRM route main line
                    if (_route.isNotEmpty)
                      Polyline(
                        points: _route,
                        color: routeColor,
                        strokeWidth: 4.5,
                        borderColor: Colors.white.withValues(alpha: 0.6),
                        borderStrokeWidth: 1.5,
                      ),
                    // Straight-line fallback only while OSRM is loading
                    if (_route.isEmpty && patientPos != null && hospitalPos != null)
                      Polyline(
                        points: [patientPos, hospitalPos],
                        color: routeColor.withValues(alpha: 0.35),
                        strokeWidth: 3,
                        pattern: StrokePattern.dashed(segments: [10, 6]),
                      ),
                  ]),
                  MarkerLayer(markers: _buildMarkers(patientPos, hospitalPos, toHospital)),
                ],
              ),

              // Top-left: satellite toggle
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 12,
                child: _MapBtn(
                  icon: _isSatellite ? Icons.map_outlined : Icons.satellite_alt,
                  onTap: () => setState(() => _isSatellite = !_isSatellite),
                  tooltip: _isSatellite ? 'Map' : 'Satellite',
                ),
              ),

              // Top-right: connection status
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                right: 12,
                child: _ConnectionBadge(status: rStatus),
              ),

              // Right-side controls
              Positioned(
                right: 12,
                bottom: 220,
                child: Column(
                  children: [
                    _MapBtn(
                      icon: Icons.my_location,
                      onTap: () {
                        if (_userLocation != null) {
                          _mapController.move(_userLocation!, 16);
                        }
                      },
                      tooltip: 'My Location',
                    ),
                    const SizedBox(height: 8),
                    _MapBtn(
                      icon: Icons.add,
                      onTap: () => _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom + 1,
                      ),
                      tooltip: 'Zoom In',
                    ),
                    const SizedBox(height: 8),
                    _MapBtn(
                      icon: Icons.remove,
                      onTap: () => _mapController.move(
                        _mapController.camera.center,
                        _mapController.camera.zoom - 1,
                      ),
                      tooltip: 'Zoom Out',
                    ),
                    const SizedBox(height: 8),
                    _MapBtn(
                      icon: Icons.fit_screen,
                      onTap: () {
                        final pts = [
                          if (_ambulancePos != null) _ambulancePos!,
                          if (patientPos != null) patientPos,
                          if (hospitalPos != null && dispatch.status == 'en_route_hospital') hospitalPos,
                        ];
                        if (pts.length >= 2) _fitBounds(pts);
                      },
                      tooltip: 'Fit All',
                    ),
                  ],
                ),
              ),

              // Bottom info panel
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: _BottomPanel(
                  dispatch: dispatch,
                  etaSeconds: _etaSeconds,
                  distanceMeters: _distanceMeters,
                  dispatchId: widget.dispatchId,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Marker> _buildMarkers(LatLng? patientPos, LatLng? hospitalPos, bool toHospital) {
    final markers = <Marker>[];

    // User's live location — small blue dot
    if (_userLocation != null) {
      markers.add(Marker(
        point: _userLocation!,
        width: 20, height: 20,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.driverBlue,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
          ),
        ),
      ));
    }

    // Patient SOS pin — pulsing red, only during pickup phase
    if (!toHospital && patientPos != null) {
      markers.add(Marker(
        point: patientPos,
        width: 48, height: 48,
        child: ScaleTransition(
          scale: Tween(begin: 0.9, end: 1.15).animate(
            CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.emergencyRed,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: AppColors.emergencyRed.withValues(alpha: 0.45),
                  blurRadius: 12, spreadRadius: 3,
                ),
              ],
            ),
            child: const Icon(Icons.person_pin, color: Colors.white, size: 24),
          ),
        ),
      ));
    }

    // Hospital — always visible, rounded square green
    if (hospitalPos != null) {
      markers.add(Marker(
        point: hospitalPos,
        width: 52, height: 52,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.hospitalGreen,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: AppColors.hospitalGreen.withValues(alpha: 0.45),
                blurRadius: 12, spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.local_hospital, color: Colors.white, size: 26),
        ),
      ));
    }

    // Ambulance — animated, rotates with bearing
    if (_ambulancePos != null) {
      LatLng renderPos = _ambulancePos!;
      if (_oldAmbulancePos != null && _ambulanceAnimCtrl.isAnimating) {
        renderPos = _lerp(_oldAmbulancePos!, _ambulancePos!, _ambulanceAnimCtrl.value);
      }
      markers.add(Marker(
        point: renderPos,
        width: 52, height: 52,
        child: Transform.rotate(
          angle: _ambulanceBearing * math.pi / 180,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.driverBlue,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.driverBlue.withValues(alpha: 0.4),
                  blurRadius: 12, spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.airport_shuttle, color: Colors.white, size: 26),
          ),
        ),
      ));
    }

    return markers;
  }

  double _bearing(LatLng a, LatLng b) {
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final y = math.sin(dLon) * math.cos(lat2);
    final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  LatLng _lerp(LatLng a, LatLng b, double t) => LatLng(
    a.latitude + (b.latitude - a.latitude) * t,
    a.longitude + (b.longitude - a.longitude) * t,
  );
}

// ── Map control button ────────────────────────────────────────────────────────
class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String tooltip;

  const _MapBtn({required this.icon, required this.onTap, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
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
      ),
    );
  }
}

// ── Connection badge ──────────────────────────────────────────────────────────
class _ConnectionBadge extends StatelessWidget {
  final RealtimeStatus status;
  const _ConnectionBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status == RealtimeStatus.connected
        ? AppColors.hospitalGreen
        : status == RealtimeStatus.reconnecting
            ? AppColors.warningAmber
            : AppColors.emergencyRed;
    final label = status == RealtimeStatus.connected
        ? 'Live'
        : status == RealtimeStatus.reconnecting
            ? 'Reconnecting'
            : 'Offline';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

// ── Bottom info panel ─────────────────────────────────────────────────────────
class _BottomPanel extends StatelessWidget {
  final DispatchUpdate dispatch;
  final double etaSeconds;
  final double distanceMeters;
  final String dispatchId;

  const _BottomPanel({
    required this.dispatch,
    required this.etaSeconds,
    required this.distanceMeters,
    required this.dispatchId,
  });

  Future<void> _cancel(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Dispatch?'),
        content: const Text('This will cancel the ambulance dispatch and notify the driver.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.emergencyRed),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await Supabase.instance.client
          .from('dispatches')
          .update({'status': 'cancelled'})
          .eq('id', dispatchId);
    } catch (e) {
      debugPrint('[PatientMap] cancel failed: $e');
    }
    if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final statusLabel = _statusLabel(dispatch.status);
    final statusColor = _statusColor(dispatch.status);
    final etaMin = etaSeconds > 0 ? (etaSeconds / 60).ceil() : null;
    final distKm = distanceMeters > 0
        ? distanceMeters >= 1000
            ? '${(distanceMeters / 1000).toStringAsFixed(1)} km'
            : '${distanceMeters.toInt()} m'
        : null;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag handle
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 14),

              // Status row
              Row(
                children: [
                  Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ETA + Distance tiles
              if (etaMin != null || distKm != null)
                Row(
                  children: [
                    if (etaMin != null)
                      Expanded(
                        child: _InfoTile(
                          icon: Icons.timer_outlined,
                          value: '$etaMin min',
                          label: 'ETA',
                          color: AppColors.primary,
                        ),
                      ),
                    if (etaMin != null && distKm != null) const SizedBox(width: 10),
                    if (distKm != null)
                      Expanded(
                        child: _InfoTile(
                          icon: Icons.straighten,
                          value: distKm,
                          label: 'Distance',
                          color: AppColors.driverBlue,
                        ),
                      ),
                  ],
                ),

              if (dispatch.hospitalName != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.local_hospital, color: AppColors.hospitalGreen, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        dispatch.hospitalName!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse('tel:108')),
                      icon: const Icon(Icons.call, size: 18),
                      label: const Text('Call · 108'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.emergencyRed,
                        side: const BorderSide(color: AppColors.emergencyRed),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _cancel(context),
                      icon: const Icon(Icons.cancel_outlined, size: 18),
                      label: const Text('Cancel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textSecondary,
                        side: const BorderSide(color: AppColors.border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(String s) {
    switch (s) {
      case 'assigned':          return 'Ambulance dispatched — on the way';
      case 'en_route_pickup':   return 'Ambulance is heading to you';
      case 'arrived_pickup':    return '🚑 Ambulance has arrived!';
      case 'arrived':           return '🚑 Ambulance has arrived at your location!';
      case 'picked_up':         return '🏥 En route to hospital with patient';
      case 'en_route_hospital': return '🏥 En route to hospital';
      case 'completed':         return '✅ Dispatch completed';
      case 'cancelled':         return 'Dispatch was cancelled';
      default:                  return 'Locating ambulance…';
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'assigned':
      case 'en_route_pickup':   return AppColors.primary;
      case 'arrived_pickup':
      case 'arrived':           return AppColors.hospitalGreen;
      case 'picked_up':
      case 'en_route_hospital': return AppColors.warningAmber;
      case 'completed':         return AppColors.hospitalGreen;
      default:                  return AppColors.textMuted;
    }
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _InfoTile({required this.icon, required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }
}
