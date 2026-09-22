import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/quotation_model.dart';
import '../../../design_system/components/auto_badge.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_empty_state.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../providers/client_portal_provider.dart';
import '../utils/client_quotation_status_helper.dart';

/// C07 — My Quotes Screen conforming to approved Day 10 specifications.
class ClientQuotesScreen extends ConsumerWidget {
  const ClientQuotesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allQuotesAsync = ref.watch(clientQuotationsProvider);
    final filteredQuotesAsync = ref.watch(clientFilteredQuotationsProvider);
    final activeFilter = ref.watch(clientQuoteFilterProvider);
    final pendingCount = ref.watch(clientPendingQuotesCountProvider);

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
              context.go('/client/services');
            }
          },
        ),
        title: Text(
          'My Quotes',
          style: AppTypography.headlineSm.copyWith(
            color: AppColors.textPrimary,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface2,
        onRefresh: () async {
          ref.invalidate(clientQuotationsProvider);
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
              // Header description
              Text(
                'Vehicle Estimates',
                style: AppTypography.headlineMd.copyWith(
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Review, accept, or request changes on estimates prepared for your vehicle.',
                style: AppTypography.bodyMd.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: AppSpacing.md),

              // Action Required Banner (if any quotes are SENT or VIEWED)
              if (pendingCount > 0) ...[
                _buildActionRequiredBanner(context, pendingCount, allQuotesAsync),
                const SizedBox(height: AppSpacing.md),
              ],

              // Filter Chips Carousel
              allQuotesAsync.maybeWhen(
                data: (allQuotes) => _buildFilterChips(
                  ref,
                  activeFilter: activeFilter,
                  allQuotes: allQuotes,
                ),
                orElse: () => const SizedBox.shrink(),
              ),
              const SizedBox(height: AppSpacing.md),

              // Quotations List
              filteredQuotesAsync.when(
                skipLoadingOnReload: true,
                skipLoadingOnRefresh: true,
                data: (List<QuotationModel> filteredList) {
                  if (filteredList.isEmpty) {
                    final isAll = activeFilter == 'all';
                    return AutoEmptyState(
                      title: isAll ? 'No Quotations' : 'No Quotes Found',
                      message: isAll
                          ? 'You do not have any vehicle quotations at this time.'
                          : 'There are no quotations under this tab right now.',
                      icon: isAll
                          ? Icons.receipt_long_outlined
                          : Icons.search_off_outlined,
                    );
                  }

                  return Column(
                    children: filteredList
                        .map((quote) => Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpacing.md,
                              ),
                              child: _buildQuoteCard(context, quote),
                            ))
                        .toList(),
                  );
                },
                loading: () => const Column(
                  children: [
                    AutoSkeleton(height: 180),
                    SizedBox(height: AppSpacing.md),
                    AutoSkeleton(height: 180),
                  ],
                ),
                error: (err, _) => AutoErrorState(
                  title: 'Unable to Load Quotes',
                  message: 'Unable to load your quotations. Please try again.',
                  onRetry: () => ref.invalidate(clientQuotationsProvider),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionRequiredBanner(
    BuildContext context,
    int pendingCount,
    AsyncValue<List<QuotationModel>> allQuotesAsync,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface2,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: Container(color: AppColors.primary),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.bolt,
                    color: AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Action Required',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'You have $pendingCount ${pendingCount == 1 ? 'quote' : 'quotes'} awaiting your review.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                allQuotesAsync.maybeWhen(
                  data: (quotes) {
                    final firstPending = quotes.firstWhere(
                      (q) =>
                          q.currentStatus.toUpperCase() == 'SENT' ||
                          q.currentStatus.toUpperCase() == 'VIEWED',
                      orElse: () => quotes.first,
                    );
                    return TextButton(
                      onPressed: () =>
                          context.push('/client/quotes/${firstPending.id}'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: AppSpacing.xs,
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            'Review',
                            style: AppTypography.labelSm.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward, size: 14),
                        ],
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips(
    WidgetRef ref, {
    required String activeFilter,
    required List<QuotationModel> allQuotes,
  }) {
    final activeCount = allQuotes.where((q) {
      final s = q.currentStatus.toUpperCase();
      return s == 'SENT' ||
          s == 'VIEWED' ||
          s == 'CHANGE_REQUESTED' ||
          s == 'ACCEPTED';
    }).length;

    final pastCount = allQuotes.where((q) {
      final s = q.currentStatus.toUpperCase();
      return s == 'REJECTED' ||
          s == 'SUPERSEDED' ||
          s == 'CANCELLED' ||
          s == 'EXPIRED';
    }).length;

    final filters = [
      {'key': 'all', 'label': 'All', 'count': allQuotes.length},
      {'key': 'active', 'label': 'Active', 'count': activeCount},
      {'key': 'past', 'label': 'Past Quotes', 'count': pastCount},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: filters.map((f) {
          final isSelected = activeFilter == f['key'];
          final count = f['count'] as int;

          return Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: ChoiceChip(
              label: Text(
                '${f['label']} ($count)',
                style: AppTypography.labelSm.copyWith(
                  color: isSelected
                      ? Colors.white
                      : AppColors.textSecondary,
                  fontWeight:
                      isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              selected: isSelected,
              onSelected: (_) {
                ref
                    .read(clientQuoteFilterProvider.notifier)
                    .setFilter(f['key'] as String);
              },
              selectedColor: AppColors.primary,
              backgroundColor: AppColors.surface2,
              side: BorderSide(
                color: isSelected
                    ? AppColors.primary
                    : AppColors.borderSubtle,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppRadius.full),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuoteCard(BuildContext context, QuotationModel quote) {
    final rev = quote.latestRevision;
    final status = quote.currentStatus;
    final statusInfo = ClientQuotationStatusHelper.getStatusInfo(status);
    final dateString = rev != null
        ? ClientQuotationStatusHelper.getFormattedRevisionDate(rev)
        : '';
    final isActionPending =
        status.toUpperCase() == 'SENT' || status.toUpperCase() == 'VIEWED';

    return AutoCard(
      onTap: () => context.push('/client/quotes/${quote.id}'),
      backgroundColor: AppColors.surface1,
      borderColor: isActionPending
          ? AppColors.primary.withValues(alpha: 0.35)
          : AppColors.borderSubtle,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Vehicle Title & Status Pill
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.vehicleTitle,
                        style: AppTypography.headlineSm.copyWith(
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text.rich(
                        TextSpan(
                          text: quote.quotationNumber,
                          style: AppTypography.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                          children: [
                            if (rev != null)
                              TextSpan(
                                text: ' · Rev ${rev.revisionNumber}',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textMuted,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                AutoBadge(
                  label: statusInfo.label,
                  color: statusInfo.color,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),

            // Date line (strictly real database fields)
            if (dateString.isNotEmpty) ...[
              Row(
                children: [
                  Icon(
                    statusInfo.icon,
                    size: 13,
                    color: AppColors.textMuted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    dateString,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
            ],

            // Scope / Line Items Summary
            if (rev != null && rev.items.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.xs),
                ),
                child: Text(
                  '${rev.items.length} ${rev.items.length == 1 ? 'item' : 'items'} included: ${rev.items.first.name}${rev.items.length > 1 ? ' + more' : ''}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
            ],

            const Divider(color: AppColors.borderSubtle, height: 1),
            const SizedBox(height: AppSpacing.sm),

            // Bottom Financials and Action Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '₹${quote.totalAmount.toStringAsFixed(0)}',
                        style: AppTypography.headlineSm.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (rev != null && rev.tax > 0)
                        Text(
                          'Tax: ₹${rev.tax.toStringAsFixed(0)}',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                            fontSize: 11,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _buildCardActionButton(context, quote, isActionPending),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardActionButton(
    BuildContext context,
    QuotationModel quote,
    bool isActionPending,
  ) {
    final status = quote.currentStatus.toUpperCase();

    if (isActionPending) {
      return ElevatedButton(
        onPressed: () => context.push('/client/quotes/${quote.id}'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Review Quote',
              style: AppTypography.labelSm.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward, size: 14),
          ],
        ),
      );
    }

    if (status == 'CHANGE_REQUESTED') {
      return OutlinedButton(
        onPressed: () => context.push('/client/quotes/${quote.id}'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.warning,
          side: const BorderSide(color: AppColors.warning),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: Text(
          'View Details',
          style: AppTypography.labelSm.copyWith(
            color: AppColors.warning,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    if (status == 'ACCEPTED') {
      return OutlinedButton(
        onPressed: () => context.push('/client/quotes/${quote.id}'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.success,
          side: const BorderSide(color: AppColors.success),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
        child: Text(
          'View Details',
          style: AppTypography.labelSm.copyWith(
            color: AppColors.success,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    }

    // Default view button for past quotes (REJECTED, etc.)
    return OutlinedButton(
      onPressed: () => context.push('/client/quotes/${quote.id}'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.textSecondary,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      child: Text(
        'View Details',
        style: AppTypography.labelSm.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
