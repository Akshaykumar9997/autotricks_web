import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/quotation_model.dart';
import '../../../design_system/components/auto_app_bar.dart';
import '../../../design_system/components/auto_badge.dart';
import '../../../design_system/components/auto_button.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_error_state.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/components/auto_toast.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../components/catalogue_product_picker_sheet.dart';
import '../providers/quotes_provider.dart';

/// State representation for an item in the A15 draft revision editor.
class _EditableItemEntry {
  final String? id;
  final String? catalogueProductId;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController rateController;

  _EditableItemEntry({
    this.id,
    this.catalogueProductId,
    required String name,
    String? description,
    double quantity = 1.0,
    double finalValue = 0.0,
  })  : nameController = TextEditingController(text: name),
        descriptionController = TextEditingController(text: description ?? ''),
        quantityController = TextEditingController(
          text: quantity.toStringAsFixed(quantity.truncateToDouble() == quantity ? 0 : 2),
        ),
        rateController = TextEditingController(
          text: finalValue.toStringAsFixed(0),
        );

  double get quantity => double.tryParse(quantityController.text.trim()) ?? 0.0;
  double get finalValue => double.tryParse(rateController.text.trim()) ?? 0.0;
  double get lineTotal => (quantity > 0 && finalValue >= 0) ? quantity * finalValue : 0.0;

  DraftQuotationItemInput toInput() {
    return DraftQuotationItemInput(
      id: id,
      catalogueProductId: catalogueProductId,
      name: nameController.text.trim(),
      description: descriptionController.text.trim().isNotEmpty
          ? descriptionController.text.trim()
          : null,
      quantity: quantity,
      finalValue: finalValue,
    );
  }

  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    quantityController.dispose();
    rateController.dispose();
  }
}

/// A15 — Edit Quote Revision screen conforming to approved Stitch A15 and DESIGN.md.
/// Strictly enforces that only DRAFT revisions can be edited.
class EditQuoteRevisionScreen extends ConsumerStatefulWidget {
  final String quotationId;
  final String revisionId;

  const EditQuoteRevisionScreen({
    super.key,
    required this.quotationId,
    required this.revisionId,
  });

  @override
  ConsumerState<EditQuoteRevisionScreen> createState() => _EditQuoteRevisionScreenState();
}

class _EditQuoteRevisionScreenState extends ConsumerState<EditQuoteRevisionScreen> {
  final List<_EditableItemEntry> _items = [];
  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _taxController = TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _termsController = TextEditingController();

  bool _isInitialized = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _discountController.addListener(_onCalculationsChanged);
    _taxController.addListener(_onCalculationsChanged);
  }

  @override
  void dispose() {
    for (final item in _items) {
      item.dispose();
    }
    _discountController.dispose();
    _taxController.dispose();
    _notesController.dispose();
    _termsController.dispose();
    super.dispose();
  }

  void _onCalculationsChanged() {
    if (mounted) setState(() {});
  }

  void _populateFromRevision(QuotationRevisionModel revision) {
    if (_isInitialized) return;
    _isInitialized = true;

    for (final item in revision.items) {
      final entry = _EditableItemEntry(
        id: item.id,
        catalogueProductId: item.catalogueProductId,
        name: item.name,
        description: item.description,
        quantity: item.quantity,
        finalValue: item.finalValue,
      );
      entry.quantityController.addListener(_onCalculationsChanged);
      entry.rateController.addListener(_onCalculationsChanged);
      _items.add(entry);
    }

    _discountController.text = revision.discount.toStringAsFixed(0);
    _taxController.text = revision.tax.toStringAsFixed(0);
    _notesController.text = revision.notes ?? '';
    _termsController.text = revision.terms ?? '';
  }

  double get _subtotal {
    return _items.fold<double>(0.0, (sum, item) => sum + item.lineTotal);
  }

  double get _discount {
    return double.tryParse(_discountController.text.trim()) ?? 0.0;
  }

  double get _tax {
    return double.tryParse(_taxController.text.trim()) ?? 0.0;
  }

  double get _total {
    final sub = _subtotal;
    final disc = _discount;
    final t = _tax;
    final afterDiscount = (sub - disc) > 0 ? (sub - disc) : 0.0;
    return afterDiscount + t;
  }

  void _addNewCustomItem() {
    setState(() {
      final entry = _EditableItemEntry(
        name: '',
        description: '',
        quantity: 1,
        finalValue: 0,
      );
      entry.quantityController.addListener(_onCalculationsChanged);
      entry.rateController.addListener(_onCalculationsChanged);
      _items.add(entry);
    });
  }

  void _addCatalogueItem(ProductModel product) {
    setState(() {
      final entry = _EditableItemEntry(
        catalogueProductId: product.id,
        name: product.name,
        description: product.description,
        quantity: 1,
        finalValue: product.defaultPrice,
      );
      entry.quantityController.addListener(_onCalculationsChanged);
      entry.rateController.addListener(_onCalculationsChanged);
      _items.add(entry);
    });
  }

  void _openCataloguePicker() {
    showModalBottomSheet<ProductModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const CatalogueProductPickerSheet(),
    ).then((product) {
      if (product != null) {
        _addCatalogueItem(product);
      }
    });
  }

  void _removeItem(int index) {
    setState(() {
      final removed = _items.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _handleSaveChanges() async {
    // 1. Validation
    if (_items.isEmpty) {
      AutoToast.showInfo(context, 'Please add at least one line item.');
      return;
    }

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      if (item.nameController.text.trim().isEmpty) {
        AutoToast.showInfo(context, 'Line item #${i + 1} must have a valid name.');
        return;
      }
      if (item.quantity <= 0) {
        AutoToast.showInfo(context, 'Line item #${i + 1} must have a quantity greater than zero.');
        return;
      }
      if (item.finalValue < 0) {
        AutoToast.showInfo(context, 'Line item #${i + 1} cannot have a negative rate.');
        return;
      }
    }

    if (_discount < 0) {
      AutoToast.showInfo(context, 'Discount cannot be negative.');
      return;
    }

    if (_tax < 0) {
      AutoToast.showInfo(context, 'Tax cannot be negative.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final itemsPayload = _items.map((entry) => entry.toInput()).toList();

      await ref.read(quotationsRepositoryProvider).updateDraftRevision(
            revisionId: widget.revisionId,
            items: itemsPayload,
            discount: _discount,
            tax: _tax,
            notes: _notesController.text.trim(),
            terms: _termsController.text.trim(),
          );

      // Invalidate relevant providers to force reload
      ref.invalidate(quotationDetailProvider(widget.quotationId));
      ref.invalidate(quotationsListProvider);

      if (mounted) {
        AutoToast.showSuccess(context, 'Revision changes saved successfully.');
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          context.go('/admin/quotes/${widget.quotationId}');
        }
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = _mapErrorMessage(e.toString());
        AutoToast.showError(context, errorMsg);
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  String _mapErrorMessage(String error) {
    final lower = error.toLowerCase();
    if (lower.contains('only draft') || lower.contains('prevent_signed_item_mutation')) {
      return 'Only draft revisions can be edited. This revision is locked.';
    }
    if (lower.contains('quotation_items_quantity_ck')) {
      return 'Quantity must be greater than zero for all items.';
    }
    if (lower.contains('quotation_items_values_ck')) {
      return 'Item values and line totals cannot be negative.';
    }
    return 'Unable to save revision changes. Please verify the inputs and try again.';
  }

  @override
  Widget build(BuildContext context) {
    final quoteAsync = ref.watch(quotationDetailProvider(widget.quotationId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AutoAppBar(
        title: 'Edit Quote Revision',
        showBack: true,
        showLogo: false,
        onBack: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/admin/quotes/${widget.quotationId}');
          }
        },
      ),
      body: quoteAsync.when(
        data: (quote) {
          // Locate the specific revision
          final revision = quote.revisions.firstWhere(
            (r) => r.id == widget.revisionId,
            orElse: () => quote.currentRevision ?? quote.revisions.first,
          );

          // IMMUTABILITY GUARD: Block editing of non-DRAFT revisions
          if (!revision.isDraft) {
            return _buildLockedRevisionView(quote, revision);
          }

          // Populate form fields on initial load
          _populateFromRevision(revision);

          return _buildEditableForm(quote, revision);
        },
        loading: () => const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              AutoSkeleton.card(height: 100),
              SizedBox(height: 16),
              AutoSkeleton.card(height: 200),
              SizedBox(height: 16),
              AutoSkeleton.card(height: 140),
            ],
          ),
        ),
        error: (err, _) => Padding(
          padding: const EdgeInsets.all(24),
          child: AutoErrorState(
            title: 'Unable to load revision',
            message: err.toString(),
            onRetry: () => ref.invalidate(quotationDetailProvider(widget.quotationId)),
          ),
        ),
      ),
      bottomNavigationBar: quoteAsync.maybeWhen(
        data: (quote) {
          final revision = quote.revisions.firstWhere(
            (r) => r.id == widget.revisionId,
            orElse: () => quote.currentRevision ?? quote.revisions.first,
          );
          if (!revision.isDraft) return const SizedBox.shrink();
          return _buildBottomActionBar();
        },
        orElse: () => const SizedBox.shrink(),
      ),
    );
  }

  /// Immutability guard banner for non-DRAFT revisions.
  Widget _buildLockedRevisionView(QuotationModel quote, QuotationRevisionModel revision) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: AutoCard(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 36),
              ),
              const SizedBox(height: 16),
              Text(
                'Revision ${revision.revisionNumber} is Locked',
                style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              AutoBadge.fromStatus(revision.status),
              const SizedBox(height: 16),
              Text(
                'This revision is in ${revision.status} status and is an immutable historical snapshot. In AutoTricks, only DRAFT revisions can be edited.',
                textAlign: TextAlign.center,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 24),
              AutoButton.primary(
                label: 'Back to Quote Details',
                icon: const Icon(Icons.arrow_back, size: 18, color: Colors.white),
                onPressed: () {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  } else {
                    context.go('/admin/quotes/${quote.id}');
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditableForm(QuotationModel quote, QuotationRevisionModel revision) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Revision Identity & Editable Notice
          _buildRevisionBanner(quote, revision),
          const SizedBox(height: 16),

          // 2. Line Items Header & Action Buttons
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Quoted Items (${_items.length})',
                style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: _openCataloguePicker,
                    icon: const Icon(Icons.inventory_2_outlined, size: 14, color: AppColors.primary),
                    label: Text(
                      'Catalogue',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary, width: 1),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSm),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _addNewCustomItem,
                    icon: const Icon(Icons.add, size: 14, color: Colors.white),
                    label: Text(
                      'Add Item',
                      style: AppTypography.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusSm),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Line Items List
          if (_items.isEmpty)
            _buildEmptyItemsPlaceholder()
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) => _buildItemEditorCard(index),
            ),

          const SizedBox(height: 20),

          // 4. Financial Calculations & Summary Card
          _buildCalculationsCard(),

          const SizedBox(height: 20),

          // 5. Notes & Terms
          _buildNotesAndTermsCard(),
        ],
      ),
    );
  }

  Widget _buildRevisionBanner(QuotationModel quote, QuotationRevisionModel revision) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.edit_note, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      quote.quotationNumber,
                      style: AppTypography.bodyMediumEmphasis.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: AppColors.border, width: 1),
                      ),
                      child: Text(
                        'Revision ${revision.revisionNumber}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'This revision is editable. Changes will update Revision ${revision.revisionNumber} draft values.',
                  style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyItemsPlaceholder() {
    return AutoCard(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.receipt_long_outlined, color: AppColors.textMuted, size: 36),
            const SizedBox(height: 10),
            Text(
              'No Line Items in Draft',
              style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 6),
            Text(
              'Add at least one item from the catalogue or create a custom item.',
              textAlign: TextAlign.center,
              style: AppTypography.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItemEditorCard(int index) {
    final item = _items[index];

    return AutoCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Item header & delete button
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '#${index + 1}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (item.catalogueProductId != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.inventory_2, size: 10, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Catalogue',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _removeItem(index),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Name Input
          TextField(
            controller: item.nameController,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Item / Service Name *',
              labelStyle: AppTypography.caption.copyWith(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(
                borderRadius: AppRadius.radiusSm,
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.radiusSm,
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.radiusSm,
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),

          // Description Input
          TextField(
            controller: item.descriptionController,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Description (Optional)',
              labelStyle: AppTypography.caption.copyWith(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(
                borderRadius: AppRadius.radiusSm,
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: AppRadius.radiusSm,
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: AppRadius.radiusSm,
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),

          // Quantity, Rate, and Line Total Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Quantity
              Expanded(
                flex: 2,
                child: TextField(
                  controller: item.quantityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Qty *',
                    labelStyle: AppTypography.caption.copyWith(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surface2,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.radiusSm,
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.radiusSm,
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.radiusSm,
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Final Value / Unit Rate
              Expanded(
                flex: 3,
                child: TextField(
                  controller: item.rateController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Rate (₹) *',
                    labelStyle: AppTypography.caption.copyWith(color: AppColors.textMuted),
                    prefixText: '₹ ',
                    prefixStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surface2,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.radiusSm,
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadius.radiusSm,
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadius.radiusSm,
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Line Total
              Expanded(
                flex: 3,
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface1,
                    borderRadius: AppRadius.radiusSm,
                    border: Border.all(color: AppColors.border, width: 1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Total',
                        style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 10),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: Text(
                          '₹${item.lineTotal.toStringAsFixed(0)}',
                          style: AppTypography.bodyMediumEmphasis.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalculationsCard() {
    return AutoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_outlined, color: AppColors.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Financial Breakdown',
                  style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Subtotal
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Subtotal (${_items.length} items)',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              Text(
                '₹${_subtotal.toStringAsFixed(0)}',
                style: AppTypography.bodyMediumEmphasis.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Discount Input
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Discount',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                flex: 2,
                child: TextField(
                  key: const Key('field_discount'),
                  controller: _discountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  textAlign: TextAlign.end,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    prefixText: '- ₹ ',
                    prefixStyle: AppTypography.bodyMedium.copyWith(color: AppColors.danger),
                    filled: true,
                    fillColor: AppColors.surface2,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.radiusSm,
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Tax Input (Strictly generic "Tax", zero GST/VAT hardcoding per Day 7 final corrections)
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  'Tax',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ),
              Expanded(
                flex: 2,
                child: TextField(
                  key: const Key('field_tax'),
                  controller: _taxController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  textAlign: TextAlign.end,
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    prefixText: '+ ₹ ',
                    prefixStyle: AppTypography.bodyMedium.copyWith(color: AppColors.info),
                    filled: true,
                    fillColor: AppColors.surface2,
                    border: OutlineInputBorder(
                      borderRadius: AppRadius.radiusSm,
                      borderSide: const BorderSide(color: AppColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(color: AppColors.border, height: 1),
          ),

          // Final Total
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'Quotation Total',
                style: AppTypography.bodyMediumEmphasis.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '₹${_total.toStringAsFixed(0)}',
                style: AppTypography.h2.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesAndTermsCard() {
    return AutoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.description_outlined, color: AppColors.textSecondary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Notes & Commercial Terms',
                  style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Notes
          TextField(
            controller: _notesController,
            maxLines: 3,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Internal Notes',
              labelStyle: AppTypography.caption.copyWith(color: AppColors.textMuted),
              hintText: 'Add revision rationale or internal workshop notes...',
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
          const SizedBox(height: 12),

          // Terms
          TextField(
            controller: _termsController,
            maxLines: 3,
            style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              labelText: 'Terms & Conditions',
              labelStyle: AppTypography.caption.copyWith(color: AppColors.textMuted),
              hintText: 'Payment schedule, delivery timelines, or warranties...',
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
        ],
      ),
    );
  }

  Widget _buildBottomActionBar() {
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
                label: 'Cancel',
                onPressed: _isProcessing
                    ? null
                    : () {
                        if (Navigator.of(context).canPop()) {
                          Navigator.of(context).pop();
                        } else {
                          context.go('/admin/quotes/${widget.quotationId}');
                        }
                      },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: AutoButton.primary(
                label: 'Save Changes',
                icon: const Icon(Icons.check, size: 18, color: Colors.white),
                isLoading: _isProcessing,
                onPressed: _isProcessing ? null : _handleSaveChanges,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
