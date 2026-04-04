import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart';
import 'package:http/retry.dart';
import 'package:latlong2/latlong.dart';
import 'package:niramaya_shared/realtime_service.dart';
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

class _DispatchTrackingScreenState
    extends ConsumerState<DispatchTrackingScreen> {
  late MapController _mapController;
  Timer? _pollTimer;
  StreamSubscription<DriverLocation>? _driverSub;

  LatLng? _userLocation;
  LatLng? _hospitalLocation;
  LatLng? _ambulanceLocation;
  DispatchModel? _dispatch;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_dispatch == null) {
      _initFromArgs();
    }
  }

  void _initFromArgs() {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    if (args == null) return;

    _dispatch = args['dispatch'] as DispatchModel?;
    final userLat = args['userLat'] as double?;
    final userLng = args['userLng'] as double?;

    if (userLat != null && userLng != null) {
      _userLocation = LatLng(userLat, userLng);
    } else if (_dispatch?.patientLat != null && _dispatch?.patientLng != null) {
      _userLocation = LatLng(_dispatch!.patientLat!, _dispatch!.patientLng!);
    }

    // Hospital coords come directly from the dispatch response
    if (_dispatch?.hospitalLat != null && _dispatch?.hospitalLng != null) {
      _hospitalLocation =
          LatLng(_dispatch!.hospitalLat!, _dispatch!.hospitalLng!);
      _ambulanceLocation = _hospitalLocation;
    } else if (_userLocation != null) {
      // Fallback only if backend omitted coords
      _hospitalLocation = LatLng(
        _userLocation!.latitude + 0.018,
        _userLocation!.longitude + 0.015,
      );
      _ambulanceLocation = _hospitalLocation;
    }

    // Subscribe to live driver GPS via Supabase realtime
    final driverId = _dispatch?.driverId;
    if (driverId != null && driverId.isNotEmpty) {
      _driverSub = ref
          .read(realTimeServiceProvider)
          .driverLocationStream(driverId)
          .listen((loc) {
        if (loc.location != null && mounted) {
          setState(() => _ambulanceLocation = loc.location);
        }
      });
    }

    // Poll dispatch status
    _pollTimer = Timer.periodic(AppConstants.dispatchPollInterval, (_) {
      ref.read(dispatchProvider.notifier).pollStatus();
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _driverSub?.cancel();
    super.dispose();
  }

  void _handleCancel() {
    ref.read(dispatchProvider.notifier).clear();
    Navigator.pop(context);
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

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.niramaya.app',
                maxNativeZoom: 18,
                tileProvider: NetworkTileProvider(
                  httpClient: RetryClient(Client()),
                ),
              ),
              // Route line: ambulance → user
              if (_ambulanceLocation != null && _userLocation != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_ambulanceLocation!, _userLocation!],
                      color: AppColors.accent.withValues(alpha: 0.6),
                      strokeWidth: 3,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  // Patient (user)
                  if (_userLocation != null)
                    Marker(
                      point: _userLocation!,
                      width: 30,
                      height: 30,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.accent.withValues(alpha: 0.4),
                              blurRadius: 8,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                      ),
                    ),
                  // Hospital
                  if (_hospitalLocation != null)
                    Marker(
                      point: _hospitalLocation!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_hospital,
                          color: AppColors.emergency,
                          size: 24,
                        ),
                      ),
                    ),
                  // Ambulance (live position)
                  if (_ambulanceLocation != null)
                    Marker(
                      point: _ambulanceLocation!,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.3),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.local_shipping,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Back button
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              elevation: 4,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(Icons.arrow_back, size: 22),
                ),
              ),
            ),
          ),

          // Bottom panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: DispatchPanel(
              dispatch: dispatch,
              status: dispatchState.status,
              onCancel: _handleCancel,
            ),
          ),
        ],
      ),
    );
  }
}
