import 'package:flutter/material.dart';
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
import '../../../data/models/client_model.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../providers/clients_provider.dart';

/// A07 — Client Detail Screen conforming to approved Stitch A07.
class ClientDetailScreen extends ConsumerWidget {
  final String clientId;

  const ClientDetailScreen({
    super.key,
    required this.clientId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync = ref.watch(clientDetailProvider(clientId));
    final vehiclesAsync = ref.watch(clientVehiclesProvider(clientId));
    final requestsAsync = ref.watch(clientServiceRequestsProvider(clientId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AutoAppBar(
        title: 'Client Profile',
        showBack: true,
        onBack: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/admin/clients');
          }
        },
        actions: [
          IconButton(
            tooltip: 'Edit Client',
            icon: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
            onPressed: () => context.push('/admin/clients/$clientId/edit'),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: () {
              ref.invalidate(clientDetailProvider(clientId));
              ref.invalidate(clientVehiclesProvider(clientId));
              ref.invalidate(clientServiceRequestsProvider(clientId));
            },
          ),
        ],
      ),
      body: clientAsync.when(
        loading: () => const Center(
          child: AutoSkeleton(
            height: 300,
            width: double.infinity,
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
          ),
        ),
        error: (err, _) => Center(
          child: AutoErrorState(
            title: 'Unable to Load Client',
            message: err.toString().replaceAll('Exception: ', ''),
            onRetry: () => ref.invalidate(clientDetailProvider(clientId)),
          ),
        ),
        data: (client) {
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
                    // Client Overview Card
                    _buildOverviewCard(context, client),
                    const SizedBox(height: 16),

                    // Contact & Address Section
                    _buildContactCard(context, client),
                    const SizedBox(height: 16),

                    // Internal Admin Notes Card
                    _buildAdminNotesCard(client),
                    const SizedBox(height: 24),

                    // Registered Vehicles Section
                    _buildVehiclesSection(context, ref, client, vehiclesAsync),
                    const SizedBox(height: 24),

                    // Related Service Requests Section
                    _buildServiceRequestsSection(context, ref, requestsAsync),
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
                            context.push('/admin/requests/create?clientId=$clientId');
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
                        tooltip: 'Edit Client',
                        onPressed: () => context.push('/admin/clients/$clientId/edit'),
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

  Widget _buildOverviewCard(BuildContext context, ClientModel client) {
    final initials = client.fullName.trim().isNotEmpty
        ? client.fullName
            .trim()
            .split(RegExp(r'\s+'))
            .take(2)
            .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
            .join()
        : 'C';

    return AutoCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surface2,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: Center(
              child: Text(
                initials,
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        client.fullName,
                        style: AppTypography.headlineSmall.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    AutoBadge(
                      label: client.isActive ? 'ACTIVE' : 'INACTIVE',
                      color: client.isActive ? AppColors.success : AppColors.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'AutoTricks Registered Client',
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
  }

  Widget _buildContactCard(BuildContext context, ClientModel client) {
    return AutoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'CONTACT & LOCATION',
            style: AppTypography.caption.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),

          // Phone Row
          InkWell(
            onTap: () => AutoToast.showInfo(context, 'Calling ${client.phone}'),
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.phone_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Phone Number', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                        Text(
                          client.phone,
                          style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.call, size: 18, color: AppColors.textMuted),
                ],
              ),
            ),
          ),

          // Email Row if present
          if (client.email != null && client.email!.isNotEmpty) ...[
            const Divider(color: AppColors.border, height: 16),
            InkWell(
              onTap: () => AutoToast.showInfo(context, 'Sending email to ${client.email}'),
              borderRadius: BorderRadius.circular(AppRadius.sm),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    const Icon(Icons.email_outlined, size: 18, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Email Address', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                          Text(
                            client.email!,
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.mail_outline, size: 18, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
          ],

          // Address Row if present
          if (client.address != null || client.city != null || client.state != null || client.pincode != null) ...[
            const Divider(color: AppColors.border, height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Address', style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
                        const SizedBox(height: 2),
                        Text(
                          [
                            if (client.address != null && client.address!.isNotEmpty) client.address,
                            if (client.city != null && client.city!.isNotEmpty) client.city,
                            if (client.state != null && client.state!.isNotEmpty) client.state,
                            if (client.pincode != null && client.pincode!.isNotEmpty) 'PIN ${client.pincode}',
                          ].join(', '),
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdminNotesCard(ClientModel client) {
    final hasNotes = client.notes != null && client.notes!.trim().isNotEmpty;

    return AutoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_outline, size: 15, color: AppColors.warning),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'CONFIDENTIAL ADMIN NOTES',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            hasNotes ? client.notes! : 'No internal admin notes recorded for this client.',
            style: AppTypography.bodyMedium.copyWith(
              color: hasNotes ? AppColors.textPrimary : AppColors.textMuted,
              fontStyle: hasNotes ? FontStyle.normal : FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehiclesSection(
    BuildContext context,
    WidgetRef ref,
    ClientModel client,
    AsyncValue<List<VehicleModel>> vehiclesAsync,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'REGISTERED VEHICLES',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                context.push('/admin/vehicles/create?clientId=${client.id}');
              },
              icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
              label: Text(
                'Add Vehicle',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        vehiclesAsync.when(
          loading: () => const AutoSkeleton(
            height: 80,
            borderRadius: BorderRadius.all(Radius.circular(AppRadius.md)),
          ),
          error: (err, _) => AutoErrorState(
            title: 'Unable to Load Vehicles',
            message: err.toString().replaceAll('Exception: ', ''),
            onRetry: () => ref.invalidate(clientVehiclesProvider(clientId)),
          ),
          data: (vehicles) {
            if (vehicles.isEmpty) {
              return AutoCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.directions_car_outlined, size: 36, color: AppColors.textMuted),
                      const SizedBox(height: 8),
                      Text(
                        'No vehicles registered yet',
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
                        ),
                        onPressed: () {
                          context.push('/admin/vehicles/create?clientId=${client.id}');
                        },
                        icon: const Icon(Icons.add, size: 16, color: AppColors.primary),
                        label: Text(
                          'Register Vehicle',
                          style: AppTypography.caption.copyWith(color: AppColors.primary),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Column(
              children: vehicles.map((vehicle) {
                final plate = vehicle.registrationNumber ?? '';
                final vin = vehicle.chassisNumber ?? '';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AutoCard(
                    onTap: () => context.push('/admin/vehicles/${vehicle.id}'),
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: AppColors.surface2,
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: const Icon(Icons.directions_car, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${vehicle.make} ${vehicle.model}${vehicle.manufacturingYear != null ? ' (${vehicle.manufacturingYear})' : ''}',
                                style: AppTypography.headlineSmall.copyWith(
                                  color: AppColors.textPrimary,
                                  fontSize: 15,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (plate.isNotEmpty) ...[
                                    _buildPlateBadge(plate),
                                    const SizedBox(width: 8),
                                  ],
                                  if (vin.isNotEmpty)
                                    Expanded(
                                      child: Text(
                                        'VIN: $vin',
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.textMuted,
                                          fontFamily: 'monospace',
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
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

  Widget _buildPlateBadge(String registrationNumber) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0),
              borderRadius: BorderRadius.circular(2),
            ),
            child: const Text(
              'IND',
              style: TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.5,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            registrationNumber,
            style: AppTypography.caption.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
              fontFamily: 'monospace',
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceRequestsSection(
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
            onRetry: () => ref.invalidate(clientServiceRequestsProvider(clientId)),
          ),
          data: (requests) {
            if (requests.isEmpty) {
              return AutoCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Center(
                  child: Text(
                    'No service history recorded for this client.',
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
                        if (sr.vehicle != null)
                          Text(
                            '${sr.vehicle!.make} ${sr.vehicle!.model} • ${sr.vehicle!.registrationNumber ?? ''}',
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                          )
                        else if (sr.vehicleTitle.isNotEmpty)
                          Text(
                            sr.vehicleTitle,
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
