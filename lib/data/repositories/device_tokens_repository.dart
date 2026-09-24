import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/device_token_model.dart';

abstract class DeviceTokensRepository {
  Future<void> upsertToken({
    required String fcmToken,
    required String platform,
    String? deviceName,
  });

  Future<void> deactivateToken(String fcmToken);

  Future<List<DeviceTokenModel>> getMyActiveTokens();
}

class SupabaseDeviceTokensRepository implements DeviceTokensRepository {
  final SupabaseClient _client;

  SupabaseDeviceTokensRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  @override
  Future<void> upsertToken({
    required String fcmToken,
    required String platform,
    String? deviceName,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      debugPrint('[DeviceTokensRepo] No authenticated user, skipping token registration');
      return;
    }

    try {
      // Primary: Call canonical RPC
      await _client.rpc('register_device_token', params: {
        'p_fcm_token': fcmToken,
        'p_platform': platform,
        'p_device_name': deviceName,
      });
    } catch (e) {
      debugPrint('[DeviceTokensRepo] register_device_token RPC failed, trying direct upsert: $e');
      // Secondary fallback: Direct table upsert
      await _client.from('device_tokens').upsert(
        {
          'profile_id': user.id,
          'fcm_token': fcmToken,
          'platform': platform,
          'device_name': deviceName,
          'is_active': true,
          'last_seen_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'fcm_token',
      );
    }
  }

  @override
  Future<void> deactivateToken(String fcmToken) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    try {
      // Primary: Call canonical RPC
      await _client.rpc('deactivate_device_token', params: {
        'p_fcm_token': fcmToken,
      });
    } catch (e) {
      debugPrint('[DeviceTokensRepo] deactivate_device_token RPC failed, trying direct update: $e');
      // Secondary fallback: Direct table update
      await _client
          .from('device_tokens')
          .update({
            'is_active': false,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('fcm_token', fcmToken)
          .eq('profile_id', user.id);
    }
  }

  @override
  Future<List<DeviceTokenModel>> getMyActiveTokens() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final response = await _client
        .from('device_tokens')
        .select('*')
        .eq('profile_id', user.id)
        .eq('is_active', true)
        .order('created_at', ascending: false);

    return (response as List)
        .map((item) => DeviceTokenModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }
}

final deviceTokensRepositoryProvider = Provider<DeviceTokensRepository>((ref) {
  return SupabaseDeviceTokensRepository();
});
