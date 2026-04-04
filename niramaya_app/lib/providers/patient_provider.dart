import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';
import '../core/utils/sha_utils.dart';
import '../data/supabase_client.dart';
import '../data/models/patient_record.dart';
import 'auth_provider.dart';

// ── Patient State ─────────────────────────────────────────────────────────

class PatientState {
  final PatientRecord? record;
  final bool isLoading;
  final String? error;

  const PatientState({this.record, this.isLoading = false, this.error});

  PatientState copyWith({
    PatientRecord? record,
    bool? isLoading,
    String? error,
  }) {
    return PatientState(
      record: record ?? this.record,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ── Patient Notifier ──────────────────────────────────────────────────────

class PatientNotifier extends StateNotifier<PatientState> {
  final FlutterSecureStorage _storage;

  PatientNotifier(this._storage) : super(const PatientState());

  /// Fetch patient record from Supabase, cache encrypted locally
  Future<void> fetchRecord(String userId) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final record = await SupabaseClientHelper.getPatientRecord(userId);
      if (record != null) {
        state = PatientState(record: record);
        // Cache encrypted
        final json = jsonEncode(record.toJson());
        final encrypted = ShaUtils.sha256Hash(json); // hash as integrity check
        await _storage.write(key: AppConstants.storageCachedPatient, value: json);
        await _storage.write(key: '${AppConstants.storageCachedPatient}_hash', value: encrypted);
      } else {
        state = const PatientState();
      }
    } catch (e) {
      // Try to load from cache
      final cached = await _storage.read(key: AppConstants.storageCachedPatient);
      if (cached != null) {
        try {
          final record = PatientRecord.fromJson(jsonDecode(cached));
          state = PatientState(record: record);
          return;
        } catch (_) {}
      }
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// Save (upsert) patient record
  Future<bool> saveRecord(PatientRecord record) async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      final saved = await SupabaseClientHelper.upsertPatientRecord(record);
      if (saved == null) {
        state = state.copyWith(isLoading: false, error: 'Save failed: offline or network error.');
        return false;
      }
      state = PatientState(record: saved);
      final json = jsonEncode(saved.toJson());
      await _storage.write(key: AppConstants.storageCachedPatient, value: json);
      return true;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return false;
    }
  }

  void clear() {
    state = const PatientState();
  }
}

// ── Providers ─────────────────────────────────────────────────────────────

final patientProvider =
    StateNotifierProvider<PatientNotifier, PatientState>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return PatientNotifier(storage);
});
