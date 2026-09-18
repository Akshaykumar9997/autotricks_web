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
}

abstract class AuthRepository {
  Future<UserProfile> signIn({
    required String email,
    required String password,
  });
  Future<void> signOut();
  UserProfile? getCurrentProfile();
  Stream<AuthState> get authStateChanges;
}

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _client;

  SupabaseAuthRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  @override
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  @override
  UserProfile? getCurrentProfile() {
    final user = _client.auth.currentUser;
    if (user == null) return null;

    final metadata = user.userMetadata ?? {};
    return UserProfile(
      id: user.id,
      email: user.email ?? '',
      fullName: metadata['full_name']?.toString() ?? 'Admin',
      role: metadata['role']?.toString() ?? 'ADMIN',
    );
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
        final fullName = profileData['full_name']?.toString() ?? 'Admin';
        final clientId = profileData['client_id']?.toString();

        return UserProfile(
          id: user.id,
          email: user.email ?? email,
          fullName: fullName,
          role: role,
          clientId: clientId,
        );
      }
    } catch (_) {
      // If table query fails, fallback to metadata or default Admin
    }

    return UserProfile(
      id: user.id,
      email: user.email ?? email,
      fullName: user.userMetadata?['full_name']?.toString() ?? 'Admin',
      role: 'ADMIN',
    );
  }

  @override
  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}
