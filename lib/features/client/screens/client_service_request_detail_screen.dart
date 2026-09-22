import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/service_request_model.dart';
import '../../../design_system/components/auto_dialog.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/components/auto_toast.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
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
              Container(
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
                    Text(
                      statusLabel,
                      style: AppTypography.labelSm.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
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
