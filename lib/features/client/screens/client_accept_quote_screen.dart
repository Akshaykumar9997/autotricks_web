import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/quotation_model.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../providers/client_portal_provider.dart';

/// C10 — Accept Quote + Consent Screen conforming to approved Day 10 specifications.
class ClientAcceptQuoteScreen extends ConsumerStatefulWidget {
  final String quotationId;

  const ClientAcceptQuoteScreen({
    super.key,
    required this.quotationId,
  });

  @override
  ConsumerState<ClientAcceptQuoteScreen> createState() =>
      _ClientAcceptQuoteScreenState();
}

class _ClientAcceptQuoteScreenState
    extends ConsumerState<ClientAcceptQuoteScreen> {
  bool _consentGiven = false;
  bool _isSubmitting = false;

  Future<void> _handleAccept(
    QuotationModel quote,
    QuotationRevisionModel rev,
  ) async {
    if (!_consentGiven) return;

    setState(() => _isSubmitting = true);
    try {
      final consentText =
          'I confirm that I have reviewed Revision ${rev.revisionNumber} of quotation ${quote.quotationNumber} and agree to the quoted scope, pricing, and terms. I understand that digital signature authorization in the next step is required before workshop service execution can begin.';

      final repo = ref.read(clientPortalRepositoryProvider);
      await repo.acceptQuotationRevision(
        revisionId: rev.id,
        consentText: consentText,
      );

      ref.invalidate(clientQuotationDetailProvider(widget.quotationId));
      ref.invalidate(clientQuotationsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Quotation accepted successfully.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to accept quotation: $err'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quoteAsync =
        ref.watch(clientQuotationDetailProvider(widget.quotationId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface1,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Accept Quotation',
          style: AppTypography.headlineSm.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: quoteAsync.when(
        data: (quote) {
          final rev = quote.latestRevision;
          if (rev == null) {
            return const Center(child: Text('No revision available.'));
          }

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.margin),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Quotation Summary Card
                      AutoCard(
                        backgroundColor: AppColors.surface1,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    quote.quotationNumber,
                                    style: AppTypography.labelMd.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceContainer,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.xs),
                                  ),
                                  child: Text(
                                    'Revision ${rev.revisionNumber}',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w600,
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

                            // Items count & Pricing summary
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Scope of Work',
                                    style: AppTypography.bodyMd.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '${rev.items.length} ${rev.items.length == 1 ? 'item' : 'items'}',
                                  style: AppTypography.bodyMd.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Subtotal',
                                    style: AppTypography.bodyMd.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '₹${rev.subtotal.toStringAsFixed(0)}',
                                  style: AppTypography.bodyMd.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            if (rev.discount > 0) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Discount',
                                      style: AppTypography.bodyMd.copyWith(
                                        color: AppColors.success,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '-₹${rev.discount.toStringAsFixed(0)}',
                                    style: AppTypography.bodyMd.copyWith(
                                      color: AppColors.success,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: AppSpacing.sm),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Tax',
                                    style: AppTypography.bodyMd.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                                Text(
                                  '₹${rev.tax.toStringAsFixed(0)}',
                                  style: AppTypography.bodyMd.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            const Divider(
                              color: AppColors.borderSubtle,
                              height: 1,
                            ),
                            const SizedBox(height: AppSpacing.md),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Total Agreed Value',
                                    style: AppTypography.bodyMdEmphasis.copyWith(
                                      color: AppColors.textPrimary,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Text(
                                  '₹${rev.total.toStringAsFixed(0)}',
                                  style: AppTypography.headlineSm.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Consent Agreement Checkbox Card
                      AutoCard(
                        backgroundColor: AppColors.surface1,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'CLIENT ACCEPTANCE & CONSENT',
                              style: AppTypography.labelMd.copyWith(
                                color: AppColors.textMuted,
                                letterSpacing: 1.0,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),

                            // Interactive Checkbox
                            InkWell(
                              onTap: () {
                                setState(() {
                                  _consentGiven = !_consentGiven;
                                });
                              },
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Checkbox(
                                    value: _consentGiven,
                                    onChanged: (val) {
                                      setState(() {
                                        _consentGiven = val ?? false;
                                      });
                                    },
                                    activeColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(AppRadius.xs),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.only(top: 10),
                                      child: Text(
                                        'I confirm that I have reviewed Revision ${rev.revisionNumber} of quotation ${quote.quotationNumber} and agree to the quoted scope, pricing, and terms.',
                                        style:
                                            AppTypography.bodyMdEmphasis.copyWith(
                                          color: AppColors.textPrimary,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Legal Disclaimer (User Correction 2)
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
                              Icons.info_outline_rounded,
                              size: 18,
                              color: AppColors.textMuted,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'By accepting this quotation, you agree to the quoted scope, pricing, and terms. Please note: Digital signature authorization in the next step is required before workshop service execution can begin. Accepting this quotation does not automatically schedule, authorize, or start workshop service work.',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.45,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Bottom Actions
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.margin,
                  vertical: AppSpacing.md,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.surface1,
                  border: Border(
                    top: BorderSide(color: AppColors.borderSubtle),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isSubmitting ? null : () => context.pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(
                              color: AppColors.borderSubtle,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                          child: Text(
                            'Cancel',
                            style: AppTypography.labelMd.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: (!_consentGiven || _isSubmitting)
                              ? null
                              : () => _handleAccept(quote, rev),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppColors.primary.withValues(alpha: 0.3),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(AppRadius.md),
                            ),
                          ),
                          child: _isSubmitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  'Accept Quotation',
                                  style: AppTypography.labelMd.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.margin),
          child: Column(
            children: [
              AutoSkeleton(height: 120),
              SizedBox(height: AppSpacing.md),
              AutoSkeleton(height: 180),
            ],
          ),
        ),
        error: (err, _) => AutoErrorState(
          title: 'Unable to Load Details',
          message: 'Unable to load quotation details.',
          onRetry: () => ref.invalidate(
            clientQuotationDetailProvider(widget.quotationId),
          ),
        ),
      ),
    );
  }
}
