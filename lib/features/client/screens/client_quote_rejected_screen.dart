import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_dialog.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../providers/client_portal_provider.dart';

/// C12 — Quote Rejected Screen conforming to approved Day 10 specifications.
class ClientQuoteRejectedScreen extends ConsumerWidget {
  final String quotationId;

  const ClientQuoteRejectedScreen({
    super.key,
    required this.quotationId,
  });

  void _showSupportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AutoDialog(
        title: 'AutoTricks Support',
        message:
            'If you have questions about your vehicle, need a different service package, or changed your mind, please reach out to our service team at 1800-TRICKS.',
        confirmLabel: 'Understood',
        onConfirm: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quoteAsync = ref.watch(clientQuotationDetailProvider(quotationId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface1,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
          onPressed: () => context.go('/client/quotes'),
        ),
        title: Text(
          'Quotation Declined',
          style: AppTypography.headlineSm.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: quoteAsync.when(
        data: (quote) {
          final rev = quote.latestRevision;
          final rejectedDate = rev?.rejectedAt ?? quote.updatedAt;
          final rejectionReason = rev?.rejectionReason;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.margin),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.lg),

                // Decline Icon
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.danger.withValues(alpha: 0.25),
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.cancel_outlined,
                        size: 38,
                        color: AppColors.danger,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                // Outcome Headline
                Text(
                  'Quotation Declined',
                  style: AppTypography.headlineMd.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'This quotation has been marked as declined. No service work will be performed under this estimate.',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),

                // Voided Quotation Details Card
                AutoCard(
                  backgroundColor: AppColors.surface1,
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            quote.quotationNumber,
                            style: AppTypography.labelMd.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.15),
                              borderRadius:
                                  BorderRadius.circular(AppRadius.xs),
                            ),
                            child: Text(
                              'DECLINED',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.danger,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        quote.vehicleTitle,
                        style: AppTypography.headlineSm.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Divider(
                        color: AppColors.borderSubtle,
                        height: 1,
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Strikethrough voided total
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Voided Total',
                            style: AppTypography.bodyMd.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                          Text(
                            '₹${(rev?.total ?? quote.totalAmount).toStringAsFixed(0)}',
                            style: AppTypography.headlineSm.copyWith(
                              color: AppColors.textMuted,
                              decoration: TextDecoration.lineThrough,
                              decorationColor: AppColors.danger,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),

                      if (rejectionReason != null &&
                          rejectionReason.trim().isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.md),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainer,
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Reason for Declining',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '“$rejectionReason”',
                                style: AppTypography.bodyMd.copyWith(
                                  color: AppColors.textPrimary,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.md),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 13,
                            color: AppColors.textMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Declined on ${DateFormatter.formatDate(rejectedDate)}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Next Steps Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppColors.textMuted,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'If you need service for this vehicle later, you can submit a new service request from the Services tab at any time.',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Actions
                ElevatedButton(
                  onPressed: () => context.go('/client/services'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: Text(
                    'Back to Services',
                    style: AppTypography.labelMd.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                OutlinedButton(
                  onPressed: () => _showSupportDialog(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    side: const BorderSide(color: AppColors.borderSubtle),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: Text(
                    'Contact AutoTricks',
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.margin),
          child: Column(
            children: [
              AutoSkeleton(height: 120),
              SizedBox(height: AppSpacing.md),
              AutoSkeleton(height: 200),
            ],
          ),
        ),
        error: (err, _) => AutoErrorState(
          title: 'Unable to Load Details',
          message: 'Unable to load quotation details.',
          onRetry: () => ref.invalidate(
            clientQuotationDetailProvider(quotationId),
          ),
        ),
      ),
    );
  }
}
