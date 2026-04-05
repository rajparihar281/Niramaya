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
  List<LatLng> _alternateRoute = [];
  double _routeDistKm = 0;
  int _routeEtaMin = 0;
  double _distToPatientM = double.infinity;
  bool _osrmLoading = false;
  bool _showAlternateRoute = false;
  String _routeType = 'fastest'; // 'fastest', 'shortest', 'avoid_tolls'

  DispatchStatus? _lastStatus;
  // Persisted destination so re-entering the map restores the correct route
  LatLng? _activeDestination;

  static const LatLng _gwaliorCenter = LatLng(26.218, 78.182);
  static const double _reachThresholdM = 50;

  @override
  void initState() {
    super.initState();
    _ttsService.init();
    _initLocation();
    // Listen for cancellation outside of build() to guarantee navigation fires
    WidgetsBinding.instance.addPostFrameCallback((_) => _listenForCancel());
  }

  void _listenForCancel() {
    ref.listenManual(dispatchProvider, (previous, next) {
      if (!mounted) return;
      final wasActive = previous?.activeDispatch != null;
      final nowIdle = next.uiState == DispatchUiState.idle && next.activeDispatch == null;
      if (next.wasCancelled || (wasActive && nowIdle)) {
        ref.read(dispatchProvider.notifier).resetCancelledFlag();
        Navigator.of(context).popUntil((r) => r.isFirst);
      }
    });
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

    // Restore correct destination based on current provider status
    // This handles re-entry after driver exited the map mid-dispatch
    final dispatch = ref.read(dispatchProvider).activeDispatch;
    if (dispatch != null) {
      final isPostPickup = dispatch.status == DispatchStatus.arrived ||
          dispatch.status == DispatchStatus.pickedUp;
      _activeDestination = isPostPickup && dispatch.hospitalLat != null
          ? LatLng(dispatch.hospitalLat!, dispatch.hospitalLng!)
          : dispatch.patientLat != null
              ? LatLng(dispatch.patientLat!, dispatch.patientLng!)
              : null;
    }

    _updateMetricsBaseline();
    if (_driverPos != null) _updateProximity(_driverPos!);

    await _fetchRoute(doAutoPan: true, dest: _activeDestination);
    _announcePhase();

    _positionSub = LocationService.instance.startPositionStream().listen((pos) {
      if (!mounted) return;
      final newPos = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _driverPos = newPos;
        _updateProximity(newPos);
      });
      _fetchRoute(dest: _activeDestination);
    });

    _osrmTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _fetchRoute(dest: _activeDestination),
    );

    // Compute initial ETA immediately using straight-line if OSRM hasn't loaded
    if (_routeDistKm == 0 && _activeDestination != null && _driverPos != null) {
      final distKm = LocationService.distanceKm(_driverPos!, _activeDestination!);
      setState(() {
        _routeDistKm = distKm;
        _routeEtaMin = LocationService.estimateMinutes(distKm);
      });
    }
  }

  // Compute straight-line distance/ETA immediately as a baseline
  void _updateMetricsBaseline() {
    if (_driverPos == null) return;
    final dispatch = ref.read(dispatchProvider).activeDispatch;
    if (dispatch == null) return;

    final toPatient = dispatch.status == DispatchStatus.assigned;
    final dest = toPatient
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
    // Only track proximity during pickup phase
    if (dispatch!.status != DispatchStatus.assigned) {
      setState(() => _distToPatientM = 0);
      return;
    }
    final d = Geolocator.distanceBetween(
      driverPos.latitude, driverPos.longitude,
      dispatch.patientLat!, dispatch.patientLng!,
    );
    setState(() => _distToPatientM = d);
  }

  // [dest] is optional — when provided it overrides the status-based target.
  // This is critical for confirmReach: the provider status hasn't updated yet
  // when the button fires, so we pass hospitalLoc directly.
  Future<void> _fetchRoute({bool doAutoPan = false, LatLng? dest}) async {
    if (_driverPos == null) return;
    final dispatch = ref.read(dispatchProvider).activeDispatch;
    if (dispatch == null) return;

    // Resolve destination: explicit override > status-based
    final target = dest ?? (() {
      final toPatient = dispatch.status == DispatchStatus.assigned;
      return toPatient
          ? LatLng(dispatch.patientLat ?? _gwaliorCenter.latitude,
              dispatch.patientLng ?? _gwaliorCenter.longitude)
          : LatLng(dispatch.hospitalLat ?? _gwaliorCenter.latitude,
              dispatch.hospitalLng ?? _gwaliorCenter.longitude);
    })();

    if (_osrmLoading) return;
    setState(() => _osrmLoading = true);

    final url = 'https://router.project-osrm.org/route/v1/driving/'
        '${_driverPos!.longitude},${_driverPos!.latitude};'
        '${target.longitude},${target.latitude}'
        '?overview=full&geometries=geojson&alternatives=true';

    try {
      final res = await RetryClient(http.Client())
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final routes = body['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final route = routes[0];
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

          if (routes.length > 1) {
            final altCoords = (routes[1]['geometry']['coordinates'] as List)
                .map((c) => LatLng(
                      (c[1] as num).toDouble(),
                      (c[0] as num).toDouble(),
                    ))
                .toList();
            setState(() => _alternateRoute = altCoords);
          }

          if (doAutoPan) _autoPan(target);
          return;
        }
      }
    } catch (_) {}

    // Fallback: straight line
    if (mounted) {
      final distKm = LocationService.distanceKm(_driverPos!, target);
      setState(() {
        _routePoints = [_driverPos!, target];
        _routeDistKm = distKm;
        _routeEtaMin = LocationService.estimateMinutes(distKm);
        _osrmLoading = false;
      });
      if (doAutoPan) _autoPan(target);
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
    final toPatient = dispatch.status == DispatchStatus.assigned;
    final dest = toPatient
        ? LatLng(dispatch.patientLat ?? _gwaliorCenter.latitude,
            dispatch.patientLng ?? _gwaliorCenter.longitude)
        : LatLng(dispatch.hospitalLat ?? _gwaliorCenter.latitude,
            dispatch.hospitalLng ?? _gwaliorCenter.longitude);
    final dist = LocationService.distanceKm(_driverPos!, dest);
    _ttsService.announcePhase(
      toPatient ? DispatchPhase.toPatient : DispatchPhase.toHospital,
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

    // Auto-pan on status transition
    if (dispatch != null && dispatch.status != _lastStatus) {
      final wasNull = _lastStatus == null;
      _lastStatus = dispatch.status;
      
      if (wasNull && dispatch.status == DispatchStatus.assigned) {
         WidgetsBinding.instance.addPostFrameCallback((_) {
             _updateMetricsBaseline();
             _fetchRoute(doAutoPan: true);
         });
      } else if (dispatch.status == DispatchStatus.arrived &&
          dispatch.hospitalLat != null) {
        final hospitalDest = LatLng(dispatch.hospitalLat!, dispatch.hospitalLng!);
        _activeDestination = hospitalDest;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() { _routePoints = []; _alternateRoute = []; _osrmLoading = false; });
          _fetchRoute(doAutoPan: true, dest: hospitalDest);
          _ttsService.speak(
              'Patient reached. Fetching route to ${dispatchState.hospitalName ?? 'hospital'}.');
        });
      } else if (dispatch.status == DispatchStatus.pickedUp &&
          dispatch.hospitalLat != null) {
        final hospitalDest = LatLng(dispatch.hospitalLat!, dispatch.hospitalLng!);
        _activeDestination = hospitalDest;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          setState(() { _routePoints = []; _alternateRoute = []; _osrmLoading = false; });
          _fetchRoute(doAutoPan: true, dest: hospitalDest);
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
    final isArrived = dispatch?.status == DispatchStatus.arrived;
    final isPickedUp = dispatch?.status == DispatchStatus.pickedUp;
    final toHospital = isArrived || isPickedUp;
    // Always allow button tap — proximity check is advisory only
    final withinReach = _distToPatientM <= _reachThresholdM || _distToPatientM.isInfinite;

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

              // Route polylines with enhanced visualization
              if (_routePoints.length >= 2)
                PolylineLayer(polylines: [
                  Polyline(
                    points: _routePoints,
                    color: toHospital ? AppColors.success : AppColors.emergencyBlue,
                    strokeWidth: 6,
                    borderColor: Colors.white.withValues(alpha: 0.8),
                    borderStrokeWidth: 2,
                  ),
                  if (_showAlternateRoute && _alternateRoute.length >= 2)
                    Polyline(
                      points: _alternateRoute,
                      color: Colors.grey.withValues(alpha: 0.6),
                      strokeWidth: 4,
                      pattern: StrokePattern.dashed(segments: [10, 5]),
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
                // Driver/ambulance marker
                if (_driverPos != null)
                  Marker(
                    point: _driverPos!,
                    width: 48, height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.driverBlue,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.driverBlue.withValues(alpha: 0.5),
                              blurRadius: 14)
                        ],
                      ),
                      child: const Icon(Icons.personal_injury,
                          color: Colors.white, size: 22),
                    ),
                  ),

                // Patient marker — only visible during pickup phase
                if (isPickup && dispatch?.patientLat != null)
                  Marker(
                    point: patientLoc,
                    width: 48, height: 48,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.emergencyRed,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.emergencyRed.withValues(alpha: 0.5),
                              blurRadius: 12)
                        ],
                      ),
                      child: const Icon(Icons.airport_shuttle,
                          color: Colors.white, size: 22),
                    ),
                  ),

                // Hospital — always visible so driver can see destination
                if (dispatch?.hospitalLat != null)
                  Marker(
                    point: hospitalLoc,
                    width: 52, height: 52,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.rectangle,
                        borderRadius: BorderRadius.circular(10),
                        color: AppColors.hospitalGreen,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.hospitalGreen.withValues(alpha: 0.5),
                              blurRadius: 14)
                        ],
                      ),
                      child: const Icon(Icons.local_hospital,
                          color: Colors.white, size: 24),
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
                  const SizedBox(width: 8),
                  _topBtn(
                    _showAlternateRoute ? Icons.alt_route : Icons.route,
                    () => setState(() {
                      _showAlternateRoute = !_showAlternateRoute;
                      _routeType = _routeType == 'fastest' ? 'shortest' : 'fastest';
                      _fetchRoute(doAutoPan: true);
                    }),
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
              _mapFab(Icons.navigation, () {
                final dispatch = ref.read(dispatchProvider).activeDispatch;
                if (dispatch != null && _driverPos != null) {
                  final toPatient = dispatch.status == DispatchStatus.assigned;
                  final dest = toPatient
                      ? LatLng(dispatch.patientLat ?? _gwaliorCenter.latitude,
                          dispatch.patientLng ?? _gwaliorCenter.longitude)
                      : LatLng(dispatch.hospitalLat ?? _gwaliorCenter.latitude,
                          dispatch.hospitalLng ?? _gwaliorCenter.longitude);
                  _autoPan(dest);
                }
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
                          toHospital ? Icons.local_hospital : Icons.directions_run,
                          color: toHospital ? AppColors.success : AppColors.emergencyBlue,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          toHospital
                              ? 'EN ROUTE TO HOSPITAL'
                              : 'HEADING TO PATIENT',
                          style: TextStyle(
                            color: toHospital ? AppColors.success : AppColors.emergencyBlue,
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
                              onPressed: () async {
                                final dispatch = ref.read(dispatchProvider).activeDispatch;
                                final hospitalDest = (dispatch?.hospitalLat != null)
                                    ? LatLng(dispatch!.hospitalLat!, dispatch.hospitalLng!)
                                    : null;
                                await ref.read(dispatchProvider.notifier).confirmReach();
                                setState(() {
                                  _activeDestination = hospitalDest;
                                  _routePoints = [];
                                  _alternateRoute = [];
                                  _osrmLoading = false;
                                });
                                await _fetchRoute(doAutoPan: true, dest: hospitalDest);
                                _ttsService.speak(
                                    'Patient reached. Navigating to ${dispatchState.hospitalName ?? 'hospital'}.');
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: withinReach ? AppColors.warning : AppColors.primary,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                _distToPatientM.isInfinite
                                    ? 'CONFIRM PATIENT REACHED'
                                    : _distToPatientM > _reachThresholdM
                                        ? 'APPROACHING · ${_distToPatientM.toInt()}m · TAP TO CONFIRM'
                                        : 'PATIENT SECURED · NAVIGATE TO HOSPITAL',
                                style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
                              ),
                            )
                          : ElevatedButton(
                              onPressed: () => ref.read(dispatchProvider.notifier).confirmPickup(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                foregroundColor: Colors.white,
                              ),
                              child: const Text(
                                'CONFIRM DROPOFF AT HOSPITAL',
                                style: TextStyle(fontWeight: FontWeight.w700, letterSpacing: 0.5),
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
