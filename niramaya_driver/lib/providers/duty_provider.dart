// ── Duty Provider — Toggle on/off duty via direct Supabase update ────────────

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/supabase_service.dart';
import 'auth_provider.dart';

class DutyState {
  final bool isOnDuty;
  final bool isToggling;

  const DutyState({this.isOnDuty = false, this.isToggling = false});

  DutyState copyWith({bool? isOnDuty, bool? isToggling}) => DutyState(
        isOnDuty: isOnDuty ?? this.isOnDuty,
        isToggling: isToggling ?? this.isToggling,
      );
}

class DutyNotifier extends StateNotifier<DutyState> {
  final Ref ref;

  DutyNotifier(this.ref) : super(const DutyState());

  void setDuty(bool isOnDuty) {
    state = state.copyWith(isOnDuty: isOnDuty);
  }

  Future<bool> toggle(String? userId) async {
    if (userId == null || userId.trim().isEmpty) {
      debugPrint('[DutyProvider] ❌ toggle called with null/empty userId');
      return state.isOnDuty;
    }
    if (state.isToggling) return state.isOnDuty;

    final newValue = !state.isOnDuty;

    // Optimistic UI flip before DB call
    state = state.copyWith(isOnDuty: newValue, isToggling: true);
    debugPrint('[DutyProvider] 🔄 drivers.id=$userId → is_on_duty=$newValue');

    try {
      // Plain update — no .select()/.maybeSingle() to avoid PGRST116
      // when RLS blocks the RETURNING clause on the drivers table.
      await SupabaseService.client
          .from('drivers')
          .update({'is_on_duty': newValue})
          .eq('id', userId.trim());

      debugPrint('[DutyProvider] ✅ is_on_duty=$newValue committed');
      state = state.copyWith(isToggling: false);

      final authState = ref.read(authProvider);
      if (authState.profile != null) {
        ref.read(authProvider.notifier).updateProfile(
              authState.profile!.copyWith(isOnDuty: newValue),
            );
      }
      return newValue;
    } catch (e) {
      debugPrint('[DutyProvider] ❌ toggle failed: $e — reverting');
      state = state.copyWith(isOnDuty: !newValue, isToggling: false);
      return !newValue;
    }
  }
}

final dutyProvider = StateNotifierProvider<DutyNotifier, DutyState>((ref) {
  return DutyNotifier(ref);
});
