import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../design_system/components/auto_app_bar.dart';
import '../../../design_system/components/auto_button.dart';
import '../../../design_system/components/auto_card.dart';
import '../../../design_system/components/auto_input.dart';
import '../../../design_system/components/auto_select.dart';
import '../../../design_system/components/auto_toast.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../service_requests/providers/service_requests_provider.dart';
import '../providers/vehicles_provider.dart';

/// A11 — Create/Edit Vehicle Screen conforming to approved Stitch A11.
class CreateEditVehicleScreen extends ConsumerStatefulWidget {
  final String? vehicleId;
  final String? initialClientId;

  const CreateEditVehicleScreen({
    super.key,
    this.vehicleId,
    this.initialClientId,
  });

  bool get isEdit => vehicleId != null;

  @override
  ConsumerState<CreateEditVehicleScreen> createState() =>
      _CreateEditVehicleScreenState();
}

class _CreateEditVehicleScreenState
    extends ConsumerState<CreateEditVehicleScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedClientId;
  String? _clientError;

  late final TextEditingController _makeController;
  late final TextEditingController _modelController;
  late final TextEditingController _yearController;
  late final TextEditingController _chassisController;
  late final TextEditingController _registrationController;

  bool _initializedWithData = false;
  ClientModel? _lockedClient;

  @override
  void initState() {
    super.initState();
    _selectedClientId = widget.initialClientId;

    _makeController = TextEditingController();
    _modelController = TextEditingController();
    _yearController = TextEditingController();
    _chassisController = TextEditingController();
    _registrationController = TextEditingController();
  }

  @override
  void dispose() {
    _makeController.dispose();
    _modelController.dispose();
    _yearController.dispose();
    _chassisController.dispose();
    _registrationController.dispose();
    super.dispose();
  }

  void _populateExistingVehicle(VehicleModel vehicle) {
    if (_initializedWithData) return;
    _initializedWithData = true;

    _selectedClientId = vehicle.clientId;
    _lockedClient = vehicle.client;
    _makeController.text = vehicle.make;
    _modelController.text = vehicle.model;
    _yearController.text = vehicle.manufacturingYear?.toString() ?? '';
    _chassisController.text = vehicle.chassisNumber ?? '';
    _registrationController.text = vehicle.registrationNumber ?? '';
  }

  Future<void> _handleSubmit() async {
    setState(() {
      _clientError = _selectedClientId == null ? 'Please select an owner' : null;
    });

    if (!_formKey.currentState!.validate() || _selectedClientId == null) {
      return;
    }

    final make = _makeController.text.trim();
    final model = _modelController.text.trim();
    final year = _yearController.text.trim().isNotEmpty
        ? int.tryParse(_yearController.text.trim())
        : null;
    final chassisNumber = _chassisController.text.trim().toUpperCase();
    final registrationNumber = _registrationController.text.trim().toUpperCase();

    final formNotifier = ref.read(vehicleFormControllerProvider.notifier);

    if (widget.isEdit) {
      final updated = await formNotifier.updateVehicle(
        id: widget.vehicleId!,
        make: make,
        model: model,
        manufacturingYear: year,
        chassisNumber: chassisNumber,
        registrationNumber: registrationNumber,
      );

      if (updated != null && mounted) {
        AutoToast.showSuccess(context, 'Vehicle updated successfully');
        context.pop();
      } else if (mounted) {
        final err = ref.read(vehicleFormControllerProvider).errorMessage;
        AutoToast.showError(context, err ?? 'Failed to update vehicle');
      }
    } else {
      final created = await formNotifier.createVehicle(
        clientId: _selectedClientId!,
        make: make,
        model: model,
        manufacturingYear: year,
        chassisNumber: chassisNumber,
        registrationNumber: registrationNumber,
      );

      if (created != null && mounted) {
        AutoToast.showSuccess(context, 'Vehicle registered successfully');
        context.pushReplacement('/admin/vehicles/${created.id}');
      } else if (mounted) {
        final err = ref.read(vehicleFormControllerProvider).errorMessage;
        AutoToast.showError(context, err ?? 'Failed to register vehicle');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEdit) {
      final vehicleAsync = ref.watch(vehicleDetailProvider(widget.vehicleId!));
      vehicleAsync.whenData((vehicle) {
        _populateExistingVehicle(vehicle);
      });
    }

    final formState = ref.watch(vehicleFormControllerProvider);
    final clientsAsync = ref.watch(activeClientsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AutoAppBar(
        title: widget.isEdit ? 'Edit Vehicle' : 'Register Vehicle',
        showBack: true,
        onBack: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          } else {
            context.go(widget.isEdit
                ? '/admin/vehicles/${widget.vehicleId}'
                : (widget.initialClientId != null
                    ? '/admin/clients/${widget.initialClientId}'
                    : '/admin/vehicles'));
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
                  // Section: Owner / Client Selection
                  AutoCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VEHICLE OWNER',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 12),

                        if (widget.isEdit) ...[
                          // Locked Owner Readout for DB trigger compliance
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lock_outline, color: AppColors.textMuted, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _lockedClient?.fullName ?? 'Assigned Client',
                                        style: AppTypography.bodyMediumEmphasis.copyWith(color: AppColors.textPrimary),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Ownership is immutable once registered.',
                                        style: AppTypography.caption.copyWith(color: AppColors.textMuted),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else ...[
                          // Create Mode: Select Client
                          clientsAsync.when(
                            loading: () => const AutoSelect<String>(
                              label: 'Client / Owner',
                              isRequired: true,
                              placeholder: 'Loading active clients...',
                              value: null,
                              items: [],
                            ),
                            error: (err, _) => Text(
                              'Failed to load clients: $err',
                              style: AppTypography.caption.copyWith(color: AppColors.danger),
                            ),
                            data: (clients) {
                              return AutoSelect<String>(
                                label: 'Client / Owner',
                                isRequired: true,
                                placeholder: 'Select vehicle owner',
                                value: _selectedClientId,
                                errorText: _clientError,
                                leadingIcon: const Icon(Icons.person_outline, color: AppColors.textMuted, size: 20),
                                items: clients.map((c) {
                                  return DropdownMenuItem<String>(
                                    value: c.id,
                                    child: Text(
                                      '${c.fullName} (${c.phone})',
                                      style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) {
                                  setState(() {
                                    _selectedClientId = val;
                                    _clientError = null;
                                  });
                                },
                              );
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Section: Vehicle Specifications
                  AutoCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VEHICLE DETAILS',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Make & Model Row
                        Row(
                          children: [
                            Expanded(
                              child: AutoInput(
                                label: 'Make',
                                isRequired: true,
                                hint: 'e.g. Honda',
                                controller: _makeController,
                                prefixIcon: const Icon(Icons.directions_car, color: AppColors.textMuted, size: 18),
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Make is required';
                                  if (val.trim().length < 2) return 'Min 2 characters';
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: AutoInput(
                                label: 'Model',
                                isRequired: true,
                                hint: 'e.g. City',
                                controller: _modelController,
                                validator: (val) {
                                  if (val == null || val.trim().isEmpty) return 'Model is required';
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Manufacturing Year
                        AutoInput(
                          label: 'Manufacturing Year',
                          hint: 'e.g. 2021',
                          keyboardType: TextInputType.number,
                          controller: _yearController,
                          maxLength: 4,
                          prefixIcon: const Icon(Icons.calendar_today_outlined, color: AppColors.textMuted, size: 18),
                          validator: (val) {
                            if (val != null && val.trim().isNotEmpty) {
                              final yr = int.tryParse(val.trim());
                              final currentYear = DateTime.now().year;
                              if (yr == null || yr < 1900 || yr > currentYear + 1) {
                                return 'Enter valid year (1900–${currentYear + 1})';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Registration Number
                        AutoInput(
                          label: 'Registration Number',
                          isRequired: true,
                          hint: 'e.g. DL01AB1234',
                          controller: _registrationController,
                          prefixIcon: const Icon(Icons.pin_outlined, color: AppColors.textMuted, size: 18),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Registration number is required';
                            }
                            final clean = val.replaceAll(RegExp(r'\s+'), '');
                            if (clean.length < 5) return 'Enter a valid registration number';
                            return null;
                          },
                        ),
                        const SizedBox(height: 14),

                        // Chassis Number / VIN
                        ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _chassisController,
                          builder: (context, val, _) {
                            final count = val.text.trim().length;
                            return AutoInput(
                              label: 'Chassis Number (VIN)',
                              isRequired: true,
                              hint: '17-character VIN',
                              controller: _chassisController,
                              maxLength: 17,
                              prefixIcon: const Icon(Icons.qr_code, color: AppColors.textMuted, size: 18),
                              suffixIcon: Padding(
                                padding: const EdgeInsets.only(right: 12),
                                child: Center(
                                  widthFactor: 1,
                                  child: Text(
                                    '$count / 17',
                                    style: AppTypography.caption.copyWith(
                                      color: count == 17 ? AppColors.success : AppColors.textMuted,
                                      fontFamily: 'monospace',
                                    ),
                                  ),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'VIN is required';
                                if (v.trim().length != 17) return 'VIN must be exactly 17 characters';
                                return null;
                              },
                            );
                          },
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
                label: widget.isEdit ? 'Save Vehicle' : 'Register Vehicle',
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
