import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/quotation_model.dart';
import '../../../design_system/components/auto_app_bar.dart';
import '../../../design_system/components/auto_badge.dart';
import '../../../design_system/components/auto_empty_state.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../providers/quotes_provider.dart';

/// A12 — Quote List Screen conforming directly to approved Stitch A12.
class QuoteListScreen extends ConsumerStatefulWidget {
  final String? initialFilter;

  const QuoteListScreen({
    super.key,
    this.initialFilter,
  });

  @override
  ConsumerState<QuoteListScreen> createState() => _QuoteListScreenState();
}

class _QuoteListScreenState extends ConsumerState<QuoteListScreen> {
  final TextEditingController _searchController = TextEditingController();
  late String _selectedStatus;
  String _searchQuery = '';

  static const List<String> _statusFilters = [
    'ALL',
    'DRAFT',
    'SENT',
    'VIEWED',
    'CHANGE_REQUESTED',
    'ACCEPTED',
    'REJECTED',
    'EXPIRED',
    'CANCELLED',
  ];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.initialFilter?.toUpperCase() ?? 'ALL';
    if (!_statusFilters.contains(_selectedStatus)) {
      _selectedStatus = 'ALL';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatStatusLabel(String status) {
    switch (status) {
      case 'ALL':
        return 'All';
      case 'DRAFT':
        return 'Draft';
      case 'SENT':
        return 'Sent';
      case 'VIEWED':
        return 'Viewed';
      case 'CHANGE_REQUESTED':
        return 'Change Requested';
      case 'ACCEPTED':
        return 'Accepted';
      case 'REJECTED':
        return 'Rejected';
      case 'EXPIRED':
        return 'Expired';
      case 'CANCELLED':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Color _getStatusAccentColor(String status) {
    switch (status.toUpperCase()) {
      case 'DRAFT':
        return AppColors.textMuted;
      case 'SENT':
      case 'VIEWED':
        return AppColors.info;
      case 'CHANGE_REQUESTED':
        return AppColors.warning;
      case 'ACCEPTED':
        return AppColors.success;
      case 'REJECTED':
      case 'CANCELLED':
        return AppColors.danger;
      case 'EXPIRED':
      default:
        return AppColors.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filterParams = QuotationFilterParams(
      statusFilter: _selectedStatus == 'ALL' ? null : _selectedStatus,
      searchQuery: _searchQuery.trim().isEmpty ? null : _searchQuery.trim(),
    );

    final quotesAsync = ref.watch(quotationsListProvider(filterParams));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AutoAppBar(
        title: 'Quotations',
        subtitle: 'Quotes & Revisions',
        showLogo: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary, size: 20),
            onPressed: () => ref.invalidate(quotationsListProvider(filterParams)),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Status Filter Section
          Container(
            color: AppColors.surface1.withValues(alpha: 0.6),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Search Bar
                Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: AppRadius.radiusMd,
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: TextField(
                    controller: _searchController,
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Search quote #, customer, vehicle...',
                      hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                      prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, color: AppColors.textMuted, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    ),
                    onChanged: (val) {
                      setState(() => _searchQuery = val);
                    },
                  ),
                ),

                const SizedBox(height: 10),

                // 2. Status Filter Chips
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _statusFilters.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final statusKey = _statusFilters[index];
                      final isSelected = _selectedStatus == statusKey;
                      final label = _formatStatusLabel(statusKey);

                      return InkWell(
                        onTap: () {
                          setState(() => _selectedStatus = statusKey);
                        },
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : AppColors.surface2,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.border,
                              width: 1,
                            ),
                          ),
                          child: Text(
                            label,
                            style: AppTypography.caption.copyWith(
                              color: isSelected ? Colors.white : AppColors.textSecondary,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          // Operational Counter Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: quotesAsync.maybeWhen(
                    data: (quotes) => Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Total Quotes: ${quotes.length}',
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    orElse: () => Text(
                      'Loading quotes...',
                      style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Sort: Recent',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),

          // Quotation List Content
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: AppColors.surface1,
              onRefresh: () async {
                ref.invalidate(quotationsListProvider(filterParams));
              },
              child: quotesAsync.when(
                data: (quotes) {
                  if (quotes.isEmpty) {
                    return ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 48),
                        AutoEmptyState(
                          title: 'No quotations found',
                          message: _searchQuery.isNotEmpty || _selectedStatus != 'ALL'
                              ? 'No quotations match the active filter or search query.'
                              : 'Create a quotation from an eligible Service Request to get started.',
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: quotes.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final quote = quotes[index];
                      return _buildQuoteCard(quote);
                    },
                  );
                },
                loading: () => ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: 4,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (_, _) => const AutoSkeleton.card(height: 160),
                ),
                error: (err, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: AutoErrorState(
                    title: 'Unable to load quotations',
                    message: err.toString(),
                    onRetry: () => ref.invalidate(quotationsListProvider(filterParams)),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteCard(QuotationModel quote) {
    final status = quote.currentStatus;
    final accentColor = _getStatusAccentColor(status);
    final totalFormatted = '₹${quote.totalAmount.toStringAsFixed(0)}';

    return InkWell(
      onTap: () => context.push('/admin/quotes/${quote.id}'),
      borderRadius: AppRadius.radiusLg,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface1,
          borderRadius: AppRadius.radiusLg,
          border: Border.all(color: AppColors.border, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored status indicator stripe
              Container(
                width: 4,
                color: accentColor,
              ),

              // Card content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Top Row: Number, Revision & Status Badge
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Row(
                              children: [
                                const Icon(Icons.receipt_long, color: AppColors.textMuted, size: 15),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    quote.quotationNumber,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyMediumEmphasis.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: AppColors.surface2,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'R${quote.currentRevisionNumber}',
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                          AutoBadge.fromStatus(status),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Customer & Vehicle Info
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  quote.customerName,
                                  style: AppTypography.bodyMediumEmphasis.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        quote.vehicleTitle,
                                        style: AppTypography.caption.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (quote.vehiclePlate.isNotEmpty) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                        decoration: BoxDecoration(
                                          color: AppColors.surface2,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          quote.vehiclePlate,
                                          style: AppTypography.caption.copyWith(
                                            color: AppColors.textSecondary,
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.directions_car_outlined,
                              color: AppColors.textSecondary,
                              size: 18,
                            ),
                          ),
                        ],
                      ),

                      // Service Note Snippet
                      if (quote.serviceSummary.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.surface2.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            quote.serviceSummary,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),
                      const Divider(color: AppColors.border, height: 1),
                      const SizedBox(height: 8),

                      // Bottom: Total & Contextual Action
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'QUOTED TOTAL',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textMuted,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                ),
                              ),
                              Text(
                                totalFormatted,
                                style: AppTypography.h3.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                'View Quote',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right, color: AppColors.primary, size: 18),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
