import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/client_model.dart';
import '../../../data/models/service_request_model.dart';
import '../../../data/models/vehicle_model.dart';
import '../../service_requests/providers/service_requests_provider.dart';

/// State for Client List search and status filter
class ClientFilterState {
  final String status; // 'all', 'active', 'inactive'
  final String searchQuery;

  const ClientFilterState({
    this.status = 'all',
    this.searchQuery = '',
  });

  ClientFilterState copyWith({
    String? status,
    String? searchQuery,
  }) {
    return ClientFilterState(
      status: status ?? this.status,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class ClientFilterNotifier extends Notifier<ClientFilterState> {
  @override
  ClientFilterState build() => const ClientFilterState();

  void setStatus(String status) {
    state = state.copyWith(status: status);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void reset() {
    state = const ClientFilterState();
  }
}

final clientFilterProvider =
    NotifierProvider<ClientFilterNotifier, ClientFilterState>(
  ClientFilterNotifier.new,
);

/// Fetches list of clients with status and search filtering applied
final clientsListProvider =
    FutureProvider.autoDispose<List<ClientModel>>((ref) async {
  final repo = ref.watch(clientVehicleRepositoryProvider);
  final filter = ref.watch(clientFilterProvider);

  bool? activeOnly;
  if (filter.status == 'active') {
    activeOnly = true;
  } else if (filter.status == 'inactive') {
    activeOnly = false;
  }

  return repo.fetchClients(
    activeOnly: activeOnly,
    searchQuery: filter.searchQuery,
  );
});

/// Fetches a single client by real UUID
final clientDetailProvider =
    FutureProvider.autoDispose.family<ClientModel, String>((ref, id) async {
  final repo = ref.watch(clientVehicleRepositoryProvider);
  return repo.getClientById(id);
});

/// Fetches vehicles belonging strictly to the specified client UUID
final clientVehiclesProvider =
    FutureProvider.autoDispose.family<List<VehicleModel>, String>((ref, clientId) async {
  final repo = ref.watch(clientVehicleRepositoryProvider);
  return repo.fetchVehiclesForClient(clientId);
});

/// Fetches related service requests for the client via admin_service_requests
final clientServiceRequestsProvider =
    FutureProvider.autoDispose.family<List<ServiceRequestModel>, String>((ref, clientId) async {
  final repo = ref.watch(clientVehicleRepositoryProvider);
  return repo.fetchServiceRequestsForClient(clientId);
});

/// State for Client creation/update forms
class ClientFormState {
  final bool isSubmitting;
  final String? errorMessage;
  final ClientModel? client;

  const ClientFormState({
    this.isSubmitting = false,
    this.errorMessage,
    this.client,
  });

  ClientFormState copyWith({
    bool? isSubmitting,
    String? errorMessage,
    ClientModel? client,
  }) {
    return ClientFormState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      client: client ?? this.client,
    );
  }
}

class ClientFormNotifier extends Notifier<ClientFormState> {
  @override
  ClientFormState build() => const ClientFormState();

  void reset() {
    state = const ClientFormState();
  }

  Future<ClientModel?> createClient({
    required String fullName,
    required String phone,
    String? email,
    String? address,
    String? city,
    String? clientState,
    String? pincode,
    String? notes,
    bool isActive = true,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final repo = ref.read(clientVehicleRepositoryProvider);
      final client = await repo.createClient(
        fullName: fullName,
        phone: phone,
        email: email,
        address: address,
        city: city,
        state: clientState,
        pincode: pincode,
        notes: notes,
        isActive: isActive,
      );
      ref.invalidate(clientsListProvider);
      state = state.copyWith(isSubmitting: false, client: client);
      return client;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return null;
    }
  }

  Future<ClientModel?> updateClient({
    required String id,
    required String fullName,
    required String phone,
    String? email,
    String? address,
    String? city,
    String? clientState,
    String? pincode,
    String? notes,
    required bool isActive,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final repo = ref.read(clientVehicleRepositoryProvider);
      final client = await repo.updateClient(
        id: id,
        fullName: fullName,
        phone: phone,
        email: email,
        address: address,
        city: city,
        state: clientState,
        pincode: pincode,
        notes: notes,
        isActive: isActive,
      );
      ref.invalidate(clientsListProvider);
      ref.invalidate(clientDetailProvider(id));
      state = state.copyWith(isSubmitting: false, client: client);
      return client;
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: e.toString().replaceAll('Exception: ', ''),
      );
      return null;
    }
  }
}

final clientFormControllerProvider =
    NotifierProvider<ClientFormNotifier, ClientFormState>(
  ClientFormNotifier.new,
);
