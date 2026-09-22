import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../providers/client_portal_provider.dart';

/// C09 — Request Quote Changes Screen conforming to approved Day 10 specifications.
class ClientRequestChangesScreen extends ConsumerStatefulWidget {
  final String quotationId;

  const ClientRequestChangesScreen({
    super.key,
    required this.quotationId,
  });

  @override
  ConsumerState<ClientRequestChangesScreen> createState() =>
      _ClientRequestChangesScreenState();
}

class _ClientRequestChangesScreenState
    extends ConsumerState<ClientRequestChangesScreen> {
  final TextEditingController _notesController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _notesController.addListener(() {
      setState(() {});
    });
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submitChangeRequest(String revisionId) async {
    final text = _notesController.text.trim();
    if (text.length < 5) return;

    setState(() => _isSubmitting = true);
    try {
      final repo = ref.read(clientPortalRepositoryProvider);
      await repo.requestQuotationChange(
        revisionId: revisionId,
        message: text,
      );

      ref.invalidate(clientQuotationDetailProvider(widget.quotationId));
      ref.invalidate(clientQuotationsProvider);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Change request submitted to service team.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.pop();
      }
    } catch (err) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit change request: $err'),
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
          'Request Changes',
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

          final charCount = _notesController.text.length;
          final isValid = charCount >= 5 && charCount <= 500;

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.margin),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Context Card
                      AutoCard(
                        backgroundColor: AppColors.surface1,
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    quote.quotationNumber,
                                    style: AppTypography.labelMd.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    quote.vehicleTitle,
                                    style: AppTypography.bodyMdEmphasis.copyWith(
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Current Total',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textMuted,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '₹${rev.total.toStringAsFixed(0)}',
                                  style: AppTypography.headlineSm.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),

                      // Instructions / Prompt
                      Text(
                        'What would you like adjusted?',
                        style: AppTypography.headlineSm.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Specify which items to remove, replace, or clarify. Our service advisor will review your notes and prepare an updated quotation revision.',
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),

                      // Text Field
                      TextField(
                        controller: _notesController,
                        maxLines: 6,
                        maxLength: 500,
                        style: AppTypography.bodyMd.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        decoration: InputDecoration(
                          hintText:
                              'e.g., Please remove the tyre rotation item as it was done recently, or clarify if OEM brake pads can be used.',
                          hintStyle: AppTypography.bodyMd.copyWith(
                            color: AppColors.textMuted,
                          ),
                          filled: true,
                          fillColor: AppColors.surface1,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.borderSubtle,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.borderSubtle,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(AppRadius.md),
                            borderSide: const BorderSide(
                              color: AppColors.primary,
                            ),
                          ),
                          counterText: '$charCount / 500',
                          counterStyle: AppTypography.caption.copyWith(
                            color: charCount > 500
                                ? AppColors.danger
                                : AppColors.textMuted,
                          ),
                        ),
                      ),

                      if (charCount > 0 && charCount < 5) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Please provide at least 5 characters to describe your requested change.',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.warning,
                          ),
                        ),
                      ],

                      const SizedBox(height: AppSpacing.lg),

                      // Workflow Reminder Banner
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainer,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(color: AppColors.borderSubtle),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Expanded(
                              child: Text(
                                'Submitting a change request marks this revision as "Changes Requested". You will receive a revised estimate once the service advisor updates the line items.',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.4,
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
                            side: const BorderSide(color: AppColors.borderSubtle),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
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
                          onPressed: (!isValid || _isSubmitting)
                              ? null
                              : () => _submitChangeRequest(rev.id),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                AppColors.primary.withValues(alpha: 0.3),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(AppRadius.md),
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
                                  'Submit Request',
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
              AutoSkeleton(height: 80),
              SizedBox(height: AppSpacing.md),
              AutoSkeleton(height: 200),
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
