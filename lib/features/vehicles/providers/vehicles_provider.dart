import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../service_requests/providers/service_requests_provider.dart';

/// State for Vehicle List search and make filtering
class VehicleFilterState {
  final String make; // 'All' or brand name
  final String searchQuery;

  const VehicleFilterState({
    this.make = 'All',
    this.searchQuery = '',
  });

  VehicleFilterState copyWith({
    String? make,
    String? searchQuery,
  }) {
    return VehicleFilterState(
      make: make ?? this.make,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class VehicleFilterNotifier extends Notifier<VehicleFilterState> {
  @override
  VehicleFilterState build() => const VehicleFilterState();

  void setMake(String make) {
    state = state.copyWith(make: make);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void reset() {
    state = const VehicleFilterState();
  }
}

final vehicleFilterProvider =
    NotifierProvider<VehicleFilterNotifier, VehicleFilterState>(
  VehicleFilterNotifier.new,
);

/// Fetches list of vehicles with make and search filtering applied
final vehiclesListProvider =
    FutureProvider.autoDispose<List<VehicleModel>>((ref) async {
  final repo = ref.watch(clientVehicleRepositoryProvider);
  final filter = ref.watch(vehicleFilterProvider);

  return repo.fetchVehicles(
    makeFilter: filter.make,
    searchQuery: filter.searchQuery,
  );
});

/// Fetches a single vehicle by real UUID with its client record
final vehicleDetailProvider =
    FutureProvider.autoDispose.family<VehicleModel, String>((ref, id) async {
  final repo = ref.watch(clientVehicleRepositoryProvider);
  return repo.getVehicleById(id);
});

/// Fetches related service requests for the vehicle via admin_service_requests
final vehicleServiceRequestsProvider =
    FutureProvider.autoDispose.family<List<ServiceRequestModel>, String>((ref, vehicleId) async {
  final repo = ref.watch(clientVehicleRepositoryProvider);
  return repo.fetchServiceRequestsForVehicle(vehicleId);
});

/// Controller for creating and updating vehicles
class VehicleFormState {
  final bool isSubmitting;
  final String? errorMessage;
  final VehicleModel? vehicle;

  const VehicleFormState({
    this.isSubmitting = false,
    this.errorMessage,
    this.vehicle,
  });

  VehicleFormState copyWith({
    bool? isSubmitting,
    String? errorMessage,
    VehicleModel? vehicle,
  }) {
    return VehicleFormState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      vehicle: vehicle ?? this.vehicle,
    );
  }
}

class VehicleFormNotifier extends Notifier<VehicleFormState> {
  @override
  VehicleFormState build() => const VehicleFormState();

  void reset() {
    state = const VehicleFormState();
  }

  Future<VehicleModel?> createVehicle({
    required String clientId,
    required String make,
    required String model,
    int? manufacturingYear,
    required String chassisNumber,
    required String registrationNumber,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final repo = ref.read(clientVehicleRepositoryProvider);
      final vehicle = await repo.createVehicle(
        clientId: clientId,
        make: make,
        model: model,
        manufacturingYear: manufacturingYear,
        chassisNumber: chassisNumber,
        registrationNumber: registrationNumber,
      );
      ref.invalidate(vehiclesListProvider);
      state = state.copyWith(isSubmitting: false, vehicle: vehicle);
      return vehicle;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return null;
    }
  }

  Future<VehicleModel?> updateVehicle({
    required String id,
    required String make,
    required String model,
    int? manufacturingYear,
    required String chassisNumber,
    required String registrationNumber,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final repo = ref.read(clientVehicleRepositoryProvider);
      final vehicle = await repo.updateVehicle(
        id: id,
        make: make,
        model: model,
        manufacturingYear: manufacturingYear,
        chassisNumber: chassisNumber,
        registrationNumber: registrationNumber,
      );
      ref.invalidate(vehiclesListProvider);
      ref.invalidate(vehicleDetailProvider(id));
      state = state.copyWith(isSubmitting: false, vehicle: vehicle);
      return vehicle;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return null;
    }
  }
}

final vehicleFormControllerProvider =
    NotifierProvider<VehicleFormNotifier, VehicleFormState>(
  VehicleFormNotifier.new,
);
