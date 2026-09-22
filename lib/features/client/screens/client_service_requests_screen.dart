import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/service_request_model.dart';
import '../../../design_system/components/auto_badge.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_dialog.dart';
import '../../../design_system/components/auto_empty_state.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../providers/client_portal_provider.dart';
import '../utils/client_status_helper.dart';

/// C05 — Service Requests Screen conforming to approved Stitch C05.
class ClientServiceRequestsScreen extends ConsumerWidget {
  const ClientServiceRequestsScreen({super.key});

  void _showConciergeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AutoDialog(
        title: 'AutoTricks Concierge',
        message:
            'For updates or questions regarding your service requests, please reach out to our service desk or your assigned service advisor.',
        confirmLabel: 'Understood',
        onConfirm: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allRequestsAsync = ref.watch(clientServiceRequestsProvider);
    final filteredRequestsAsync = ref.watch(filteredClientServiceRequestsProvider);
    final activeFilter = ref.watch(clientServiceFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface1,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: AppSpacing.margin,
        title: Row(
          children: [
            Image.asset(
              AppAssets.logoMaster,
              height: 28,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Services',
              style: AppTypography.headlineSm.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.margin),
            child: CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.person, size: 18, color: Colors.white),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface2,
        onRefresh: () async {
          ref.invalidate(clientServiceRequestsProvider);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.margin,
            vertical: AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Section: Title & Active Count Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Service Requests',
                      style: AppTypography.headlineMd.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  allRequestsAsync.maybeWhen(
                    data: (List<ServiceRequestModel> list) {
                      final activeCount = list
                          .where((sr) => ClientStatusHelper.isActive(
                                requestStatus: sr.status,
                                jobStatus: sr.jobStatus,
                              ))
                          .length;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: AppRadius.radiusPill,
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: AppColors.info,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$activeCount Active',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'View and track your service requests.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Filter Chips Carousel with real data counts
              allRequestsAsync.maybeWhen(
                data: (allList) => _buildFilterChips(
                  ref,
                  activeFilter: activeFilter,
                  allRequests: allList,
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.md),

              // Request Cards List
              filteredRequestsAsync.when(
                data: (List<ServiceRequestModel> filteredList) {
                  if (filteredList.isEmpty) {
                    final isAll = activeFilter == 'all';
                    return AutoEmptyState(
                      title: isAll ? 'No Service Requests' : 'No Requests Found',
                      message: isAll
                          ? 'You have not submitted any service requests yet.'
                          : 'There are no service requests in this category right now.',
                      icon: isAll
                          ? Icons.car_repair_outlined
                          : Icons.search_off_outlined,
                      actionLabel: 'Contact Concierge',
                      onAction: () => _showConciergeDialog(context),
                    );
                  }

                  return Column(
                    children: filteredList
                        .map((sr) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              child: _buildRequestCard(context, sr),
                            ))
                        .toList(),
                  );
                },
                loading: () => const Column(
                  children: [
                    AutoSkeleton(height: 160),
                    SizedBox(height: AppSpacing.md),
                    AutoSkeleton(height: 160),
                  ],
                ),
                error: (err, _) => AutoErrorState(
                  title: 'Unable to Load Requests',
                  message: 'Unable to load service requests.',
                  onRetry: () => ref.invalidate(clientServiceRequestsProvider),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Concierge Help Note
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(
                        Icons.support_agent,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need help with your service request?',
                            style: AppTypography.bodyMdEmphasis.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Contact AutoTricks for live updates regarding your vehicle service.',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          GestureDetector(
                            onTap: () => _showConciergeDialog(context),
                            child: Text(
                              'Contact AutoTricks',
                              style: AppTypography.labelMd.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChips(
    WidgetRef ref, {
    required String activeFilter,
    required List<ServiceRequestModel> allRequests,
  }) {
    final activeCount = allRequests
        .where((sr) => ClientStatusHelper.isActive(
              requestStatus: sr.status,
              jobStatus: sr.jobStatus,
            ))
        .length;
    final completedCount = allRequests
        .where((sr) => ClientStatusHelper.isCompleted(
              requestStatus: sr.status,
              jobStatus: sr.jobStatus,
            ))
        .length;
    final cancelledCount = allRequests
        .where((sr) => ClientStatusHelper.isCancelled(
              requestStatus: sr.status,
              jobStatus: sr.jobStatus,
            ))
        .length;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildChip(
            ref,
            filterKey: 'all',
            label: 'All (${allRequests.length})',
            isSelected: activeFilter == 'all',
          ),
          const SizedBox(width: 8),
          _buildChip(
            ref,
            filterKey: 'active',
            label: 'Active ($activeCount)',
            isSelected: activeFilter == 'active',
          ),
          const SizedBox(width: 8),
          _buildChip(
            ref,
            filterKey: 'completed',
            label: 'Completed ($completedCount)',
            isSelected: activeFilter == 'completed',
          ),
          const SizedBox(width: 8),
          _buildChip(
            ref,
            filterKey: 'cancelled',
            label: 'Cancelled ($cancelledCount)',
            isSelected: activeFilter == 'cancelled',
          ),
        ],
      ),
    );
  }

  Widget _buildChip(
    WidgetRef ref, {
    required String filterKey,
    required String label,
    required bool isSelected,
  }) {
    return InkWell(
      onTap: () {
        ref.read(clientServiceFilterProvider.notifier).setFilter(filterKey);
      },
      borderRadius: AppRadius.radiusPill,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : AppColors.surface1,
          borderRadius: AppRadius.radiusPill,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderSubtle,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, ServiceRequestModel sr) {
    final statusInfo = ClientStatusHelper.getStatusInfo(
      requestStatus: sr.status,
      jobStatus: sr.jobStatus,
    );

    return AutoCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Vehicle Row & Status Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.directions_car,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sr.vehicleTitle,
                      style: AppTypography.bodyLgEmphasis.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (sr.vehiclePlate.isNotEmpty)
                      Text(
                        sr.vehiclePlate,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          fontFamily: 'monospace',
                        ),
                      ),
                  ],
                ),
              ),
              AutoBadge(
                label: statusInfo.label,
                color: statusInfo.color,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Requested Works Box
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface2.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.build,
                      size: 14,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Requested Works',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  sr.customerServiceDescription,
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Next Step Hint Banner (if active)
          if (statusInfo.nextActionHint != null &&
              ClientStatusHelper.isActive(
                requestStatus: sr.status,
                jobStatus: sr.jobStatus,
              )) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(AppRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.hourglass_top,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      statusInfo.nextActionHint!,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],

          // Card Footer
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_outlined,
                      size: 13,
                      color: AppColors.textMuted,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        'Submitted: ${DateFormatter.formatDate(sr.createdAt)}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => context.push('/client/services/${sr.id}'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Request',
                      style: AppTypography.bodyMdEmphasis.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
