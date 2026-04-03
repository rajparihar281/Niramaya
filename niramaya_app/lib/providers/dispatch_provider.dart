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

      final dispatch = DispatchModel.fromJson(response.data);
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
