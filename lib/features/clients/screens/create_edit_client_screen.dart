import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../design_system/components/auto_app_bar.dart';
import '../../../design_system/components/auto_button.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_input.dart';
import '../../../design_system/components/auto_toast.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../data/models/client_model.dart';
import '../providers/clients_provider.dart';

/// A08 — Create/Edit Client Screen conforming to approved Stitch A08.
class CreateEditClientScreen extends ConsumerStatefulWidget {
  final String? clientId;

  const CreateEditClientScreen({
    super.key,
    this.clientId,
  });

  bool get isEdit => clientId != null;

  @override
  ConsumerState<CreateEditClientScreen> createState() =>
      _CreateEditClientScreenState();
}

class _CreateEditClientScreenState
    extends ConsumerState<CreateEditClientScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _addressController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  late final TextEditingController _pincodeController;
  late final TextEditingController _notesController;

  bool _isActive = true;
  bool _initializedWithData = false;

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
    _addressController = TextEditingController();
    _cityController = TextEditingController();
    _stateController = TextEditingController();
    _pincodeController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _pincodeController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _populateExistingClient(ClientModel client) {
    if (_initializedWithData) return;
    _initializedWithData = true;

    _fullNameController.text = client.fullName;
    _phoneController.text = client.phone;
    _emailController.text = client.email ?? '';
    _addressController.text = client.address ?? '';
    _cityController.text = client.city ?? '';
    _stateController.text = client.state ?? '';
    _pincodeController.text = client.pincode ?? '';
    _notesController.text = client.notes ?? '';
    _isActive = client.isActive;
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final formNotifier = ref.read(clientFormControllerProvider.notifier);

    final fullName = _fullNameController.text.trim();
    final phone = _phoneController.text.trim();
    final email = _emailController.text.trim().isEmpty ? null : _emailController.text.trim();
    final address = _addressController.text.trim().isEmpty ? null : _addressController.text.trim();
    final city = _cityController.text.trim().isEmpty ? null : _cityController.text.trim();
    final stateRegion = _stateController.text.trim().isEmpty ? null : _stateController.text.trim();
    final pincode = _pincodeController.text.trim().isEmpty ? null : _pincodeController.text.trim();
    final notes = _notesController.text.trim().isEmpty ? null : _notesController.text.trim();

    if (widget.isEdit) {
      final updated = await formNotifier.updateClient(
        id: widget.clientId!,
        fullName: fullName,
        phone: phone,
        email: email,
        address: address,
        city: city,
        clientState: stateRegion,
        pincode: pincode,
        notes: notes,
        isActive: _isActive,
      );

      if (updated != null && mounted) {
        AutoToast.showSuccess(context, 'Client updated successfully');
        context.pop();
      } else if (mounted) {
        final err = ref.read(clientFormControllerProvider).errorMessage;
        AutoToast.showError(context, err ?? 'Failed to update client');
      }
    } else {
      final created = await formNotifier.createClient(
        fullName: fullName,
        phone: phone,
        email: email,
        address: address,
        city: city,
        clientState: stateRegion,
        pincode: pincode,
        notes: notes,
        isActive: _isActive,
      );

      if (created != null && mounted) {
        AutoToast.showSuccess(context, 'Client created successfully');
        context.pushReplacement('/admin/clients/${created.id}');
      } else if (mounted) {
        final err = ref.read(clientFormControllerProvider).errorMessage;
        AutoToast.showError(context, err ?? 'Failed to create client');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEdit) {
      final clientAsync = ref.watch(clientDetailProvider(widget.clientId!));
      clientAsync.whenData((client) {
        _populateExistingClient(client);
      });
    }

    final formState = ref.watch(clientFormControllerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AutoAppBar(
        title: widget.isEdit ? 'Edit Client' : 'Create Client',
        showBack: true,
        onBack: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go(widget.isEdit
                ? '/admin/clients/${widget.clientId}'
                : '/admin/clients');
          }
        },
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 16,
              bottom: 110, // Space for sticky bottom bar
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Section: Basic Info
                  AutoCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'BASIC INFORMATION',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 14),
                        AutoInput(
                          label: 'Full Name',
                          isRequired: true,
                          hint: 'e.g. Rahul Kumar',
                          controller: _fullNameController,
                          prefixIcon: const Icon(Icons.person_outline, color: AppColors.textMuted, size: 20),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Full name is required';
                            if (val.trim().length < 2) return 'Full name must be at least 2 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        AutoInput(
                          label: 'Phone Number',
                          isRequired: true,
                          hint: 'e.g. 9876543210',
                          keyboardType: TextInputType.phone,
                          controller: _phoneController,
                          prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.textMuted, size: 20),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) return 'Phone number is required';
                            final clean = val.replaceAll(RegExp(r'\s+|-'), '');
                            if (clean.length < 10) return 'Enter a valid 10-digit phone number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),
                        AutoInput(
                          label: 'Email Address',
                          hint: 'e.g. rahul@example.com (optional)',
                          keyboardType: TextInputType.emailAddress,
                          controller: _emailController,
                          prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textMuted, size: 20),
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              if (!val.contains('@') || !val.contains('.')) {
                                return 'Enter a valid email address';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section: Address & Location
                  AutoCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'LOCATION & ADDRESS',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 14),
                        AutoInput(
                          label: 'Street Address',
                          hint: 'Flat / House No., Street, Locality',
                          controller: _addressController,
                          prefixIcon: const Icon(Icons.home_outlined, color: AppColors.textMuted, size: 20),
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: [
                            Expanded(
                              child: AutoInput(
                                label: 'City',
                                hint: 'e.g. New Delhi',
                                controller: _cityController,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AutoInput(
                                label: 'State',
                                hint: 'e.g. Delhi',
                                controller: _stateController,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        AutoInput(
                          label: 'PIN Code',
                          hint: 'e.g. 110001',
                          keyboardType: TextInputType.number,
                          controller: _pincodeController,
                          maxLength: 6,
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              if (val.trim().length != 6 || int.tryParse(val.trim()) == null) {
                                return 'Enter 6-digit PIN code';
                              }
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section: Admin Confidential Notes
                  AutoCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.lock_outline, size: 15, color: AppColors.warning),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'CONFIDENTIAL ADMIN NOTES',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.warning,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Internal staff notes regarding preferences, payment terms, or VIP handling.',
                          style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(height: 14),
                        AutoInput(
                          hint: 'Enter internal confidential notes...',
                          controller: _notesController,
                          maxLines: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section: Active Status
                  AutoCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Client Account Status',
                                style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _isActive ? 'Active and eligible for service' : 'Inactive / Archived client',
                                style: AppTypography.caption.copyWith(
                                  color: _isActive ? AppColors.success : AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isActive,
                          activeThumbColor: AppColors.primary,
                          activeTrackColor: AppColors.primarySoft,
                          onChanged: (val) => setState(() => _isActive = val),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sticky Bottom Action Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              decoration: BoxDecoration(
                color: AppColors.surface1,
                border: const Border(
                  top: BorderSide(color: AppColors.border, width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 12,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: AutoButton(
                label: widget.isEdit ? 'Save Changes' : 'Create Client',
                icon: Icon(widget.isEdit ? Icons.save_outlined : Icons.check, size: 18),
                isLoading: formState.isSubmitting,
                onPressed: formState.isSubmitting ? null : _handleSubmit,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
