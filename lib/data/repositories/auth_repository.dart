import 'package:supabase_flutter/supabase_flutter.dart';

class UserProfile {
  final String id;
  final String email;
  final String fullName;
  final String role; // 'ADMIN' or 'CLIENT'
  final String? clientId;

  const UserProfile({
    required this.id,
    required this.email,
    required this.fullName,
    required this.role,
    this.clientId,
  });

  bool get isAdmin => role.toUpperCase() == 'ADMIN';
  bool get isClient => role.toUpperCase() == 'CLIENT';
}

abstract class AuthRepository {
  Future<UserProfile> signIn({
    required String email,
    required String password,
  });
  Future<void> signOut();
  UserProfile? getCurrentProfile();
  Future<UserProfile?> refreshCurrentProfile();
  Stream<AuthState> get authStateChanges;
}

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;
  UserProfile? _cachedProfile;

  SupabaseAuthRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  UserProfile? getCurrentProfile() {
    if (_cachedProfile != null) return _cachedProfile;

    final user = _client.auth.currentUser;
    if (user == null) return null;

    final metadata = user.userMetadata ?? {};
    final role = metadata['role']?.toString() ?? 'ADMIN';
    final fullName = metadata['full_name']?.toString() ??
        (role == 'CLIENT' ? 'Client' : 'Admin');

    _cachedProfile = UserProfile(
      id: user.id,
      email: user.email ?? '',
      fullName: fullName,
      role: role,
    );

    return _cachedProfile;
  }

  @override
  Future<UserProfile?> refreshCurrentProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _cachedProfile = null;
      return null;
    }

    try {
      final profileData = await _client
          .from('profiles')
          .select('role, full_name, client_id')
          .eq('id', user.id)
          .maybeSingle();

      if (profileData != null) {
        final role = profileData['role']?.toString() ?? 'ADMIN';
        final fullName = profileData['full_name']?.toString() ??
            (role == 'CLIENT' ? 'Client' : 'Admin');
        final clientId = profileData['client_id']?.toString();

        _cachedProfile = UserProfile(
          id: user.id,
          email: user.email ?? '',
          fullName: fullName,
          role: role,
          clientId: clientId,
        );
        return _cachedProfile;
      }
    } catch (_) {
      // If table query fails, fallback to metadata
    }

    return getCurrentProfile();
  }

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );

    final user = response.user;
    if (user == null) {
      throw const AuthException('Invalid login credentials');
    }

    // Query user's role from profiles table
    try {
      final profileData = await _client
          .from('profiles')
          .select('role, full_name, client_id')
          .eq('id', user.id)
          .maybeSingle();

      if (profileData != null) {
        final role = profileData['role']?.toString() ?? 'ADMIN';
        final fullName = profileData['full_name']?.toString() ??
            (role == 'CLIENT' ? 'Client' : 'Admin');
        final clientId = profileData['client_id']?.toString();

        _cachedProfile = UserProfile(
          id: user.id,
          email: user.email ?? email,
          fullName: fullName,
          role: role,
          clientId: clientId,
        );
        return _cachedProfile!;
      }
    } catch (_) {
      // If table query fails, fallback to metadata or default
    }

    _cachedProfile = UserProfile(
      id: user.id,
      email: user.email ?? email,
      fullName: user.userMetadata?['full_name']?.toString() ?? 'User',
      role: user.userMetadata?['role']?.toString() ?? 'CLIENT',
    );
    return _cachedProfile!;
  }

  @override
  Future<void> signOut() async {
    _cachedProfile = null;
    await _client.auth.signOut();
  }
}
