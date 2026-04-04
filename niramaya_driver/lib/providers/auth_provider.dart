// ── Auth Provider — unified public.drivers table ─────────────────────────────

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants.dart';
import '../models/driver_profile_model.dart';
import '../services/supabase_service.dart';

enum AuthStatus {
  initial,
  loading,
  authenticated,
  pendingVerification,
  unauthenticated,
  error,
}

class AuthState {
  final AuthStatus status;
  final DriverProfile? profile;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.profile,
    this.errorMessage,
  });

  AuthState copyWith({
    AuthStatus? status,
    DriverProfile? profile,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      errorMessage: errorMessage,
    );
  }
}

class StaffAuthNotifier extends StateNotifier<AuthState> {
  StaffAuthNotifier() : super(const AuthState());

  // ── Single-table fetch from public.drivers ────────────────────────────────
  Future<DriverProfile?> _fetchProfile(String staffId, String phone) async {
    if (SupabaseService.isOffline) {
      debugPrint('[Auth] ⚠ Offline — skipping Supabase query');
      return null;
    }
    try {
      final result = await SupabaseService.client
          .from('drivers')
          .select()
          .eq('staff_id', staffId.trim())
          .eq('phone', phone.trim())
          .maybeSingle();
      debugPrint('[Auth] drivers query → staff_id="${staffId.trim()}" result=$result');
      if (result == null) return null;
      return DriverProfile.fromDrivers(result);
    } catch (e) {
      debugPrint('[Auth] _fetchProfile failed: $e');
      return null;
    }
  }

  Future<void> checkSession() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final prefs = await SharedPreferences.getInstance();
      final staffId = prefs.getString(AppConstants.prefStaffId);
      final phone = prefs.getString(AppConstants.prefPhone);

      if (staffId == null || phone == null) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }

      if (SupabaseService.isOffline) {
        // Offline: can't verify session — send to login with a warning
        debugPrint('[Auth] checkSession: offline, cannot verify session');
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'No connection. Please check your network.',
        );
        return;
      }

      final profile = await _fetchProfile(staffId, phone);

      if (profile == null) {
        await _clearSession();
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }

      if (!profile.isActive) {
        await _clearSession();
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Account deactivated',
        );
        return;
      }

      if (!profile.isVerified) {
        state = state.copyWith(
          status: AuthStatus.pendingVerification,
          profile: profile,
        );
        return;
      }

      state = state.copyWith(
        status: AuthStatus.authenticated,
        profile: profile,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.toString(),
      );
    }
  }

  Future<DriverProfile?> login(String staffId, String phone) async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final profile = await _fetchProfile(staffId, phone);

      if (profile == null) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Staff ID or phone not found',
        );
        return null;
      }

      if (!profile.isActive) {
        state = state.copyWith(
          status: AuthStatus.error,
          errorMessage: 'Account is not active',
        );
        return null;
      }

      if (!profile.isVerified) {
        state = state.copyWith(
          status: AuthStatus.pendingVerification,
          profile: profile,
        );
        return profile;
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(AppConstants.prefPhone, phone);

      state = state.copyWith(
        status: AuthStatus.pendingVerification,
        profile: profile,
      );
      return profile;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Login failed: ${e.toString()}',
      );
      return null;
    }
  }

  Future<void> completeAuth(DriverProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.prefStaffId, profile.staffId);
    await prefs.setString(AppConstants.prefUserId, profile.id);
    await prefs.setString(AppConstants.prefPhone, profile.phone ?? '');
    await prefs.setString(AppConstants.prefRole, profile.role);
    await prefs.setString(AppConstants.prefFullName, profile.fullName ?? '');
    await prefs.setString(AppConstants.prefAmbulanceId, profile.ambulanceId ?? '');
    await prefs.setString(AppConstants.prefHospitalId, profile.hospitalId ?? '');

    state = state.copyWith(
      status: AuthStatus.authenticated,
      profile: profile,
    );
  }

  void updateProfile(DriverProfile profile) {
    state = state.copyWith(profile: profile);
  }

  Future<void> logout() async {
    await _clearSession();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  Future<void> _clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.prefStaffId);
    await prefs.remove(AppConstants.prefUserId);
    await prefs.remove(AppConstants.prefPhone);
    await prefs.remove(AppConstants.prefRole);
    await prefs.remove(AppConstants.prefFullName);
    await prefs.remove(AppConstants.prefAmbulanceId);
    await prefs.remove(AppConstants.prefHospitalId);
  }
}

final authProvider =
    StateNotifierProvider<StaffAuthNotifier, AuthState>((ref) {
  return StaffAuthNotifier();
});
