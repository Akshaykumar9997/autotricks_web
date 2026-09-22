import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_assets.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_empty_state.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/client_portal_provider.dart';
import '../utils/client_status_helper.dart';

/// C03 — My Vehicles Screen conforming to approved Stitch C03.
class ClientVehiclesScreen extends ConsumerWidget {
  const ClientVehiclesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final profileAsync = ref.watch(clientProfileProvider);
    final vehiclesAsync = ref.watch(clientVehiclesProvider);
    final allRequestsAsync = ref.watch(clientServiceRequestsProvider);

    final clientName = profileAsync.value?.fullName ??
        authState.profile?.fullName ??
        'Client';

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
              'Vehicles',
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
          ref.invalidate(clientVehiclesProvider);
          ref.invalidate(clientProfileProvider);
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
              // Intro Title Section
              Text(
                'My Vehicles',
                style: AppTypography.headlineMd.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              vehiclesAsync.maybeWhen(
                data: (vehicles) => Text(
                  '${vehicles.length} ${vehicles.length == 1 ? 'vehicle' : 'vehicles'} registered under $clientName',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                orElse: () => Text(
                  'Vehicles registered under $clientName',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Vehicles Content
              vehiclesAsync.when(
                data: (vehicles) {
                  if (vehicles.isEmpty) {
                    return const AutoEmptyState(
                      title: 'No vehicles yet',
                      message:
                          'Your vehicles will appear here once they are registered by your workshop advisor.',
                      icon: Icons.directions_car_outlined,
                    );
                  }

                  return allRequestsAsync.maybeWhen(
                    data: (requests) => _buildVehiclesList(
                      context,
                      vehicles: vehicles,
                      requests: requests,
                    ),
                    orElse: () => _buildVehiclesList(
                      context,
                      vehicles: vehicles,
                      requests: const [],
                    ),
                  );
                },
                loading: () => const Column(
                  children: [
                    AutoSkeleton(height: 180),
                    SizedBox(height: AppSpacing.md),
                    AutoSkeleton(height: 180),
                  ],
                ),
                error: (err, _) => AutoErrorState(
                  title: 'Unable to Load Vehicles',
                  message: 'Failed to load your vehicles.',
                  onRetry: () => ref.invalidate(clientVehiclesProvider),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // Informational Support Footer Note
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: AppColors.textMuted,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Vehicles are registered and managed by your workshop service advisor.',
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.textSecondary,
                        ),
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

  Widget _buildVehiclesList(
    BuildContext context, {
    required List<VehicleModel> vehicles,
    required List<ServiceRequestModel> requests,
  }) {
    return Column(
      children: vehicles.map((v) {
        // Find active service request for this vehicle
        ServiceRequestModel? activeReq;
        for (final req in requests) {
          if (req.effectiveVehicleId == v.id &&
              ClientStatusHelper.isActive(
                requestStatus: req.status,
                jobStatus: req.jobStatus,
              )) {
            activeReq = req;
            break;
          }
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: _buildVehicleCard(context, vehicle: v, activeReq: activeReq),
        );
      }).toList(),
    );
  }

  Widget _buildVehicleCard(
    BuildContext context, {
    required VehicleModel vehicle,
    ServiceRequestModel? activeReq,
  }) {
    final vinDisplay = vehicle.chassisNumber != null &&
            vehicle.chassisNumber!.isNotEmpty
        ? (vehicle.chassisNumber!.length > 6
            ? '••••••••${vehicle.chassisNumber!.substring(vehicle.chassisNumber!.length - 4)}'
            : vehicle.chassisNumber!)
        : 'Not recorded';

    return AutoCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Icon + Info
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.directions_car,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${vehicle.make} ${vehicle.model}',
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      vehicle.manufacturingYear != null
                          ? '${vehicle.manufacturingYear}'
                          : 'Year unrecorded',
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.pin_outlined,
                          size: 14,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'VIN: $vinDisplay',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textMuted,
                              fontFamily: 'monospace',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),

          // Plate & Status Tag Row
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: AppColors.surface2.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Plate
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 4,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        vehicle.registrationNumber ?? 'NO PLATE',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                ),

                // Active Request Tag
                if (activeReq != null)
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
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          '1 Active Request',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Action Button
          InkWell(
            onTap: () => context.push('/client/vehicles/${vehicle.id}'),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              height: 46,
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'View Vehicle Details',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
