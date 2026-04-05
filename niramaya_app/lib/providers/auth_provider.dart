
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../core/constants.dart';
import '../data/supabase_client.dart';
import '../data/models/user_model.dart';

// ── Auth State ────────────────────────────────────────────────────────────

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final UserModel? user;
  final bool isLoading;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.isLoading = false,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    UserModel? user,
    bool? isLoading,
    String? error,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ── Auth Notifier ─────────────────────────────────────────────────────────

class AuthNotifier extends StateNotifier<AuthState> {
  final FlutterSecureStorage _storage;

  AuthNotifier(this._storage) : super(const AuthState());

  /// Check if user is already logged in (persistent session)
  Future<bool> checkPersistentLogin() async {
    final userId = await _storage.read(key: AppConstants.storageUserId);
    final abhaId = await _storage.read(key: AppConstants.storageAbhaId);

    if (userId != null && abhaId != null) {
      state = AuthState(
        status: AuthStatus.authenticated,
        user: UserModel(id: userId, abhaId: abhaId),
      );
      return true;
    }

    state = const AuthState(status: AuthStatus.unauthenticated);
    return false;
  }

  /// Login with ABHA ID — queries Supabase, creates user if new
  Future<bool> loginWithAbha(String abhaId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      // Strip hyphens for storage/query
      final cleanAbha = abhaId.replaceAll('-', '');

      // Try to find existing user or create a new one
      final existing = await SupabaseClientHelper.findUserByAbha(cleanAbha);
      final UserModel? user = existing ?? await SupabaseClientHelper.createUser(cleanAbha);

      if (user == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Could not create account. Check your connection.',
        );
        return false;
      }

      // Persist session
      await _storage.write(key: AppConstants.storageUserId, value: user.id);
      await _storage.write(key: AppConstants.storageAbhaId, value: user.abhaId);

      state = AuthState(
        status: AuthStatus.authenticated,
        user: user,
      );
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Login failed: ${e.toString()}',
      );
      return false;
    }
  }

  /// Logout — clear storage and reset state
  Future<void> logout() async {
    await _storage.delete(key: AppConstants.storageUserId);
    await _storage.delete(key: AppConstants.storageAbhaId);
    await _storage.delete(key: AppConstants.storageCachedPatient);
    state = const AuthState(status: AuthStatus.unauthenticated);
  }

  String? get userId => state.user?.id;
  String? get abhaId => state.user?.abhaId;
}

// ── Providers ─────────────────────────────────────────────────────────────

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return AuthNotifier(storage);
});
