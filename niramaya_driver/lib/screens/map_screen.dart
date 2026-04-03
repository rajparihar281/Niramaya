// ── Map Screen — Voice-navigated fullscreen map ─────────────────────────────

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  final LocationService _locationService = LocationService.instance;
  final TtsService _ttsService = TtsService.instance;

  LatLng? _currentPosition;
  StreamSubscription? _positionSub;
  bool _isSatellite = false;
  Timer? _ttsTimer;

  // Gwalior base coordinates — overridden by live dispatch data when available
  static const LatLng _gwaliorCenter = LatLng(26.218, 78.182);

  LatLng get _patientLocation {
    final d = ref.read(dispatchProvider).activeDispatch;
    if (d?.patientLat != null && d?.patientLng != null) {
      return LatLng(d!.patientLat!, d.patientLng!);
    }
    return const LatLng(26.2183, 78.1828); // Gwalior city centre fallback
  }

  LatLng get _hospitalLocation {
    final d = ref.read(dispatchProvider).activeDispatch;
    if (d?.hospitalLat != null && d?.hospitalLng != null) {
      return LatLng(d!.hospitalLat!, d.hospitalLng!);
    }
    return const LatLng(26.2124, 78.1772); // Gwalior hospital fallback
  }

  @override
  void initState() {
    super.initState();
    _initLocation();
    _ttsService.init();
  }

  Future<void> _initLocation() async {
    await _locationService.requestPermission();
    final pos = await _locationService.getCurrentPosition();

    if (pos != null && mounted) {
      setState(() {
        _currentPosition = LatLng(pos.latitude, pos.longitude);
      });
    } else {
      // Fallback to Gwalior centre
      setState(() {
        _currentPosition = _gwaliorCenter;
      });
    }

    // Start position stream
    _positionSub = _locationService.startPositionStream().listen((pos) {
      if (mounted) {
        setState(() {
          _currentPosition = LatLng(pos.latitude, pos.longitude);
        });
      }
    });

    // Announce phase
    final dispatchState = ref.read(dispatchProvider);
    _announcePhase(dispatchState);
  }

  void _announcePhase(DispatchState dispatchState) {
    if (dispatchState.activeDispatch == null || _currentPosition == null) return;

    final dispatch = dispatchState.activeDispatch!;
    final isPickupPhase = dispatch.status == DispatchStatus.assigned ||
        dispatch.status == DispatchStatus.enRoute;

    final destination = isPickupPhase ? _patientLocation : _hospitalLocation;
    final distKm =
        LocationService.distanceKm(_currentPosition!, destination);

    if (isPickupPhase) {
      _ttsService.announcePhase(
        DispatchPhase.toPatient,
        dispatchState.hospitalName ?? 'Hospital',
        distKm,
      );
    } else {
      _ttsService.announcePhase(
        DispatchPhase.toHospital,
        dispatchState.hospitalName ?? 'Hospital',
        distKm,
      );
    }

    // Periodic announcements
    _ttsTimer?.cancel();
    _ttsTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_currentPosition == null) return;
      final bearing =
          LocationService.bearingDirection(_currentPosition!, destination);
      final dist =
          LocationService.distanceKm(_currentPosition!, destination);
      _ttsService.speak(
        'Continue for ${dist.toStringAsFixed(1)} kilometers. Heading $bearing.',
      );
    });
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _ttsTimer?.cancel();
    _ttsService.stop();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dispatchState = ref.watch(dispatchProvider);
    final dispatch = dispatchState.activeDispatch;
    final isPickupPhase = dispatch != null &&
        (dispatch.status == DispatchStatus.assigned ||
            dispatch.status == DispatchStatus.enRoute);
    final destination = isPickupPhase ? _patientLocation : _hospitalLocation;

    final distKm = _currentPosition != null
        ? LocationService.distanceKm(_currentPosition!, destination)
        : 0.0;
    final etaMin = LocationService.estimateMinutes(distKm);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentPosition ?? _gwaliorCenter,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: _isSatellite
                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.niramaya.driver',
              ),

              // Double-leg route:
              // Leg 1 (blue):  Driver → Patient
              // Leg 2 (green): Patient → Hospital
              if (_currentPosition != null)
                PolylineLayer(
                  polylines: [
                    // Leg 1: current → patient (always shown)
                    Polyline(
                      points: [_currentPosition!, _patientLocation],
                      color: AppColors.emergencyBlue,
                      strokeWidth: 4,
                    ),
                    // Leg 2: patient → hospital (shown dimmed until pickup)
                    Polyline(
                      points: [_patientLocation, _hospitalLocation],
                      color: AppColors.success.withValues(
                        alpha: isPickupPhase ? 0.35 : 1.0,
                      ),
                      strokeWidth: 4,
                      pattern: isPickupPhase
                          ? StrokePattern.dashed(segments: [8, 6])
                          : const StrokePattern.solid(),
                    ),
                  ],
                ),

              // Markers
              MarkerLayer(
                markers: [
                  // Driver position
                  if (_currentPosition != null)
                    Marker(
                      point: _currentPosition!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_shipping,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                    ),

                  // Patient marker (always shown)
                  Marker(
                    point: _patientLocation,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.emergencyBlue,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.emergencyBlue.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),

                  // Hospital marker (always shown)
                  Marker(
                    point: _hospitalLocation,
                    width: 44,
                    height: 44,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.success,
                        border: Border.all(color: Colors.white, width: 3),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.success.withValues(alpha: 0.4),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.local_hospital,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 12,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.background,
                    AppColors.background.withValues(alpha: 0),
                  ],
                ),
              ),
              child: Row(
                children: [
                  // Back button
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back,
                          color: AppColors.textPrimary, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                  const Spacer(),
                  // Satellite toggle
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border),
                    ),
                    child: IconButton(
                      icon: Icon(
                        _isSatellite ? Icons.map : Icons.satellite_alt,
                        color: AppColors.textPrimary,
                        size: 20,
                      ),
                      onPressed: () {
                        setState(() => _isSatellite = !_isSatellite);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Recenter FAB
          Positioned(
            right: 16,
            bottom: 200,
            child: Column(
              children: [
                _mapFab(Icons.my_location, () {
                  if (_currentPosition != null) {
                    _mapController.move(_currentPosition!, 15);
                  }
                }),
                const SizedBox(height: 8),
                _mapFab(Icons.add, () {
                  final zoom = _mapController.camera.zoom;
                  _mapController.move(
                      _mapController.camera.center, zoom + 1);
                }),
                const SizedBox(height: 8),
                _mapFab(Icons.remove, () {
                  final zoom = _mapController.camera.zoom;
                  _mapController.move(
                      _mapController.camera.center, zoom - 1);
                }),
              ],
            ),
          ),

          // Bottom sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                border: Border(
                  top: BorderSide(color: AppColors.border),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Phase label
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: (isPickupPhase
                                ? Colors.blue
                                : AppColors.primary)
                            .withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            isPickupPhase
                                ? Icons.directions_run
                                : Icons.local_hospital,
                            color: isPickupPhase
                                ? Colors.blue.shade400
                                : AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isPickupPhase
                                ? 'HEADING TO PATIENT'
                                : 'HEADING TO HOSPITAL',
                            style: TextStyle(
                              color: isPickupPhase
                                  ? Colors.blue.shade400
                                  : AppColors.primary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (!isPickupPhase)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          dispatchState.hospitalName ?? 'Hospital',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                    // Distance + ETA
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _metricChip(
                          'Distance',
                          '${distKm.toStringAsFixed(1)} km',
                          Icons.straighten,
                        ),
                        _metricChip(
                          'ETA',
                          '~$etaMin min',
                          Icons.schedule,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Action button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          if (isPickupPhase) {
                            ref
                                .read(dispatchProvider.notifier)
                                .confirmPickup();
                          } else {
                            ref
                                .read(dispatchProvider.notifier)
                                .arrivedAtHospital();
                            Navigator.pop(context);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isPickupPhase
                              ? AppColors.warning
                              : AppColors.success,
                          foregroundColor: Colors.white,
                        ),
                        child: Text(
                          isPickupPhase
                              ? 'CONFIRM PICKUP'
                              : 'ARRIVED AT HOSPITAL',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _mapFab(IconData icon, VoidCallback onPressed) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: AppColors.textPrimary, size: 20),
        onPressed: onPressed,
      ),
    );
  }

  Widget _metricChip(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppColors.textMuted, size: 16),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}
