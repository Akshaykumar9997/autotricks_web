enum UserRole {
  admin,
  client;

  static UserRole fromString(String? role) {
    if (role == null) return UserRole.client;
    switch (role.toUpperCase()) {
      case 'ADMIN':
        return UserRole.admin;
      case 'CLIENT':
      default:
        return UserRole.client;
    }
  }

  String get dbValue {
    switch (this) {
      case UserRole.admin:
        return 'ADMIN';
      case UserRole.client:
        return 'CLIENT';
    }
  }
}

/// User profile linked to Supabase public.profiles table
class UserProfile {
  final String id;
  final String fullName;
  final UserRole role;
  final String? clientId;

  const UserProfile({
    required this.id,
    required this.fullName,
    required this.role,
    this.clientId,
  });

  bool get isAdmin => role == UserRole.admin;
  bool get isClient => role == UserRole.client;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'User',
      role: UserRole.fromString(json['role'] as String?),
      clientId: json['client_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'full_name': fullName,
        'role': role.dbValue,
        'client_id': clientId,
      };
}
