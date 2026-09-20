import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../design_system/components/auto_app_bar.dart';
import '../../../design_system/components/auto_badge.dart';
import '../../../design_system/components/auto_button.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/components/auto_toast.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../providers/vehicles_provider.dart';

/// A10 — Vehicle Detail Screen conforming to approved Stitch A10.
/// Note: Telemetry terminology and concepts are strictly prohibited.
class VehicleDetailScreen extends ConsumerWidget {
  final String vehicleId;

  const VehicleDetailScreen({
    super.key,
    required this.vehicleId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicleAsync = ref.watch(vehicleDetailProvider(vehicleId));
    final requestsAsync = ref.watch(vehicleServiceRequestsProvider(vehicleId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AutoAppBar(
        title: 'Vehicle Details',
        showBack: true,
        onBack: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/admin/vehicles');
          }
        },
        actions: [
          IconButton(
            tooltip: 'Edit Vehicle',
            icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
            onPressed: () => context.push('/admin/vehicles/$vehicleId/edit'),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: () {
              ref.invalidate(vehicleDetailProvider(vehicleId));
              ref.invalidate(vehicleServiceRequestsProvider(vehicleId));
            },
          ),
        ],
      ),
      body: vehicleAsync.when(
        loading: () => const Center(
          child: AutoSkeleton(
            height: 300,
            width: double.infinity,
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
          ),
        ),
        error: (err, _) => Center(
          child: AutoErrorState(
            title: 'Unable to Load Vehicle',
            message: err.toString().replaceAll('Exception: ', ''),
            onRetry: () => ref.invalidate(vehicleDetailProvider(vehicleId)),
          ),
        ),
        data: (vehicle) {
          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 16,
                  bottom: 110, // Space for sticky bottom bar
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Vehicle Hero Identity Card
                    _buildIdentityCard(vehicle),
                    const SizedBox(height: 16),

                    // Vehicle Specifications Section
                    _buildSpecificationsCard(context, vehicle),
                    const SizedBox(height: 16),

                    // Owner Information Card
                    _buildOwnerCard(context, vehicle),
                    const SizedBox(height: 24),

                    // Service History Section
                    _buildServiceHistorySection(context, ref, requestsAsync),
                  ],
                ),
              ),

              // Sticky Bottom Action Bar
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    border: const Border(
                      top: BorderSide(color: AppColors.border, width: 1),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.35),
                        blurRadius: 12,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: AutoButton(
                          label: 'New Service Request',
                          icon: const Icon(Icons.add_circle_outline, size: 18),
                          onPressed: () {
                            final qClientId = vehicle.clientId;
                            context.push(
                              '/admin/requests/create?clientId=$qClientId&vehicleId=${vehicle.id}',
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.surface2,
                          side: const BorderSide(color: AppColors.border, width: 1),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.md)),
                          padding: const EdgeInsets.all(12),
                        ),
                        icon: const Icon(Icons.edit_outlined, color: AppColors.textPrimary, size: 20),
                        tooltip: 'Edit Vehicle',
                        onPressed: () => context.push('/admin/vehicles/$vehicleId/edit'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildIdentityCard(VehicleModel vehicle) {
    final plate = vehicle.registrationNumber ?? '';

    return AutoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  border: Border.all(color: AppColors.primary, width: 1.5),
                ),
                child: const Icon(Icons.directions_car, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${vehicle.make} ${vehicle.model}',
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      vehicle.manufacturingYear != null
                          ? 'Model Year ${vehicle.manufacturingYear}'
                          : 'Registered Vehicle',
                      style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (plate.isNotEmpty) ...[
            const SizedBox(height: 16),
            // Large IND Registration Plate Display
            _buildLargePlateBadge(plate),
          ],
        ],
      ),
    );
  }

  Widget _buildLargePlateBadge(String registrationNumber) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(3),
            ),
            child: const Text(
              'IND',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.0,
              ),
            ),
          ),
          Flexible(
            child: Text(
              registrationNumber,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                letterSpacing: 1.5,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecificationsCard(BuildContext context, VehicleModel vehicle) {
    final vin = vehicle.chassisNumber ?? '';

    return AutoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'VEHICLE SPECIFICATIONS',
            style: AppTypography.caption.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 14),

          // Grid: Make, Model, Year
          Row(
            children: [
              Expanded(
                child: _buildSpecItem('Make', vehicle.make),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSpecItem('Model', vehicle.model),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSpecItem(
                  'Year',
                  vehicle.manufacturingYear != null ? '${vehicle.manufacturingYear}' : 'N/A',
                ),
              ),
            ],
          ),
          if (vin.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 14),

            // Full Chassis Number / VIN Readout with Copy Button
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Chassis Number (VIN)',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code, size: 18, color: AppColors.textMuted),
                      const SizedBox(width: 10),
                      Expanded(
                        child: SelectableText(
                          vin,
                          style: AppTypography.bodyMediumEmphasis.copyWith(
                            color: AppColors.textPrimary,
                            fontFamily: 'monospace',
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(ClipboardData(text: vin));
                          AutoToast.showSuccess(context, 'VIN copied to clipboard');
                        },
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        child: const Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.copy, size: 16, color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.caption.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.textPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOwnerCard(BuildContext context, VehicleModel vehicle) {
    final client = vehicle.client;

    return AutoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'REGISTERED OWNER',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              if (client != null)
                TextButton(
                  onPressed: () => context.push('/admin/clients/${client.id}'),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View Profile',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right, size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (client != null) ...[
            InkWell(
              onTap: () => context.push('/admin/clients/${client.id}'),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      child: const Center(
                        child: Icon(Icons.person, color: AppColors.primary, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            client.fullName,
                            style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            client.phone,
                            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.call, color: AppColors.primary, size: 18),
                      onPressed: () => AutoToast.showInfo(context, 'Calling ${client.phone}'),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Text(
              'Owner details unavailable',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textMuted,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceHistorySection(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<ServiceRequestModel>> requestsAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SERVICE HISTORY',
          style: AppTypography.caption.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 10),
        requestsAsync.when(
          loading: () => const AutoSkeleton(
            height: 90,
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
          ),
          error: (err, _) => AutoErrorState(
            title: 'Unable to Load History',
            message: err.toString().replaceAll('Exception: ', ''),
            onRetry: () => ref.invalidate(vehicleServiceRequestsProvider(vehicleId)),
          ),
          data: (requests) {
            if (requests.isEmpty) {
              return AutoCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Center(
                  child: Text(
                    'No service history recorded for this vehicle.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textMuted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              );
            }

            return Column(
              children: requests.map((sr) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AutoCard(
                    onTap: () => context.push('/admin/requests/${sr.id}'),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '#${sr.requestNumber}',
                              style: AppTypography.bodyMediumEmphasis.copyWith(
                                color: AppColors.primary,
                                fontFamily: 'monospace',
                              ),
                            ),
                            AutoBadge(
                              label: sr.status,
                              color: _badgeColorForStatus(sr.status),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (sr.customerName.isNotEmpty)
                          Text(
                            'Client: ${sr.customerName}',
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormatter.formatDateTime(sr.createdAt),
                              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                            ),
                            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 16),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

  Color _badgeColorForStatus(String status) {
    switch (status.toUpperCase()) {
      case 'NEW':
        return AppColors.info;
      case 'UNDER_REVIEW':
        return AppColors.warning;
      case 'APPROVED':
      case 'CONVERTED_TO_JOB':
        return AppColors.success;
      case 'CANCELLED':
        return AppColors.danger;
      default:
        return AppColors.textMuted;
    }
  }
}
