// ── Dispatch Provider — Realtime subscription + state management ────────────

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dispatch_model.dart';
import '../services/supabase_service.dart';
import '../services/alert_service.dart';

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
  // Track IDs we have already alerted so reconnect re-emissions don't re-fire
  final Set<String> _alertedIds = {};

  void initRealtimeSubscription(String driverId) {
    _realtimeSub?.cancel();
    debugPrint('[DispatchProvider] 🔌 Subscribing to dispatches for driver=$driverId');

    _realtimeSub = SupabaseService.client
        .from('dispatches')
        .stream(primaryKey: ['id'])
        .eq('driver_id', driverId)
        .listen((rows) {
          debugPrint('[DispatchProvider] 📦 Realtime rows: ${rows.length}');

          // New assigned dispatch: not alerted in DB AND not already alerted in-memory
          final assigned = rows.where((r) =>
              r['status'] == 'assigned' &&
              r['alert_sent_at'] == null &&
              !_alertedIds.contains(r['id']?.toString()));

          if (assigned.isNotEmpty) {
            final row = assigned.first;
            _alertedIds.add(row['id']?.toString() ?? '');
            _triggerAlert(row);
          }

          // Active dispatch already alerted — just sync state
          final active = rows.where((r) =>
              r['status'] != 'completed' && r['alert_sent_at'] != null);

          if (active.isNotEmpty && state.uiState != DispatchUiState.alerting) {
            _enrichAndSetActive(active.first);
          }
        }, onError: (e) {
          debugPrint('[DispatchProvider] ❌ Realtime error: $e');
        });
  }

  // ── Enrich dispatch: coords now live in the dispatches row itself ──────────
  // hospital_lat/lng and patient_lat/lng are written by the Go backend
  // at INSERT time — no secondary query needed.
  Future<DispatchModel> _enrichDispatch(Map<String, dynamic> row) async {
    final hospitalId = row['hospital_id']?.toString();
    String hospitalName = row['hospital_name']?.toString() ?? 'Unknown Hospital';

    // Fetch hospital name if not already in the row
    if ((hospitalName == 'Unknown Hospital' || hospitalName.isEmpty) &&
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

    final enriched = Map<String, dynamic>.from(row)
      ..['hospital_name'] = hospitalName;

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

    _autoDismissTimer?.cancel();
    _autoDismissTimer = Timer(const Duration(seconds: 30), () {
      if (state.uiState == DispatchUiState.alerting) acknowledgeAlert();
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
        'status': 'en_route',
        'pickup_confirmed_at': DateTime.now().toIso8601String(),
      }).eq('id', state.activeDispatch!.id);
    } catch (_) {}
  }

  Future<void> arrivedAtHospital() async {
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
    } catch (e) {
      debugPrint('[DispatchProvider] ❌ completeDispatch failed: $e');
    }
  }

  void cancelSubscription() {
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

