import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/product_model.dart';
import '../../../design_system/components/auto_app_bar.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../providers/products_provider.dart';

/// A22 — Products Catalogue Screen conforming directly to Stitch A22 & DESIGN.md.
class ProductsListScreen extends ConsumerStatefulWidget {
  const ProductsListScreen({super.key});

  @override
  ConsumerState<ProductsListScreen> createState() => _ProductsListScreenState();
}

class _ProductsListScreenState extends ConsumerState<ProductsListScreen> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatPrice(double price) {
    final isWhole = price.truncateToDouble() == price;
    final parts = (isWhole ? price.toInt().toString() : price.toStringAsFixed(2)).split('.');
    final intPart = parts[0];
    final reg = RegExp(r'(\d+?)(?=(\d{3})+(?!\d))');
    final formattedInt = intPart.replaceAllMapped(reg, (m) => '${m[1]},');
    return '₹${parts.length > 1 ? '$formattedInt.${parts[1]}' : formattedInt}';
  }

  IconData _getCategoryIcon(String? category) {
    switch (category) {
      case ProductCategories.braking:
        return Icons.album_outlined;
      case ProductCategories.fluidsAndLubricants:
        return Icons.water_drop_outlined;
      case ProductCategories.filters:
        return Icons.air_outlined;
      case ProductCategories.suspension:
        return Icons.build_circle_outlined;
      case ProductCategories.electrical:
        return Icons.electric_bolt_outlined;
      case ProductCategories.ignition:
        return Icons.flash_on_outlined;
      default:
        return Icons.inventory_2_outlined;
    }
  }

  Color _getCategoryIconColor(String? category) {
    switch (category) {
      case ProductCategories.braking:
        return AppColors.warning;
      case ProductCategories.fluidsAndLubricants:
        return AppColors.primary;
      case ProductCategories.filters:
        return AppColors.textSecondary;
      case ProductCategories.suspension:
        return AppColors.warning;
      case ProductCategories.electrical:
        return AppColors.info;
      case ProductCategories.ignition:
        return AppColors.textMuted;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsListProvider);
    final metricsAsync = ref.watch(productMetricsProvider);
    final filter = ref.watch(productFilterProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AutoAppBar(
        title: 'Products Catalogue',
        showBack: Navigator.canPop(context),
        showLogo: !Navigator.canPop(context),
        onBack: () {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/admin');
          }
        },
        actions: [
          IconButton(
            tooltip: 'Refresh Catalogue',
            icon: const Icon(Icons.refresh, color: AppColors.textSecondary),
            onPressed: () => ref.invalidate(allProductsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add),
        label: Text(
          'Create Product',
          style: AppTypography.bodyMediumEmphasis.copyWith(color: Colors.white),
        ),
        onPressed: () => context.push('/admin/products/create'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        backgroundColor: AppColors.surface1,
        onRefresh: () async {
          ref.invalidate(allProductsProvider);
          await ref.read(allProductsProvider.future);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Context Header & Metrics
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CATALOGUE ITEMS',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textMuted,
                                  letterSpacing: 1.2,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Products Catalogue',
                                style: AppTypography.headlineSmall.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.surface1,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  color: AppColors.success,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Synced',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Quotation Rate Guide Context Banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface1,
                        borderRadius: AppRadius.radiusMd,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.info_outline,
                              color: AppColors.primary,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quotation Rate Guide',
                                  style: AppTypography.bodyMediumEmphasis.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Physical catalogue items used when building quotations. Default price is suggested quote value.',
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textMuted,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Search Input
                    Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.surface1,
                        borderRadius: AppRadius.radiusMd,
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Search products or category...',
                          hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                          prefixIcon: const Icon(Icons.search, color: AppColors.textMuted, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.close, color: AppColors.textMuted, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(productFilterProvider.notifier).setSearchQuery('');
                                    setState(() {});
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onChanged: (val) {
                          ref.read(productFilterProvider.notifier).setSearchQuery(val);
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Filter Pills Strip
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          // Status: ALL
                          _buildFilterChip(
                            label: metricsAsync.when(
                              data: (m) => 'All (${m.totalCount})',
                              loading: () => 'All',
                              error: (error, stackTrace) => 'All',
                            ),
                            isSelected: filter.status == 'ALL' && filter.category == 'ALL',
                            onTap: () {
                              ref.read(productFilterProvider.notifier).setStatus('ALL');
                              ref.read(productFilterProvider.notifier).setCategory('ALL');
                            },
                          ),
                          const SizedBox(width: 8),

                          // Status: ACTIVE
                          _buildFilterChip(
                            label: metricsAsync.when(
                              data: (m) => 'Active (${m.activeCount})',
                              loading: () => 'Active',
                              error: (error, stackTrace) => 'Active',
                            ),
                            isSelected: filter.status == 'ACTIVE',
                            onTap: () {
                              ref.read(productFilterProvider.notifier).setStatus(
                                    filter.status == 'ACTIVE' ? 'ALL' : 'ACTIVE',
                                  );
                            },
                          ),
                          const SizedBox(width: 8),

                          // Status: INACTIVE
                          _buildFilterChip(
                            label: metricsAsync.when(
                              data: (m) => 'Inactive (${m.inactiveCount})',
                              loading: () => 'Inactive',
                              error: (error, stackTrace) => 'Inactive',
                            ),
                            isSelected: filter.status == 'INACTIVE',
                            onTap: () {
                              ref.read(productFilterProvider.notifier).setStatus(
                                    filter.status == 'INACTIVE' ? 'ALL' : 'INACTIVE',
                                  );
                            },
                          ),
                          const SizedBox(width: 8),

                          Container(
                            width: 1,
                            height: 20,
                            color: AppColors.borderSubtle,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                          ),

                          // Approved Categories: Braking, Fluids & Lubricants, Filters, Suspension, Electrical, Ignition
                          ...ProductCategories.all.map((cat) {
                            final isCatSelected = filter.category == cat;
                            return Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: _buildFilterChip(
                                label: cat,
                                isSelected: isCatSelected,
                                onTap: () {
                                  ref.read(productFilterProvider.notifier).setCategory(
                                        isCatSelected ? 'ALL' : cat,
                                      );
                                },
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),

            // Product Cards List
            productsAsync.when(
              loading: () => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: List.generate(
                      4,
                      (_) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: AutoSkeleton.card(),
                      ),
                    ),
                  ),
                ),
              ),
              error: (err, _) => SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'Unable to load product catalogue',
                        style: AppTypography.headlineSmall.copyWith(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        err.toString(),
                        style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(allProductsProvider),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
                        child: const Text('Retry', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ),
              data: (products) {
                if (products.isEmpty) {
                  return SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 40, 16, 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: AppColors.surface1,
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              color: AppColors.textMuted,
                              size: 32,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No items found',
                            style: AppTypography.headlineSmall.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'No catalogue products match your search or filter criteria.',
                            style: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.border),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: () {
                              _searchController.clear();
                              ref.read(productFilterProvider.notifier).reset();
                              setState(() {});
                            },
                            child: const Text('Clear Filters'),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final product = products[index];
                        return _buildProductCard(context, product);
                      },
                      childCount: products.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primarySoft : AppColors.surface1,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: AppTypography.caption.copyWith(
            color: isSelected ? AppColors.primary : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildProductCard(BuildContext context, ProductModel product) {
    final catIcon = _getCategoryIcon(product.category);
    final catColor = _getCategoryIconColor(product.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: Icon + Category/Name + Status Badge
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(catIcon, color: catColor, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (product.category != null && product.category!.isNotEmpty)
                            Container(
                              margin: const EdgeInsets.only(bottom: 4),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.surface2,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                product.category!.toUpperCase(),
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          Text(
                            product.name,
                            style: AppTypography.bodyLargeEmphasis.copyWith(
                              color: product.isActive ? AppColors.textPrimary : AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Status Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: product.isActive
                            ? AppColors.successSoft
                            : AppColors.surface2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: product.isActive ? AppColors.success : AppColors.textMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            product.isActive ? 'ACTIVE' : 'INACTIVE',
                            style: AppTypography.caption.copyWith(
                              color: product.isActive ? AppColors.success : AppColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (product.description != null && product.description!.trim().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    product.description!,
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textMuted,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Bottom Price and CTA Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: const BoxDecoration(
              color: AppColors.surface2,
              border: Border(
                top: BorderSide(color: AppColors.border, width: 0.5),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Suggested Quote Value',
                        style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatPrice(product.defaultPrice),
                        style: AppTypography.headlineSmall.copyWith(
                          color: product.isActive ? AppColors.textPrimary : AppColors.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () => context.push('/admin/products/${product.id}/edit'),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'View / Edit',
                          style: AppTypography.bodyMediumEmphasis.copyWith(
                            color: product.isActive ? AppColors.primary : AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward,
                          size: 14,
                          color: product.isActive ? AppColors.primary : AppColors.textSecondary,
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
}
