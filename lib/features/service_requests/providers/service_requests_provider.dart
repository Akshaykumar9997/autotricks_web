import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autotricks/data/models/client_model.dart';
import 'package:autotricks/data/models/service_request_model.dart';
import 'package:autotricks/data/models/vehicle_model.dart';
import 'package:autotricks/data/repositories/client_vehicle_repository.dart';
import 'package:autotricks/data/repositories/service_requests_repository.dart';

final serviceRequestsRepositoryProvider = Provider<ServiceRequestsRepository>((ref) {
  return SupabaseServiceRequestsRepository();
});

final clientVehicleRepositoryProvider = Provider<ClientVehicleRepository>((ref) {
  return SupabaseClientVehicleRepository();
});

class ServiceRequestFilterState {
  final String statusFilter;
  final String searchQuery;

  const ServiceRequestFilterState({
    this.statusFilter = 'ALL',
    this.searchQuery = '',
  });

  ServiceRequestFilterState copyWith({
    String? statusFilter,
    String? searchQuery,
  }) {
    return ServiceRequestFilterState(
      statusFilter: statusFilter ?? this.statusFilter,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class ServiceRequestFilterNotifier extends Notifier<ServiceRequestFilterState> {
  @override
  ServiceRequestFilterState build() => const ServiceRequestFilterState();

  void setFilter(String status) {
    state = state.copyWith(statusFilter: status);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void reset() {
    state = const ServiceRequestFilterState();
  }
}

final serviceRequestFilterProvider =
    NotifierProvider<ServiceRequestFilterNotifier, ServiceRequestFilterState>(
  ServiceRequestFilterNotifier.new,
);

final serviceRequestsListProvider =
    FutureProvider.autoDispose<List<ServiceRequestModel>>((ref) async {
  final repo = ref.watch(serviceRequestsRepositoryProvider);
  final filter = ref.watch(serviceRequestFilterProvider);

  return await repo.fetchServiceRequests(
    statusFilter: filter.statusFilter,
    searchQuery: filter.searchQuery,
  );
});

final serviceRequestDetailProvider =
    FutureProvider.family<ServiceRequestModel, String>((ref, id) async {
  final repo = ref.watch(serviceRequestsRepositoryProvider);
  return await repo.getServiceRequestById(id);
});

final activeClientsProvider =
    FutureProvider.autoDispose<List<ClientModel>>((ref) async {
  final repo = ref.watch(clientVehicleRepositoryProvider);
  return await repo.fetchClients();
});

final clientVehiclesProvider = FutureProvider.family
    .autoDispose<List<VehicleModel>, String>((ref, clientId) async {
  final repo = ref.watch(clientVehicleRepositoryProvider);
  return await repo.fetchVehiclesForClient(clientId);
});
