import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart';
import 'package:http/retry.dart';
import 'package:latlong2/latlong.dart';
import 'package:vibration/vibration.dart';
import 'package:niramaya_shared/realtime_service.dart';
import 'package:niramaya_shared/osrm_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../data/models/dispatch_model.dart';
import '../providers/dispatch_provider.dart';
import '../widgets/dispatch_panel.dart';

class DispatchTrackingScreen extends ConsumerStatefulWidget {
  const DispatchTrackingScreen({super.key});

  @override
  ConsumerState<DispatchTrackingScreen> createState() =>
      _DispatchTrackingScreenState();
}

class _DispatchTrackingScreenState extends ConsumerState<DispatchTrackingScreen> {
  late MapController _mapController;
  Timer? _pollTimer;
  StreamSubscription<DriverLocation>? _driverSub;
  StreamSubscription<Position>? _locationSub;

  LatLng? _userLocation;
  LatLng? _hospitalLocation;
  LatLng? _ambulanceLocation;
  DispatchModel? _dispatch;

  List<LatLng> _route = [];
  double _etaSeconds = 0;
  double _distanceMeters = 0;
  String _lastStatus = '';
  Timer? _routeTimer;

  bool _isSatellite = false;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _initUserLocation();
  }

  Future<void> _initUserLocation() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
    if (perm == LocationPermission.whileInUse || perm == LocationPermission.always) {
      final pos = await Geolocator.getCurrentPosition();
      if (mounted) setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
      _locationSub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 15),
      ).listen((p) {
        if (mounted) setState(() => _userLocation = LatLng(p.latitude, p.longitude));
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dispatch == null) _initFromArgs();
  }

  void _initFromArgs() {
    final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args == null) return;

    _dispatch = args['dispatch'] as DispatchModel?;
    final userLat = args['userLat'] as double?;
    final userLng = args['userLng'] as double?;

    if (userLat != null && userLng != null) {
      _userLocation = LatLng(userLat, userLng);
    } else if (_dispatch?.patientLat != null) {
      _userLocation = LatLng(_dispatch!.patientLat!, _dispatch!.patientLng!);
    }

    if (_dispatch?.hospitalLat != null) {
      _hospitalLocation = LatLng(_dispatch!.hospitalLat!, _dispatch!.hospitalLng!);
      _ambulanceLocation = _hospitalLocation;
    } else if (_userLocation != null) {
      _hospitalLocation = LatLng(_userLocation!.latitude + 0.018, _userLocation!.longitude + 0.015);
      _ambulanceLocation = _hospitalLocation;
    }

    final driverId = _dispatch?.driverId;
    if (driverId != null && driverId.isNotEmpty) {
      _driverSub = ref.read(realTimeServiceProvider).driverLocationStream(driverId).listen((loc) {
        if (loc.location != null && mounted) {
          setState(() => _ambulanceLocation = loc.location);
          _fetchRoute();
        }
      });
    }

    _pollTimer = Timer.periodic(AppConstants.dispatchPollInterval, (_) {
      ref.read(dispatchProvider.notifier).pollStatus();
    });
  }

  void _fetchRoute() {
    if (_ambulanceLocation == null) return;
    final currentStatus = _dispatch?.status ?? _lastStatus;
    final target = currentStatus == 'en_route_hospital' ? _hospitalLocation : _userLocation;
    if (target == null) return;
    _routeTimer?.cancel();
    _routeTimer = Timer(const Duration(seconds: 2), () async {
      final r = await ref.read(osrmServiceProvider).getRoute(_ambulanceLocation!, target);
      if (r != null && mounted) {
        setState(() {
          _route = r.polyline;
          _etaSeconds = r.durationTotal;
          _distanceMeters = r.distanceTotal;
        });
      }
    });
  }

  void _fitBounds(List<LatLng> pts) {
    if (pts.length < 2) return;
    try {
      _mapController.fitCamera(
        CameraFit.bounds(bounds: LatLngBounds.fromPoints(pts), padding: const EdgeInsets.all(72)),
      );
    } catch (_) {}
  }

  void _handleStatusChange(String newStatus) {
    if (newStatus == _lastStatus) return;
    _lastStatus = newStatus;
    if (newStatus == 'assigned' || newStatus == 'en_route_pickup') {
      _doVibrate([0, 200, 100, 200]);
    } else if (newStatus == 'arrived_pickup') {
      _doVibrate([0, 400, 100, 400]);
    }
    _fetchRoute();
  }

  Future<void> _doVibrate(List<int> pattern) async {
    if (await Vibration.hasVibrator()) Vibration.vibrate(pattern: pattern);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _driverSub?.cancel();
    _routeTimer?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }

  Future<void> _handleCancel() async {
    final dispatchId = _dispatch?.dispatchId;
    if (dispatchId != null && dispatchId.isNotEmpty) {
      try {
        // Write cancelled to Supabase — driver's realtime stream will pick this up
        await Supabase.instance.client
            .from('dispatches')
            .update({'status': 'cancelled'})
            .eq('id', dispatchId);
      } catch (e) {
        debugPrint('[Cancel] Supabase update failed: $e');
      }
    }
    ref.read(dispatchProvider.notifier).clear();
    if (mounted) Navigator.pop(context);
  }

  String _formatEta(double seconds) {
    if (seconds <= 0) return '—';
    final mins = (seconds / 60).round();
    if (mins < 1) return '< 1 min';
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }

  String _formatDist(double meters) {
    if (meters <= 0) return '—';
    if (meters < 1000) return '${meters.toInt()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    final dispatchState = ref.watch(dispatchProvider);
    final dispatch = _dispatch ?? dispatchState.dispatch;

    if (dispatch == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dispatch Tracking')),
        body: const Center(child: Text('No active dispatch')),
      );
    }

    final center = _userLocation ?? const LatLng(20.5937, 78.9629);
    final status = _dispatch?.status ?? dispatchState.status?.status ?? '';
    _handleStatusChange(status);
    final routeColor = status == 'en_route_hospital' ? AppColors.hospitalGreen : AppColors.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
              interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
            ),
            children: [
              TileLayer(
                urlTemplate: _isSatellite
                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.niramaya.app',
                maxNativeZoom: 19,
                tileProvider: NetworkTileProvider(httpClient: RetryClient(Client())),
              ),
              if (_route.isNotEmpty)
                PolylineLayer(polylines: [
                  Polyline(points: _route, color: routeColor.withValues(alpha: 0.2), strokeWidth: 9),
                  Polyline(points: _route, color: routeColor, strokeWidth: 4.5),
                ])
              else if (_ambulanceLocation != null && _userLocation != null)
                PolylineLayer(polylines: [
                  Polyline(points: [_ambulanceLocation!, _userLocation!], color: routeColor.withValues(alpha: 0.4), strokeWidth: 3),
                ]),
              MarkerLayer(markers: [
                if (_userLocation != null)
                  Marker(
                    point: _userLocation!, width: 32, height: 32,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary, shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.person, color: Colors.white, size: 16),
                    ),
                  ),
                if (_hospitalLocation != null)
                  Marker(
                    point: _hospitalLocation!, width: 44, height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.hospitalGreen,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                      ),
                      child: const Icon(Icons.local_hospital, color: Colors.white, size: 22),
                    ),
                  ),
                if (_ambulanceLocation != null)
                  Marker(
                    point: _ambulanceLocation!, width: 44, height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.local_shipping, color: Colors.white, size: 22),
                    ),
                  ),
              ]),
            ],
          ),

          // Top-left: back + satellite
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 12,
            child: Column(children: [
              _MapBtn(icon: Icons.arrow_back, onTap: () => Navigator.pop(context)),
              const SizedBox(height: 8),
              _MapBtn(
                icon: _isSatellite ? Icons.map_outlined : Icons.satellite_alt,
                onTap: () => setState(() => _isSatellite = !_isSatellite),
                tooltip: _isSatellite ? 'Map View' : 'Satellite',
              ),
            ]),
          ),

          // Top-right: ETA badge
          if (_etaSeconds > 0)
            Positioned(
              top: MediaQuery.of(context).padding.top + 10,
              right: 12,
              child: _EtaBadge(
                etaSeconds: _etaSeconds,
                distanceMeters: _distanceMeters,
                color: routeColor,
                label: 'Ambulance ETA',
              ),
            ),

          // Right-side controls
          Positioned(
            right: 12, bottom: 280,
            child: Column(children: [
              _MapBtn(
                icon: Icons.my_location,
                onTap: () { if (_userLocation != null) _mapController.move(_userLocation!, 16); },
                tooltip: 'My Location',
              ),
              const SizedBox(height: 8),
              _MapBtn(icon: Icons.add, onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom + 1)),
              const SizedBox(height: 8),
              _MapBtn(icon: Icons.remove, onTap: () => _mapController.move(_mapController.camera.center, _mapController.camera.zoom - 1)),
              const SizedBox(height: 8),
              _MapBtn(
                icon: Icons.fit_screen,
                onTap: () {
                  final pts = [
                    if (_userLocation != null) _userLocation!,
                    if (_hospitalLocation != null) _hospitalLocation!,
                    if (_ambulanceLocation != null) _ambulanceLocation!,
                  ];
                  if (pts.length >= 2) _fitBounds(pts);
                },
                tooltip: 'Fit All',
              ),
            ]),
          ),

          // Bottom panel
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              // Ambulance info card
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 12)],
                ),
                child: Row(children: [
                  Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.local_shipping, color: AppColors.primary, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(dispatch.driverName ?? 'Assigned Driver',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Row(children: [
                        const Icon(Icons.star, size: 12, color: Color(0xFFD97706)),
                        const SizedBox(width: 3),
                        Text((dispatch.driverRating ?? 5.0).toStringAsFixed(1),
                            style: const TextStyle(fontSize: 12, color: Color(0xFFD97706), fontWeight: FontWeight.w600)),
                        const SizedBox(width: 8),
                        Text(dispatch.plateNumber ?? '',
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                      ]),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(
                      _etaSeconds > 0 ? _formatEta(_etaSeconds) : dispatch.liveEta ?? _formatEta(dispatch.etaMinutes * 60),
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: routeColor),
                    ),
                    Text(
                      _distanceMeters > 0 ? _formatDist(_distanceMeters) : dispatch.liveDistance ?? dispatch.distance,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ]),
                ]),
              ),
              // Hospital info
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8)],
                ),
                child: Row(children: [
                  const Icon(Icons.local_hospital, color: AppColors.emergency, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(dispatch.hospital,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
                  if (dispatch.requiredDept != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.emergency.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(dispatch.requiredDept!.toUpperCase(),
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.emergency)),
                    ),
                ]),
              ),
              DispatchPanel(
                dispatch: dispatch,
                status: dispatchState.status,
                etaSeconds: _etaSeconds,
                distanceMeters: _distanceMeters,
                onCancel: _handleCancel,
              ),
            ]),
          ),
        ],
      ),
    );
  }
}

class _MapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  const _MapBtn({required this.icon, required this.onTap, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: Colors.white, shape: BoxShape.circle,
            boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
          ),
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
  }
}

class _EtaBadge extends StatelessWidget {
  final double etaSeconds;
  final double distanceMeters;
  final Color color;
  final String label;
  const _EtaBadge({required this.etaSeconds, required this.distanceMeters, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final mins = etaSeconds > 0 ? (etaSeconds / 60).round() : 0;
    final etaStr = mins < 1 ? '< 1 min' : mins < 60 ? '$mins min' : '${mins ~/ 60}h ${mins % 60}m';
    final distStr = distanceMeters < 1000 ? '${distanceMeters.toInt()} m' : '${(distanceMeters / 1000).toStringAsFixed(1)} km';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(12),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(label, style: TextStyle(fontSize: 9, color: color, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
        Text(etaStr, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: color)),
        Text(distStr, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
      ]),
    );
  }
}
