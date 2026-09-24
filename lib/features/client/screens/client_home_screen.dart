import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/quotation_model.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../design_system/components/auto_badge.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../data/models/service_job_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../components/service_progress_tracker.dart';
import '../providers/client_portal_provider.dart';
import '../utils/client_status_helper.dart';

/// C02 — Client Home Screen conforming to approved Stitch C02.
class ClientHomeScreen extends ConsumerWidget {
  const ClientHomeScreen({super.key});

  String _getTimeBasedGreeting(String name) {
    final hour = DateTime.now().hour;
    String greeting = 'Good morning';
    if (hour >= 12 && hour < 17) {
      greeting = 'Good afternoon';
    } else if (hour >= 17) {
      greeting = 'Good evening';
    }
    return '$greeting, $name';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(clientRealtimeJobsProvider);
    final authState = ref.watch(authProvider);
    final profileAsync = ref.watch(clientProfileProvider);
    final vehiclesAsync = ref.watch(clientVehiclesProvider);
    final activeJobAsync = ref.watch(clientActiveJobProvider);
    final activeRequestAsync = ref.watch(clientActiveRequestProvider);
    final allRequestsAsync = ref.watch(clientServiceRequestsProvider);
    final quotesAsync = ref.watch(clientQuotationsProvider);
    final pendingCount = ref.watch(clientPendingQuotesCountProvider);

    final clientName = profileAsync.value?.fullName ??
        authState.profile?.fullName ??
        'Valued Client';

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
              'Home',
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
          ref.invalidate(clientProfileProvider);
          ref.invalidate(clientVehiclesProvider);
          ref.invalidate(clientServiceRequestsProvider);
          ref.invalidate(clientQuotationsProvider);
          ref.invalidate(clientActiveJobProvider);
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
              // Greeting & Vehicles Count Summary
              _buildGreetingSection(
                greeting: _getTimeBasedGreeting(clientName),
                vehiclesAsync: vehiclesAsync,
              ),
              const SizedBox(height: AppSpacing.lg),

              // Contextual Pending Action Banner (Quotation ready)
              quotesAsync.maybeWhen(
                data: (quotes) {
                  final pendingQuote = quotes.where((q) {
                    final s = q.currentStatus.toUpperCase();
                    return s == 'SENT' || s == 'VIEWED';
                  }).firstOrNull;

                  if (pendingQuote != null) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: _buildDashboardQuotationBanner(
                        context,
                        quote: pendingQuote,
                        pendingCount: pendingCount > 0 ? pendingCount : 1,
                      ),
                    );
                  }

                  return activeRequestAsync.maybeWhen(
                    data: (sr) {
                      if (sr != null && sr.status.toUpperCase() == 'QUOTATION_SENT') {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                          child: _buildLegacyQuoteReadyBanner(context, sr),
                        );
                      }
                      return const SizedBox.shrink();
                    },
                    orElse: () => const SizedBox.shrink(),
                  );
                },
                orElse: () => activeRequestAsync.maybeWhen(
                  data: (sr) {
                    if (sr != null && sr.status.toUpperCase() == 'QUOTATION_SENT') {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                        child: _buildLegacyQuoteReadyBanner(context, sr),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ),

              // Section: Active Service or Current Service Request (Day 12 Section 8)
              activeJobAsync.when(
                data: (ServiceJobModel? job) {
                  if (job != null && job.isActive) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'YOUR ACTIVE SERVICE',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.textMuted,
                            letterSpacing: 1.0,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _buildActiveServiceJobCard(context, job),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'CURRENT SERVICE REQUEST',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.textMuted,
                          letterSpacing: 1.0,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      activeRequestAsync.when(
                        data: (ServiceRequestModel? activeSr) => activeSr != null
                            ? _buildActiveRequestCard(context, activeSr)
                            : _buildNoActiveRequestCard(context),
                        loading: () => const AutoSkeleton(height: 180),
                        error: (err, _) => AutoErrorState(
                          title: 'Unable to Load Status',
                          message: 'Unable to load active service status.',
                          onRetry: () => ref.invalidate(clientServiceRequestsProvider),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const AutoSkeleton(height: 180),
                error: (err, stack) => activeRequestAsync.when(
                  data: (ServiceRequestModel? activeSr) => activeSr != null
                      ? _buildActiveRequestCard(context, activeSr)
                      : _buildNoActiveRequestCard(context),
                  loading: () => const AutoSkeleton(height: 180),
                  error: (err, _) => AutoErrorState(
                    title: 'Unable to Load Status',
                    message: 'Unable to load active service status.',
                    onRetry: () => ref.invalidate(clientServiceRequestsProvider),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Section: My Vehicles
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'MY VEHICLES',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.textMuted,
                      letterSpacing: 1.0,
                      fontSize: 12,
                    ),
                  ),
                  vehiclesAsync.maybeWhen(
                    data: (vehicles) => vehicles.isNotEmpty
                        ? GestureDetector(
                            onTap: () => context.go('/client/vehicles'),
                            child: Row(
                              children: [
                                Text(
                                  'View All (${vehicles.length})',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 2),
                                const Icon(
                                  Icons.chevron_right,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(),
                    orElse: () => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              vehiclesAsync.when(
                data: (vehicles) => vehicles.isNotEmpty
                    ? _buildVehiclesPreview(context, vehicles)
                    : _buildNoVehiclesCard(context),
                loading: () => const AutoSkeleton(height: 120),
                error: (err, _) => AutoErrorState(
                  title: 'Unable to Load Vehicles',
                  message: 'Unable to load vehicles.',
                  onRetry: () => ref.invalidate(clientVehiclesProvider),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Section: Recent Activity Timeline
              Text(
                'RECENT ACTIVITY',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 1.0,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              allRequestsAsync.when(
                data: (requests) => _buildRecentActivitySection(requests),
                loading: () => const AutoSkeleton(height: 100),
                error: (_, _) => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreetingSection({
    required String greeting,
    required AsyncValue<List<VehicleModel>> vehiclesAsync,
  }) {
    final countText = vehiclesAsync.maybeWhen(
      data: (v) => '${v.length} ${v.length == 1 ? 'Vehicle' : 'Vehicles'} Registered',
      orElse: () => 'Vehicles Registered',
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: AppTypography.headlineMd.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.garage_outlined,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    countText,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: AppColors.borderSubtle),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(
                Icons.notifications_outlined,
                size: 22,
                color: AppColors.textSecondary,
              ),
              Positioned(
                top: 10,
                right: 10,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDashboardQuotationBanner(
    BuildContext context, {
    required QuotationModel quote,
    required int pendingCount,
  }) {
    final revNum = quote.currentRevisionNumber;
    final total = quote.totalAmount;
    final itemsCount = quote.currentRevision?.items.length ?? 0;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: Container(color: AppColors.primary),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: AppRadius.radiusPill,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'ACTION REQUIRED',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        '$pendingCount ${pendingCount == 1 ? 'Quote' : 'Quotes'} Awaiting Review',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your Quotation is Ready for Review',
                  style: AppTypography.headlineSm.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Quotation for ${quote.vehicleTitle} is prepared for your digital review.',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text.rich(
                              TextSpan(
                                text: quote.quotationNumber,
                                style: AppTypography.bodyMdEmphasis.copyWith(
                                  color: AppColors.primary,
                                ),
                                children: [
                                  TextSpan(
                                    text: ' · Rev $revNum',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textMuted,
                                      fontWeight: FontWeight.w400,
                                    ),
                                  ),
                                ],
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (itemsCount > 0)
                              Text(
                                '$itemsCount ${itemsCount == 1 ? 'item' : 'items'} included',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textMuted,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '₹${total.toStringAsFixed(0)}',
                        style: AppTypography.headlineSm.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                InkWell(
                  onTap: () => context.push('/client/quotes/${quote.id}'),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Review Quotation',
                          style: AppTypography.labelMd.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegacyQuoteReadyBanner(BuildContext context, ServiceRequestModel sr) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.borderSubtle),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: Container(color: AppColors.primary),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: AppRadius.radiusPill,
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt, size: 14, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(
                            'ACTION REQUIRED',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Ready for review',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Your Quotation is Ready for Review',
                  style: AppTypography.headlineSm.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Quotation for ${sr.vehicleTitle} is prepared for your digital review.',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                InkWell(
                  onTap: () => context.push('/client/quotes'),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  child: Container(
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Review Quotation',
                          style: AppTypography.labelMd.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveServiceJobCard(BuildContext context, ServiceJobModel job) {
    final statusColor = ServiceProgressTracker.getStatusColor(job.status);
    final statusDisplayName = ServiceProgressTracker.stepLabels[job.status.toUpperCase()] ?? job.status;

    return AutoCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Job number & Status Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(
                        Icons.build_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        'JOB #${job.jobNumber}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AutoBadge(
                label: statusDisplayName,
                color: statusColor,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Vehicle Title & Registration
          Text(
            job.vehicleTitle,
            style: AppTypography.bodyLgEmphasis.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (job.vehiclePlate.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                job.vehiclePlate,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),

          // Prominent Status Callout (Day 12 Section 8)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              borderRadius: AppRadius.radiusMd,
              border: Border.all(color: statusColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: statusColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Current Status: $statusDisplayName',
                    style: AppTypography.bodyMdEmphasis.copyWith(color: statusColor),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Visual Progress Tracker (Day 12 Section 8)
          Text(
            'SERVICE PROGRESS',
            style: AppTypography.caption.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w600,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ServiceProgressTracker(
            currentStatus: job.status,
            isCompact: true,
          ),
          const SizedBox(height: AppSpacing.sm),

          // Footer: Last updated & View Details action
          const Divider(color: AppColors.borderSubtle, height: 1),
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  'Updated ${DateFormatter.timeAgo(job.updatedAt)}',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              InkWell(
                onTap: () => context.push('/client/services/${job.serviceRequestId}'),
                borderRadius: AppRadius.radiusSm,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'View Details',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.primary),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRequestCard(BuildContext context, ServiceRequestModel sr) {
    final statusInfo = ClientStatusHelper.getStatusInfo(
      requestStatus: sr.status,
      jobStatus: sr.jobStatus,
    );

    return AutoCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Request number & Status badge
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                      ),
                      child: const Icon(
                        Icons.directions_car,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        sr.requestNumber,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              AutoBadge(
                label: statusInfo.label,
                color: statusInfo.color,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),

          // Vehicle Title & Plate
          Text(
            sr.vehicleTitle,
            style: AppTypography.bodyLgEmphasis.copyWith(
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (sr.vehiclePlate.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 6,
                vertical: 1,
              ),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                sr.vehiclePlate,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.md),

          // Selected Scope
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface2.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected Scope',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sr.customerServiceDescription,
                  style: AppTypography.bodyMdEmphasis.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),

          // Humanized Status Explanation
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surface2.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  color: statusInfo.color,
                  size: 18,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    statusInfo.explanation,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (sr.status.toUpperCase() == 'CONVERTED_TO_JOB') ...[
            const SizedBox(height: AppSpacing.md),
            Text(
              'SERVICE PROGRESS',
              style: AppTypography.caption.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 1.0,
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ServiceProgressTracker(
              currentStatus: sr.jobStatus ?? 'SCHEDULED',
              isCompact: true,
            ),
          ],
          const SizedBox(height: AppSpacing.md),

          // View Request Link
          GestureDetector(
            onTap: () => context.push('/client/services/${sr.id}'),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'View Service Request',
                  style: AppTypography.bodyMdEmphasis.copyWith(
                    color: AppColors.primary,
                  ),
                ),
                const Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoActiveRequestCard(BuildContext context) {
    return AutoCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: const Icon(
              Icons.check_circle_outline,
              color: AppColors.success,
              size: 22,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'All Vehicles in Good Standing',
                  style: AppTypography.bodyMdEmphasis.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'No pending service requests right now.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehiclesPreview(BuildContext context, List<VehicleModel> vehicles) {
    final previewList = vehicles.take(2).toList();

    return Column(
      children: previewList.map((v) {
        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: InkWell(
            onTap: () => context.push('/client/vehicles/${v.id}'),
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(AppRadius.sm),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          v.displayName,
                          style: AppTypography.bodyMdEmphasis.copyWith(
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (v.registrationNumber != null &&
                            v.registrationNumber!.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            v.registrationNumber!,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right,
                    size: 20,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNoVehiclesCard(BuildContext context) {
    return AutoCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Text(
        'No vehicles registered yet.',
        style: AppTypography.bodyMd.copyWith(color: AppColors.textMuted),
      ),
    );
  }

  Widget _buildRecentActivitySection(List<ServiceRequestModel> requests) {
    if (requests.isEmpty) {
      return AutoCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          'No recent activity recorded.',
          style: AppTypography.bodyMd.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    final recent = requests.take(3).toList();

    return AutoCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: recent.asMap().entries.map((entry) {
          final idx = entry.key;
          final sr = entry.value;
          final isLast = idx == recent.length - 1;

          return Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long,
                      color: AppColors.primary,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Service Request',
                                style: AppTypography.bodyMdEmphasis.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              DateFormatter.formatRelative(sr.createdAt),
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${sr.requestNumber} for ${sr.vehicleTitle}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (!isLast) const Divider(color: AppColors.borderSubtle, height: 20),
            ],
          );
        }).toList(),
      ),
    );
  }
}
