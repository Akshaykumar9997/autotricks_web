import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_assets.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/pdf_launcher_helper.dart';
import '../../../data/models/quotation_model.dart';
import '../../../design_system/components/auto_badge.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../providers/client_portal_provider.dart';
import '../utils/client_quotation_status_helper.dart';

/// C08 — Quote Detail Screen conforming to approved Day 10 specifications.
class ClientQuoteDetailScreen extends ConsumerStatefulWidget {
  final String quotationId;

  const ClientQuoteDetailScreen({
    super.key,
    required this.quotationId,
  });

  @override
  ConsumerState<ClientQuoteDetailScreen> createState() =>
      _ClientQuoteDetailScreenState();
}

class _ClientQuoteDetailScreenState
    extends ConsumerState<ClientQuoteDetailScreen> {
  String? _autoViewedRevisionId;
  bool _isRejecting = false;
  bool _isLoadingPdf = false;

  Future<void> _viewSignedPdf(QuotationRevisionModel rev) async {
    setState(() => _isLoadingPdf = true);
    try {
      final repo = ref.read(clientPortalRepositoryProvider);
      final storagePath = rev.signedDocument?.storagePath ?? '';
      final url = await repo.getSignedQuotationPdfUrl(
        revisionId: rev.id,
        storagePath: storagePath,
      );

      if (url != null && url.isNotEmpty && mounted) {
        await PdfLauncherHelper.openPdf(
          context,
          pdfUrl: url,
          title: 'Signed Quotation PDF',
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Signed PDF document not available.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading signed PDF: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingPdf = false);
      }
    }
  }

  void _triggerAutoMarkViewed(QuotationRevisionModel rev) {
    if (_autoViewedRevisionId == rev.id) return;
    _autoViewedRevisionId = rev.id;

    if (rev.status.toUpperCase() == 'SENT') {
      Future.microtask(() async {
        try {
          final repo = ref.read(clientPortalRepositoryProvider);
          await repo.markQuotationViewed(rev.id);
          ref.invalidate(clientQuotationDetailProvider(widget.quotationId));
          ref.invalidate(clientQuotationsProvider);
        } catch (_) {
          // Silent fallback if network fails
        }
      });
    }
  }

  Future<void> _showRejectDialog(
    QuotationRevisionModel rev,
    QuotationModel quote,
  ) async {
    final reasonController = TextEditingController();
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: const BorderSide(color: AppColors.borderSubtle),
        ),
        title: Text(
          'Decline Quotation Revision',
          style: AppTypography.headlineSm.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to decline Revision ${rev.revisionNumber} of quotation ${quote.quotationNumber}? No service work will be performed under this estimate.',
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: reasonController,
              maxLines: 3,
              style: AppTypography.bodyMd.copyWith(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Reason for declining (optional)',
                hintStyle: AppTypography.bodyMd.copyWith(
                  color: AppColors.textMuted,
                ),
                filled: true,
                fillColor: AppColors.surface2,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.borderSubtle),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                  borderSide: const BorderSide(color: AppColors.primary),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              'Cancel',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
            child: Text(
              'Decline Quote',
              style: AppTypography.labelMd.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true && mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final router = GoRouter.of(context);
      setState(() => _isRejecting = true);
      try {
        final repo = ref.read(clientPortalRepositoryProvider);
        await repo.rejectQuotationRevision(
          revisionId: rev.id,
          reason: reasonController.text.trim().isNotEmpty
              ? reasonController.text.trim()
              : 'Declined by client',
        );
        ref.invalidate(clientQuotationDetailProvider(widget.quotationId));
        ref.invalidate(clientQuotationsProvider);
        if (mounted) {
          router.pushReplacement('/client/quotes/${widget.quotationId}/rejected');
        }
      } catch (err) {
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Failed to decline quotation: $err'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isRejecting = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final quoteAsync = ref.watch(clientQuotationDetailProvider(widget.quotationId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface1,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/client/quotes');
            }
          },
        ),
        title: quoteAsync.maybeWhen(
          data: (quote) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                quote.quotationNumber,
                style: AppTypography.headlineSm.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                quote.vehicleTitle,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          orElse: () => Text(
            'Quotation Detail',
            style: AppTypography.headlineSm.copyWith(
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
      body: quoteAsync.when(
        skipLoadingOnReload: true,
        skipLoadingOnRefresh: true,
        data: (quote) {
          final rev = quote.latestRevision;
          if (rev == null) {
            return const Center(
              child: Text('No revision found for this quotation.'),
            );
          }

          // Auto-mark viewed if currently SENT
          _triggerAutoMarkViewed(rev);

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  color: AppColors.primary,
                  backgroundColor: AppColors.surface2,
                  onRefresh: () async {
                    ref.invalidate(
                      clientQuotationDetailProvider(widget.quotationId),
                    );
                    ref.invalidate(clientQuotationsProvider);
                  },
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(AppSpacing.margin),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // 1. Status Banner
                        _buildStatusBanner(rev),
                        const SizedBox(height: AppSpacing.md),

                        // 2. Vehicle & Metadata Header Card
                        _buildHeaderCard(quote, rev),
                        const SizedBox(height: AppSpacing.md),

                        // 3. Line Items Section
                        _buildItemsSection(rev),
                        const SizedBox(height: AppSpacing.md),

                        // 4. Financial Summary Card
                        _buildSummaryCard(rev),
                        const SizedBox(height: AppSpacing.md),

                        // 4b. Customer Acceptance & Signed Document (if accepted & signed)
                        if (rev.isSigned || rev.signedDocument != null) ...[
                          _buildSignedSection(quote, rev),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // 5. Notes & Terms (if present)
                        if ((rev.notes != null && rev.notes!.trim().isNotEmpty) ||
                            (rev.terms != null && rev.terms!.trim().isNotEmpty)) ...[
                          _buildNotesAndTermsCard(rev),
                          const SizedBox(height: AppSpacing.md),
                        ],

                        // 6. Dynamic Revision History
                        _buildRevisionHistorySection(quote),
                        const SizedBox(height: AppSpacing.xl),
                      ],
                    ),
                  ),
                ),
              ),

              // Bottom Decision Drawer / Action Bar
              _buildBottomActionBar(context, quote, rev),
            ],
          );
        },
        loading: () => const Padding(
          padding: EdgeInsets.all(AppSpacing.margin),
          child: Column(
            children: [
              AutoSkeleton(height: 80),
              SizedBox(height: AppSpacing.md),
              AutoSkeleton(height: 140),
              SizedBox(height: AppSpacing.md),
              AutoSkeleton(height: 220),
            ],
          ),
        ),
        error: (err, _) => Center(
          child: AutoErrorState(
            title: 'Unable to Load Quotation',
            message: 'Unable to load quotation details. Please try again.',
            onRetry: () => ref.invalidate(
              clientQuotationDetailProvider(widget.quotationId),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBanner(QuotationRevisionModel rev) {
    final status = rev.status.toUpperCase();
    final statusInfo = ClientQuotationStatusHelper.getStatusInfo(status);

    Color bannerBg;
    Color borderCol;
    IconData icon;
    String bannerTitle;
    String bannerDesc;

    if (status == 'SENT' || status == 'VIEWED') {
      bannerBg = AppColors.primarySoft;
      borderCol = AppColors.primary.withValues(alpha: 0.3);
      icon = Icons.bolt;
      bannerTitle = 'Action Required';
      bannerDesc =
          'Please review the line items and scope below. You can accept this quotation or request adjustments.';
    } else if (status == 'CHANGE_REQUESTED') {
      bannerBg = AppColors.warning.withValues(alpha: 0.12);
      borderCol = AppColors.warning.withValues(alpha: 0.35);
      icon = Icons.edit_note_rounded;
      bannerTitle = 'Changes Requested';
      bannerDesc =
          'Your change request has been submitted to the service advisor. An updated estimate will be issued.';
    } else if (status == 'ACCEPTED') {
      bannerBg = AppColors.success.withValues(alpha: 0.12);
      borderCol = AppColors.success.withValues(alpha: 0.35);
      icon = Icons.verified_rounded;
      bannerTitle = rev.isSigned ? 'Quotation Signed & Accepted' : 'Quotation Accepted';
      bannerDesc = rev.isSigned
          ? 'Digitally signed and authorized. Official signed PDF document has been archived.'
          : 'You agreed to the quoted scope, pricing, and terms.';
    } else if (status == 'REJECTED') {
      bannerBg = AppColors.danger.withValues(alpha: 0.12);
      borderCol = AppColors.danger.withValues(alpha: 0.35);
      icon = Icons.cancel_outlined;
      bannerTitle = 'Quotation Declined';
      bannerDesc = rev.rejectionReason != null && rev.rejectionReason!.isNotEmpty
          ? 'Declined: “${rev.rejectionReason}”'
          : 'This quotation revision was declined.';
    } else {
      bannerBg = AppColors.surfaceContainer;
      borderCol = AppColors.borderSubtle;
      icon = Icons.info_outline;
      bannerTitle = statusInfo.label;
      bannerDesc = statusInfo.explanation;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: bannerBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderCol),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: statusInfo.color),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bannerTitle,
                  style: AppTypography.bodyMdEmphasis.copyWith(
                    color: statusInfo.color,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  bannerDesc,
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

  Widget _buildHeaderCard(QuotationModel quote, QuotationRevisionModel rev) {
    final statusInfo = ClientQuotationStatusHelper.getStatusInfo(rev.status);
    final dateFormatted =
        ClientQuotationStatusHelper.getFormattedRevisionDate(rev);

    return AutoCard(
      backgroundColor: AppColors.surface1,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Official Document Header with Full AutoTricks Logo
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(
                AppAssets.logoFull,
                height: 30,
                fit: BoxFit.contain,
              ),
              AutoBadge(
                label: statusInfo.label,
                color: statusInfo.color,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          // Vehicle Name & Status
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  quote.vehicleTitle,
                  style: AppTypography.headlineSm.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Plate and Service Request reference
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (quote.vehiclePlate.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Text(
                    quote.vehiclePlate,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              GestureDetector(
                onTap: () {
                  if (quote.serviceRequestId.isNotEmpty) {
                    context.push('/client/services/${quote.serviceRequestId}');
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.link,
                        size: 12,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        quote.requestNumber.isNotEmpty
                            ? quote.requestNumber
                            : 'Service Request',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
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
          const SizedBox(height: AppSpacing.sm),

          // Real DB Date
          Row(
            children: [
              const Icon(
                Icons.calendar_today_outlined,
                size: 13,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                dateFormatted,
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(QuotationRevisionModel rev) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'QUOTATION ITEMS (${rev.items.length})',
          style: AppTypography.labelMd.copyWith(
            color: AppColors.textMuted,
            letterSpacing: 1.0,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AutoCard(
          backgroundColor: AppColors.surface1,
          padding: EdgeInsets.zero,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: rev.items.length,
            separatorBuilder: (_, _) => const Divider(
              color: AppColors.borderSubtle,
              height: 1,
            ),
            itemBuilder: (context, index) {
              final item = rev.items[index];
              return Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: AppTypography.bodyMdEmphasis.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '₹${item.lineTotal.toStringAsFixed(0)}',
                          style: AppTypography.bodyMdEmphasis.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    if (item.description != null &&
                        item.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        item.description!.trim(),
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          'Qty: ${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2)}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '·  Rate: ₹${item.finalValue.toStringAsFixed(0)}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(QuotationRevisionModel rev) {
    return AutoCard(
      backgroundColor: AppColors.surface1,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'COST SUMMARY',
            style: AppTypography.labelMd.copyWith(
              color: AppColors.textMuted,
              letterSpacing: 1.0,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Subtotal
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.textSecondary,
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

          // Discount (if any)
          if (rev.discount > 0) ...[
            const SizedBox(height: AppSpacing.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Discount',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.success,
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

          // Tax (strictly "Tax", NO "GST" or "VAT")
          const SizedBox(height: AppSpacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tax',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.textSecondary,
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
          const Divider(color: AppColors.borderSubtle, height: 1),
          const SizedBox(height: AppSpacing.md),

          // Total
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: AppTypography.headlineSm.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
    );
  }

  Widget _buildNotesAndTermsCard(QuotationRevisionModel rev) {
    return AutoCard(
      backgroundColor: AppColors.surface1,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rev.notes != null && rev.notes!.trim().isNotEmpty) ...[
            Row(
              children: [
                const Icon(
                  Icons.notes_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Notes from Service Advisor',
                    style: AppTypography.bodyMdEmphasis.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              rev.notes!.trim(),
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
          if (rev.notes != null &&
              rev.notes!.trim().isNotEmpty &&
              rev.terms != null &&
              rev.terms!.trim().isNotEmpty) ...[
            const SizedBox(height: AppSpacing.md),
            const Divider(color: AppColors.borderSubtle, height: 1),
            const SizedBox(height: AppSpacing.md),
          ],
          if (rev.terms != null && rev.terms!.trim().isNotEmpty) ...[
            Row(
              children: [
                const Icon(
                  Icons.gavel_rounded,
                  size: 16,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Terms & Conditions',
                    style: AppTypography.bodyMdEmphasis.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              rev.terms!.trim(),
              style: AppTypography.bodyMd.copyWith(
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSignedSection(QuotationModel quote, QuotationRevisionModel rev) {
    final sig = rev.signature;
    final signedDate = sig?.signedAt ?? rev.acceptedAt;

    return AutoCard(
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
                  'DIGITAL SIGNATURE & ACCEPTANCE',
                  style: AppTypography.labelMd.copyWith(
                    color: AppColors.textMuted,
                    letterSpacing: 1.0,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              const AutoBadge(
                label: 'AUTHORIZED',
                color: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          if (signedDate != null)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Signed On',
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  DateFormatter.formatDateTime(signedDate),
                  style: AppTypography.bodyMdEmphasis.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          const SizedBox(height: AppSpacing.xs),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Authorization Method',
                  style: AppTypography.bodyMd.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                sig?.signatureMethod ?? 'DRAWN',
                style: AppTypography.bodyMdEmphasis.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          const Divider(color: AppColors.borderSubtle, height: 1),
          const SizedBox(height: AppSpacing.md),
          ElevatedButton.icon(
            onPressed: _isLoadingPdf ? null : () => _viewSignedPdf(rev),
            icon: _isLoadingPdf
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.picture_as_pdf_rounded, size: 18),
            label: const Text('View Signed Quotation (PDF)'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevisionHistorySection(QuotationModel quote) {
    final sortedRevisions = List<QuotationRevisionModel>.from(quote.revisions)
      ..sort((a, b) => b.revisionNumber.compareTo(a.revisionNumber));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'REVISION HISTORY',
          style: AppTypography.labelMd.copyWith(
            color: AppColors.textMuted,
            letterSpacing: 1.0,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        AutoCard(
          backgroundColor: AppColors.surface1,
          padding: EdgeInsets.zero,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedRevisions.length,
            separatorBuilder: (_, _) => const Divider(
              color: AppColors.borderSubtle,
              height: 1,
            ),
            itemBuilder: (context, index) {
              final r = sortedRevisions[index];
              final rStatusInfo =
                  ClientQuotationStatusHelper.getStatusInfo(r.status);
              final isCurrent = index == 0;

              return Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 6,
                            children: [
                              Text(
                                'Revision ${r.revisionNumber}',
                                style: AppTypography.bodyMdEmphasis.copyWith(
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              if (isCurrent)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySoft,
                                    borderRadius:
                                        BorderRadius.circular(AppRadius.xs),
                                  ),
                                  child: Text(
                                    'Current',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.primary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        AutoBadge(
                          label: rStatusInfo.label,
                          color: rStatusInfo.color,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            ClientQuotationStatusHelper.getFormattedRevisionDate(r),
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          '₹${r.total.toStringAsFixed(0)}',
                          style: AppTypography.bodyMdEmphasis.copyWith(
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),

                    // Display change requests submitted for this revision (if any)
                    if (r.changeRequests.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.sm),
                      ...r.changeRequests.map((cr) => Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainer,
                              borderRadius:
                                  BorderRadius.circular(AppRadius.xs),
                              border: Border.all(
                                color: AppColors.borderSubtle,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 12,
                                      color: AppColors.warning,
                                    ),
                                    const SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Your Change Request · ${DateFormatter.formatDate(cr.createdAt)}',
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.warning,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 11,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '“${cr.message}”',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textPrimary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                          )),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    QuotationModel quote,
    QuotationRevisionModel rev,
  ) {
    final status = rev.status.toUpperCase();

    if (status == 'SENT' || status == 'VIEWED') {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.margin,
          vertical: AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          border: const Border(
            top: BorderSide(color: AppColors.borderSubtle),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              // Reject Button
              OutlinedButton(
                onPressed: _isRejecting
                    ? null
                    : () => _showRejectDialog(rev, quote),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: const BorderSide(color: AppColors.danger),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                ),
                child: _isRejecting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.danger,
                        ),
                      )
                    : FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Decline',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.danger,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Request Changes Button
              Expanded(
                child: OutlinedButton(
                  onPressed: () => context.push(
                    '/client/quotes/${quote.id}/changes',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    side: const BorderSide(color: AppColors.border),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Request Changes',
                      style: AppTypography.labelMd.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),

              // Accept Button
              Expanded(
                child: ElevatedButton(
                  onPressed: () => context.push(
                    '/client/quotes/${quote.id}/accept',
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      'Accept Quote',
                      style: AppTypography.labelMd.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (status == 'ACCEPTED') {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.margin,
          vertical: AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface1,
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: AppColors.success,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  rev.isSigned
                      ? 'Quotation Signed & Accepted'
                      : 'Quotation Accepted',
                  style: AppTypography.bodyMdEmphasis.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ),
              if (rev.isSigned || rev.signedDocument != null) ...[
                const SizedBox(width: AppSpacing.sm),
                ElevatedButton.icon(
                  onPressed: _isLoadingPdf ? null : () => _viewSignedPdf(rev),
                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                  label: const Text('View PDF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (status == 'CHANGE_REQUESTED') {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.margin,
          vertical: AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface1,
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Change request submitted · Waiting for workshop update',
                  style: AppTypography.bodyMdEmphasis.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (status == 'REJECTED') {
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.margin,
          vertical: AppSpacing.md,
        ),
        decoration: const BoxDecoration(
          color: AppColors.surface1,
          border: Border(top: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.cancel_outlined,
                      color: AppColors.danger,
                      size: 20,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      'Quotation Declined',
                      style: AppTypography.bodyMdEmphasis.copyWith(
                        color: AppColors.danger,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.push(
                  '/client/quotes/${quote.id}/rejected',
                ),
                child: Text(
                  'View Details',
                  style: AppTypography.labelSm.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }
}
