import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http/retry.dart';
import 'package:latlong2/latlong.dart';
import '../core/theme.dart';
import '../models/dispatch_model.dart';
import '../providers/dispatch_provider.dart';
import '../services/location_service.dart';
import '../services/tts_service.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  final MapController _mapController = MapController();
  final TtsService _ttsService = TtsService.instance;

  LatLng? _driverPos;
  StreamSubscription? _positionSub;
  bool _isSatellite = false;
  Timer? _ttsTimer;
  Timer? _osrmTimer;

  List<LatLng> _routePoints = [];
  double _routeDistKm = 0;
  int _routeEtaMin = 0;
  double _distToPatientM = double.infinity;
  bool _osrmLoading = false;

  DispatchStatus? _lastStatus;

  static const LatLng _gwaliorCenter = LatLng(26.218, 78.182);
  static const double _reachThresholdM = 50;

  @override
  void initState() {
    super.initState();
    _ttsService.init();
    _initLocation();
  }

  Future<void> _initLocation() async {
    await LocationService.instance.requestPermission();
    final pos = await LocationService.instance.getCurrentPosition();

    if (!mounted) return;
    setState(() {
      _driverPos = pos != null
          ? LatLng(pos.latitude, pos.longitude)
          : _gwaliorCenter;
    });

    // Set haversine baseline immediately so metrics show something
    _updateMetricsBaseline();

    // Then fetch OSRM route
    await _fetchRoute();
    _announcePhase();

    _positionSub = LocationService.instance.startPositionStream().listen((pos) {
      if (!mounted) return;
      final newPos = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _driverPos = newPos;
        _updateProximity(newPos);
      });
      _fetchRoute();
    });

    _osrmTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchRoute(),
    );
  }

  // Compute straight-line distance/ETA immediately as a baseline
  void _updateMetricsBaseline() {
    if (_driverPos == null) return;
    final dispatch = ref.read(dispatchProvider).activeDispatch;
    if (dispatch == null) return;

    final isPickup = dispatch.status == DispatchStatus.assigned;
    final dest = isPickup
        ? LatLng(dispatch.patientLat ?? _gwaliorCenter.latitude,
            dispatch.patientLng ?? _gwaliorCenter.longitude)
        : LatLng(dispatch.hospitalLat ?? _gwaliorCenter.latitude,
            dispatch.hospitalLng ?? _gwaliorCenter.longitude);

    final distKm = LocationService.distanceKm(_driverPos!, dest);
    setState(() {
      _routePoints = [_driverPos!, dest];
      _routeDistKm = distKm;
      _routeEtaMin = LocationService.estimateMinutes(distKm);
    });
  }

  void _updateProximity(LatLng driverPos) {
    final dispatch = ref.read(dispatchProvider).activeDispatch;
    if (dispatch?.patientLat == null) return;
    final d = Geolocator.distanceBetween(
      driverPos.latitude, driverPos.longitude,
      dispatch!.patientLat!, dispatch.patientLng!,
    );
    setState(() => _distToPatientM = d);
  }

  Future<void> _fetchRoute() async {
    if (_driverPos == null) return;
    final dispatch = ref.read(dispatchProvider).activeDispatch;
    if (dispatch == null) return;

    final isPickup = dispatch.status == DispatchStatus.assigned;
    final dest = isPickup
        ? LatLng(dispatch.patientLat ?? _gwaliorCenter.latitude,
            dispatch.patientLng ?? _gwaliorCenter.longitude)
        : LatLng(dispatch.hospitalLat ?? _gwaliorCenter.latitude,
            dispatch.hospitalLng ?? _gwaliorCenter.longitude);

    setState(() => _osrmLoading = true);

    final url = 'https://router.project-osrm.org/route/v1/driving/'
        '${_driverPos!.longitude},${_driverPos!.latitude};'
        '${dest.longitude},${dest.latitude}'
        '?overview=full&geometries=geojson';

    try {
      final res = await RetryClient(http.Client())
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final route = body['routes']?[0];
        if (route != null) {
          final coords = (route['geometry']['coordinates'] as List)
              .map((c) => LatLng(
                    (c[1] as num).toDouble(),
                    (c[0] as num).toDouble(),
                  ))
              .toList();
          final distM = (route['distance'] as num).toDouble();
          final durS = (route['duration'] as num).toDouble();

          setState(() {
            _routePoints = coords;
            _routeDistKm = distM / 1000;
            _routeEtaMin = (durS / 60).ceil();
            _osrmLoading = false;
          });
          _autoPan(dest);
          return;
        }
      }
    } catch (_) {}

    // Fallback: straight line
    if (mounted) {
      final distKm = LocationService.distanceKm(_driverPos!, dest);
      setState(() {
        _routePoints = [_driverPos!, dest];
        _routeDistKm = distKm;
        _routeEtaMin = LocationService.estimateMinutes(distKm);
        _osrmLoading = false;
      });
    }
  }

  void _autoPan(LatLng dest) {
    if (_driverPos == null) return;
    final bounds = LatLngBounds.fromPoints([_driverPos!, dest]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mapController.fitCamera(
        CameraFit.bounds(
          bounds: bounds,
          padding: const EdgeInsets.all(72),
        ),
      );
    });
  }

  void _announcePhase() {
    final dispatchState = ref.read(dispatchProvider);
    if (dispatchState.activeDispatch == null || _driverPos == null) return;
    final dispatch = dispatchState.activeDispatch!;
    final isPickup = dispatch.status == DispatchStatus.assigned;
    final dest = isPickup
        ? LatLng(dispatch.patientLat ?? _gwaliorCenter.latitude,
            dispatch.patientLng ?? _gwaliorCenter.longitude)
        : LatLng(dispatch.hospitalLat ?? _gwaliorCenter.latitude,
            dispatch.hospitalLng ?? _gwaliorCenter.longitude);
    final dist = LocationService.distanceKm(_driverPos!, dest);
    _ttsService.announcePhase(
      isPickup ? DispatchPhase.toPatient : DispatchPhase.toHospital,
      dispatchState.hospitalName ?? 'Hospital',
      dist,
    );
    _ttsTimer?.cancel();
    _ttsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_driverPos == null) return;
      final d = LocationService.distanceKm(_driverPos!, dest);
      final b = LocationService.bearingDirection(_driverPos!, dest);
      _ttsService.speak(
          'Continue for ${d.toStringAsFixed(1)} kilometers. Heading $b.');
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _ttsTimer?.cancel();
    _osrmTimer?.cancel();
    _ttsService.stop();
    _mapController.dispose();
    super.dispose();
  }

  // Human-readable triage label
  String _triageLabel(String? dept) {
    switch (dept?.toLowerCase()) {
      case 'trauma':     return '🚗 ACCIDENT';
      case 'cardiology': return '❤️ CARDIAC';
      case 'maternity':  return '🤱 MATERNITY';
      case 'emergency':  return '🚨 EMERGENCY';
      default:           return dept?.toUpperCase() ?? '🚨 EMERGENCY';
    }
  }

  @override
  Widget build(BuildContext context) {
    final dispatchState = ref.watch(dispatchProvider);
    final dispatch = dispatchState.activeDispatch;

    // Auto-pan on picked_up transition
    if (dispatch != null && dispatch.status != _lastStatus) {
      _lastStatus = dispatch.status;
      if (dispatch.status == DispatchStatus.pickedUp &&
          dispatch.hospitalLat != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _fetchRoute();
          _autoPan(LatLng(dispatch.hospitalLat!, dispatch.hospitalLng!));
          _ttsService.speak(
              'Patient picked up. Heading to ${dispatchState.hospitalName ?? 'hospital'}.');
        });
      }
    }

    final patientLoc =
        (dispatch?.patientLat != null && dispatch?.patientLng != null)
            ? LatLng(dispatch!.patientLat!, dispatch.patientLng!)
            : _gwaliorCenter;

    final hospitalLoc =
        (dispatch?.hospitalLat != null && dispatch?.hospitalLng != null)
            ? LatLng(dispatch!.hospitalLat!, dispatch.hospitalLng!)
            : _gwaliorCenter;

    final isPickup = dispatch?.status == DispatchStatus.assigned;
    final isPickedUp = dispatch?.status == DispatchStatus.pickedUp;
    final withinReach = _distToPatientM <= _reachThresholdM;

    final distLabel = _routeDistKm > 0
        ? '${_routeDistKm.toStringAsFixed(1)} km'
        : (_osrmLoading ? '...' : (dispatch?.liveDistance ?? '—'));
    final etaLabel = _routeEtaMin > 0
        ? '~$_routeEtaMin min'
        : (_osrmLoading ? '...' : (dispatch?.liveEta ?? '—'));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _driverPos ?? _gwaliorCenter,
              initialZoom: 14,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: _isSatellite
                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.niramaya.driver',
                maxNativeZoom: 18,
                tileProvider: NetworkTileProvider(
                    httpClient: RetryClient(http.Client())),
              ),

              // Route polyline — always shown (OSRM or straight-line fallback)
              if (_routePoints.length >= 2)
                PolylineLayer(polylines: [
                  Polyline(
                    points: _routePoints,
                    color: isPickup
                        ? AppColors.emergencyBlue
                        : AppColors.success,
                    strokeWidth: 5,
                    borderColor: Colors.white.withValues(alpha: 0.5),
                    borderStrokeWidth: 2,
                  ),
                  // Faded preview leg: patient → hospital during pickup phase
                  if (isPickup && patientLoc != _gwaliorCenter)
                    Polyline(
                      points: [patientLoc, hospitalLoc],
                      color: AppColors.success.withValues(alpha: 0.3),
                      strokeWidth: 3,
                      pattern: StrokePattern.dashed(segments: [8, 6]),
                    ),
                ]),

              MarkerLayer(markers: [
                // Driver
                if (_driverPos != null)
                  Marker(
                    point: _driverPos!,
                    width: 44, height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.primary,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.5),
                              blurRadius: 12)
                        ],
                      ),
                      child: const Icon(Icons.local_shipping,
                          color: Colors.white, size: 20),
                    ),
                  ),

                // Patient
                if (dispatch?.patientLat != null)
                  Marker(
                    point: patientLoc,
                    width: 48, height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.emergencyBlue,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.emergencyBlue
                                  .withValues(alpha: 0.5),
                              blurRadius: 12)
                        ],
                      ),
                      child: const Icon(Icons.person_pin_circle,
                          color: Colors.white, size: 22),
                    ),
                  ),

                // Hospital
                if (dispatch?.hospitalLat != null)
                  Marker(
                    point: hospitalLoc,
                    width: 44, height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.success.withValues(alpha: 0.5),
                              blurRadius: 12)
                        ],
                      ),
                      child: const Icon(Icons.local_hospital,
                          color: Colors.white, size: 20),
                    ),
                  ),
              ]),
            ],
          ),

          // Top bar
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16, right: 16, bottom: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background,
                    AppColors.background.withValues(alpha: 0)
                  ],
                ),
              ),
              child: Row(
                children: [
                  _topBtn(Icons.arrow_back, () => Navigator.pop(context)),
                  const Spacer(),
                  if (_osrmLoading)
                    const Padding(
                      padding: EdgeInsets.only(right: 8),
                      child: SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.primary),
                      ),
                    ),
                  _topBtn(
                    _isSatellite ? Icons.map : Icons.satellite_alt,
                    () => setState(() => _isSatellite = !_isSatellite),
                  ),
                ],
              ),
            ),
          ),

          // FABs
          Positioned(
            right: 16, bottom: 260,
            child: Column(children: [
              _mapFab(Icons.my_location, () {
                if (_driverPos != null) _mapController.move(_driverPos!, 15);
              }),
              const SizedBox(height: 8),
              _mapFab(Icons.add, () {
                _mapController.move(_mapController.camera.center,
                    _mapController.camera.zoom + 1);
              }),
              const SizedBox(height: 8),
              _mapFab(Icons.remove, () {
                _mapController.move(_mapController.camera.center,
                    _mapController.camera.zoom - 1);
              }),
            ]),
          ),

          // Bottom sheet
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(16, 14, 16, MediaQuery.of(context).padding.bottom > 0 ? 0 : 8),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border(top: BorderSide(color: AppColors.border)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 20,
                      offset: const Offset(0, -5))
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Phase chip
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: (isPickup ? AppColors.emergencyBlue : AppColors.success)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (isPickup
                                  ? AppColors.emergencyBlue
                                  : AppColors.success)
                              .withValues(alpha: 0.25),
                        ),
                      ),
                      child: Row(children: [
                        Icon(
                          isPickup
                              ? Icons.directions_run
                              : Icons.local_hospital,
                          color: isPickup
                              ? AppColors.emergencyBlue
                              : AppColors.success,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isPickup
                              ? 'HEADING TO PATIENT'
                              : isPickedUp
                                  ? 'EN ROUTE TO HOSPITAL'
                                  : 'HEADING TO HOSPITAL',
                          style: TextStyle(
                            color: isPickup
                                ? AppColors.emergencyBlue
                                : AppColors.success,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 10),

                    // Victim profile + metrics row
                    Row(
                      children: [
                        // Triage badge
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: AppColors.emergencyRed
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: AppColors.emergencyRed
                                      .withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'EMERGENCY',
                                  style: TextStyle(
                                    color: AppColors.textMuted,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _triageLabel(dispatch?.requiredDept),
                                  style: const TextStyle(
                                    color: AppColors.emergencyRed,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),

                        // Distance
                        Expanded(
                          child: _metricCard(
                              'DISTANCE', distLabel, Icons.straighten),
                        ),
                        const SizedBox(width: 8),

                        // ETA
                        Expanded(
                          child:
                              _metricCard('ETA', etaLabel, Icons.schedule),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Action button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: isPickup
                          ? ElevatedButton(
                              onPressed: withinReach
                                  ? () => ref
                                      .read(dispatchProvider.notifier)
                                      .confirmReach()
                                  : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: withinReach
                                    ? AppColors.warning
                                    : AppColors.cardElevated,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor:
                                    AppColors.cardElevated,
                                disabledForegroundColor: AppColors.textMuted,
                              ),
                              child: Text(
                                withinReach
                                    ? 'CONFIRM REACH  •  ${_distToPatientM.toInt()}m'
                                    : _distToPatientM.isInfinite
                                        ? 'LOCATING PATIENT...'
                                        : 'APPROACHING  •  ${_distToPatientM.toInt()}m away',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5),
                              ),
                            )
                          : ElevatedButton(
                              onPressed: () => ref
                                  .read(dispatchProvider.notifier)
                                  .confirmPickup(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isPickedUp
                                    ? AppColors.success
                                    : AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                isPickedUp
                                    ? 'CONFIRM PICKUP & HEAD TO HOSPITAL'
                                    : 'ARRIVED AT HOSPITAL',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5),
                              ),
                            ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _topBtn(IconData icon, VoidCallback onTap) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
        ),
        child: IconButton(
            icon: Icon(icon, color: AppColors.textPrimary, size: 20),
            onPressed: onTap),
      );

  Widget _mapFab(IconData icon, VoidCallback onPressed) => Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.2), blurRadius: 8)
          ],
        ),
        child: IconButton(
            icon: Icon(icon, color: AppColors.textPrimary, size: 20),
            onPressed: onPressed),
      );

  Widget _metricCard(String label, String value, IconData icon) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.cardElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.textMuted, size: 14),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              label,
              style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 9,
                  letterSpacing: 0.5),
            ),
          ],
        ),
      );
}
