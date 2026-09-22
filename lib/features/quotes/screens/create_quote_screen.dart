import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../data/models/product_model.dart';
import '../../../data/models/quotation_model.dart';
import '../../../data/models/service_request_model.dart';
import '../../../design_system/components/auto_app_bar.dart';
import '../../../design_system/components/auto_button.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_skeleton.dart';
import '../../../design_system/components/auto_toast.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../service_requests/providers/service_requests_provider.dart';
import '../components/catalogue_product_picker_sheet.dart';
import '../providers/quotes_provider.dart';

/// Helper state for an in-progress draft item within the A14 builder.
class _DraftItemEntry {
  final String? catalogueProductId;
  final TextEditingController nameController;
  final TextEditingController descriptionController;
  final TextEditingController quantityController;
  final TextEditingController rateController;

  _DraftItemEntry({
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

  void dispose() {
    nameController.dispose();
    descriptionController.dispose();
    quantityController.dispose();
    rateController.dispose();
  }
}

/// A14 — Create Quote / Quote Builder conforming to approved Stitch A14.
class CreateQuoteScreen extends ConsumerStatefulWidget {
  final String? serviceRequestId;

  const CreateQuoteScreen({
    super.key,
    required this.serviceRequestId,
  });

  @override
  ConsumerState<CreateQuoteScreen> createState() => _CreateQuoteScreenState();
}

class _CreateQuoteScreenState extends ConsumerState<CreateQuoteScreen> {
  final List<_DraftItemEntry> _items = [];
  final TextEditingController _discountController = TextEditingController(text: '0');
  final TextEditingController _taxController = TextEditingController(text: '0');
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _termsController = TextEditingController();

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
      final entry = _DraftItemEntry(
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
      final entry = _DraftItemEntry(
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

  void _removeItem(int index) {
    setState(() {
      final item = _items.removeAt(index);
      item.dispose();
    });
  }

  Future<void> _handleSaveDraft(ServiceRequestModel sr) async {
    // 0. Eligibility validation
    if (sr.status.toUpperCase() != 'UNDER_REVIEW' ||
        sr.effectiveClientId == null ||
        sr.effectiveClientId!.isEmpty ||
        sr.effectiveVehicleId == null ||
        sr.effectiveVehicleId!.isEmpty) {
      AutoToast.showError(
        context,
        'Quote creation is available after the service request is under review with a linked client and vehicle.',
      );
      return;
    }

    // 1. Validations
    if (_items.isEmpty) {
      AutoToast.showError(context, 'Please add at least one line item to the quotation.');
      return;
    }

    for (int i = 0; i < _items.length; i++) {
      final item = _items[i];
      final title = item.nameController.text.trim();
      if (title.isEmpty) {
        AutoToast.showError(context, 'Item #${i + 1} must have a title.');
        return;
      }
      if (item.quantity <= 0) {
        AutoToast.showError(context, 'Item #${i + 1} quantity must be greater than 0.');
        return;
      }
      if (item.finalValue < 0) {
        AutoToast.showError(context, 'Item #${i + 1} rate cannot be negative.');
        return;
      }
    }

    if (_discount < 0) {
      AutoToast.showError(context, 'Discount cannot be negative.');
      return;
    }

    if (_discount > _subtotal) {
      AutoToast.showError(context, 'Discount cannot exceed subtotal.');
      return;
    }

    if (_tax < 0) {
      AutoToast.showError(context, 'Tax cannot be negative.');
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final repo = ref.read(quotationsRepositoryProvider);

      final draftInputs = _items.map((entry) {
        return DraftQuotationItemInput(
          catalogueProductId: entry.catalogueProductId,
          name: entry.nameController.text.trim(),
          description: entry.descriptionController.text.trim().isNotEmpty
              ? entry.descriptionController.text.trim()
              : null,
          quantity: entry.quantity,
          approximateValue: entry.finalValue,
          finalValue: entry.finalValue,
        );
      }).toList();

      final notes = _notesController.text.trim().isNotEmpty
          ? _notesController.text.trim()
          : null;
      final terms = _termsController.text.trim().isNotEmpty
          ? _termsController.text.trim()
          : null;

      final createdQuote = await repo.createDraftQuotation(
        serviceRequestId: sr.id,
        items: draftInputs,
        discount: _discount,
        tax: _tax,
        notes: notes,
        terms: terms,
      );

      // Invalidate relevant providers
      ref.invalidate(serviceRequestDetailProvider(sr.id));
      ref.invalidate(serviceRequestsListProvider);
      ref.invalidate(quotationsListProvider(const QuotationFilterParams()));

      if (mounted) {
        AutoToast.showSuccess(
          context,
          'Quotation ${createdQuote.quotationNumber} saved as Draft (Rev 1)',
        );
        // Replace current route with the newly created quote detail
        context.pushReplacement('/admin/quotes/${createdQuote.id}');
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = _humanizeError(e.toString());
        AutoToast.showError(context, errorMsg);
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  String _humanizeError(String error) {
    if (error.contains('A quotation already exists')) {
      return 'A quotation already exists for this service request.';
    }
    if (error.contains('must be UNDER_REVIEW') || error.contains('UNDER_REVIEW status')) {
      return 'Quote creation is available after the service request is under review.';
    }
    if (error.contains('Link the service request to a client and vehicle') ||
        error.contains('requires an identified client and vehicle')) {
      return 'Please link a client and vehicle to the request before quoting.';
    }
    if (error.contains('discount cannot exceed subtotal')) {
      return 'Discount cannot exceed quotation subtotal.';
    }
    if (error.contains('permission denied') || error.contains('42501')) {
      return 'Permission denied. Please verify your administrative access.';
    }
    if (error.contains('SocketException') ||
        error.contains('NetworkException') ||
        error.contains('connection refused') ||
        error.contains('ClientException')) {
      return 'Network connection error. Please check your connection and try again.';
    }
    if (error.contains('PostgrestException') || error.contains('PGRST')) {
      return 'A server error occurred while saving the quotation. Please try again.';
    }
    return 'Unable to save quotation. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    final srId = widget.serviceRequestId;

    if (srId == null || srId.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: const AutoAppBar(
          title: 'Create Quote',
          showBack: true,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AutoCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.warningSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: AppColors.warning,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Context Required',
                    style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Quotation creation must be initiated contextually from an eligible Service Request.',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  AutoButton.primary(
                    label: 'Back to Requests',
                    icon: const Icon(Icons.arrow_back, size: 18, color: Colors.white),
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        context.go('/admin/requests');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final srAsync = ref.watch(serviceRequestDetailProvider(srId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AutoAppBar(
        title: 'Create Quote',
        showBack: true,
        showLogo: true,
        onBack: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go('/admin/requests/$srId');
          }
        },
      ),
      body: srAsync.when(
        data: (sr) {
          final isEligible = sr.status.toUpperCase() == 'UNDER_REVIEW' &&
              sr.effectiveClientId != null &&
              sr.effectiveClientId!.isNotEmpty &&
              sr.effectiveVehicleId != null &&
              sr.effectiveVehicleId!.isNotEmpty;

          if (!isEligible) {
            String title = 'Quotation Unavailable';
            String message = 'Quote creation is available after the service request is under review.';

            if (sr.status.toUpperCase() == 'NEW') {
              title = 'Quotation Unavailable';
              message = 'Quote creation is available after the service request is under review.';
            } else if (sr.status.toUpperCase() == 'QUOTATION_CREATED' ||
                sr.status.toUpperCase() == 'QUOTATION_SENT') {
              title = 'Quotation Already Exists';
              message = 'A quotation has already been created for this service request.';
            } else if (sr.status.toUpperCase() == 'APPROVED') {
              title = 'Request Approved';
              message = 'This service request has already been approved.';
            } else if (sr.status.toUpperCase() == 'CONVERTED_TO_JOB') {
              title = 'Job in Progress';
              message = 'This service request has already been converted to a service job.';
            } else if (sr.status.toUpperCase() == 'CANCELLED') {
              title = 'Request Cancelled';
              message = 'Cannot create a quote for a cancelled service request.';
            } else if (sr.effectiveClientId == null ||
                sr.effectiveClientId!.isEmpty ||
                sr.effectiveVehicleId == null ||
                sr.effectiveVehicleId!.isEmpty) {
              title = 'Linking Required';
              message = 'Quote creation requires an identified client and vehicle linked to the request.';
            }

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: AutoCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: const BoxDecoration(
                          color: AppColors.warningSoft,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.info_outline,
                          color: AppColors.warning,
                          size: 32,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        title,
                        style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        message,
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      AutoButton.primary(
                        label: 'Back to Request',
                        icon: const Icon(Icons.arrow_back, size: 18, color: Colors.white),
                        onPressed: () {
                          if (Navigator.of(context).canPop()) {
                            Navigator.of(context).pop();
                          } else {
                            context.go('/admin/requests/${sr.id}');
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return _buildBuilderForm(context, sr);
        },
        loading: () => const SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              AutoSkeleton.card(height: 120),
              SizedBox(height: 16),
              AutoSkeleton.card(height: 200),
              SizedBox(height: 16),
              AutoSkeleton.card(height: 140),
            ],
          ),
        ),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AutoCard(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: const BoxDecoration(
                      color: AppColors.dangerSoft,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline,
                      color: AppColors.danger,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Service Request Not Found',
                    style: AppTypography.h3.copyWith(color: AppColors.textPrimary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The requested service request could not be loaded. Please return to the requests list.',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  AutoButton.primary(
                    label: 'Back to Requests',
                    icon: const Icon(Icons.arrow_back, size: 18, color: Colors.white),
                    onPressed: () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        context.go('/admin/requests');
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBuilderForm(BuildContext context, ServiceRequestModel sr) {
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Indicator
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.warningSoft,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            'Draft Rev 1',
                            style: AppTypography.caption.copyWith(
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '#${sr.requestNumber}',
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.request_quote_outlined,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // 1. Quote Context Card
              _buildQuoteContextCard(sr),
              const SizedBox(height: 20),

              // 2. Quoted Line Items Builder
              _buildLineItemsSection(context),
              const SizedBox(height: 20),

              // 3. Financial Calculation Summary Card
              _buildSummaryCard(),
              const SizedBox(height: 20),

              // 4. Operational Notes & Terms
              _buildNotesAndTermsSection(),
            ],
          ),
        ),

        // Sticky Bottom Actions
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: _buildStickyBottomBar(sr),
        ),
      ],
    );
  }

  Widget _buildQuoteContextCard(ServiceRequestModel sr) {
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
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.person_outline, color: AppColors.primary, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sr.customerName,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyMediumEmphasis.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (sr.customerPhone.isNotEmpty)
                            Text(
                              sr.customerPhone,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (sr.vehiclePlate.isNotEmpty) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    sr.vehiclePlate,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.surface2,
              borderRadius: AppRadius.radiusMd,
            ),
            child: Row(
              children: [
                const Icon(Icons.directions_car_outlined, color: AppColors.primary, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sr.vehicleTitle,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          if (sr.serviceDescription.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surface2.withValues(alpha: 0.5),
                borderRadius: AppRadius.radiusMd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'CUSTOMER CONCERN',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '“${sr.serviceDescription}”',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textSecondary,
                      fontStyle: FontStyle.italic,
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

  Widget _buildLineItemsSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      'Quoted Line Items',
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h3.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: AppColors.surface2,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${_items.length}',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Catalogue Quick Pick Button
            InkWell(
              onTap: () async {
                final selected = await CatalogueProductPickerSheet.show(context);
                if (selected != null) {
                  _addCatalogueItem(selected);
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.border, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.menu_book, color: AppColors.primary, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      'Catalogue',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Items List
        if (_items.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface1,
              borderRadius: AppRadius.radiusLg,
              border: Border.all(color: AppColors.border, width: 1),
            ),
            child: Column(
              children: [
                const Icon(Icons.post_add_outlined, color: AppColors.textMuted, size: 32),
                const SizedBox(height: 8),
                Text(
                  'No items added yet',
                  style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Add a custom line item or select parts from the product catalogue.',
                  style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              return _buildItemCard(index);
            },
          ),

        const SizedBox(height: 12),

        // Add Line Item Button
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            minimumSize: const Size(double.infinity, 46),
            backgroundColor: AppColors.surface1,
            side: const BorderSide(color: AppColors.border, width: 1),
            shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
          ),
          icon: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 18),
          label: Text(
            'Add Line Item',
            style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.primary),
          ),
          onPressed: _addNewCustomItem,
        ),
      ],
    );
  }

  Widget _buildItemCard(int index) {
    final item = _items[index];
    final isCatalogue = item.catalogueProductId != null;
    final lineTotalFormatted = '₹${item.lineTotal.toStringAsFixed(0)}';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface1,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Item Index, Tag & Remove
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Item #${index + 1}',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (isCatalogue) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Catalogue Part',
                        style: AppTypography.caption.copyWith(
                          color: AppColors.primary,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.delete_outline, color: AppColors.danger, size: 18),
                onPressed: () => _removeItem(index),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Title Field
          TextField(
            controller: item.nameController,
            style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.textPrimary),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Item Title (e.g. Brake Pad Replacement)',
              hintStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(
                borderRadius: AppRadius.radiusMd,
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),

          const SizedBox(height: 8),

          // Description Field
          TextField(
            controller: item.descriptionController,
            style: AppTypography.caption.copyWith(color: AppColors.textSecondary),
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Scope description / specifications (optional)',
              hintStyle: AppTypography.caption.copyWith(color: AppColors.textMuted),
              filled: true,
              fillColor: AppColors.surface2,
              border: OutlineInputBorder(
                borderRadius: AppRadius.radiusMd,
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
          ),

          const SizedBox(height: 10),

          // Numeric Grid: Quantity, Rate, Line Total
          Row(
            children: [
              // Quantity
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QTY',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: item.quantityController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                      style: AppTypography.bodyMediumEmphasis.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: AppColors.surface2,
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.radiusMd,
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Rate (₹)
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UNIT RATE',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: item.rateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*'))],
                      style: AppTypography.bodyMediumEmphasis.copyWith(
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.right,
                      decoration: InputDecoration(
                        isDense: true,
                        prefixText: '₹ ',
                        prefixStyle: AppTypography.bodyMedium.copyWith(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surface2,
                        border: OutlineInputBorder(
                          borderRadius: AppRadius.radiusMd,
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Line Total
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'LINE TOTAL',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      height: 38,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface2,
                        borderRadius: AppRadius.radiusMd,
                      ),
                      alignment: Alignment.centerRight,
                      child: Text(
                        lineTotalFormatted,
                        style: AppTypography.bodyMediumEmphasis.copyWith(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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

  Widget _buildSummaryCard() {
    final subtotal = _subtotal;
    final total = _total;

    return AutoCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Subtotal
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

          const SizedBox(height: 10),

          // Discount Input
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Discount (-₹)',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              SizedBox(
                width: 110,
                height: 36,
                child: TextField(
                  controller: _discountController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.success),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixText: '-₹ ',
                    prefixStyle: AppTypography.caption.copyWith(color: AppColors.success),
                    filled: true,
                    fillColor: AppColors.surface2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // Tax Input
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Tax (+₹)',
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary),
              ),
              SizedBox(
                width: 110,
                height: 36,
                child: TextField(
                  controller: _taxController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.right,
                  style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    isDense: true,
                    prefixText: '+₹ ',
                    prefixStyle: AppTypography.caption.copyWith(color: AppColors.textMuted),
                    filled: true,
                    fillColor: AppColors.surface2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(6),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(color: AppColors.border, height: 1),
          const SizedBox(height: 12),

          // Total Highlight
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'QUOTED TOTAL',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                    Text(
                      'Live calculation preview',
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

          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surface2.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              children: [
                const Icon(Icons.cloud_sync_outlined, color: AppColors.textMuted, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Server is authoritative for final calculations upon saving draft.',
                    style: AppTypography.caption.copyWith(
                      color: AppColors.textMuted,
                      fontSize: 11,
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

  Widget _buildNotesAndTermsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Notes
        AutoCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.description_outlined, color: AppColors.primary, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'NOTES',
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Customer visible',
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _notesController,
                maxLines: 2,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. Expected turnaround 4 hours. Genuine parts guarantee.',
                  hintStyle: AppTypography.caption.copyWith(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surface2,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.radiusMd,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Terms
        AutoCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        const Icon(Icons.gavel_outlined, color: AppColors.primary, size: 16),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'TERMS & VALIDITY',
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.caption.copyWith(
                              color: AppColors.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Service terms',
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted, fontSize: 10),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _termsController,
                maxLines: 2,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: 'e.g. Quote valid for 7 days. Diagnostic fee applies if declined.',
                  hintStyle: AppTypography.caption.copyWith(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surface2,
                  border: OutlineInputBorder(
                    borderRadius: AppRadius.radiusMd,
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.all(10),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStickyBottomBar(ServiceRequestModel sr) {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.paddingOf(context).bottom + 12,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 48),
                backgroundColor: AppColors.surface2,
                side: const BorderSide(color: AppColors.border, width: 1),
                shape: RoundedRectangleBorder(borderRadius: AppRadius.radiusMd),
              ),
              onPressed: _isProcessing
                  ? null
                  : () {
                      if (Navigator.of(context).canPop()) {
                        Navigator.of(context).pop();
                      } else {
                        context.go('/admin/requests/${sr.id}');
                      }
                    },
              child: Text(
                'Cancel',
                style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.textSecondary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 8,
            child: AutoButton.primary(
              label: _isProcessing ? 'Saving Draft...' : 'Save Draft',
              isLoading: _isProcessing,
              icon: const Icon(Icons.save_outlined, size: 20, color: Colors.white),
              onPressed: _isProcessing ? null : () => _handleSaveDraft(sr),
            ),
          ),
        ],
      ),
    );
  }
}
