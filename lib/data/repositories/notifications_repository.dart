import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

abstract class NotificationsRepository {
  Future<List<NotificationModel>> getNotifications({int limit = 50});
  Future<int> getUnreadCount();
  Future<void> markAsRead(String id);
  Future<void> markAllAsRead();
  Stream<List<NotificationModel>> streamNotifications({int limit = 50});
  RealtimeChannel subscribeToNotifications(void Function() onNotificationChanged);
  Future<String?> resolveTargetRoute(NotificationModel notification, {required bool isAdmin});
}

class SupabaseNotificationsRepository implements NotificationsRepository {
  final SupabaseClient _client;

  SupabaseNotificationsRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<NotificationModel>> getNotifications({int limit = 50}) async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    final response = await _client
        .from('notifications')
        .select('*')
        .eq('profile_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit);

    return (response as List)
        .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  @override
  Future<int> getUnreadCount() async {
    final user = _client.auth.currentUser;
    if (user == null) return 0;

    final response = await _client
        .from('notifications')
        .select('id')
        .eq('profile_id', user.id)
        .eq('is_read', false);

    return (response as List).length;
  }

  @override
  Future<void> markAsRead(String id) async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id).eq('profile_id', user.id);
  }

  @override
  Future<void> markAllAsRead() async {
    final user = _client.auth.currentUser;
    if (user == null) return;

    await _client.from('notifications').update({
      'is_read': true,
      'read_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('profile_id', user.id).eq('is_read', false);
  }

  @override
  Stream<List<NotificationModel>> streamNotifications({int limit = 50}) {
    final user = _client.auth.currentUser;
    if (user == null) return Stream.value([]);

    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('profile_id', user.id)
        .order('created_at', ascending: false)
        .limit(limit)
        .map((data) => data.map((item) => NotificationModel.fromJson(item)).toList());
  }

  @override
  RealtimeChannel subscribeToNotifications(void Function() onNotificationChanged) {
    final user = _client.auth.currentUser;
    final profileId = user?.id ?? 'all';
    return _client
        .channel('public:notifications:$profileId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'notifications',
          filter: user != null
              ? PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'profile_id',
                  value: user.id,
                )
              : null,
          callback: (payload) {
            onNotificationChanged();
          },
        )
        .subscribe();
  }

  @override
  Future<String?> resolveTargetRoute(
    NotificationModel notification, {
    required bool isAdmin,
  }) async {
    final entityType = notification.entityType;
    final entityId = notification.entityId;

    if (entityType == null || entityId == null) {
      return isAdmin ? '/admin' : '/client';
    }

    try {
      switch (entityType) {
        case 'service_request':
          return isAdmin ? '/admin/requests/$entityId' : '/client/services/$entityId';

        case 'quotation_revision':
          final rev = await _client
              .from('quotation_revisions')
              .select('quotation_id')
              .eq('id', entityId)
              .maybeSingle();
          final qId = rev != null ? rev['quotation_id'] as String? : null;
          if (qId != null) {
            return isAdmin ? '/admin/quotes/$qId' : '/client/quotes/$qId';
          }
          return isAdmin ? '/admin/quotes' : '/client/quotes';

        case 'quotation':
          return isAdmin ? '/admin/quotes/$entityId' : '/client/quotes/$entityId';

        case 'quotation_change_request':
          final cr = await _client
              .from('quotation_change_requests')
              .select('quotation_revisions(quotation_id)')
              .eq('id', entityId)
              .maybeSingle();
          String? qId;
          if (cr != null && cr['quotation_revisions'] != null) {
            final qr = cr['quotation_revisions'] as Map<String, dynamic>;
            qId = qr['quotation_id'] as String?;
          }
          if (qId != null) {
            return isAdmin
                ? '/admin/quotes/$qId/change-requests?requestId=$entityId'
                : '/client/quotes/$qId';
          }
          return isAdmin ? '/admin/quotes' : '/client/quotes';

        case 'service_job':
          if (isAdmin) {
            return '/admin/jobs/$entityId';
          } else {
            final job = await _client
                .from('service_jobs')
                .select('service_request_id')
                .eq('id', entityId)
                .maybeSingle();
            final srId = job != null ? job['service_request_id'] as String? : null;
            return srId != null ? '/client/services/$srId' : '/client/services';
          }

        case 'service_work_item':
          final item = await _client
              .from('service_work_items')
              .select('service_job_id, service_jobs(service_request_id)')
              .eq('id', entityId)
              .maybeSingle();
          if (item != null) {
            final jobId = item['service_job_id'] as String?;
            if (isAdmin && jobId != null) {
              return '/admin/jobs/$jobId';
            }
            if (!isAdmin && item['service_jobs'] != null) {
              final sj = item['service_jobs'] as Map<String, dynamic>;
              final srId = sj['service_request_id'] as String?;
              if (srId != null) return '/client/services/$srId';
            }
          }
          return isAdmin ? '/admin' : '/client/services';

        case 'vehicle_correction_request':
          return isAdmin ? '/admin/vehicles' : '/client/vehicles';

        default:
          return isAdmin ? '/admin' : '/client';
      }
    } catch (e) {
      debugPrint('Error resolving notification target route: $e');
      return isAdmin ? '/admin' : '/client';
    }
  }
}

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return SupabaseNotificationsRepository();
});
