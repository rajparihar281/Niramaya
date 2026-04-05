// ── Driver Profile Provider ─────────────────────────────────────────────────
// Manages the loaded DriverProfile and supports editable field updates.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/driver_profile_model.dart';
import '../services/supabase_service.dart';
import 'auth_provider.dart';

class DriverProfileNotifier extends StateNotifier<DriverProfile?> {
  final Ref ref;

  DriverProfileNotifier(this.ref) : super(null) {
    // Sync with auth state
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (next.status == AuthStatus.authenticated && next.profile != null) {
        state = next.profile;
      }
    });
  }

  void setProfile(DriverProfile profile) {
    state = profile;
  }

  /// Update blood_group in the unified drivers table
  Future<bool> updateBloodGroup(String newGroup) async {
    if (state == null) return false;
    final id = state!.id;
    debugPrint('[ProfileProvider] drivers.id=$id → blood_group=$newGroup');
    try {
      // Plain update — no .select()/.maybeSingle() to avoid PGRST116
      await SupabaseService.client
          .from('drivers')
          .update({'blood_group': newGroup})
          .eq('id', id);

      debugPrint('[ProfileProvider] ✅ blood_group=$newGroup committed');
      state = state!.copyWith(bloodGroup: newGroup);
      ref.read(authProvider.notifier).updateProfile(state!);
      return true;
    } catch (e) {
      debugPrint('[ProfileProvider] ❌ updateBloodGroup failed: $e');
      return false;
    }
  }

  /// Update multiple editable fields at once
  Future<bool> updateEditableFields({
    String? bloodGroup,
  }) async {
    if (bloodGroup != null) return updateBloodGroup(bloodGroup);
    return true;
  }

  /// Fetch hospital name by ID
  Future<String> getHospitalName(String hospitalId) async {
    try {
      final result = await SupabaseService.client
          .from('hospitals')
          .select('name')
          .eq('id', hospitalId)
          .maybeSingle();
      return result?['name']?.toString() ?? 'Unknown Hospital';
    } catch (_) {
      return 'Unknown Hospital';
    }
  }
}

final driverProfileProvider =
    StateNotifierProvider<DriverProfileNotifier, DriverProfile?>((ref) {
  return DriverProfileNotifier(ref);
});

/// Fetch hospital name — cached via FutureProvider.family
final hospitalNameProvider =
    FutureProvider.family<String, String>((ref, hospitalId) async {
  if (hospitalId.isEmpty) return 'Unknown Hospital';
  try {
    final result = await SupabaseService.client
        .from('hospitals')
        .select('name')
        .eq('id', hospitalId)
        .maybeSingle();
    return result?['name']?.toString() ?? 'Unknown Hospital';
  } catch (_) {
    return 'Unknown Hospital';
  }
});
