import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/product_model.dart';
import '../../../design_system/components/auto_app_bar.dart';
import '../../../design_system/components/auto_button.dart';
import '../../../design_system/components/auto_dialog.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/components/auto_toast.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../providers/products_provider.dart';

/// A23 — Product Detail / Edit Screen conforming to Stitch A23 & DESIGN.md.
class CreateEditProductScreen extends ConsumerStatefulWidget {
  final String? productId;

  const CreateEditProductScreen({
    super.key,
    this.productId,
  });

  bool get isEditMode => productId != null && productId!.isNotEmpty;

  @override
  ConsumerState<CreateEditProductScreen> createState() => _CreateEditProductScreenState();
}

class _CreateEditProductScreenState extends ConsumerState<CreateEditProductScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _descController;

  String _selectedCategory = ProductCategories.braking;
  bool _isActive = true;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _priceController = TextEditingController();
    _descController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _populateForm(ProductModel product) {
    if (_isInitialized) return;
    _nameController.text = product.name;
    _priceController.text = product.defaultPrice.truncateToDouble() == product.defaultPrice
        ? product.defaultPrice.toInt().toString()
        : product.defaultPrice.toStringAsFixed(2);
    _descController.text = product.description ?? '';
    if (ProductCategories.isValid(product.category)) {
      _selectedCategory = product.category!;
    } else {
      _selectedCategory = ProductCategories.braking;
    }
    _isActive = product.isActive;
    _isInitialized = true;
  }

  void _navigateBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/admin/products');
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final price = double.tryParse(_priceController.text.replaceAll(',', '').trim()) ?? 0.0;
    final desc = _descController.text.trim();

    if (widget.isEditMode) {
      final updated = await ref.read(productFormProvider.notifier).updateProduct(
            id: widget.productId!,
            name: name,
            category: _selectedCategory,
            defaultPrice: price,
            description: desc.isEmpty ? null : desc,
            isActive: _isActive,
          );

      if (!mounted) return;
      if (updated != null) {
        AutoToast.showSuccess(context, 'Product updated successfully');
        _navigateBack();
      } else {
        final err = ref.read(productFormProvider).errorMessage ?? 'Failed to update product';
        AutoToast.showError(context, err);
      }
    } else {
      final created = await ref.read(productFormProvider.notifier).createProduct(
            name: name,
            category: _selectedCategory,
            defaultPrice: price,
            description: desc.isEmpty ? null : desc,
            isActive: _isActive,
          );

      if (!mounted) return;
      if (created != null) {
        AutoToast.showSuccess(context, 'Product created successfully');
        _navigateBack();
      } else {
        final err = ref.read(productFormProvider).errorMessage ?? 'Failed to create product';
        AutoToast.showError(context, err);
      }
    }
  }

  Future<void> _handleDeactivateToggle(ProductModel product) async {
    if (_isActive) {
      // Show confirmation dialog for deactivation
      final confirmed = await AutoDialog.show(
        context: context,
        title: 'Deactivate Product?',
        message:
            'This product will no longer appear when creating new quotations. Existing signed quotes and service jobs will retain their historical pricing snapshots.',
        confirmLabel: 'Confirm Deactivation',
        cancelLabel: 'Cancel',
        isDestructive: true,
      );

      if (confirmed == true && mounted) {
        final updated = await ref.read(productFormProvider.notifier).toggleStatus(
              id: product.id,
              isActive: false,
            );
        if (!mounted) return;
        if (updated != null) {
          setState(() {
            _isActive = false;
          });
          AutoToast.showSuccess(context, 'Product deactivated successfully');
        } else {
          final err = ref.read(productFormProvider).errorMessage ?? 'Failed to deactivate product';
          AutoToast.showError(context, err);
        }
      }
    } else {
      // Reactivate
      final updated = await ref.read(productFormProvider.notifier).toggleStatus(
            id: product.id,
            isActive: true,
          );
      if (!mounted) return;
      if (updated != null) {
        setState(() {
          _isActive = true;
        });
        AutoToast.showSuccess(context, 'Product reactivated successfully');
      } else {
        final err = ref.read(productFormProvider).errorMessage ?? 'Failed to reactivate product';
        AutoToast.showError(context, err);
      }
    }
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

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(productFormProvider);

    if (widget.isEditMode) {
      final productAsync = ref.watch(productDetailProvider(widget.productId!));

      return productAsync.when(
        loading: () => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AutoAppBar(
            title: 'Edit Product',
            showBack: true,
            showLogo: false,
            onBack: _navigateBack,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                AutoSkeleton.card(),
                const SizedBox(height: 16),
                AutoSkeleton.card(),
              ],
            ),
          ),
        ),
        error: (err, _) => Scaffold(
          backgroundColor: AppColors.background,
          appBar: AutoAppBar(
            title: 'Edit Product',
            showBack: true,
            showLogo: false,
            onBack: _navigateBack,
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
                const SizedBox(height: 12),
                Text('Product not found', style: AppTypography.headlineSmall),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: _navigateBack,
                  child: const Text('Back to Catalogue'),
                ),
              ],
            ),
          ),
        ),
        data: (product) {
          _populateForm(product);
          return _buildScaffold(context, formState, product: product);
        },
      );
    }

    return _buildScaffold(context, formState);
  }

  Widget _buildScaffold(
    BuildContext context,
    ProductFormState formState, {
    ProductModel? product,
  }) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AutoAppBar(
        title: widget.isEditMode ? 'Edit Product' : 'New Catalogue Item',
        showBack: true,
        showLogo: false,
        onBack: _navigateBack,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Breadcrumb / Context header
              if (widget.isEditMode && product != null) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          const Icon(Icons.inventory_2_outlined, color: AppColors.textMuted, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Catalog / Component #${product.id.length >= 8 ? product.id.substring(0, 8).toUpperCase() : product.id.toUpperCase()}',
                              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _isActive
                            ? AppColors.successSoft
                            : AppColors.surface2,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _isActive ? AppColors.success : AppColors.textMuted,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _isActive ? 'ACTIVE' : 'INACTIVE',
                            style: AppTypography.caption.copyWith(
                              color: _isActive ? AppColors.success : AppColors.textMuted,
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
                const SizedBox(height: 12),

                // 2. Product Header Summary Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: AppRadius.radiusLg,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _getCategoryIcon(product.category),
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              style: AppTypography.headlineSmall.copyWith(
                                color: AppColors.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                if (product.category != null) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  _formatPrice(product.defaultPrice),
                                  style: AppTypography.bodyMediumEmphasis.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                const Icon(Icons.schedule, color: AppColors.textMuted, size: 12),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Updated ${product.updatedAt.day} ${_monthName(product.updatedAt.month)} ${product.updatedAt.year}',
                                    style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // 3. Quotation Snapshot Rule Notice
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: AppRadius.radiusMd,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.infoSoft,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.info_outline,
                        color: AppColors.info,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Quotation Snapshot Rule',
                            style: AppTypography.bodyMediumEmphasis.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'The Default Price is the suggested value when adding this item to a new quotation. Existing signed quotation revisions and job snapshots will not be affected by price changes.',
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
              const SizedBox(height: 18),

              // 4. Form Fields
              // Field 1: Product Name
              _buildFieldHeader('Product Name *', 'Canonical Title'),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: AppRadius.radiusMd,
                  border: Border.all(color: AppColors.border),
                ),
                child: TextFormField(
                  controller: _nameController,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'e.g. Brake Pad Set (Front)',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    suffixIcon: Icon(Icons.edit_note, color: AppColors.textMuted),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Product name is required';
                    }
                    if (val.trim().length < 2) {
                      return 'Name must be at least 2 characters';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Field 2: Category Dropdown (Strictly locked to approved 6 categories per user constraint)
              _buildFieldHeader('Category *', 'Workshop Taxonomy'),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: AppRadius.radiusMd,
                  border: Border.all(color: AppColors.border),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCategory,
                    isExpanded: true,
                    dropdownColor: AppColors.surface2,
                    icon: const Icon(Icons.expand_more, color: AppColors.textMuted),
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                    items: ProductCategories.all.map((cat) {
                      return DropdownMenuItem<String>(
                        value: cat,
                        child: Text(cat),
                      );
                    }).toList(),
                    onChanged: (newVal) {
                      if (newVal != null) {
                        setState(() {
                          _selectedCategory = newVal;
                        });
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Field 3: Default Price (₹)
              _buildFieldHeader('Default Price (₹) *', 'Pre-tax MSRP', rightColor: AppColors.primary),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: AppRadius.radiusMd,
                  border: Border.all(color: AppColors.border),
                ),
                child: TextFormField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  style: AppTypography.bodyLargeEmphasis.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    prefixIcon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                      child: Text(
                        '₹',
                        style: AppTypography.headlineSmall.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                    suffixIcon: Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'INR',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    hintText: '0.00',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Default price is required';
                    }
                    final price = double.tryParse(val.replaceAll(',', '').trim());
                    if (price == null) {
                      return 'Please enter a valid numeric amount';
                    }
                    if (price < 0) {
                      return 'Price cannot be negative';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Suggested default value for quotation line items',
                style: AppTypography.caption.copyWith(color: AppColors.textMuted),
              ),
              const SizedBox(height: 16),

              // Field 4: Description
              _buildFieldHeader('Description', 'Quotation Subtitle'),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: AppRadius.radiusMd,
                  border: Border.all(color: AppColors.border),
                ),
                child: TextFormField(
                  controller: _descController,
                  maxLines: 3,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                  decoration: const InputDecoration(
                    hintText: 'Detailed service or part note displayed to clients...',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.all(14),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Field 5: Product Status Selector
              Text(
                'Product Status',
                style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surface1,
                  borderRadius: AppRadius.radiusMd,
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isActive = true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _isActive ? AppColors.primary : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: _isActive ? Colors.white : AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Active',
                                style: AppTypography.bodyMediumEmphasis.copyWith(
                                  color: _isActive ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: InkWell(
                        onTap: () => setState(() => _isActive = false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: !_isActive ? AppColors.surface2 : Colors.transparent,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.block,
                                size: 16,
                                color: !_isActive ? AppColors.warning : AppColors.textMuted,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Inactive',
                                style: AppTypography.bodyMediumEmphasis.copyWith(
                                  color: !_isActive ? AppColors.warning : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              AutoButton(
                label: widget.isEditMode ? 'Save Changes' : 'Create Product',
                variant: AutoButtonVariant.primary,
                isLoading: formState.isSubmitting,
                icon: Icon(widget.isEditMode ? Icons.save_outlined : Icons.add, size: 18, color: Colors.white),
                onPressed: formState.isSubmitting ? null : _handleSave,
              ),
              const SizedBox(height: 10),
              AutoButton(
                label: 'Cancel',
                variant: AutoButtonVariant.secondary,
                onPressed: _navigateBack,
              ),

              // 5. Deactivation Zone (Edit mode only)
              if (widget.isEditMode && product != null) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: AppRadius.radiusLg,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: _isActive ? AppColors.warning : AppColors.success,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Product Status',
                            style: AppTypography.bodyLargeEmphasis.copyWith(color: AppColors.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Inactive products will no longer be available for new quotations. Existing quotation history and signed repair orders remain completely unchanged.',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 14),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _isActive ? AppColors.danger : AppColors.success,
                          side: BorderSide(
                            color: _isActive ? AppColors.danger : AppColors.success,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size.fromHeight(44),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: formState.isSubmitting
                            ? null
                            : () => _handleDeactivateToggle(product),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _isActive ? Icons.power_settings_new : Icons.refresh,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                _isActive ? 'Deactivate Product' : 'Reactivate Product',
                                style: AppTypography.bodyMediumEmphasis.copyWith(
                                  color: _isActive ? AppColors.danger : AppColors.success,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFieldHeader(String title, String subtitle, {Color? rightColor}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(
            title,
            style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.textPrimary),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          subtitle,
          style: AppTypography.caption.copyWith(
            color: rightColor ?? AppColors.textMuted,
            fontWeight: rightColor != null ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  String _monthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return (month >= 1 && month <= 12) ? months[month - 1] : '';
  }
}
