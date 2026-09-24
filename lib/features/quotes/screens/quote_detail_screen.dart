import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../core/utils/pdf_launcher_helper.dart';
import '../../../data/models/quotation_model.dart';
import '../../../design_system/components/auto_app_bar.dart';
import '../../../design_system/components/auto_badge.dart';
import '../../../design_system/components/auto_button.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/components/auto_timeline.dart';
import '../../../design_system/components/auto_toast.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../providers/quotes_provider.dart';
import '../../service_jobs/providers/service_jobs_provider.dart';

/// A13 — Quote Detail Screen conforming to approved Stitch A13 and user corrections.
class QuoteDetailScreen extends ConsumerStatefulWidget {
  final String quotationId;

  const QuoteDetailScreen({
    super.key,
    required this.quotationId,
  });

  @override
  ConsumerState<QuoteDetailScreen> createState() => _QuoteDetailScreenState();
}

class _QuoteDetailScreenState extends ConsumerState<QuoteDetailScreen> {
  String? _selectedRevisionId;

  @override
  Widget build(BuildContext context) {
    final quoteAsync = ref.watch(quotationDetailProvider(widget.quotationId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AutoAppBar(
        title: 'Quote Details',
        showBack: true,
        showLogo: true,
        onBack: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/admin/quotes');
          }
        },
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary, size: 20),
            onPressed: () => ref.invalidate(quotationDetailProvider(widget.quotationId)),
          ),
        ],
      ),
      body: quoteAsync.when(
        data: (quote) => _buildContent(context, ref, quote),
        loading: () => const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              AutoSkeleton.card(height: 100),
              SizedBox(height: 16),
              AutoSkeleton.card(height: 140),
              SizedBox(height: 16),
              AutoSkeleton.card(height: 200),
              SizedBox(height: 16),
              AutoSkeleton.card(height: 160),
            ],
          ),
        ),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: AutoErrorState(
            title: 'Unable to load quote details',
            message: err.toString(),
            onRetry: () => ref.invalidate(quotationDetailProvider(widget.quotationId)),
          ),
        ),
      ),
      bottomNavigationBar: quoteAsync.maybeWhen(
        data: (quote) {
          final activeRevision = quote.revisions.isNotEmpty
              ? quote.revisions.firstWhere(
                  (r) => r.id == _selectedRevisionId,
                  orElse: () => quote.currentRevision ?? quote.revisions.first,
                )
              : quote.currentRevision;
          return _buildBottomActionBar(context, ref, quote, activeRevision);
        },
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, QuotationModel quote) {
    final activeRevision = quote.revisions.isNotEmpty
        ? quote.revisions.firstWhere(
            (r) => r.id == _selectedRevisionId,
            orElse: () => quote.currentRevision ?? quote.revisions.first,
          )
        : quote.currentRevision;
    final isDraft = activeRevision?.isDraft ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Quotation File Header & Status
          _buildQuotationHeader(quote, activeRevision),
          const SizedBox(height: 16),

          // 2. Customer & Vehicle Intelligence Card
          _buildCustomerVehicleCard(context, quote),
          const SizedBox(height: 16),

          // 3. Change Request Notice Banner (with direct review action)
          if (activeRevision != null && activeRevision.changeRequests.isNotEmpty) ...[
            _buildChangeRequestBanner(context, quote, activeRevision.changeRequests.first),
            const SizedBox(height: 16),
          ],

          // 4. Draft Context Notice (with direct edit action)
          if (isDraft && activeRevision != null) ...[
            _buildDraftNotice(context, quote, activeRevision),
            const SizedBox(height: 16),
          ],

          // 5. Quoted Line Items (Historical Snapshot)
          _buildQuotedScopeCard(activeRevision),
          const SizedBox(height: 16),

          // 6. Pricing Summary Matrix
          _buildPricingSummaryCard(activeRevision),
          const SizedBox(height: 16),

          // 6b. Customer Acceptance & Digital Signature Card
          if (activeRevision != null && activeRevision.isSigned) ...[
            _buildCustomerSignatureCard(context, ref, quote, activeRevision),
            const SizedBox(height: 16),
          ],

          // 7. Notes & Terms
          if (activeRevision != null &&
              ((activeRevision.notes != null && activeRevision.notes!.isNotEmpty) ||
                  (activeRevision.terms != null && activeRevision.terms!.isNotEmpty))) ...[
            _buildNotesAndTermsCard(activeRevision),
            const SizedBox(height: 16),
          ],

          // 8. Revision History Card
          if (quote.revisions.isNotEmpty) ...[
            _buildRevisionHistoryCard(quote, activeRevision),
            const SizedBox(height: 16),
          ],

          // 9. Timeline / Audit Trail
          _buildAuditTimeline(quote, activeRevision),
        ],
      ),
    );
  }

  Widget _buildQuotationHeader(QuotationModel quote, QuotationRevisionModel? revision) {
    final status = revision?.status ?? quote.currentStatus;
    final revisionNumber = revision?.revisionNumber ?? quote.currentRevisionNumber;
    final createdDateStr = DateFormatter.formatDateTime(revision?.createdAt ?? quote.createdAt);

    return AutoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.receipt_long, color: AppColors.textMuted, size: 16),
                      const SizedBox(width: 6),
                      Text(
                        'QUOTATION FILE',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    quote.quotationNumber,
                    style: AppTypography.h2.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              AutoBadge.fromStatus(status),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.layers_outlined, color: AppColors.primary, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Revision $revisionNumber · Created $createdDateStr',
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerVehicleCard(BuildContext context, QuotationModel quote) {
    final phone = quote.customerPhone;

    return AutoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Customer Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.person_outline, color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.customerName,
                        style: AppTypography.bodyMediumEmphasis.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (phone.isNotEmpty)
                        Text(
                          phone,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
              if (phone.isNotEmpty)
                IconButton(
                  tooltip: 'Copy phone number',
                  icon: const Icon(Icons.phone_outlined, color: AppColors.primary, size: 20),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: phone));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Copied $phone to clipboard')),
                    );
                  },
                ),
            ],
          ),

          const SizedBox(height: 12),

          // Vehicle & Linked Request Sub-panel
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppRadius.radiusMd,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.surface1,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.directions_car_outlined,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quote.vehicleTitle,
                              style: AppTypography.bodyMediumEmphasis.copyWith(
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (quote.vehiclePlate.isNotEmpty)
                              Text(
                                quote.vehiclePlate,
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (quote.requestNumber.isNotEmpty)
                  InkWell(
                    onTap: () {
                      context.push('/admin/requests/${quote.serviceRequestId}');
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface1,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.link, color: AppColors.primary, size: 14),
                          const SizedBox(width: 4),
                          Text(
                            quote.requestNumber,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
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

  Widget _buildChangeRequestBanner(
    BuildContext context,
    QuotationModel quote,
    QuotationChangeRequestModel cr,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.warningSoft,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4), width: 1),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  const Icon(Icons.notifications_active_outlined, color: AppColors.warning, size: 20),
                  Text(
                    'Client Requested Changes',
                    style: AppTypography.bodyMediumEmphasis.copyWith(
                      color: AppColors.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  cr.status,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.warning,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface1.withValues(alpha: 0.5),
              borderRadius: AppRadius.radiusMd,
            ),
            child: Text(
              '“${cr.message}”',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textPrimary,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.schedule, color: AppColors.textMuted, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    DateFormatter.formatDateTime(cr.createdAt),
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/admin/quotes/${quote.id}/change-requests'),
                icon: const Icon(Icons.rate_review_outlined, size: 14, color: AppColors.warning),
                label: Text(
                  'Review Changes',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.warning, width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSm),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDraftNotice(
    BuildContext context,
    QuotationModel quote,
    QuotationRevisionModel revision,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.edit_note, color: AppColors.primary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'This revision is currently in DRAFT status. You can edit line items or dispatch the quote to the customer.',
              style: AppTypography.caption.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () => context.push('/admin/quotes/${quote.id}/revisions/${revision.id}/edit'),
            icon: const Icon(Icons.edit_outlined, size: 14, color: AppColors.primary),
            label: Text(
              'Edit Draft',
              style: AppTypography.caption.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuotedScopeCard(QuotationRevisionModel? revision) {
    final items = revision?.items ?? [];
    final isLocked = !(revision?.isDraft ?? false);

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
                    Icon(
                      isLocked ? Icons.lock_outline : Icons.format_list_bulleted,
                      color: isLocked ? AppColors.textMuted : AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Quoted Line Items',
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.h3.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${items.length} ${items.length == 1 ? 'Item' : 'Items'} · ${isLocked ? 'Locked' : 'Draft'}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No line items found for this quotation revision.',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = items[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: AppRadius.radiusMd,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${index + 1}. ${item.name}',
                        style: AppTypography.bodyMediumEmphasis.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (item.description != null && item.description!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          item.description!,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Qty: ${item.quantity.toStringAsFixed(item.quantity.truncateToDouble() == item.quantity ? 0 : 2)} × ₹${item.finalValue.toStringAsFixed(0)}',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '₹${item.lineTotal.toStringAsFixed(0)}',
                            style: AppTypography.bodyMediumEmphasis.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildPricingSummaryCard(QuotationRevisionModel? revision) {
    final subtotal = revision?.subtotal ?? 0.0;
    final discount = revision?.discount ?? 0.0;
    final tax = revision?.tax ?? 0.0;
    final total = revision?.total ?? 0.0;

    return AutoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subtotal',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              Text(
                '₹${subtotal.toStringAsFixed(0)}',
                style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
          if (discount > 0) ...[
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.loyalty_outlined, color: AppColors.success, size: 15),
                    const SizedBox(width: 4),
                    Text(
                      'Discount',
                      style: AppTypography.bodyMedium.copyWith(color: AppColors.success),
                    ),
                  ],
                ),
                Text(
                  '-₹${discount.toStringAsFixed(0)}',
                  style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.success),
                ),
              ],
            ),
          ],
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tax',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              Text(
                tax > 0 ? '+₹${tax.toStringAsFixed(0)}' : '₹${tax.toStringAsFixed(0)}',
                style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TOTAL QUOTATION VALUE',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Authoritative server calculation',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '₹${total.toStringAsFixed(0)}',
                style: AppTypography.display.copyWith(
                  color: AppColors.primary,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerSignatureCard(
    BuildContext context,
    WidgetRef ref,
    QuotationModel quote,
    QuotationRevisionModel revision,
  ) {
    final sig = revision.signature;
    final signedDate = sig?.signedAt ?? revision.acceptedAt;

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
                    const Icon(
                      Icons.verified_rounded,
                      color: AppColors.success,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Customer Signature & Acceptance',
                        style: AppTypography.h3.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const AutoBadge(
                label: 'ACCEPTED · SIGNED',
                color: AppColors.success,
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (signedDate != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'Signed Timestamp',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                Text(
                  DateFormatter.formatDateTime(signedDate),
                  style: AppTypography.bodyMediumEmphasis.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Authorization Method',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              Text(
                sig?.signatureMethod ?? 'DRAWN',
                style: AppTypography.bodyMediumEmphasis.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          if (sig?.consentText != null && sig!.consentText.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadius.sm),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recorded Legal Consent',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '“${sig.consentText}”',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 16),
          AutoButton(
            label: 'View Signed Quotation (PDF)',
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18, color: Colors.white),
            variant: AutoButtonVariant.primary,
            isExpanded: true,
            onPressed: () async {
              try {
                final repo = ref.read(quotationsRepositoryProvider);
                final storagePath = revision.signedDocument?.storagePath ?? '';
                final url = await repo.getSignedQuotationPdfUrl(
                  revisionId: revision.id,
                  storagePath: storagePath,
                );
                if (url != null && url.isNotEmpty && context.mounted) {
                  await PdfLauncherHelper.openPdf(
                    context,
                    pdfUrl: url,
                    title: 'Signed Quotation - ${quote.quotationNumber}',
                  );
                } else if (context.mounted) {
                  AutoToast.showError(context, 'Signed PDF document not found');
                }
              } catch (e) {
                if (context.mounted) {
                  AutoToast.showError(context, 'Failed to get signed PDF: $e');
                }
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNotesAndTermsCard(QuotationRevisionModel revision) {
    return AutoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Text(
                'Notes & Terms',
                style: AppTypography.h3.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (revision.notes != null && revision.notes!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: AppRadius.radiusMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'INTERNAL NOTES',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    revision.notes!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
          if (revision.terms != null && revision.terms!.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: AppRadius.radiusMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SERVICE TERMS & VALIDITY',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    revision.terms!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      height: 1.4,
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

  Widget _buildRevisionHistoryCard(QuotationModel quote, QuotationRevisionModel? activeRevision) {
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
                    const Icon(Icons.history_edu, color: AppColors.textSecondary, size: 18),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Revision History',
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.h3.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${quote.revisions.length} ${quote.revisions.length == 1 ? 'Revision' : 'Revisions'}',
                style: AppTypography.caption.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: quote.revisions.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final rev = quote.revisions[index];
              final isSelected = rev.id == activeRevision?.id;
              final isLatest = index == 0;

              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedRevisionId = rev.id;
                  });
                },
                borderRadius: AppRadius.radiusMd,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.08)
                        : AppColors.surface2,
                    borderRadius: AppRadius.radiusMd,
                    border: isSelected
                        ? Border.all(color: AppColors.primary, width: 1.5)
                        : (isLatest ? Border.all(color: AppColors.border, width: 1) : null),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : AppColors.surface1,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            'R${rev.revisionNumber}',
                            style: AppTypography.caption.copyWith(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Revision ${rev.revisionNumber}',
                                  style: AppTypography.bodyMediumEmphasis.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                  ),
                                ),
                                AutoBadge.fromStatus(rev.status),
                                if (isSelected)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'VIEWING',
                                      style: AppTypography.caption.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 9,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            Text(
                              DateFormatter.formatDateTime(rev.createdAt),
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${rev.total.toStringAsFixed(0)}',
                            style: AppTypography.bodyMediumEmphasis.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (isLatest)
                            Text(
                              'Latest',
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textMuted,
                                fontSize: 9,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAuditTimeline(QuotationModel quote, QuotationRevisionModel? revision) {
    return AutoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.timeline, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  revision != null
                      ? 'Quotation Lifecycle · Revision ${revision.revisionNumber}'
                      : 'Quotation Lifecycle',
                  style: AppTypography.h3.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (revision != null)
                AutoBadge.fromStatus(revision.status),
            ],
          ),
          const SizedBox(height: 14),
          if (revision != null)
            AutoTimeline.forRevision(revision: revision)
          else
            AutoTimeline.forQuotation(
              currentStatus: quote.currentStatus,
              timestamp: DateFormatter.timeAgo(quote.createdAt),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomActionBar(
    BuildContext context,
    WidgetRef ref,
    QuotationModel quote,
    QuotationRevisionModel? activeRevision,
  ) {
    final latestRev = quote.currentRevision;
    if (latestRev == null && activeRevision == null) return const SizedBox.shrink();

    final targetRev = activeRevision ?? latestRev!;
    final isViewingLatest = latestRev != null && targetRev.id == latestRev.id;

    if (!isViewingLatest && latestRev != null) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        decoration: BoxDecoration(
          color: AppColors.surface1,
          border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Viewing Revision ${targetRev.revisionNumber} (${targetRev.status})',
                      style: AppTypography.bodyMediumEmphasis.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Historical read-only snapshot',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedRevisionId = latestRev.id;
                  });
                },
                icon: const Icon(Icons.arrow_forward, size: 14, color: AppColors.primary),
                label: Text(
                  'View Current (R${latestRev.revisionNumber})',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary, width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSm),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final status = targetRev.status.toUpperCase();

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        border: const Border(top: BorderSide(color: AppColors.border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: _buildStatusBarContent(context, ref, quote, targetRev, status),
      ),
    );
  }

  Widget _buildStatusBarContent(
    BuildContext context,
    WidgetRef ref,
    QuotationModel quote,
    QuotationRevisionModel revision,
    String status,
  ) {
    switch (status) {
      case 'DRAFT':
        return Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  context.push('/admin/quotes/${quote.id}/revisions/${revision.id}/edit');
                },
                icon: const Icon(Icons.edit_outlined, size: 16, color: AppColors.primary),
                label: Text(
                  'Edit Quote',
                  style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.primary),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AutoButton.primary(
                label: 'Send Quote',
                icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
                onPressed: () => _handleSendQuote(context, ref, quote, revision),
              ),
            ),
          ],
        );

      case 'CHANGE_REQUESTED':
        return AutoButton.primary(
          label: 'Review Changes',
          icon: const Icon(Icons.rate_review_outlined, size: 16, color: Colors.white),
          onPressed: () {
            context.push('/admin/quotes/${quote.id}/change-requests');
          },
        );

      case 'SENT':
      case 'VIEWED':
        return Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        status == 'VIEWED' ? Icons.visibility_outlined : Icons.schedule_send,
                        color: AppColors.info,
                        size: 14,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        status == 'VIEWED' ? 'Quote Viewed' : 'Quote Sent',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.info,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (revision.sentAt != null)
                    Text(
                      DateFormatter.formatDateTime(revision.sentAt!),
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 10,
                      ),
                    ),
                ],
              ),
            ),
            OutlinedButton.icon(
              onPressed: () => _handleCreateNewRevision(context, ref, quote),
              icon: const Icon(Icons.add, size: 14, color: AppColors.primary),
              label: Text(
                'New Revision',
                style: AppTypography.caption.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary, width: 1),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSm),
              ),
            ),
          ],
        );

      case 'ACCEPTED':
        final jobAsync = ref.watch(serviceJobForRevisionProvider(revision.id));
        return jobAsync.when(
          data: (existingJob) {
            if (existingJob != null) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.1),
                      borderRadius: AppRadius.radiusMd,
                      border: Border.all(color: AppColors.success.withValues(alpha: 0.3), width: 1),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.verified_outlined, color: AppColors.success, size: 16),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'Quotation Accepted · Service Job Active',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  AutoButton(
                    label: 'View Service Job (${existingJob.jobNumber})',
                    icon: const Icon(Icons.build_circle_outlined, size: 18),
                    onPressed: () => context.push('/admin/jobs/${existingJob.id}'),
                  ),
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: AppRadius.radiusMd,
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.3), width: 1),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.verified_outlined, color: AppColors.success, size: 16),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Quotation Accepted · Locked',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                AutoButton(
                  label: 'Create Service Job',
                  icon: const Icon(Icons.build_rounded, size: 18),
                  onPressed: () => _showCreateServiceJobDialog(context, ref, quote, revision),
                ),
              ],
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
              ),
            ),
          ),
          error: (err, stack) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              AutoButton(
                label: 'Create Service Job',
                icon: const Icon(Icons.build_rounded, size: 18),
                onPressed: () => _showCreateServiceJobDialog(context, ref, quote, revision),
              ),
            ],
          ),
        );

      case 'REJECTED':
      case 'EXPIRED':
      case 'CANCELLED':
      case 'SUPERSEDED':
      default:
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: AppRadius.radiusMd,
            border: Border.all(color: AppColors.border, width: 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.history, color: AppColors.textMuted, size: 18),
              const SizedBox(width: 8),
              Text(
                'Quotation is $status · Historical Record',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        );
    }
  }

  Future<void> _handleSendQuote(
    BuildContext context,
    WidgetRef ref,
    QuotationModel quote,
    QuotationRevisionModel revision,
  ) async {
    if (revision.items.isEmpty) {
      AutoToast.showInfo(context, 'Cannot send quote without line items. Please edit the draft.');
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusLg,
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        title: Text(
          'Send Quote to Customer?',
          style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          'Revision ${revision.revisionNumber} (Total ₹${revision.total.toStringAsFixed(0)}) will be dispatched to ${quote.customerName}. Once sent, this revision will be locked and cannot be edited.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text('Cancel', style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted)),
          ),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSm),
            ),
            icon: const Icon(Icons.send_rounded, size: 16, color: Colors.white),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            label: Text(
              'Send Quote',
              style: AppTypography.bodyMediumEmphasis.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(quotationsRepositoryProvider).sendQuotationRevision(revision.id);
      ref.invalidate(quotationDetailProvider(quote.id));
      ref.invalidate(quotationsListProvider);

      if (context.mounted) {
        AutoToast.showSuccess(context, 'Quote sent successfully.');
      }
    } catch (e) {
      if (context.mounted) {
        final errorMsg = _mapSendErrorMessage(e.toString());
        AutoToast.showError(context, errorMsg);
      }
    }
  }

  Future<void> _handleCreateNewRevision(
    BuildContext context,
    WidgetRef ref,
    QuotationModel quote,
  ) async {
    final activeDraft = quote.revisions.where((r) => r.isDraft).firstOrNull;
    if (activeDraft != null) {
      AutoToast.showInfo(context, 'A draft revision already exists. Opening editor...');
      context.push('/admin/quotes/${quote.id}/revisions/${activeDraft.id}/edit');
      return;
    }

    final nextRevNum = quote.currentRevisionNumber + 1;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AppColors.surface1,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.radiusLg,
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        title: Text(
          'Create Revision $nextRevNum?',
          style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
        ),
        content: Text(
          'A new DRAFT revision will be created duplicating the previous scope and pricing snapshot. Revision ${quote.currentRevisionNumber} will remain preserved in history.',
          style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text('Cancel', style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSm),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: Text(
              'Create Revision $nextRevNum',
              style: AppTypography.bodyMediumEmphasis.copyWith(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final result = await ref
          .read(quotationsRepositoryProvider)
          .createQuotationRevision(quote.id);
      final newRevId = result['revision_id'] as String;
      final newRevNum = result['revision_number'] as int? ?? nextRevNum;

      ref.invalidate(quotationDetailProvider(quote.id));
      ref.invalidate(quotationsListProvider);

      if (context.mounted) {
        AutoToast.showSuccess(context, 'Revision $newRevNum created as draft.');
        context.push('/admin/quotes/${quote.id}/revisions/$newRevId/edit');
      }
    } catch (e) {
      if (context.mounted) {
        AutoToast.showError(context, 'Unable to create revision: $e');
      }
    }
  }

  String _mapSendErrorMessage(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('at least one item')) {
      return 'Add at least one item before sending the quotation.';
    }
    if (lower.contains('only draft')) {
      return 'Only draft revisions can be sent.';
    }
    if (lower.contains('already has a signed revision')) {
      return 'This quotation already has a signed revision.';
    }
    return 'Unable to send this quote. Please try again.';
  }

  Future<void> _showCreateServiceJobDialog(
    BuildContext context,
    WidgetRef ref,
    QuotationModel quote,
    QuotationRevisionModel revision,
  ) async {
    DateTime scheduledDate = DateTime.now().add(const Duration(hours: 2));

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: AppColors.surface1,
              shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusLg),
              title: Row(
                children: [
                  const Icon(Icons.build_circle_rounded, color: AppColors.primary, size: 24),
                  const SizedBox(width: AppSpacing.sm),
                  Flexible(
                    child: Text(
                      'Create Service Job',
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
                      'Confirm Service Job creation from the accepted quotation snapshot.',
                      style: AppTypography.caption.copyWith(color: AppColors.textMuted),
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
                          _buildModalRow('Customer', quote.customerName),
                          if (quote.customerPhone.isNotEmpty)
                            _buildModalRow('Phone', quote.customerPhone),
                          const Divider(color: AppColors.borderSubtle, height: 12),
                          _buildModalRow('Vehicle', quote.vehicleTitle),
                          _buildModalRow('Registration', quote.vehiclePlate),
                          const Divider(color: AppColors.borderSubtle, height: 12),
                          _buildModalRow('Service Request', '#${quote.requestNumber}'),
                          if (quote.serviceSummary.isNotEmpty)
                            _buildModalRow('Requirement', quote.serviceSummary),
                          const Divider(color: AppColors.borderSubtle, height: 12),
                          _buildModalRow('Quotation', '#${quote.quotationNumber} (Rev ${revision.revisionNumber})'),
                          _buildModalRow('Accepted Total', 'Rs. ${revision.total.toStringAsFixed(2)}'),
                          _buildModalRow('Items Included', '${revision.items.length} Quoted Items'),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Schedule Service Date:',
                      style: AppTypography.labelSm.copyWith(color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: scheduledDate,
                          firstDate: DateTime.now().subtract(const Duration(days: 1)),
                          lastDate: DateTime.now().add(const Duration(days: 60)),
                          builder: (context, child) {
                            return Theme(
                              data: Theme.of(context).copyWith(
                                colorScheme: const ColorScheme.dark(
                                  primary: AppColors.primary,
                                  surface: AppColors.surface1,
                                ),
                              ),
                              child: child!,
                            );
                          },
                        );
                        if (picked != null) {
                          setDialogState(() {
                            scheduledDate = DateTime(
                              picked.year,
                              picked.month,
                              picked.day,
                              scheduledDate.hour,
                              scheduledDate.minute,
                            );
                          });
                        }
                      },
                      borderRadius: AppRadius.radiusMd,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: AppRadius.radiusMd,
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Text(
                              DateFormatter.formatDate(scheduledDate),
                              style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.textPrimary),
                            ),
                            const Spacer(),
                            Text('Change', style: AppTypography.caption.copyWith(color: AppColors.primary)),
                          ],
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
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  icon: const Icon(Icons.check, size: 16),
                  label: const Text('Confirm & Create Job'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed == true && context.mounted) {
      try {
        final jobsRepo = ref.read(serviceJobsRepositoryProvider);
        final result = await jobsRepo.createServiceJob(
          quotationRevisionId: revision.id,
          scheduledAt: scheduledDate,
        );

        ref.invalidate(serviceJobForRevisionProvider(revision.id));
        ref.invalidate(serviceJobForRequestProvider(quote.serviceRequestId));
        ref.invalidate(serviceJobsListProvider);
        ref.invalidate(quotationDetailProvider(quote.id));

        final jobId = result['service_job_id'] as String;
        final jobNum = result['job_number'] as String? ?? 'New Job';

        if (context.mounted) {
          AutoToast.showSuccess(context, 'Service Job #$jobNum created successfully!');
          context.push('/admin/jobs/$jobId');
        }
      } catch (e) {
        if (context.mounted) {
          if (e.toString().contains('already exists')) {
            AutoToast.showInfo(context, 'A service job already exists for this request.');
            try {
              final jobsRepo = ref.read(serviceJobsRepositoryProvider);
              final existing = await jobsRepo.getServiceJobByRequestId(quote.serviceRequestId);
              if (existing != null && context.mounted) {
                context.push('/admin/jobs/${existing.id}');
                return;
              }
            } catch (_) {}
          } else {
            AutoToast.showError(context, 'Failed to create service job: $e');
          }
        }
      }
    }
  }

  Widget _buildModalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMdEmphasis.copyWith(color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
