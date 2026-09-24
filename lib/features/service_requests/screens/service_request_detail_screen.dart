import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../design_system/components/auto_app_bar.dart';
import '../../../design_system/components/auto_badge.dart';
import '../../../design_system/components/auto_button.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_dialog.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/components/auto_timeline.dart';
import '../../../design_system/components/auto_toast.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../data/models/service_request_model.dart';
import '../../quotes/providers/quotes_provider.dart';
import '../../service_jobs/providers/service_jobs_provider.dart';
import '../providers/service_requests_provider.dart';

/// A04 — Service Request Detail Screen conforming to approved Stitch A04.
class ServiceRequestDetailScreen extends ConsumerStatefulWidget {
  final String requestId;

  const ServiceRequestDetailScreen({
    super.key,
    required this.requestId,
  });

  @override
  ConsumerState<ServiceRequestDetailScreen> createState() =>
      _ServiceRequestDetailScreenState();
}

class _ServiceRequestDetailScreenState
    extends ConsumerState<ServiceRequestDetailScreen> {
  bool _isProcessing = false;

  Future<void> _handlePrimaryAction(ServiceRequestModel sr) async {
    final status = sr.status.toUpperCase();
    final repo = ref.read(serviceRequestsRepositoryProvider);

    if (status == 'NEW') {
      if (sr.effectiveClientId == null ||
          sr.effectiveClientId!.isEmpty ||
          sr.effectiveVehicleId == null ||
          sr.effectiveVehicleId!.isEmpty) {
        AutoToast.showError(
          context,
          'Please link a client and vehicle to the request before moving to Under Review.',
        );
        return;
      }
      setState(() => _isProcessing = true);
      try {
        await repo.updateStatus(requestId: sr.id, status: 'UNDER_REVIEW');
        ref.invalidate(serviceRequestDetailProvider(widget.requestId));
        ref.invalidate(serviceRequestsListProvider);
        if (mounted) {
          AutoToast.showSuccess(context, 'Request moved to Under Review');
        }
      } catch (e) {
        if (mounted) AutoToast.showError(context, e.toString());
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    } else if (status == 'UNDER_REVIEW') {
      if (sr.effectiveClientId == null ||
          sr.effectiveClientId!.isEmpty ||
          sr.effectiveVehicleId == null ||
          sr.effectiveVehicleId!.isEmpty) {
        AutoToast.showError(
          context,
          'Quote creation requires an identified client and vehicle linked to the request.',
        );
        return;
      }
      context.push('/admin/quotes/create?serviceRequestId=${sr.id}');
    } else if (status == 'QUOTATION_CREATED' || status == 'QUOTATION_SENT') {
      setState(() => _isProcessing = true);
      try {
        final quote = await ref
            .read(quotationsRepositoryProvider)
            .getQuotationByServiceRequestId(sr.id);
        if (mounted) {
          if (quote != null) {
            context.push('/admin/quotes/${quote.id}');
          } else {
            AutoToast.showInfo(context, 'No quotation found for this request.');
          }
        }
      } catch (e) {
        if (mounted) AutoToast.showError(context, 'Unable to open quotation: $e');
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    } else if (status == 'APPROVED') {
      try {
        setState(() => _isProcessing = true);
        final quotesRepo = ref.read(quotationsRepositoryProvider);
        final quote = await quotesRepo.getQuotationByServiceRequestId(sr.id);
        if (quote != null) {
          if (mounted) context.push('/admin/quotes/${quote.id}');
        } else {
          if (mounted) AutoToast.showError(context, 'No quotation found for this request.');
        }
      } catch (e) {
        if (mounted) AutoToast.showError(context, 'Unable to open quotation: $e');
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    } else if (status == 'CONVERTED_TO_JOB') {
      try {
        setState(() => _isProcessing = true);
        final jobsRepo = ref.read(serviceJobsRepositoryProvider);
        final job = await jobsRepo.getServiceJobByRequestId(sr.id);
        if (job != null) {
          if (mounted) context.push('/admin/jobs/${job.id}');
        } else {
          if (mounted) AutoToast.showError(context, 'Service Job not found.');
        }
      } catch (e) {
        if (mounted) AutoToast.showError(context, 'Unable to load service job: $e');
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleCancelRequest(ServiceRequestModel sr) async {
    final confirmed = await AutoDialog.show(
      context: context,
      title: 'Cancel Service Request',
      message: 'Are you sure you want to cancel request #${sr.requestNumber}? This action cannot be undone.',
      confirmLabel: 'Cancel Request',
      isDestructive: true,
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      try {
        final repo = ref.read(serviceRequestsRepositoryProvider);
        await repo.cancelServiceRequest(sr.id);
        ref.invalidate(serviceRequestDetailProvider(widget.requestId));
        ref.invalidate(serviceRequestsListProvider);
        if (mounted) {
          AutoToast.showSuccess(context, 'Request marked as cancelled.');
        }
      } catch (e) {
        if (mounted) AutoToast.showError(context, e.toString());
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final requestAsync = ref.watch(serviceRequestDetailProvider(widget.requestId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AutoAppBar(
        title: 'Service Request',
        showBack: true,
        showLogo: true,
        onBack: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/admin/requests');
          }
        },
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined, color: AppColors.textSecondary, size: 20),
            onPressed: () {
              AutoToast.showInfo(context, 'Share link copied.');
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: AppColors.textSecondary, size: 20),
            onPressed: () {},
          ),
        ],
      ),
      body: requestAsync.when(
        data: (sr) => Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 120, // space for sticky action bar
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Request Header & Current Status
                  _buildRequestHeader(sr),
                  const SizedBox(height: 12),

                  // 2. Linking Context verification
                  _buildLinkingContext(sr),
                  const SizedBox(height: 16),

                  // 3. Customer Section (Card)
                  _buildCustomerCard(sr),
                  const SizedBox(height: 16),

                  // 4. Vehicle Section (Card)
                  _buildVehicleCard(sr),
                  const SizedBox(height: 16),

                  // 5. Service Request Details Section (Card)
                  _buildServiceDetailsCard(sr),
                  const SizedBox(height: 16),

                  // 6. Operational Progression / Lifecycle Timeline
                  _buildLifecycleTimelineCard(sr),
                  const SizedBox(height: 16),
                ],
              ),
            ),

            // Sticky Bottom Primary & Secondary Actions
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildStickyActionBar(sr),
            ),
          ],
        ),
        loading: () => const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              AutoSkeleton.card(height: 80),
              SizedBox(height: 16),
              AutoSkeleton.card(height: 140),
              SizedBox(height: 16),
              AutoSkeleton.card(height: 120),
              SizedBox(height: 16),
              AutoSkeleton.card(height: 120),
            ],
          ),
        ),
        error: (err, _) => AutoErrorState(
          title: 'Unable to load service request',
          message: err.toString(),
          onRetry: () =>
              ref.invalidate(serviceRequestDetailProvider(widget.requestId)),
        ),
      ),
    );
  }

  Widget _buildRequestHeader(ServiceRequestModel sr) {
    final timeStr = DateFormatter.formatDateTime(sr.createdAt);
    final sourceStr = sr.source.toUpperCase() == 'WEBSITE' ? 'WEBSITE' : 'PHONE';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                '#${sr.requestNumber}',
                style: AppTypography.display.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            AutoBadge.fromStatus(sr.status),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.schedule, size: 15, color: AppColors.textMuted),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                timeStr,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Text('•', style: TextStyle(color: AppColors.textMuted)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                sourceStr,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLinkingContext(ServiceRequestModel sr) {
    if (!sr.isLinked) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.warningSoft,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(color: AppColors.warning.withValues(alpha: 0.4), width: 1),
        ),
        child: Row(
          children: [
            const Icon(Icons.link_off_rounded, color: AppColors.warning, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Unlinked Intake Request',
                    style: AppTypography.bodyMediumEmphasis.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Link to client & vehicle record before quoting.',
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user, color: AppColors.success, size: 17),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Client & Vehicle Verified from Intake',
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(ServiceRequestModel sr) {
    return AutoCard(
      onTap: sr.clientId != null ? () => context.push('/admin/clients/${sr.clientId}') : null,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'CUSTOMER',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              if (sr.clientId != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Profile',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 14, color: AppColors.primary),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sr.customerName,
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (sr.customerEmail.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        sr.customerEmail,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                children: [
                  IconButton(
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface2,
                      side: const BorderSide(color: AppColors.border, width: 1),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.call, color: AppColors.primary, size: 18),
                    onPressed: () {
                      AutoToast.showInfo(context, 'Calling ${sr.customerPhone}');
                    },
                  ),
                ],
              ),
            ],
          ),
          if (sr.customerPhone.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Contact Number',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sr.customerPhone,
                    textAlign: TextAlign.end,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyMediumEmphasis.copyWith(
                      color: AppColors.textPrimary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVehicleCard(ServiceRequestModel sr) {
    return AutoCard(
      onTap: sr.vehicleId != null ? () => context.push('/admin/vehicles/${sr.vehicleId}') : null,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.directions_car_outlined,
                      size: 16, color: AppColors.textSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'VEHICLE',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
              if (sr.vehiclePlate.isNotEmpty)
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
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sr.vehicleTitle,
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Vehicle Registered with Client',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (sr.vehicleId != null)
                const Icon(Icons.chevron_right, size: 20, color: AppColors.textMuted),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceDetailsCard(ServiceRequestModel sr) {
    return AutoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.build_outlined, size: 16, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(
                'SERVICE REQUEST',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surface2.withValues(alpha: 0.6),
              borderRadius: AppRadius.radiusMd,
              border: Border.all(color: AppColors.border.withValues(alpha: 0.5), width: 1),
            ),
            child: Text(
              sr.serviceDescription,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLifecycleTimelineCard(ServiceRequestModel sr) {
    return AutoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.timeline_rounded,
                        size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'REQUEST LIFECYCLE',
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Step Progression',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AutoTimeline.forServiceRequest(
            currentStatus: sr.status,
            timestamp: DateFormatter.timeAgo(sr.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _buildStickyActionBar(ServiceRequestModel sr) {
    final status = sr.status.toUpperCase();
    final isCancelled = status == 'CANCELLED';

    String primaryLabel;
    IconData primaryIcon;

    switch (status) {
      case 'NEW':
        primaryLabel = 'Review Request';
        primaryIcon = Icons.assignment_turned_in;
        break;
      case 'UNDER_REVIEW':
        primaryLabel = 'Create Quote';
        primaryIcon = Icons.request_quote;
        break;
      case 'QUOTATION_CREATED':
        primaryLabel = 'Review Quote';
        primaryIcon = Icons.rate_review;
        break;
      case 'QUOTATION_SENT':
        primaryLabel = 'View Quote';
        primaryIcon = Icons.visibility;
        break;
      case 'APPROVED':
        primaryLabel = 'Create Service Job';
        primaryIcon = Icons.build;
        break;
      case 'CONVERTED_TO_JOB':
        primaryLabel = 'Open Service Job';
        primaryIcon = Icons.build_circle;
        break;
      default:
        primaryLabel = 'Request Cancelled';
        primaryIcon = Icons.block;
    }

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isCancelled)
            AutoButton.primary(
              label: _isProcessing ? 'Updating...' : primaryLabel,
              isLoading: _isProcessing,
              icon: Icon(primaryIcon, size: 20, color: Colors.white),
              onPressed: () => _handlePrimaryAction(sr),
            ),
          if (status == 'NEW' || status == 'UNDER_REVIEW') ...[
            const SizedBox(height: 6),
            TextButton(
              onPressed: _isProcessing ? null : () => _handleCancelRequest(sr),
              child: Text(
                'Cancel Request',
                style: AppTypography.caption.copyWith(
                  color: AppColors.danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
