import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';
import 'models/user_model.dart';
import 'models/patient_record.dart';

class SupabaseClientHelper {
  SupabaseClientHelper._();

  static SupabaseClient get client => Supabase.instance.client;

  /// Initialize Supabase — call once in main.dart
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: AppConstants.supabaseUrl,
      anonKey: AppConstants.supabaseAnonKey,
    );
  }

  // ── Auth: registered_users ──────────────────────────────────────────────

  /// Look up a user by ABHA ID. Returns null if not found.
  static Future<UserModel?> findUserByAbha(String abhaId) async {
    final response = await client
        .from('registered_users')
        .select('id, abha_id, phone, email')
        .eq('abha_id', abhaId)
        .maybeSingle();

    if (response == null) return null;
    return UserModel.fromJson(response);
  }

  /// Create a new user with ABHA ID. Returns the created user.
  static Future<UserModel> createUser(String abhaId) async {
    final response = await client
        .from('registered_users')
        .insert({'abha_id': abhaId})
        .select('id, abha_id, phone, email')
        .single();

    return UserModel.fromJson(response);
  }

  // ── Patient Records ─────────────────────────────────────────────────────

  /// Fetch patient record for a given user_id.
  static Future<PatientRecord?> getPatientRecord(String userId) async {
    final response = await client
        .from('patient_records')
        .select()
        .eq('user_id', userId)
        .maybeSingle();

    if (response == null) return null;
    return PatientRecord.fromJson(response);
  }

  /// Upsert (insert or update) a patient record.
  static Future<PatientRecord> upsertPatientRecord(PatientRecord record) async {
    final data = record.toJson();

    final response = await client
        .from('patient_records')
        .upsert(data, onConflict: 'user_id')
        .select()
        .single();

    return PatientRecord.fromJson(response);
  }

  // ── Consent / Hospital Access ───────────────────────────────────────────

  /// Get consent settings for a patient hash.
  static Future<Map<String, dynamic>?> getConsentSettings(String patientHash) async {
    final response = await client
        .from('hospital_access')
        .select()
        .eq('patient_hash', patientHash)
        .maybeSingle();

    return response;
  }

  /// Upsert consent settings.
  static Future<void> upsertConsentSettings({
    required String patientHash,
    required String userId,
    required bool accessGranted,
    required bool govShareEnabled,
  }) async {
    await client.from('hospital_access').upsert({
      'patient_hash': patientHash,
      'user_id': userId,
      'access_granted': accessGranted,
      'gov_share_enabled': govShareEnabled,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'patient_hash');
  }

  // ── Hospitals (for dispatch tracking) ──────────────────────────────────

  /// Find a hospital by name (for getting coordinates post-dispatch).
  static Future<Map<String, dynamic>?> findHospitalByName(String name) async {
    final response = await client
        .from('hospitals')
        .select()
        .eq('name', name)
        .maybeSingle();

    return response;
  }
}
