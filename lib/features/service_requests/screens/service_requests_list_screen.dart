import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../design_system/components/auto_app_bar.dart';
import '../../../design_system/components/auto_badge.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_empty_state.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/components/auto_toast.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../data/models/service_request_model.dart';
import '../providers/service_requests_provider.dart';

/// A03 — Service Requests List Screen conforming to approved Stitch A03.
class ServiceRequestsListScreen extends ConsumerStatefulWidget {
  final String? initialFilter;

  const ServiceRequestsListScreen({super.key, this.initialFilter});

  @override
  ConsumerState<ServiceRequestsListScreen> createState() =>
      _ServiceRequestsListScreenState();
}

class _ServiceRequestsListScreenState
    extends ConsumerState<ServiceRequestsListScreen> {
  late final TextEditingController _searchController;

  static const _filters = [
    {'key': 'ALL', 'label': 'All'},
    {'key': 'NEW', 'label': 'New'},
    {'key': 'UNDER_REVIEW', 'label': 'Under Review'},
    {'key': 'QUOTATION_CREATED', 'label': 'Quotation Created'},
    {'key': 'QUOTATION_SENT', 'label': 'Quotation Sent'},
    {'key': 'APPROVED', 'label': 'Approved'},
    {'key': 'CONVERTED_TO_JOB', 'label': 'Converted to Job'},
    {'key': 'CANCELLED', 'label': 'Cancelled'},
  ];

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();

    if (widget.initialFilter != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref
            .read(serviceRequestFilterProvider.notifier)
            .setFilter(widget.initialFilter!.toUpperCase());
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Color _getStatusStripeColor(String status) {
    switch (status.toUpperCase()) {
      case 'NEW':
        return AppColors.info;
      case 'UNDER_REVIEW':
        return AppColors.warning;
      case 'QUOTATION_CREATED':
      case 'QUOTATION_SENT':
        return AppColors.info;
      case 'APPROVED':
      case 'CONVERTED_TO_JOB':
        return AppColors.success;
      case 'CANCELLED':
        return AppColors.danger;
      default:
        return AppColors.textMuted;
    }
  }

  String _getActionLabel(String status) {
    switch (status.toUpperCase()) {
      case 'NEW':
        return 'Review Request';
      case 'UNDER_REVIEW':
        return 'Create Quote';
      case 'QUOTATION_CREATED':
        return 'Review Quote';
      case 'QUOTATION_SENT':
        return 'View Quote';
      case 'APPROVED':
        return 'Create Service Job';
      case 'CONVERTED_TO_JOB':
        return 'Open Service Job';
      default:
        return 'View Request';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filter = ref.watch(serviceRequestFilterProvider);
    final requestsAsync = ref.watch(serviceRequestsListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AutoAppBar(
        title: 'Requests',
        subtitle: 'Admin Operations',
        showLogo: true,
        hasUnreadNotifications: true,
        onNotificationTap: () {
          AutoToast.showInfo(context, 'Notifications are up to date.');
        },
      ),
      body: Stack(
        children: [
          RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: AppColors.surface1,
            onRefresh: () async {
              ref.invalidate(serviceRequestsListProvider);
            },
            child: CustomScrollView(
              slivers: [
                // Top Search & Title Bar
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Service Requests',
                                style: AppTypography.headlineSmall.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.filter_list,
                                      color: AppColors.textSecondary, size: 20),
                                  onPressed: () {
                                    AutoToast.showInfo(context, 'Status filter bar is active below.');
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.swap_vert,
                                      color: AppColors.textSecondary, size: 20),
                                  onPressed: () {
                                    AutoToast.showInfo(context, 'Ordered by newest intake first.');
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Search Bar
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.surface1,
                            borderRadius: AppRadius.radiusMd,
                            border: Border.all(color: AppColors.border, width: 1),
                          ),
                          child: TextField(
                            controller: _searchController,
                            onChanged: (val) {
                              ref
                                  .read(serviceRequestFilterProvider.notifier)
                                  .setSearchQuery(val);
                            },
                            style: AppTypography.bodyMediumEmphasis.copyWith(
                              color: AppColors.textPrimary,
                            ),
                            cursorColor: AppColors.primary,
                            decoration: InputDecoration(
                              hintText: 'Search request #, customer, vehicle...',
                              hintStyle: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textMuted,
                              ),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: AppColors.textMuted,
                                size: 20,
                              ),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close,
                                          color: AppColors.textMuted, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        ref
                                            .read(serviceRequestFilterProvider.notifier)
                                            .setSearchQuery('');
                                      },
                                    )
                                  : null,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Filter Tabs Horizontal List
                SliverToBoxAdapter(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: _filters.map((f) {
                        final isSelected = filter.statusFilter == f['key'];
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(f['label']!),
                            selected: isSelected,
                            onSelected: (selected) {
                              if (selected) {
                                ref
                                    .read(serviceRequestFilterProvider.notifier)
                                    .setFilter(f['key']!);
                              }
                            },
                            backgroundColor: AppColors.surface1,
                            selectedColor: AppColors.primarySoft,
                            side: BorderSide(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.border,
                              width: 1,
                            ),
                            labelStyle: AppTypography.caption.copyWith(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: AppRadius.radiusPill,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),

                // Requests List Stack
                requestsAsync.when(
                  data: (requests) {
                    if (requests.isEmpty) {
                      return SliverFillRemaining(
                        hasScrollBody: false,
                        child: AutoEmptyState(
                          title: 'No Service Requests Found',
                          message:
                              'Check the vehicle registration or customer phone number, or try switching filter tabs.',
                          actionLabel: 'Reset All Filters',
                          icon: Icons.manage_search,
                          useIllustration: false,
                          onAction: () {
                            _searchController.clear();
                            ref
                                .read(serviceRequestFilterProvider.notifier)
                                .reset();
                          },
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.only(
                          left: 16, right: 16, top: 8, bottom: 96),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final sr = requests[index];
                            return _buildRequestCard(context, sr);
                          },
                          childCount: requests.length,
                        ),
                      ),
                    );
                  },
                  loading: () => SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: AutoSkeleton.card(height: 190),
                        ),
                        childCount: 4,
                      ),
                    ),
                  ),
                  error: (err, _) => SliverFillRemaining(
                    child: AutoErrorState(
                      title: 'Error loading service requests',
                      message: err.toString(),
                      onRetry: () => ref.invalidate(serviceRequestsListProvider),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Floating Sticky Create Request Action Button
          Positioned(
            bottom: 20,
            right: 16,
            child: FloatingActionButton.extended(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: AppRadius.radiusPill,
              ),
              icon: const Icon(Icons.add, size: 20),
              label: Text(
                'Create Request',
                style: AppTypography.button.copyWith(fontSize: 14),
              ),
              onPressed: () => context.push('/admin/requests/create'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestCard(BuildContext context, ServiceRequestModel sr) {
    final stripeColor = _getStatusStripeColor(sr.status);
    final actionLabel = _getActionLabel(sr.status);
    final timeStr = DateFormatter.timeAgo(sr.createdAt);

    return AutoCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      statusStripeColor: stripeColor,
      onTap: () => context.push('/admin/requests/${sr.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Request #, Time ago, Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        '#${sr.requestNumber}',
                        style: AppTypography.bodyMediumEmphasis.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.schedule, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 3),
                        Text(
                          timeStr,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              AutoBadge.fromStatus(sr.status),
            ],
          ),
          const SizedBox(height: 10),

          // Row 2: Vehicle Title & Plate Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.directions_car, size: 18, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        sr.vehicleTitle,
                        style: AppTypography.bodyLargeEmphasis.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (sr.vehiclePlate.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Text(
                    sr.vehiclePlate,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),

          // Row 3: Customer Name & Phone
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.person_outline, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        sr.customerName,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (sr.customerPhone.isNotEmpty) ...[
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.call, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      sr.customerPhone,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),

          // Row 4: Short Service Description
          Text(
            sr.serviceDescription,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 14),

          // Row 5: Action Button
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.radiusMd,
                ),
              ),
              onPressed: () => context.push('/admin/requests/${sr.id}'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    actionLabel,
                    style: AppTypography.button.copyWith(fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward, size: 18),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
