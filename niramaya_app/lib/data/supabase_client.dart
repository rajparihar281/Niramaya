import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import 'models/user_model.dart';
import 'models/patient_record.dart';

class SupabaseClientHelper {
  SupabaseClientHelper._();

  static bool isOffline = false;

  static SupabaseClient get client => Supabase.instance.client;

  /// Initialize Supabase — call once in main.dart.
  /// Sets isOffline=true if the host is unreachable at cold start.
  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        anonKey: AppConstants.supabaseAnonKey,
        realtimeClientOptions: const RealtimeClientOptions(
          timeout: Duration(seconds: 30),
        ),
      );
      isOffline = false;
    } catch (e) {
      debugPrint('[Supabase] ⚠ Initialize failed (offline mode): $e');
      isOffline = true;
    }
  }

  // ── Auth: registered_users ──────────────────────────────────────────────

  /// Look up a user by ABHA ID. Returns null if not found or offline.
  static Future<UserModel?> findUserByAbha(String abhaId) async {
    if (isOffline) return null;
    try {
      final response = await client
          .from('registered_users')
          .select('id, abha_id, phone, email')
          .eq('abha_id', abhaId)
          .maybeSingle();
      if (response == null) return null;
      return UserModel.fromJson(response);
    } catch (e) {
      debugPrint('[Supabase] findUserByAbha failed: $e');
      return null;
    }
  }

  /// Create a new user with ABHA ID. Returns null if offline or on error.
  static Future<UserModel?> createUser(String abhaId) async {
    if (isOffline) return null;
    try {
      final response = await client
          .from('registered_users')
          .insert({'abha_id': abhaId})
          .select('id, abha_id, phone, email')
          .single();
      return UserModel.fromJson(response);
    } catch (e) {
      debugPrint('[Supabase] createUser failed: $e');
      return null;
    }
  }

  // ── Patient Records ─────────────────────────────────────────────────────

  /// Fetch patient record for a given user_id. Returns null if offline.
  static Future<PatientRecord?> getPatientRecord(String userId) async {
    if (isOffline) return null;
    try {
      final response = await client
          .from('patient_records')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      if (response == null) return null;
      return PatientRecord.fromJson(response);
    } catch (e) {
      debugPrint('[Supabase] getPatientRecord failed: $e');
      return null;
    }
  }

  /// Upsert a patient record. Returns null if offline or on error.
  static Future<PatientRecord?> upsertPatientRecord(PatientRecord record) async {
    if (isOffline) return null;
    try {
      final response = await client
          .from('patient_records')
          .upsert(record.toJson(), onConflict: 'user_id')
          .select()
          .single();
      return PatientRecord.fromJson(response);
    } catch (e) {
      debugPrint('[Supabase] upsertPatientRecord failed: $e');
      return null;
    }
  }

  // ── Consent / Hospital Access ───────────────────────────────────────────

  /// Get consent settings for a patient hash. Returns null if offline.
  static Future<Map<String, dynamic>?> getConsentSettings(
      String patientHash) async {
    if (isOffline) return null;
    try {
      return await client
          .from('hospital_access')
          .select()
          .eq('patient_hash', patientHash)
          .maybeSingle();
    } catch (e) {
      debugPrint('[Supabase] getConsentSettings failed: $e');
      return null;
    }
  }

  /// Upsert consent settings. No-op if offline.
  static Future<void> upsertConsentSettings({
    required String patientHash,
    required String userId,
    required bool accessGranted,
    required bool govShareEnabled,
  }) async {
    if (isOffline) return;
    try {
      await client.from('hospital_access').upsert({
        'patient_hash': patientHash,
        'user_id': userId,
        'access_granted': accessGranted,
        'gov_share_enabled': govShareEnabled,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      }, onConflict: 'patient_hash');
    } catch (e) {
      debugPrint('[Supabase] upsertConsentSettings failed: $e');
    }
  }

  // ── Hospitals ───────────────────────────────────────────────────────────

  /// Find a hospital by name. Returns null if offline.
  static Future<Map<String, dynamic>?> findHospitalByName(String name) async {
    if (isOffline) return null;
    try {
      return await client
          .from('hospitals')
          .select()
          .eq('name', name)
          .maybeSingle();
    } catch (e) {
      debugPrint('[Supabase] findHospitalByName failed: $e');
      return null;
    }
  }
}
