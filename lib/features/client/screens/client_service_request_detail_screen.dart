import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/service_job_model.dart';
import '../../../data/models/service_request_model.dart';
import '../../../design_system/components/auto_dialog.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/components/auto_toast.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../components/service_progress_tracker.dart';
import '../providers/client_portal_provider.dart';
import '../utils/client_quotation_status_helper.dart';
import '../utils/client_status_helper.dart';

/// C06 — Service Request Detail Screen conforming to approved Stitch C06.
class ClientServiceRequestDetailScreen extends ConsumerWidget {
  final String requestId;

  const ClientServiceRequestDetailScreen({
    super.key,
    required this.requestId,
  });

  void _copyVin(BuildContext context, String vin) {
    Clipboard.setData(ClipboardData(text: vin));
    AutoToast.showSuccess(context, 'VIN copied to clipboard');
  }

  void _showConciergeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AutoDialog(
        title: 'AutoTricks Concierge',
        message:
            'For questions or updates regarding your service request, our team is available at support@autotricks.com or +91 98765 43210.',
        confirmLabel: 'Understood',
        onConfirm: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Keep client view in sync with live job status changes via Realtime
    ref.watch(clientRealtimeJobsProvider);
    final requestAsync = ref.watch(clientServiceRequestDetailProvider(requestId));

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
              AppAssets.logoMaster,
              height: 26,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Request Details',
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
      body: requestAsync.when(
        data: (ServiceRequestModel request) => RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: AppColors.surface2,
          onRefresh: () async {
            ref.invalidate(clientServiceRequestDetailProvider(requestId));
            ref.invalidate(clientQuotationForServiceRequestProvider(requestId));
            ref.invalidate(clientJobForRequestProvider(requestId));
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
                // 1. Identifier Sub-bar
                _buildIdentifierSubBar(request),
                const SizedBox(height: AppSpacing.md),

                // 2. Status & Next Action Banner
                _buildStatusBanner(context, request),
                const SizedBox(height: AppSpacing.md),

                // 2b. Live Service Job Progress Tracker (when CONVERTED_TO_JOB)
                if (request.status.toUpperCase() == 'CONVERTED_TO_JOB') ...[
                  _buildServiceJobCard(context, ref, request),
                  const SizedBox(height: AppSpacing.md),
                  _buildAdditionalWorkApprovalsCard(context, ref, request),
                ],

                // 3. Vehicle Information Card
                _buildVehicleInfoCard(context, request),
                const SizedBox(height: AppSpacing.md),

                // 4. Request Details Card
                _buildRequestDetailsCard(request),
                const SizedBox(height: AppSpacing.md),

                // 5. Quotation Card
                _buildQuotationCard(context, ref, request),
                const SizedBox(height: AppSpacing.md),

                // 6. Concierge Support Card
                _buildSupportCard(context),
                const SizedBox(height: AppSpacing.xxl),
              ],
            ),
          ),
        ),
        loading: () => _buildSkeleton(),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: AutoErrorState(
              title: 'Request Not Found',
              message: 'Unable to load service request details. Please check your connection or permission.',
              onRetry: () => ref.invalidate(clientServiceRequestDetailProvider(requestId)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIdentifierSubBar(ServiceRequestModel request) {
    final statusColor = ClientStatusHelper.getStatusColor(request);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Text(
              'REQUEST ID',
              style: AppTypography.caption.copyWith(
                color: AppColors.textMuted,
                letterSpacing: 1.2,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Text(
              request.requestNumber.isNotEmpty
                  ? request.requestNumber
                  : request.id.substring(0, 8).toUpperCase(),
              style: AppTypography.bodyMdEmphasis.copyWith(
                color: AppColors.primary,
                letterSpacing: 0.5,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBanner(BuildContext context, ServiceRequestModel request) {
    final statusLabel = ClientStatusHelper.getStatusLabel(request);
    final statusColor = ClientStatusHelper.getStatusColor(request);
    final explanation = ClientStatusHelper.getStatusExplanation(request);

    // Contextual headline
    String headline;
    String nextActionText;
    IconData nextActionIcon = Icons.request_quote_rounded;

    final reqStatus = request.status.toUpperCase();
    if (reqStatus == 'NEW') {
      headline = "We've received your service request.";
      nextActionText = 'Our workshop team will review the details and initiate the quotation process.';
    } else if (reqStatus == 'UNDER_REVIEW') {
      headline = "We're reviewing your service request.";
      nextActionText = 'Quotation will be ready shortly. You will be able to review and approve quote items directly in the app.';
    } else if (reqStatus == 'QUOTATION_CREATED') {
      headline = 'Estimate is being prepared.';
      nextActionText = 'Our service advisor is calculating parts and labor estimates for your vehicle.';
    } else if (reqStatus == 'QUOTATION_SENT') {
      headline = 'Your quotation is ready for review.';
      nextActionText = 'You can review line items and approve quotation in the quote portal.';
      nextActionIcon = Icons.fact_check_outlined;
    } else if (reqStatus == 'APPROVED') {
      headline = 'Quotation approved.';
      nextActionText = 'Quotation accepted. Digital signature authorization is required in the next step before service execution begins.';
      nextActionIcon = Icons.event_available_rounded;
    } else if (reqStatus == 'CONVERTED_TO_JOB') {
      final jobStatus = request.jobStatus?.toUpperCase() ?? '';
      if (jobStatus == 'COMPLETED') {
        headline = 'Service completed successfully!';
        nextActionText = 'Your vehicle service is finished and ready for collection.';
        nextActionIcon = Icons.check_circle_outline_rounded;
      } else if (jobStatus == 'READY_FOR_DELIVERY') {
        headline = 'Vehicle ready for delivery.';
        nextActionText = 'All service tasks and quality checks have been completed.';
        nextActionIcon = Icons.car_repair_rounded;
      } else {
        headline = 'Service actively in progress.';
        nextActionText = 'Our certified technicians are performing scheduled service tasks.';
        nextActionIcon = Icons.handyman_rounded;
      }
    } else if (reqStatus == 'CANCELLED') {
      headline = 'This service request was cancelled.';
      nextActionText = 'No further action required. Contact our support desk if you need assistance.';
      nextActionIcon = Icons.cancel_outlined;
    } else {
      headline = 'Service request is being processed.';
      nextActionText = 'AutoTricks team is managing your request.';
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        ClientStatusHelper.getStatusIcon(request),
                        size: 14,
                        color: statusColor,
                      ),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          statusLabel,
                          style: AppTypography.labelSm.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                DateFormatter.formatRelative(request.updatedAt),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            headline,
            style: AppTypography.headlineSm.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            explanation,
            style: AppTypography.bodyMd.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          // Next Action Context Box
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  nextActionIcon,
                  size: 20,
                  color: AppColors.primary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Next Action',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        nextActionText,
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.3,
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

  Widget _buildVehicleInfoCard(BuildContext context, ServiceRequestModel request) {
    final vehicle = request.vehicle;
    final vin = vehicle?.chassisNumber ?? '';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.directions_car_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'VEHICLE',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textMuted,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  'Verified Reg',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Center(
                  child: Icon(
                    Icons.sports_score_rounded,
                    size: 26,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.vehicleTitle,
                      style: AppTypography.headlineSm.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (request.vehiclePlate.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(AppRadius.xs),
                        ),
                        child: Text(
                          request.vehiclePlate,
                          style: AppTypography.bodyMdEmphasis.copyWith(
                            color: AppColors.primary,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (vin.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            InkWell(
              onTap: () => _copyVin(context, vin),
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Text(
                      'CHASSIS / VIN',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: Text(
                              vin,
                              style: AppTypography.labelSm.copyWith(
                                color: AppColors.textPrimary,
                                fontFamily: 'monospace',
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.copy_rounded,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRequestDetailsCard(ServiceRequestModel request) {
    final items = request.requestedItemList;
    final symptom = request.reportedSymptom;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.build_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Flexible(
                      child: Text(
                        'SERVICE REQUEST DETAILS',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.textMuted,
                          letterSpacing: 1.0,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                DateFormatter.formatDate(request.createdAt),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Requested Items',
            style: AppTypography.labelSm.copyWith(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          // List of requested items
          ...items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 20,
                        color: AppColors.success,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          item,
                          style: AppTypography.bodyMdEmphasis.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )),
          if (symptom != null && symptom.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xs),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer.withValues(alpha: 0.7),
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 15,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Reported Symptom',
                        style: AppTypography.labelSm.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '“$symptom”',
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.textPrimary,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Text(
                'Intake Timestamp',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  DateFormatter.formatDateTime(request.createdAt),
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuotationCard(
    BuildContext context,
    WidgetRef ref,
    ServiceRequestModel request,
  ) {
    final quoteAsync =
        ref.watch(clientQuotationForServiceRequestProvider(request.id));

    return quoteAsync.maybeWhen(
      data: (quote) {
        if (quote != null) {
          final rev = quote.latestRevision;
          final status = quote.currentStatus;
          final isPendingAction =
              status.toUpperCase() == 'SENT' || status.toUpperCase() == 'VIEWED';
          final statusInfo = ClientQuotationStatusHelper.getStatusInfo(status);

          return Container(
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: isPendingAction
                    ? AppColors.primary.withValues(alpha: 0.4)
                    : AppColors.borderSubtle,
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.receipt_long_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Text(
                          'QUOTATION',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.textMuted,
                            letterSpacing: 1.0,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: statusInfo.color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.xs),
                      ),
                      child: Text(
                        statusInfo.label,
                        style: AppTypography.caption.copyWith(
                          color: statusInfo.color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            quote.quotationNumber,
                            style: AppTypography.bodyMdEmphasis.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text(
                            '₹${quote.totalAmount.toStringAsFixed(0)}',
                            style: AppTypography.headlineSm.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      if (rev != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Revision ${rev.revisionNumber} · ${rev.items.length} ${rev.items.length == 1 ? 'item' : 'items'}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: isPendingAction
                            ? ElevatedButton(
                                onPressed: () =>
                                    context.push('/client/quotes/${quote.id}'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                  ),
                                ),
                                child: Text(
                                  'Review Quotation',
                                  style: AppTypography.labelMd.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              )
                            : OutlinedButton(
                                onPressed: () =>
                                    context.push('/client/quotes/${quote.id}'),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.textPrimary,
                                  side: const BorderSide(
                                    color: AppColors.border,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.md),
                                  ),
                                ),
                                child: Text(
                                  'View Quotation',
                                  style: AppTypography.labelMd.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w600,
                                  ),
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
        return _buildDefaultQuotationPlaceholder(request);
      },
      orElse: () => _buildDefaultQuotationPlaceholder(request),
    );
  }

  Widget _buildDefaultQuotationPlaceholder(ServiceRequestModel request) {
    final isQuoteReady = request.status.toUpperCase() == 'QUOTATION_SENT';
    final isApproved = request.status.toUpperCase() == 'APPROVED' ||
        request.status.toUpperCase() == 'CONVERTED_TO_JOB';

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.receipt_long_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Text(
                    'QUOTATION',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textMuted,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isQuoteReady
                      ? AppColors.primarySoft
                      : isApproved
                          ? AppColors.success.withValues(alpha: 0.15)
                          : AppColors.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  isQuoteReady
                      ? 'Ready'
                      : isApproved
                          ? 'Approved'
                          : 'Upcoming',
                  style: AppTypography.caption.copyWith(
                    color: isQuoteReady
                        ? AppColors.primary
                        : isApproved
                            ? AppColors.success
                            : AppColors.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isQuoteReady
                      ? 'Your quotation is ready for review.'
                      : isApproved
                          ? 'Service quotation has been approved.'
                          : 'Your quotation will appear here when it is ready for review.',
                  style: AppTypography.bodyMdEmphasis.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isQuoteReady
                      ? 'You can review line items and approve quote items directly in the quote portal.'
                      : isApproved
                          ? 'Quotation accepted. Digital signature authorization is required in the next step before service execution begins.'
                          : 'You will be able to review and approve quote items directly once ready.',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceJobCard(
    BuildContext context,
    WidgetRef ref,
    ServiceRequestModel request,
  ) {
    final jobAsync = ref.watch(clientJobForRequestProvider(request.id));

    return jobAsync.when(
      data: (job) {
        if (job == null) return const SizedBox.shrink();

        final statusColor = ServiceProgressTracker.getStatusColor(job.status);
        final statusLabel =
            ServiceProgressTracker.stepLabels[job.status] ?? job.status;

        return Container(
          decoration: BoxDecoration(
            color: AppColors.surface1,
            borderRadius: BorderRadius.circular(AppRadius.xl),
            border: Border.all(
              color: statusColor.withValues(alpha: 0.35),
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(
                          Icons.engineering_rounded,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppSpacing.xs),
                        Expanded(
                          child: Text(
                            'LIVE SERVICE PROGRESS',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.textMuted,
                              letterSpacing: 1.0,
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      border: Border.all(
                        color: statusColor.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: statusColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: AppTypography.caption.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),

              // Job Number badge & date info
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainer,
                      borderRadius: BorderRadius.circular(AppRadius.xs),
                    ),
                    child: Text(
                      job.jobNumber,
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  if (job.startedAt != null)
                    Text(
                      'Started ${DateFormatter.formatDate(job.startedAt!)}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),

              // 7-step Visual Stepper
              ServiceProgressTracker(
                currentStatus: job.status,
              ),
              const SizedBox(height: AppSpacing.md),

              // Work Items progress counter
              if (job.workItems.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Service Tasks',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '${job.completedItemsCount} / ${job.workItems.length} completed',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        child: LinearProgressIndicator(
                          value: job.workItems.isEmpty
                              ? 0.0
                              : job.completedItemsCount /
                                  job.workItems.length,
                          backgroundColor: AppColors.surfaceContainerHigh,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            job.isCompleted
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
              ],

              // Status History Timeline
              if (job.statusHistory.isNotEmpty) ...[
                Material(
                  color: Colors.transparent,
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    initiallyExpanded: false,
                    title: Text(
                      'Progress Updates (${job.statusHistory.length})',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    children: [
                      const SizedBox(height: AppSpacing.xs),
                      ...job.statusHistory.reversed.map((history) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: ServiceProgressTracker.getStatusColor(
                                    history.toStatus,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            ServiceProgressTracker.stepLabels[
                                                    history.toStatus] ??
                                                history.toStatus,
                                            style:
                                                AppTypography.caption.copyWith(
                                              color: AppColors.textPrimary,
                                              fontWeight: FontWeight.w600,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.xs),
                                        Text(
                                          DateFormatter.formatDateTime(
                                            history.createdAt,
                                          ),
                                          style:
                                              AppTypography.caption.copyWith(
                                            color: AppColors.textMuted,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (history.note != null &&
                                        history.note!.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        history.note!,
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.textSecondary,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                ),
              ],
            ],
          ),
        );
      },
      loading: () => Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: BorderRadius.circular(AppRadius.xl),
          border: Border.all(color: AppColors.borderSubtle),
        ),
        child: const Center(
          child: Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }

  Future<void> _showApproveAdditionalWorkDialog(
    BuildContext context,
    WidgetRef ref,
    ServiceRequestModel request,
    ServiceWorkItemModel item,
  ) async {
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface1,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          title: Row(
            children: [
              const Icon(Icons.check_circle_outline_rounded, color: AppColors.success, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Authorize Additional Work',
                  style: AppTypography.headlineSm.copyWith(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'You are authorizing AutoTricks technicians to carry out the following additional task:',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: AppRadius.radiusMd,
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name,
                        style: AppTypography.bodyMediumEmphasis.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (item.description != null && item.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.description!,
                          style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      const Divider(color: AppColors.borderSubtle, height: 1),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Quantity:',
                              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1),
                            style: AppTypography.bodyMdEmphasis.copyWith(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              'Chargeable Price:',
                              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Text(
                            '₹${item.finalValue?.toStringAsFixed(2) ?? "0.00"}',
                            style: AppTypography.bodyLgEmphasis.copyWith(color: AppColors.primary),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.1),
                    borderRadius: AppRadius.radiusSm,
                    border: Border.all(color: AppColors.info.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: AppColors.info, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This amount will be added to your service job. Payment will be collected upon job completion and delivery.',
                          style: AppTypography.caption.copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Optional Note / Instructions:',
                  style: AppTypography.labelSm.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. Please proceed, keep old parts for inspection...',
                    hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surface2,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.radiusMd,
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Cancel', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
              ),
              child: const Text('Confirm Authorization'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final repo = ref.read(clientPortalRepositoryProvider);
        await repo.decideAdditionalWork(
          workItemId: item.id,
          approve: true,
          expectedFinalValue: item.finalValue ?? 0,
          note: noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
        );

        ref.invalidate(clientJobForRequestProvider(request.id));
        ref.invalidate(clientActiveJobProvider);
        ref.invalidate(clientServiceRequestDetailProvider(request.id));

        if (context.mounted) {
          AutoToast.showSuccess(context, 'Additional work authorized successfully.');
        }
      } catch (e) {
        if (context.mounted) {
          AutoToast.showError(context, 'Failed to authorize additional work: $e');
        }
      }
    }
  }

  Future<void> _showRejectAdditionalWorkDialog(
    BuildContext context,
    WidgetRef ref,
    ServiceRequestModel request,
    ServiceWorkItemModel item,
  ) async {
    final noteController = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppColors.surface1,
          shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
          title: Row(
            children: [
              const Icon(Icons.cancel_outlined, color: AppColors.danger, size: 24),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Decline Additional Work',
                  style: AppTypography.headlineSm.copyWith(color: AppColors.danger),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to decline this additional work?',
                  style: AppTypography.bodyMdEmphasis.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                Text(
                  'AutoTricks technicians will NOT perform "${item.name}".',
                  style: AppTypography.bodyMd.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Reason for declining (optional):',
                  style: AppTypography.labelSm.copyWith(color: AppColors.textMuted),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: noteController,
                  maxLines: 2,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'e.g. Will address in future service...',
                    hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surface2,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.radiusMd,
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text('Go Back', style: TextStyle(color: AppColors.textMuted)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
              ),
              child: const Text('Confirm Decline'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        final repo = ref.read(clientPortalRepositoryProvider);
        await repo.decideAdditionalWork(
          workItemId: item.id,
          approve: false,
          expectedFinalValue: item.finalValue ?? 0,
          note: noteController.text.trim().isNotEmpty ? noteController.text.trim() : null,
        );

        ref.invalidate(clientJobForRequestProvider(request.id));
        ref.invalidate(clientActiveJobProvider);
        ref.invalidate(clientServiceRequestDetailProvider(request.id));

        if (context.mounted) {
          AutoToast.showSuccess(context, 'Additional work declined.');
        }
      } catch (e) {
        if (context.mounted) {
          AutoToast.showError(context, 'Failed to decline work: $e');
        }
      }
    }
  }

  Widget _buildAdditionalWorkApprovalsCard(
    BuildContext context,
    WidgetRef ref,
    ServiceRequestModel request,
  ) {
    final jobAsync = ref.watch(clientJobForRequestProvider(request.id));

    return jobAsync.when(
      data: (job) {
        if (job == null || job.additionalWorkItems.isEmpty) {
          return const SizedBox.shrink();
        }

        final pendingItems = job.pendingAdditionalWorkItems;
        final decidedItems = job.additionalWorkItems.where((w) => !w.isApprovalPending).toList();

        return Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.md),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: BorderRadius.circular(AppRadius.xl),
              border: Border.all(
                color: pendingItems.isNotEmpty
                    ? AppColors.warning.withValues(alpha: 0.5)
                    : AppColors.borderSubtle,
              ),
            ),
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Icon(
                            pendingItems.isNotEmpty
                                ? Icons.notification_important_rounded
                                : Icons.playlist_add_check_rounded,
                            size: 20,
                            color: pendingItems.isNotEmpty ? AppColors.warning : AppColors.primary,
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              'ADDITIONAL WORK DISCOVERED',
                              style: AppTypography.labelSm.copyWith(
                                color: pendingItems.isNotEmpty ? AppColors.warning : AppColors.textMuted,
                                letterSpacing: 1.0,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: (pendingItems.isNotEmpty ? AppColors.warning : AppColors.success)
                            .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: (pendingItems.isNotEmpty ? AppColors.warning : AppColors.success)
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        pendingItems.isNotEmpty
                            ? '${pendingItems.length} Awaiting Authorization'
                            : 'All Decided',
                        style: AppTypography.caption.copyWith(
                          color: pendingItems.isNotEmpty ? AppColors.warning : AppColors.success,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),

                // Prominent banner
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 18, color: AppColors.textSecondary),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'During vehicle inspection, our workshop discovered additional work items not covered by your signed quotation. Technicians cannot begin this work without your explicit authorization.',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Pending items
                if (pendingItems.isNotEmpty) ...[
                  Text(
                    'AWAITING YOUR DECISION (${pendingItems.length})',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ...pendingItems.map((item) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.md),
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  item.name,
                                  style: AppTypography.bodyMdEmphasis.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Text(
                                '₹${item.finalValue?.toStringAsFixed(2) ?? '0.00'}',
                                style: AppTypography.headlineSm.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          if (item.description != null && item.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              item.description!,
                              style: AppTypography.bodyMd.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.3,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: AppSpacing.sm,
                            children: [
                              Text(
                                'Quantity: ${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 1)}',
                                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                              ),
                              if (item.approximateValue != null)
                                Text(
                                  'Estimated: ₹${item.approximateValue!.toStringAsFixed(2)}',
                                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _showRejectAdditionalWorkDialog(context, ref, request, item),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.danger,
                                    side: const BorderSide(color: AppColors.danger),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  child: const Text('Decline'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.sm),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _showApproveAdditionalWorkDialog(context, ref, request, item),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(AppRadius.md),
                                    ),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                  ),
                                  child: const Text('Authorize'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }),
                ],

                // Decided items
                if (decidedItems.isNotEmpty) ...[
                  Text(
                    'DECIDED ITEMS (${decidedItems.length})',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  ...decidedItems.map((item) {
                    final isApproved = item.isApproved;
                    final badgeColor = isApproved ? AppColors.success : AppColors.danger;
                    final badgeText = isApproved ? 'AUTHORIZED' : 'DECLINED';

                    return Container(
                      margin: const EdgeInsets.only(bottom: AppSpacing.xs),
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        border: Border.all(color: AppColors.borderSubtle),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isApproved ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                            size: 18,
                            color: badgeColor,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        item.name,
                                        style: AppTypography.bodyMdEmphasis.copyWith(
                                          color: isApproved ? AppColors.textPrimary : AppColors.textMuted,
                                          decoration: isApproved ? null : TextDecoration.lineThrough,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: badgeColor.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(AppRadius.xs),
                                      ),
                                      child: Text(
                                        badgeText,
                                        style: AppTypography.caption.copyWith(
                                          color: badgeColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                if (item.description != null && item.description!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    item.description!,
                                    style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                                  ),
                                ],
                                const SizedBox(height: 2),
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: AppSpacing.xs,
                                  runSpacing: 2,
                                  children: [
                                    Text(
                                      'Price: ₹${item.finalValue?.toStringAsFixed(2) ?? "0.00"}',
                                      style: AppTypography.caption.copyWith(
                                        color: isApproved ? AppColors.primary : AppColors.textMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    if (item.decisionAt != null)
                                      Text(
                                        '· Decided ${DateFormatter.formatDate(item.decisionAt!)}',
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                                if (item.approvalNote != null && item.approvalNote!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    'Your note: "${item.approvalNote}"',
                                    style: AppTypography.caption.copyWith(
                                      color: badgeColor,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildSupportCard(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: AppColors.surfaceContainer,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.support_agent_rounded,
                      size: 20,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Need help with your request?',
                        style: AppTypography.bodyMdEmphasis.copyWith(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Reach AutoTricks Desk',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
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
          InkWell(
            onTap: () => _showConciergeDialog(context),
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.phone_in_talk_rounded,
                    size: 15,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Contact',
                    style: AppTypography.labelSm.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeleton() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.margin,
        vertical: AppSpacing.md,
      ),
      child: Column(
        children: [
          AutoSkeleton(
            width: double.infinity,
            height: 180,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          const SizedBox(height: AppSpacing.md),
          AutoSkeleton(
            width: double.infinity,
            height: 140,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          const SizedBox(height: AppSpacing.md),
          AutoSkeleton(
            width: double.infinity,
            height: 220,
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
        ],
      ),
    );
  }
}
