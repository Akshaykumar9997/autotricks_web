import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autotricks/core/services/fcm_service.dart';
import 'package:autotricks/data/repositories/auth_repository.dart';
import 'package:autotricks/data/repositories/device_tokens_repository.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return SupabaseAuthRepository();
});

class AuthState {
  final bool isLoading;
  final String? errorMessage;
  final UserProfile? profile;

  const AuthState({
    this.isLoading = false,
    this.errorMessage,
    this.profile,
  });

  bool get isAuthenticated => profile != null;
  bool get isAdmin => profile?.isAdmin ?? false;
  bool get isClient => profile?.isClient ?? false;

  AuthState copyWith({
    bool? isLoading,
    String? errorMessage,
    UserProfile? profile,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
      profile: profile ?? this.profile,
    );
  }
}

class AuthNotifier extends Notifier<AuthState> {
  @override
  AuthState build() {
    final repo = ref.watch(authRepositoryProvider);
    final currentProfile = repo.getCurrentProfile();

    // If a session exists, trigger async refresh in background to populate role & clientId from profiles table
    if (currentProfile != null) {
      Future.microtask(() async {
        final refreshed = await repo.refreshCurrentProfile();
        if (refreshed != null && refreshed != state.profile) {
          state = state.copyWith(profile: refreshed);
        }
        if (state.isAuthenticated) {
          _syncDeviceToken();
        }
      });
    }

    return AuthState(profile: currentProfile);
  }

  void _syncDeviceToken() {
    if (!state.isAuthenticated) return;
    try {
      final fcmService = ref.read(fcmServiceProvider);
      final tokensRepo = ref.read(deviceTokensRepositoryProvider);
      unawaited(fcmService.syncTokenWithBackend(repository: tokensRepo));
    } catch (e) {
      debugPrint('[Auth] Error syncing device token: $e');
    }
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final repo = ref.read(authRepositoryProvider);
      final profile = await repo.signIn(
        email: email,
        password: password,
      );
      state = state.copyWith(isLoading: false, profile: profile);
      _syncDeviceToken();
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return false;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    try {
      final fcmService = ref.read(fcmServiceProvider);
      final tokensRepo = ref.read(deviceTokensRepositoryProvider);
      await fcmService.deactivateCurrentToken(repository: tokensRepo);
    } catch (e) {
      debugPrint('[Auth] Error deactivating device token on logout: $e');
    }
    final repo = ref.read(authRepositoryProvider);
    await repo.signOut();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);

