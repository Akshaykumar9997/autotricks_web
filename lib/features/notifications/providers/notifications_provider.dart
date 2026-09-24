import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/repositories/notifications_repository.dart';

/// Stream of all notifications for the current authenticated profile, ordered newest first.
final notificationsStreamProvider =
    StreamProvider.autoDispose<List<NotificationModel>>((ref) {
  final repo = ref.watch(notificationsRepositoryProvider);
  return repo.streamNotifications();
});

/// Count of unread notifications for the current authenticated profile.
final unreadNotificationCountProvider = Provider.autoDispose<int>((ref) {
  final streamAsync = ref.watch(notificationsStreamProvider);
  return streamAsync.maybeWhen(
    data: (list) => list.where((n) => !n.isRead).length,
    orElse: () => 0,
  );
});

/// Controller for marking notifications as read / mark all as read.
class NotificationActionsNotifier extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncValue.data(null);

  Future<void> markAsRead(String id) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(notificationsRepositoryProvider);
      await repo.markAsRead(id);
    });
  }

  Future<void> markAllAsRead() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(notificationsRepositoryProvider);
      await repo.markAllAsRead();
    });
  }
}

final notificationActionsProvider =
    NotifierProvider<NotificationActionsNotifier, AsyncValue<void>>(
  NotificationActionsNotifier.new,
);
