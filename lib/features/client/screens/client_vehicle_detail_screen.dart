import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../design_system/components/auto_badge.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/components/auto_toast.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../providers/client_portal_provider.dart';
import '../utils/client_status_helper.dart';

/// C04 — Vehicle Detail Screen conforming to approved Stitch C04.
class ClientVehicleDetailScreen extends ConsumerWidget {
  final String vehicleId;

  const ClientVehicleDetailScreen({
    super.key,
    required this.vehicleId,
  });

  void _copyVin(BuildContext context, String vin) {
    Clipboard.setData(ClipboardData(text: vin));
    AutoToast.showSuccess(context, 'VIN copied to clipboard');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleAsync = ref.watch(clientVehicleDetailProvider(vehicleId));
    final requestsAsync = ref.watch(vehicleServiceRequestsProvider(vehicleId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface1,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: AppColors.textPrimary,
          ),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Image.asset(
              AppAssets.logoSymbol,
              height: 26,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Vehicle Details',
                style: AppTypography.headlineSm.copyWith(
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
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
      body: vehicleAsync.when(
        data: (VehicleModel vehicle) => RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface2,
          onRefresh: () async {
            ref.invalidate(clientVehicleDetailProvider(vehicleId));
            ref.invalidate(vehicleServiceRequestsProvider(vehicleId));
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
                // Vehicle Hero Card
                _buildVehicleHeroCard(context, vehicle),
                const SizedBox(height: AppSpacing.lg),

                // Active Service Requests Section
                _buildActiveRequestsSection(context, ref, requestsAsync),
                const SizedBox(height: AppSpacing.lg),

                // Service History Section
                _buildServiceHistorySection(context, requestsAsync),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          ),
        ),
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.margin),
          child: Column(
            children: [
              AutoSkeleton(height: 240),
              SizedBox(height: AppSpacing.md),
              AutoSkeleton(height: 160),
            ],
          ),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.margin),
            child: AutoErrorState(
              title: 'Unable to Load Vehicle',
              message: err.toString().replaceAll('Exception: ', ''),
              onRetry: () => ref.invalidate(clientVehicleDetailProvider(vehicleId)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVehicleHeroCard(BuildContext context, VehicleModel vehicle) {
    final vin = vehicle.chassisNumber ?? 'NOT SPECIFIED';

    return AutoCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Graphic header banner
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(AppRadius.lg),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.borderSubtle),
                    ),
                    child: const Icon(
                      Icons.directions_car,
                      color: AppColors.primary,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${vehicle.make} ${vehicle.model} • ${vehicle.manufacturingYear ?? ""}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REGISTERED VEHICLE',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${vehicle.make} ${vehicle.model}',
                          style: AppTypography.headlineSm.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          vehicle.manufacturingYear != null
                              ? 'Model Year ${vehicle.manufacturingYear}'
                              : 'Model Year Unspecified',
                          style: AppTypography.bodyMd.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                      ),
                      child: const Icon(
                        Icons.directions_car,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                // Stylized Indian License Plate Tile
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      // IND Blue Strip
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E3A8A),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'IND',
                              style: AppTypography.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                                fontSize: 8,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFFFBBF24),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          vehicle.registrationNumber ?? 'NO PLATE',
                          style: AppTypography.headlineSm.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontFamily: 'monospace',
                            letterSpacing: 2.0,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surface1,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.verified,
                              size: 13,
                              color: AppColors.success,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Verified',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Read-Only Specifications Grid
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surface2.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    children: [
                      _buildSpecRow(
                        icon: Icons.badge_outlined,
                        label: 'Registration',
                        value: vehicle.registrationNumber ?? '—',
                        isMono: true,
                      ),
                      const SizedBox(height: 6),
                      _buildSpecRow(
                        icon: Icons.calendar_today_outlined,
                        label: 'Model Year',
                        value: vehicle.manufacturingYear != null
                            ? '${vehicle.manufacturingYear}'
                            : '—',
                      ),
                      const SizedBox(height: 6),
                      _buildSpecRow(
                        icon: Icons.tag_outlined,
                        label: 'Chassis / VIN',
                        value: vin,
                        isMono: true,
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.content_copy,
                            size: 16,
                            color: AppColors.textMuted,
                          ),
                          onPressed: () => _copyVin(context, vin),
                          tooltip: 'Copy VIN',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecRow({
    required IconData icon,
    required String label,
    required String value,
    bool isMono = false,
    Widget? trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      child: Row(
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Flexible(
                  child: Text(
                    value,
                    style: AppTypography.bodyMdEmphasis.copyWith(
                      color: AppColors.textPrimary,
                      fontFamily: isMono ? 'monospace' : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  trailing,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveRequestsSection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<ServiceRequestModel>> requestsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'ACTIVE SERVICE REQUESTS',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.textMuted,
                  letterSpacing: 1.0,
                  fontSize: 12,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            requestsAsync.maybeWhen(
              data: (list) {
                final active = list
                    .where((sr) => ClientStatusHelper.isActive(
                          requestStatus: sr.status,
                          jobStatus: sr.jobStatus,
                        ))
                    .toList();
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: AppRadius.radiusPill,
                  ),
                  child: Text(
                    '${active.length} OPEN',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        requestsAsync.when(
          data: (list) {
            final active = list
                .where((sr) => ClientStatusHelper.isActive(
                      requestStatus: sr.status,
                      jobStatus: sr.jobStatus,
                    ))
                .toList();

            if (active.isEmpty) {
              return AutoCard(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.success,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'No open service requests for this vehicle.',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: active.map((sr) {
                final statusInfo = ClientStatusHelper.getStatusInfo(
                  requestStatus: sr.status,
                  jobStatus: sr.jobStatus,
                );

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: AutoCard(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
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
                                      Icons.build_circle_outlined,
                                      color: AppColors.primary,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Request No.',
                                          style: AppTypography.caption.copyWith(
                                            color: AppColors.textMuted,
                                            fontSize: 10,
                                          ),
                                        ),
                                        Text(
                                          sr.requestNumber,
                                          style: AppTypography.bodyMdEmphasis.copyWith(
                                            color: AppColors.textPrimary,
                                            fontFamily: 'monospace',
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
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
                        const SizedBox(height: AppSpacing.md),
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
                                sr.customerServiceDescription,
                                style: AppTypography.bodyMd.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.event_outlined,
                                    size: 13,
                                    color: AppColors.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Submitted: ${DateFormatter.formatDate(sr.createdAt)}',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textMuted,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        InkWell(
                          onTap: () => context.push('/client/services/${sr.id}'),
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.borderSubtle),
                            ),
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Flexible(
                                  child: Text(
                                    'View Request Details',
                                    style: AppTypography.labelMd.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.arrow_forward,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => const AutoSkeleton(height: 120),
          error: (err, _) => AutoErrorState(
            title: 'Unable to Load Requests',
            message: 'Unable to load vehicle requests.',
            onRetry: () => ref.invalidate(vehicleServiceRequestsProvider(vehicleId)),
          ),
        ),
      ],
    );
  }

  Widget _buildServiceHistorySection(
    BuildContext context,
    AsyncValue<List<ServiceRequestModel>> requestsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'SERVICE HISTORY',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 1.0,
                fontSize: 12,
              ),
            ),
            const Icon(Icons.history, size: 18, color: AppColors.textMuted),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),

        requestsAsync.maybeWhen(
          data: (list) {
            final completed = list
                .where((sr) => ClientStatusHelper.isCompleted(
                      requestStatus: sr.status,
                      jobStatus: sr.jobStatus,
                    ))
                .toList();

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
                      Icons.build,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          completed.isEmpty
                              ? 'No completed services recorded'
                              : '${completed.length} completed ${completed.length == 1 ? "service" : "services"}',
                          style: AppTypography.bodyMdEmphasis.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          completed.isNotEmpty
                              ? 'Last completed: ${DateFormatter.formatDate(completed.first.jobCompletedAt ?? completed.first.updatedAt)}'
                              : 'Service history will appear here once work is finished.',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
          orElse: () => const SizedBox.shrink(),
        ),
      ],
    );
  }
}
