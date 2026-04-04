import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants.dart';

class SupabaseService {
  SupabaseService._();

  static SupabaseClient? _client;
  static bool isOffline = false;

  static Future<void> initialize() async {
    try {
      await Supabase.initialize(
        url: AppConstants.supabaseUrl,
        anonKey: AppConstants.supabaseAnonKey,
      );
      _client = Supabase.instance.client;
      isOffline = false;
    } catch (e) {
      debugPrint('[Supabase] ⚠ Initialize failed: $e');
      isOffline = true;
    }
  }

  static SupabaseClient get client {
    if (_client == null) {
      throw StateError(
        'SupabaseService not initialized. Call initialize() first.',
      );
    }
    return _client!;
  }
}
