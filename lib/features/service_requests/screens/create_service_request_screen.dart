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
import '../providers/service_requests_provider.dart';

/// A05 — Create Service Request Screen conforming to approved Stitch A05.
class CreateServiceRequestScreen extends ConsumerStatefulWidget {
  const CreateServiceRequestScreen({super.key});

  @override
  ConsumerState<CreateServiceRequestScreen> createState() =>
      _CreateServiceRequestScreenState();
}

class _CreateServiceRequestScreenState
    extends ConsumerState<CreateServiceRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  ClientModel? _selectedClient;
  VehicleModel? _selectedVehicle;
  late final TextEditingController _descriptionController;
  bool _isProcessing = false;
  String? _clientError;
  String? _vehicleError;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController(
      text:
          'Routine 25,000 km periodic service. Customer reports high-pitched brake squeal from front left wheel under deceleration.',
    );
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    setState(() {
      _clientError = _selectedClient == null ? 'Please select a client' : null;
      _vehicleError =
          _selectedVehicle == null ? 'Please select a vehicle' : null;
    });

    if (!_formKey.currentState!.validate() ||
        _selectedClient == null ||
        _selectedVehicle == null) {
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final repo = ref.read(serviceRequestsRepositoryProvider);
      final newSr = await repo.createServiceRequest(
        clientId: _selectedClient!.id,
        vehicleId: _selectedVehicle!.id,
        description: _descriptionController.text.trim(),
      );

      ref.invalidate(serviceRequestsListProvider);

      if (mounted) {
        AutoToast.showSuccess(
            context, 'Request #${newSr.requestNumber} created');
        context.go('/admin/requests/${newSr.id}');
      }
    } catch (e) {
      if (mounted) {
        AutoToast.showError(
          context,
          'Failed to create request: ${e.toString().replaceAll('Exception: ', '')}',
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(activeClientsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const AutoAppBar(
        title: 'Create Service Request',
        showBack: true,
        showLogo: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(
              left: 16,
              right: 16,
              top: 12,
              bottom: 140, // Space for sticky bottom action bar
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Context Note: Phone Intake / Manual Entry
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.surface1,
                      borderRadius: AppRadius.radiusMd,
                      border: Border.all(color: AppColors.border, width: 1),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.phone_in_talk,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'PHONE REQUEST',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Field 1: Client Selection
                  AutoCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        clientsAsync.when(
                          data: (List<ClientModel> clients) {
                            if (_selectedClient == null && clients.isNotEmpty) {
                              _selectedClient = clients.first;
                            }

                            return AutoSelect<ClientModel>(
                              label: 'Client',
                              isRequired: true,
                              placeholder: 'Select client...',
                              value: _selectedClient,
                              errorText: _clientError,
                              leadingIcon: const Icon(Icons.person,
                                  color: AppColors.primary, size: 20),
                              items: clients
                                  .map<DropdownMenuItem<ClientModel>>(
                                      (ClientModel c) {
                                return DropdownMenuItem<ClientModel>(
                                  value: c,
                                  child: Text(c.fullName),
                                );
                              }).toList(),
                              onChanged: (ClientModel? newClient) {
                                setState(() {
                                  _selectedClient = newClient;
                                  _selectedVehicle = null;
                                  _clientError = null;
                                });
                              },
                            );
                          },
                          loading: () => const AutoSelect(
                            label: 'Client',
                            isRequired: true,
                            placeholder: 'Loading clients...',
                          ),
                          error: (e, s) => const AutoSelect(
                            label: 'Client',
                            isRequired: true,
                            placeholder: 'Failed to load clients',
                          ),
                        ),
                        if (_selectedClient != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.contact_phone,
                                  size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  _selectedClient!.phone,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontFamily: 'monospace',
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (_selectedClient!.email != null) ...[
                                const SizedBox(width: 6),
                                const Text('•',
                                    style:
                                        TextStyle(color: AppColors.textMuted)),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _selectedClient!.email!,
                                    style: AppTypography.caption.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Field 2: Vehicle Selection
                  AutoCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_selectedClient != null)
                          Consumer(
                            builder: (context, ref, _) {
                              final vehiclesAsync = ref.watch(
                                clientVehiclesProvider(_selectedClient!.id),
                              );

                              return vehiclesAsync.when(
                                data: (List<VehicleModel> vehicles) {
                                  if (_selectedVehicle == null &&
                                      vehicles.isNotEmpty) {
                                    _selectedVehicle = vehicles.first;
                                  }

                                  return AutoSelect<VehicleModel>(
                                    label: 'Vehicle',
                                    isRequired: true,
                                    placeholder: 'Select vehicle...',
                                    value: _selectedVehicle,
                                    errorText: _vehicleError,
                                    leadingIcon: const Icon(
                                        Icons.directions_car,
                                        color: AppColors.primary,
                                        size: 20),
                                    items: vehicles
                                        .map<DropdownMenuItem<VehicleModel>>(
                                            (VehicleModel v) {
                                      final reg = v.registrationNumber != null
                                          ? ' (${v.registrationNumber})'
                                          : '';
                                      return DropdownMenuItem<VehicleModel>(
                                        value: v,
                                        child: Text('${v.displayName}$reg'),
                                      );
                                    }).toList(),
                                    onChanged: (VehicleModel? newVehicle) {
                                      setState(() {
                                        _selectedVehicle = newVehicle;
                                        _vehicleError = null;
                                      });
                                    },
                                  );
                                },
                                loading: () => const AutoSelect(
                                  label: 'Vehicle',
                                  isRequired: true,
                                  placeholder: 'Loading vehicles...',
                                ),
                                error: (e, s) => const AutoSelect(
                                  label: 'Vehicle',
                                  isRequired: true,
                                  placeholder: 'No vehicles found for client',
                                ),
                              );
                            },
                          )
                        else
                          const AutoSelect(
                            label: 'Vehicle',
                            isRequired: true,
                            placeholder: 'Select a client first',
                          ),
                        if (_selectedVehicle != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.info_outline,
                                  size: 14, color: AppColors.textMuted),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Registered with selected customer',
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Field 3: Service Description
                  AutoCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AutoInput(
                          label: 'Service Description',
                          isRequired: true,
                          hint:
                              'Enter customer reported symptoms, issues, or specific maintenance requests...',
                          controller: _descriptionController,
                          maxLines: 4,
                          maxLength: 500,
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please provide a service description';
                            }
                            if (val.trim().length < 5) {
                              return 'Description must be at least 5 characters';
                            }
                            return null;
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
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AutoButton.primary(
                    label: _isProcessing
                        ? 'Creating Request...'
                        : 'Create Service Request',
                    isLoading: _isProcessing,
                    icon: const Icon(Icons.add_task,
                        size: 20, color: Colors.white),
                    onPressed: _submitRequest,
                  ),
                  const SizedBox(height: 8),
                  AutoButton.secondary(
                    label: 'Cancel',
                    onPressed: _isProcessing
                        ? null
                        : () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
