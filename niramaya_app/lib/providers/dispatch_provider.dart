import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/api_client.dart';
import '../data/models/dispatch_model.dart';

// ── Dispatch State ────────────────────────────────────────────────────────

class DispatchState {
  final DispatchModel? dispatch;
  final DispatchStatusModel? status;
  final bool isLoading;
  final String? error;
  final String? scanningHospital;
  final bool noDriversAvailable;

  const DispatchState({
    this.dispatch,
    this.status,
    this.isLoading = false,
    this.error,
    this.scanningHospital,
    this.noDriversAvailable = false,
  });

  DispatchState copyWith({
    DispatchModel? dispatch,
    DispatchStatusModel? status,
    bool? isLoading,
    String? error,
    String? scanningHospital,
    bool? noDriversAvailable,
  }) {
    return DispatchState(
      dispatch: dispatch ?? this.dispatch,
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      scanningHospital: scanningHospital ?? this.scanningHospital,
      noDriversAvailable: noDriversAvailable ?? this.noDriversAvailable,
    );
  }
}

// ── Dispatch Notifier ─────────────────────────────────────────────────────

class DispatchNotifier extends StateNotifier<DispatchState> {
  DispatchNotifier() : super(const DispatchState());

  // Gwalior hospital grid — cycled in UI while backend processes
  static const _hospitals = [
    'J.A. Hospital',
    'Birla Hospital',
    'Apollo Spectra',
    'Gajra Raja Medical College',
    'Kamla Raja Hospital',
    'City Hospital Gwalior',
    'Sanjay Gandhi Hospital',
  ];

  Timer? _scanTimer;
  int _scanIndex = 0;

  Future<bool> triggerDispatch({
    required String patientId,
    required double latitude,
    required double longitude,
  }) async {
    _scanIndex = 0;
    state = state.copyWith(
      isLoading: true,
      error: null,
      noDriversAvailable: false,
      scanningHospital: _hospitals[0],
    );
    debugPrint('[Dispatch] 📡 POST /v1/dispatch → patient=$patientId lat=$latitude lng=$longitude');

    // Cycle hospital names every 1.2s while waiting for backend
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(milliseconds: 1200), (_) {
      _scanIndex = (_scanIndex + 1) % _hospitals.length;
      if (mounted) {
        state = state.copyWith(scanningHospital: _hospitals[_scanIndex]);
      }
    });

    try {
      final response = await ApiClient.dispatch(
        patientId: patientId,
        latitude: latitude,
        longitude: longitude,
      );

      _scanTimer?.cancel();
      debugPrint('[Dispatch] ← HTTP ${response.statusCode} body=${response.data}');

      if (response.statusCode != null && response.statusCode! >= 400) {
        final msg = response.data is Map
            ? (response.data['error'] ?? 'Server error ${response.statusCode}')
            : 'Server error ${response.statusCode}';
        debugPrint('[Dispatch] ❌ HTTP error: $msg');
        state = state.copyWith(isLoading: false, error: msg.toString());
        return false;
      }

      final data = response.data as Map<String, dynamic>;

      if (data['status'] == 'no_drivers_available') {
        debugPrint('[Dispatch] ⚠ no_drivers_available');
        state = state.copyWith(
          isLoading: false,
          noDriversAvailable: true,
          error: 'No government ambulances available.',
        );
        return false;
      }

      debugPrint('[Dispatch] ✅ Assigned → dispatch_id=${data["dispatch_id"]} hospital=${data["hospital"]}');
      final dispatch = DispatchModel.fromJson(data);
      state = DispatchState(dispatch: dispatch);
      return true;
    } catch (e) {
      _scanTimer?.cancel();
      debugPrint('[Dispatch] ❌ Exception: $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Dispatch failed: ${e.toString()}',
      );
      return false;
    }
  }

  @override
  void dispose() {
    _scanTimer?.cancel();
    super.dispose();
  }

  /// Poll dispatch status
  Future<void> pollStatus() async {
    if (state.dispatch == null) return;
    try {
      final response = await ApiClient.dispatchStatus(state.dispatch!.dispatchId);
      final status = DispatchStatusModel.fromJson(response.data);
      state = state.copyWith(status: status);
    } catch (_) {
      // Silently fail — will retry on next poll
    }
  }

  void clear() {
    state = const DispatchState();
  }
}

// ── Provider ──────────────────────────────────────────────────────────────

final dispatchProvider =
    StateNotifierProvider<DispatchNotifier, DispatchState>((ref) {
  return DispatchNotifier();
});
