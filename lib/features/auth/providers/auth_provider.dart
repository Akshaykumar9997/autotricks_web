import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autotricks/core/config/env_config.dart';
import 'package:autotricks/features/auth/models/user_profile.dart';

enum AuthStatus {
  initial,
  unauthenticated,
  authenticating,
  authenticatedAdmin,
  authenticatedClient,
}

class AuthState {
  final AuthStatus status;
  final UserProfile? profile;
  final String? email;
  final String? errorMessage;

  const AuthState({
    this.status = AuthStatus.initial,
    this.profile,
    this.email,
    this.errorMessage,
  });

  bool get isAuthenticated =>
      status == AuthStatus.authenticatedAdmin ||
      status == AuthStatus.authenticatedClient;

  bool get isAdmin => status == AuthStatus.authenticatedAdmin;
  bool get isClient => status == AuthStatus.authenticatedClient;

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? profile,
    String? email,
    String? errorMessage,
  }) {
    return AuthState(
      status: status ?? this.status,
      profile: profile ?? this.profile,
      email: email ?? this.email,
      errorMessage: errorMessage,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  AuthState build() {
    // Check initial session
    Future.microtask(() => checkSession());
    return const AuthState(status: AuthStatus.initial);
  }

  Future<void> checkSession() async {
    if (state.status != AuthStatus.initial) {
      return;
    }

    final client = _supabase;
    if (client == null || !EnvConfig.isConfigured) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    final currentSession = client.auth.currentSession;
    if (currentSession == null) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
      return;
    }

    await _fetchProfileAndSetState(currentSession.user.id, currentSession.user.email);
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.authenticating, errorMessage: null);

    final client = _supabase;
    if (client == null) {
      // Mock login fallback if Supabase client is not available in local test env
      if (email.contains('client')) {
        signInAsMockClient(email: email);
      } else {
        signInAsMockAdmin(email: email);
      }
      return;
    }

    try {
      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final user = response.user;
      if (user == null) {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          errorMessage: 'Authentication failed. Please try again.',
        );
        return;
      }

      await _fetchProfileAndSetState(user.id, user.email);
    } on AuthException catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: e.message,
      );
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'An unexpected error occurred: ${e.toString()}',
      );
    }
  }

  Future<void> _fetchProfileAndSetState(String userId, String? email) async {
    final client = _supabase;
    if (client == null) return;

    try {
      final res = await client
          .from('profiles')
          .select('id, full_name, role, client_id')
          .eq('id', userId)
          .maybeSingle();

      if (res != null) {
        final profile = UserProfile.fromJson(res);
        if (profile.isAdmin) {
          state = AuthState(
            status: AuthStatus.authenticatedAdmin,
            profile: profile,
            email: email,
          );
        } else {
          state = AuthState(
            status: AuthStatus.authenticatedClient,
            profile: profile,
            email: email,
          );
        }
      } else {
        // Fallback for user without profile entry yet
        state = AuthState(
          status: AuthStatus.authenticatedClient,
          profile: UserProfile(
            id: userId,
            fullName: email?.split('@').first ?? 'User',
            role: UserRole.client,
          ),
          email: email,
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        errorMessage: 'Failed to retrieve user profile: $e',
      );
    }
  }

  void signInAsMockAdmin({
    String email = 'admin@autotricks.com',
    String name = 'Admin Alex',
  }) {
    if (kReleaseMode || !EnvConfig.enableDevAuth) {
      throw UnsupportedError('Mock authentication is prohibited in production builds.');
    }
    state = AuthState(
      status: AuthStatus.authenticatedAdmin,
      email: email,
      profile: UserProfile(
        id: 'mock-admin-001',
        fullName: name,
        role: UserRole.admin,
      ),
    );
  }

  void signInAsMockClient({
    String email = 'client@example.com',
    String name = 'Rohit Sharma',
  }) {
    if (kReleaseMode || !EnvConfig.enableDevAuth) {
      throw UnsupportedError('Mock authentication is prohibited in production builds.');
    }
    state = AuthState(
      status: AuthStatus.authenticatedClient,
      email: email,
      profile: UserProfile(
        id: 'mock-client-001',
        fullName: name,
        role: UserRole.client,
        clientId: 'mock-client-id',
      ),
    );
  }

  Future<void> signOut() async {
    try {
      await _supabase?.auth.signOut();
    } catch (_) {}
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);
