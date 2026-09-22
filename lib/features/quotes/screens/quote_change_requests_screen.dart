import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/utils/date_formatter.dart';
import '../../../data/models/quotation_model.dart';
import '../../../design_system/components/auto_app_bar.dart';
import '../../../design_system/components/auto_badge.dart';
import '../../../design_system/components/auto_button.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_empty_state.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/components/auto_toast.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../providers/quotes_provider.dart';

/// A16 — Quote Change Requests review and resolution screen conforming to approved Stitch A16.
class QuoteChangeRequestsScreen extends ConsumerStatefulWidget {
  final String quotationId;
  final String? changeRequestId;

  const QuoteChangeRequestsScreen({
    super.key,
    required this.quotationId,
    this.changeRequestId,
  });

  @override
  ConsumerState<QuoteChangeRequestsScreen> createState() => _QuoteChangeRequestsScreenState();
}

class _QuoteChangeRequestsScreenState extends ConsumerState<QuoteChangeRequestsScreen> {
  bool _isCreatingRevision = false;

  Future<void> _handleCreateNewRevision(QuotationModel quote) async {
    // Check if an active DRAFT revision already exists
    final activeDraft = quote.revisions.where((r) => r.isDraft).firstOrNull;
    if (activeDraft != null) {
      AutoToast.showInfo(context, 'An active draft revision already exists. Opening editor...');
      context.push('/admin/quotes/${quote.id}/revisions/${activeDraft.id}/edit');
      return;
    }

    final currentRevNum = quote.currentRevisionNumber;
    final nextRevNum = currentRevNum + 1;

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
          'A new DRAFT revision will be created duplicating the previous scope and pricing snapshot. Revision $currentRevNum will remain immutable in history.',
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

    if (confirmed != true || !mounted) return;

    setState(() => _isCreatingRevision = true);

    try {
      final result = await ref
          .read(quotationsRepositoryProvider)
          .createQuotationRevision(quote.id);

      final newRevisionId = result['revision_id'] as String;
      final newRevNumber = result['revision_number'] as int? ?? nextRevNum;

      ref.invalidate(quotationDetailProvider(quote.id));
      ref.invalidate(quotationsListProvider);

      if (mounted) {
        AutoToast.showSuccess(context, 'Revision $newRevNumber created as draft.');
        // Navigate directly to A15 to edit the new revision draft
        context.push('/admin/quotes/${quote.id}/revisions/$newRevisionId/edit');
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = _mapRevisionCreationError(e.toString());
        AutoToast.showError(context, errorMsg);
      }
    } finally {
      if (mounted) {
        setState(() => _isCreatingRevision = false);
      }
    }
  }

  String _mapRevisionCreationError(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('already has a signed revision')) {
      return 'This quotation already has a signed revision and cannot be revised.';
    }
    if (lower.contains('a draft revision already exists')) {
      return 'A draft revision already exists for this quotation. Please edit the existing draft.';
    }
    return 'Unable to create a new revision. Please try again.';
  }

  void _openRespondDialog(QuotationChangeRequestModel cr, QuotationModel quote) {
    String selectedStatus = 'ACCEPTED';
    final responseController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 20,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              decoration: const BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Respond to Change Request',
                          style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: AppColors.textMuted, size: 20),
                        onPressed: () => Navigator.of(modalCtx).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Client message summary
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: AppRadius.radiusMd,
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Text(
                      '“${cr.message}”',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Resolution status selector
                  Text(
                    'Resolution Status *',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    dropdownColor: AppColors.surface2,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.surface2,
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.radiusSm,
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'ACCEPTED', child: Text('Accepted')),
                      DropdownMenuItem(value: 'PARTIALLY_ACCEPTED', child: Text('Partially Accepted')),
                      DropdownMenuItem(value: 'REJECTED', child: Text('Rejected')),
                      DropdownMenuItem(value: 'CANCELLED', child: Text('Cancelled')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedStatus = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  // Admin response text
                  Text(
                    'Admin Response Note (Optional)',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: responseController,
                    maxLines: 3,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Add response notes or client explanation...',
                      hintStyle: AppTypography.caption.copyWith(color: AppColors.textMuted),
                      filled: true,
                      fillColor: AppColors.surface2,
                      border: OutlineInputBorder(
                        borderRadius: AppRadius.radiusSm,
                        borderSide: const BorderSide(color: AppColors.border),
                      ),
                      contentPadding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit button
                  AutoButton.primary(
                    label: 'Submit Resolution',
                    icon: const Icon(Icons.check_circle_outline, size: 18, color: Colors.white),
                    isLoading: isSubmitting,
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            setModalState(() => isSubmitting = true);
                            try {
                              await ref
                                  .read(quotationsRepositoryProvider)
                                  .respondChangeRequest(
                                    changeRequestId: cr.id,
                                    status: selectedStatus,
                                    response: responseController.text.trim(),
                                  );

                              ref.invalidate(quotationDetailProvider(quote.id));
                              ref.invalidate(quotationsListProvider);

                              if (modalCtx.mounted) {
                                Navigator.of(modalCtx).pop();
                              }
                              if (mounted) {
                                AutoToast.showSuccess(context, 'Change request marked $selectedStatus.');
                              }
                            } catch (e) {
                              setModalState(() => isSubmitting = false);
                              if (mounted) {
                                AutoToast.showError(context, 'Unable to update change request: $e');
                              }
                            }
                          },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final quoteAsync = ref.watch(quotationDetailProvider(widget.quotationId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AutoAppBar(
        title: 'Quote Change Requests',
        showBack: true,
        showLogo: false,
        onBack: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/admin/quotes/${widget.quotationId}');
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
        data: (quote) => _buildContent(quote),
        loading: () => const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              AutoSkeleton.card(height: 100),
              SizedBox(height: 16),
              AutoSkeleton.card(height: 180),
              SizedBox(height: 16),
              AutoSkeleton.card(height: 140),
            ],
          ),
        ),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: AutoErrorState(
            title: 'Unable to load change requests',
            message: err.toString(),
            onRetry: () => ref.invalidate(quotationDetailProvider(widget.quotationId)),
          ),
        ),
      ),
      bottomNavigationBar: quoteAsync.maybeWhen(
        data: (quote) => _buildBottomBar(quote),
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildContent(QuotationModel quote) {
    // Gather all change requests across all revisions of this quotation
    final allChangeRequests = <MapEntry<QuotationRevisionModel, QuotationChangeRequestModel>>[];
    for (final rev in quote.revisions) {
      for (final cr in rev.changeRequests) {
        allChangeRequests.add(MapEntry(rev, cr));
      }
    }

    // Sort newest change requests first
    allChangeRequests.sort((a, b) => b.value.createdAt.compareTo(a.value.createdAt));

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Quotation & Client Summary Card
          _buildContextCard(quote),
          const SizedBox(height: 16),

          // 2. Change Requests Section Header
          Row(
            children: [
              const Icon(Icons.rate_review_outlined, color: AppColors.warning, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Negotiation History (${allChangeRequests.length})',
                  style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Change Requests List
          if (allChangeRequests.isEmpty)
            const AutoEmptyState(
              title: 'No Change Requests',
              message: 'This quotation has no client change requests on file.',
              icon: Icons.check_circle_outline,
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: allChangeRequests.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final entry = allChangeRequests[index];
                return _buildChangeRequestCard(entry.key, entry.value, quote);
              },
            ),
        ],
      ),
    );
  }

  Widget _buildContextCard(QuotationModel quote) {
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
                  Text(
                    quote.quotationNumber,
                    style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Revision ${quote.currentRevisionNumber} · ₹${quote.totalAmount.toStringAsFixed(0)}',
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                  ),
                ],
              ),
              AutoBadge.fromStatus(quote.currentStatus),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.border, height: 1),
          ),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Customer',
                      style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 10),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      quote.customerName,
                      style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.textPrimary),
                    ),
                    if (quote.customerPhone.isNotEmpty)
                      Text(
                        quote.customerPhone,
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Vehicle',
                      style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 10),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      quote.vehicleTitle,
                      style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.textPrimary),
                    ),
                    if (quote.vehiclePlate.isNotEmpty)
                      Text(
                        quote.vehiclePlate,
                        style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChangeRequestCard(
    QuotationRevisionModel rev,
    QuotationChangeRequestModel cr,
    QuotationModel quote,
  ) {
    final isPending = cr.status.toUpperCase() == 'PENDING';

    return AutoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Revision badge + Status badge
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Text(
                      'Revision ${rev.revisionNumber}',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AutoBadge.fromStatus(cr.status),
                ],
              ),
              Text(
                DateFormatter.formatDateTime(cr.createdAt),
                style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Client message box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppRadius.radiusMd,
              border: Border.all(
                color: isPending
                    ? AppColors.warning.withValues(alpha: 0.4)
                    : AppColors.border,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Client Request',
                  style: AppTypography.caption.copyWith(
                    color: isPending ? AppColors.warning : AppColors.textMuted,
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '“${cr.message}”',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),

          // Admin response if already resolved
          if (!isPending) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: AppRadius.radiusMd,
                border: Border.all(color: AppColors.border, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Admin Response · ${cr.status}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                          fontSize: 10,
                        ),
                      ),
                      if (cr.respondedAt != null)
                        Text(
                          DateFormatter.formatDateTime(cr.respondedAt!),
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 10,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (cr.adminResponse != null && cr.adminResponse!.isNotEmpty)
                        ? cr.adminResponse!
                        : 'No detailed comments provided with resolution.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Actions for pending request
          if (isPending) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () => _openRespondDialog(cr, quote),
                icon: const Icon(Icons.reply, size: 14, color: AppColors.warning),
                label: Text(
                  'Respond & Resolve',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.warning, width: 1),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSm),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBottomBar(QuotationModel quote) {
    final activeDraft = quote.revisions.where((r) => r.isDraft).firstOrNull;

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
              child: AutoButton.secondary(
                label: 'Back',
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/admin/quotes/${quote.id}');
                  }
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AutoButton.primary(
                label: activeDraft != null
                    ? 'Open Draft (Rev ${activeDraft.revisionNumber})'
                    : 'Create New Revision',
                icon: Icon(
                  activeDraft != null ? Icons.edit_note : Icons.add,
                  size: 18,
                  color: Colors.white,
                ),
                isLoading: _isCreatingRevision,
                onPressed: _isCreatingRevision ? null : () => _handleCreateNewRevision(quote),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
