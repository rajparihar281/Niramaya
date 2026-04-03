import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/api_client.dart';
import '../data/models/dispatch_model.dart';

// ── Dispatch State ────────────────────────────────────────────────────────

class DispatchState {
  final DispatchModel? dispatch;
  final DispatchStatusModel? status;
  final bool isLoading;
  final String? error;

  const DispatchState({
    this.dispatch,
    this.status,
    this.isLoading = false,
    this.error,
  });

  DispatchState copyWith({
    DispatchModel? dispatch,
    DispatchStatusModel? status,
    bool? isLoading,
    String? error,
  }) {
    return DispatchState(
      dispatch: dispatch ?? this.dispatch,
      status: status ?? this.status,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ── Dispatch Notifier ─────────────────────────────────────────────────────

class DispatchNotifier extends StateNotifier<DispatchState> {
  DispatchNotifier() : super(const DispatchState());

  /// Trigger SOS dispatch to backend
  Future<bool> triggerDispatch({
    required String patientId,
    required double latitude,
    required double longitude,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final response = await ApiClient.dispatch(
        patientId: patientId,
        latitude: latitude,
        longitude: longitude,
      );

      // Surface HTTP errors as readable messages
      if (response.statusCode != null && response.statusCode! >= 400) {
        final msg = response.data is Map
            ? (response.data['error'] ?? 'Server error ${response.statusCode}')
            : 'Server error ${response.statusCode}';
        state = state.copyWith(isLoading: false, error: msg.toString());
        return false;
      }

      final data = response.data as Map<String, dynamic>;

      // Backend returns 200 with status=no_drivers_available when no driver is on duty
      if (data['status'] == 'no_drivers_available') {
        state = state.copyWith(
          isLoading: false,
          error: 'No drivers available right now. Please try again shortly.',
        );
        return false;
      }

      final dispatch = DispatchModel.fromJson(data);
      state = DispatchState(dispatch: dispatch);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Dispatch failed: ${e.toString()}',
      );
      return false;
    }
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
