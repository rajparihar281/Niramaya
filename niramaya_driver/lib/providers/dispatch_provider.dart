import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/dispatch_model.dart';
import '../services/supabase_service.dart';
import '../services/alert_service.dart';
import '../services/location_service.dart';

enum DispatchUiState { idle, alerting, active }

class DispatchState {
  final DispatchUiState uiState;
  final DispatchModel? activeDispatch;
  final String? hospitalName;
  final DateTime? dispatchStartTime;

  const DispatchState({
    this.uiState = DispatchUiState.idle,
    this.activeDispatch,
    this.hospitalName,
    this.dispatchStartTime,
  });

  DispatchState copyWith({
    DispatchUiState? uiState,
    DispatchModel? activeDispatch,
    String? hospitalName,
    DateTime? dispatchStartTime,
  }) {
    return DispatchState(
      uiState: uiState ?? this.uiState,
      activeDispatch: activeDispatch ?? this.activeDispatch,
      hospitalName: hospitalName ?? this.hospitalName,
      dispatchStartTime: dispatchStartTime ?? this.dispatchStartTime,
    );
  }

  DispatchState clearDispatch() =>
      const DispatchState(uiState: DispatchUiState.idle);
}

class DispatchNotifier extends StateNotifier<DispatchState> {
  DispatchNotifier() : super(const DispatchState());

  StreamSubscription? _realtimeSub;
  Timer? _autoDismissTimer;
  Timer? _reconnectTimer;
  Timer? _osrmTimer;
  String? _driverId;
  int _reconnectDelay = 4;
  final Set<String> _alertedIds = {};

  void initRealtimeSubscription(String driverId) {
    _driverId = driverId;
    _reconnectDelay = 4;
    _reconnectTimer?.cancel();
    _subscribe(driverId);
  }

  void _subscribe(String driverId) {
    _realtimeSub?.cancel();
    debugPrint('[DispatchProvider] 🔌 Subscribing for driver=$driverId');

    _realtimeSub = SupabaseService.client
        .from('dispatches')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .listen(
          _onRows,
          onError: (e) {
            debugPrint('[DispatchProvider] ❌ Realtime error: $e');
            _scheduleReconnect();
          },
          cancelOnError: true,
        );
  }

  void _scheduleReconnect() {
    if (!mounted) return;
    _reconnectTimer?.cancel();
    debugPrint('[DispatchProvider] 🔄 Reconnecting in ${_reconnectDelay}s...');
    _reconnectTimer = Timer(Duration(seconds: _reconnectDelay), () {
      if (!mounted || _driverId == null) return;
      _reconnectDelay = (_reconnectDelay * 2).clamp(4, 60);
      _subscribe(_driverId!);
    });
  }

  void _onRows(List<Map<String, dynamic>> rows) {
    _reconnectDelay = 4;
    debugPrint('[DispatchProvider] 📦 Realtime rows: ${rows.length}');

    // Ghost fix: only consider non-completed dispatches
    final live = rows.where((r) => r['status'] != 'completed').toList();

    // New assigned dispatch: must be recent (within last 5 minutes) AND
    // not yet alerted in-memory or DB. This prevents old stale rows from
    // triggering an alert on cold start.
    final fiveMinutesAgo = DateTime.now().subtract(const Duration(minutes: 5));
    final assigned = live.where((r) {
      if (r['status'] != 'assigned') return false;
      if (r['alert_sent_at'] != null) return false;
      if (_alertedIds.contains(r['id']?.toString())) return false;
      final created = DateTime.tryParse(r['created_at']?.toString() ?? '');
      return created != null && created.isAfter(fiveMinutesAgo);
    });

    if (assigned.isNotEmpty) {
      final row = assigned.first;
      _alertedIds.add(row['id']?.toString() ?? '');
      _triggerAlert(row);
      return;
    }

    // Active dispatch already acknowledged — sync state
    final active = live.where((r) => r['alert_sent_at'] != null);
    if (active.isNotEmpty && state.uiState != DispatchUiState.alerting) {
      _enrichAndSetActive(active.first);
    }
  }

  // ── Enrich dispatch: fetch hospital name + driver info ─────────────────
  Future<DispatchModel> _enrichDispatch(Map<String, dynamic> row) async {
    final hospitalId = row['hospital_id']?.toString();
    String hospitalName = row['hospital_name']?.toString() ?? '';

    if ((hospitalName.isEmpty || hospitalName == 'Unknown Hospital') &&
        hospitalId != null) {
      try {
        final h = await SupabaseService.client
            .from('hospitals')
            .select('name')
            .eq('id', hospitalId)
            .maybeSingle();
        hospitalName = h?['name']?.toString() ?? 'Unknown Hospital';
      } catch (e) {
        debugPrint('[DispatchProvider] ⚠ Hospital name fetch failed: $e');
      }
    }

    // Fetch driver info for the Victim Profile card
    String? driverName;
    double? driverRating;
    String? plateNumber;
    final driverId = row['driver_id']?.toString();
    if (driverId != null) {
      try {
        final d = await SupabaseService.client
            .from('drivers')
            .select('full_name, rating, ambulance_id')
            .eq('id', driverId)
            .maybeSingle();
        driverName = d?['full_name']?.toString();
        driverRating = (d?['rating'] as num?)?.toDouble();
        plateNumber = d?['ambulance_id']?.toString();
      } catch (_) {}
    }

    final enriched = Map<String, dynamic>.from(row)
      ..['hospital_name'] = hospitalName
      ..['driver_name'] = driverName
      ..['driver_rating'] = driverRating
      ..['plate_number'] = plateNumber;

    return DispatchModel.fromJson(enriched);
  }

  Future<void> _triggerAlert(Map<String, dynamic> row) async {
    debugPrint('[DispatchProvider] 🚨 New assigned dispatch — triggering alert');
    final dispatch = await _enrichDispatch(row);

    state = state.copyWith(
      uiState: DispatchUiState.alerting,
      activeDispatch: dispatch,
      hospitalName: dispatch.hospitalName,
      dispatchStartTime: DateTime.now(),
    );

    AlertService.instance.triggerAlert();
    _startOsrmTimer(dispatch.id);

    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 30), () {
      if (state.uiState == DispatchUiState.alerting) acknowledgeAlert();
    });
  }

  // ── OSRM live ETA: update dispatches.live_dist_km/live_eta_min every 10s ──
  void _startOsrmTimer(String dispatchId) {
    _osrmTimer?.cancel();
    _osrmTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      final dispatch = state.activeDispatch;
      final driverPos = LocationService.instance.lastLatLng;
      if (dispatch == null || driverPos == null) return;

      final toPatient = dispatch.status == DispatchStatus.assigned;
      final dest = toPatient
          ? LatLng(dispatch.patientLat ?? 0, dispatch.patientLng ?? 0)
          : LatLng(dispatch.hospitalLat ?? 0, dispatch.hospitalLng ?? 0);
      if (dest.latitude == 0) return;

      double distKm;
      int etaMin;

      try {
        final url = 'https://router.project-osrm.org/route/v1/driving/'
            '${driverPos.longitude},${driverPos.latitude};'
            '${dest.longitude},${dest.latitude}?overview=false';
        final res = await http.get(Uri.parse(url))
            .timeout(const Duration(seconds: 8));
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body);
          final route = body['routes']?[0];
          distKm = (route?['distance'] as num? ?? 0) / 1000;
          etaMin = ((route?['duration'] as num? ?? 0) / 60).ceil();
        } else {
          throw Exception('OSRM ${res.statusCode}');
        }
      } catch (_) {
        distKm = LocationService.distanceKm(driverPos, dest);
        etaMin = LocationService.estimateMinutes(distKm);
      }

      try {
        await SupabaseService.client.from('dispatches').update({
          'live_distance': '${distKm.toStringAsFixed(1)} km',
          'live_eta': '~$etaMin min',
        }).eq('id', dispatchId);
      } catch (_) {}
    });
  }

  Future<void> _enrichAndSetActive(Map<String, dynamic> row) async {
    final dispatch = await _enrichDispatch(row);
    state = state.copyWith(
      uiState: DispatchUiState.active,
      activeDispatch: dispatch,
      hospitalName: dispatch.hospitalName,
    );
  }

  Future<void> acknowledgeAlert() async {
    _autoDismissTimer?.cancel();
    await AlertService.instance.stopAlert();

    if (state.activeDispatch != null) {
      try {
        await SupabaseService.client
            .from('dispatches')
            .update({'alert_sent_at': DateTime.now().toIso8601String()})
            .eq('id', state.activeDispatch!.id);
      } catch (_) {}
      state = state.copyWith(uiState: DispatchUiState.active);
    }
  }

  Future<void> confirmPickup() async {
    if (state.activeDispatch == null) return;
    try {
      await SupabaseService.client.from('dispatches').update({
        'status': 'picked_up',
        'pickup_confirmed_at': DateTime.now().toIso8601String(),
      }).eq('id', state.activeDispatch!.id);
    } catch (_) {}
  }

  Future<void> confirmReach() async {
    if (state.activeDispatch == null) return;
    try {
      await SupabaseService.client
          .from('dispatches')
          .update({'status': 'arrived'})
          .eq('id', state.activeDispatch!.id);
    } catch (_) {}
  }

  // ── Fixed: use drivers table, not deleted staff_driver_details ────────────
  Future<void> completeDispatch(String driverId) async {
    if (state.activeDispatch == null) return;
    try {
      await SupabaseService.client.from('dispatches').update({
        'status': 'completed',
        'dropoff_confirmed_at': DateTime.now().toIso8601String(),
      }).eq('id', state.activeDispatch!.id);

      // Mark driver back on duty after completing dispatch
      await SupabaseService.client
          .from('drivers')
          .update({'is_on_duty': true})
          .eq('id', driverId);

      state = state.clearDispatch();
      _alertedIds.clear();
      _osrmTimer?.cancel();
    } catch (e) {
      debugPrint('[DispatchProvider] ❌ completeDispatch failed: $e');
    }
  }

  void cancelSubscription() {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _osrmTimer?.cancel();
    _osrmTimer = null;
    _realtimeSub?.cancel();
    _realtimeSub = null;
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
  }

  @override
  void dispose() {
    cancelSubscription();
    super.dispose();
  }
}

final dispatchProvider =
    StateNotifierProvider<DispatchNotifier, DispatchState>((ref) {
  return DispatchNotifier();
});

