import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autotricks/data/repositories/auth_repository.dart';

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
    return AuthState(profile: currentProfile);
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
    final repo = ref.read(authRepositoryProvider);
    await repo.signOut();
    state = const AuthState();
  }
}

final authProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
