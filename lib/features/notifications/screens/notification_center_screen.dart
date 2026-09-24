import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/notification_model.dart';
import '../../../data/repositories/notifications_repository.dart';
import '../../../design_system/components/auto_app_bar.dart';
import '../../../design_system/components/auto_badge.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../providers/notifications_provider.dart';

/// Notification Center Screen for both Admin and Client portals.
class NotificationCenterScreen extends ConsumerWidget {
  final bool isAdmin;

  const NotificationCenterScreen({
    super.key,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsStreamProvider);
    final unreadCount = ref.watch(unreadNotificationCountProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AutoAppBar(
        title: 'Notifications',
        subtitle: isAdmin ? 'Admin Operations' : 'Client Updates',
        showBack: true,
        showLogo: false,
        onBack: () => context.pop(),
        actions: [
          if (unreadCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: TextButton.icon(
                key: const Key('mark_all_read_button'),
                onPressed: () async {
                  await ref
                      .read(notificationActionsProvider.notifier)
                      .markAllAsRead();
                },
                icon: const Icon(
                  Icons.done_all_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
                label: Text(
                  'Mark all read',
                  style: AppTypography.labelMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: notificationsAsync.when(
        data: (notifications) {
          if (notifications.isEmpty) {
            return _buildEmptyState();
          }

          // Ensure sorted newest first
          final sortedList = List<NotificationModel>.from(notifications)
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface1,
            onRefresh: () async {
              ref.invalidate(notificationsStreamProvider);
            },
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              itemCount: sortedList.length,
              separatorBuilder: (_, _) =>
                  const SizedBox(height: AppSpacing.xs),
              itemBuilder: (context, index) {
                final notification = sortedList[index];
                return _buildNotificationCard(context, ref, notification);
              },
            ),
          );
        },
        loading: () => _buildLoadingState(),
        error: (err, _) => AutoErrorState(
          title: 'Unable to load notifications',
          message: err.toString(),
          onRetry: () => ref.refresh(notificationsStreamProvider),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.surface2,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                size: 36,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No notifications yet',
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'You are all caught up! Updates regarding service jobs, quotations, and approvals will appear here.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.md),
      itemCount: 6,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, _) =>
          const AutoSkeleton(height: 84, width: double.infinity),
    );
  }

  Widget _buildNotificationCard(
    BuildContext context,
    WidgetRef ref,
    NotificationModel notification,
  ) {
    final isUnread = !notification.isRead;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: AppRadius.radiusMd,
        onTap: () async {
          if (isUnread) {
            await ref
                .read(notificationActionsProvider.notifier)
                .markAsRead(notification.id);
          }
          final repo = ref.read(notificationsRepositoryProvider);
          final route = await repo.resolveTargetRoute(
            notification,
            isAdmin: isAdmin,
          );
          if (context.mounted && route != null && route.isNotEmpty) {
            context.push(route);
          }
        },
        child: Container(
          decoration: BoxDecoration(
            color: isUnread ? AppColors.surface2 : AppColors.surface1,
            borderRadius: AppRadius.radiusMd,
            border: Border.all(
              color: isUnread
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : AppColors.border,
              width: isUnread ? 1.5 : 1.0,
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.sm),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Notification category/type icon
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: notification.iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  notification.icon,
                  color: notification.iconColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Content body
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: AppTypography.bodyLargeEmphasis.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight:
                                  isUnread ? FontWeight.w700 : FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: AppSpacing.xs),
                          Container(
                            key: Key('unread_dot_${notification.id}'),
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.message,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Row(
                      children: [
                        AutoBadge(
                          label: notification.typeLabel,
                          color: notification.iconColor,
                          showDot: false,
                        ),
                        const Spacer(),
                        Text(
                          DateFormatter.timeAgo(notification.createdAt),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        if (isUnread) ...[
                          const SizedBox(width: AppSpacing.xs),
                          IconButton(
                            key: Key('mark_read_btn_${notification.id}'),
                            icon: const Icon(
                              Icons.check_circle_outline_rounded,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                            tooltip: 'Mark as read',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 24,
                              minHeight: 24,
                            ),
                            onPressed: () async {
                              await ref
                                  .read(notificationActionsProvider.notifier)
                                  .markAsRead(notification.id);
                            },
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
