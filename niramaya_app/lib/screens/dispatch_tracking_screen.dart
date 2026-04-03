import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../data/models/dispatch_model.dart';
import '../data/supabase_client.dart';
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
  Timer? _simTimer;

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
    }

    // Try to get hospital location
    _fetchHospitalLocation();

    // Start polling dispatch status
    _pollTimer = Timer.periodic(AppConstants.dispatchPollInterval, (_) {
      ref.read(dispatchProvider.notifier).pollStatus();
    });

    // Start ambulance simulation
    _simTimer = Timer.periodic(AppConstants.ambulanceSimInterval, (_) {
      _simulateAmbulanceMovement();
    });
  }

  Future<void> _fetchHospitalLocation() async {
    if (_dispatch == null) return;
    try {
      final hospitalData =
          await SupabaseClientHelper.findHospitalByName(_dispatch!.hospital);
      if (hospitalData != null && mounted) {
        // Hospital location is stored as PostGIS geography
        // Try to parse from the response — the location might come as WKT or as lat/lng
        // For Supabase REST, geography columns are returned as GeoJSON or as text
        // We'll try a fallback approach
        final location = hospitalData['location'];
        if (location is String && location.contains('POINT')) {
          // POINT(lng lat) format
          final match =
              RegExp(r'POINT\(([^ ]+) ([^ ]+)\)').firstMatch(location);
          if (match != null) {
            final lng = double.tryParse(match.group(1) ?? '');
            final lat = double.tryParse(match.group(2) ?? '');
            if (lat != null && lng != null) {
              setState(() {
                _hospitalLocation = LatLng(lat, lng);
                _ambulanceLocation = _hospitalLocation;
              });
              return;
            }
          }
        }

        // If location parsing fails, place hospital ~2km from user
        if (_userLocation != null) {
          setState(() {
            _hospitalLocation = LatLng(
              _userLocation!.latitude + 0.018,
              _userLocation!.longitude + 0.015,
            );
            _ambulanceLocation = _hospitalLocation;
          });
        }
      }
    } catch (_) {
      // Fallback: place hospital nearby
      if (_userLocation != null) {
        setState(() {
          _hospitalLocation = LatLng(
            _userLocation!.latitude + 0.018,
            _userLocation!.longitude + 0.015,
          );
          _ambulanceLocation = _hospitalLocation;
        });
      }
    }
  }

  void _simulateAmbulanceMovement() {
    if (_ambulanceLocation == null || _userLocation == null) return;

    setState(() {
      // Move 10% closer to user each tick
      _ambulanceLocation = LatLng(
        _ambulanceLocation!.latitude +
            (_userLocation!.latitude - _ambulanceLocation!.latitude) * 0.1,
        _ambulanceLocation!.longitude +
            (_userLocation!.longitude - _ambulanceLocation!.longitude) * 0.1,
      );
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _simTimer?.cancel();
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

    // Map center
    final center = _userLocation ?? const LatLng(20.5937, 78.9629);

    return Scaffold(
      body: Stack(
        children: [
          // Map
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
              ),
              MarkerLayer(
                markers: [
                  // User marker (blue dot)
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
                  // Hospital marker (red cross)
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
                  // Ambulance marker (moving)
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
              // Line between user and hospital
              if (_userLocation != null && _hospitalLocation != null)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: [_userLocation!, _hospitalLocation!],
                      color: AppColors.accent.withValues(alpha: 0.6),
                      strokeWidth: 3,
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
