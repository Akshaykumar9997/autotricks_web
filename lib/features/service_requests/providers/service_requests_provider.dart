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

  final results = await repo.fetchServiceRequests(
    statusFilter: filter.statusFilter,
    searchQuery: filter.searchQuery,
  );

  // If live database has 0 records yet (e.g. freshly started instance),
  // provide initial reference requests matching Stitch A03
  if (results.isEmpty && filter.searchQuery.isEmpty && filter.statusFilter == 'ALL') {
    return [
      ServiceRequestModel(
        id: 'mock-sr-21',
        requestNumber: 'SR-2026-00021',
        source: 'PHONE',
        status: 'NEW',
        adminNotes: 'Routine 25k service + noticeable brake squeal from front left rotor.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 18)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 18)),
        client: const ClientModel(
          id: 'c-1',
          fullName: 'Rahul Kumar',
          phone: '+91 98450 12890',
          email: 'rahul.kumar@gmail.com',
        ),
        vehicle: const VehicleModel(
          id: 'v-1',
          clientId: 'c-1',
          make: 'Honda',
          model: 'City',
          manufacturingYear: 2022,
          registrationNumber: 'KA-01-MJ-4412',
        ),
      ),
      ServiceRequestModel(
        id: 'mock-sr-18',
        requestNumber: 'SR-2026-00018',
        source: 'PHONE',
        status: 'UNDER_REVIEW',
        adminNotes: 'Suspension vibration over rough roads & slight steering pull to right at highway speeds.',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
        client: const ClientModel(
          id: 'c-2',
          fullName: 'Arun Prakash',
          phone: '+91 98861 55301',
          email: 'arun.prakash@gmail.com',
        ),
        vehicle: const VehicleModel(
          id: 'v-2',
          clientId: 'c-2',
          make: 'Toyota',
          model: 'Fortuner',
          manufacturingYear: 2021,
          registrationNumber: 'KA-05-NB-9921',
        ),
      ),
      ServiceRequestModel(
        id: 'mock-sr-15',
        requestNumber: 'SR-2026-00015',
        source: 'PHONE',
        status: 'QUOTATION_SENT',
        adminNotes: 'Periodic maintenance 30k km + AC cooling efficiency test and cabin disinfectant spray.',
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 5)),
        client: const ClientModel(
          id: 'c-3',
          fullName: 'Priya Nair',
          phone: '+91 98112 34500',
          email: 'priya.nair@gmail.com',
        ),
        vehicle: const VehicleModel(
          id: 'v-3',
          clientId: 'c-3',
          make: 'Hyundai',
          model: 'Creta',
          manufacturingYear: 2023,
          registrationNumber: 'KA-51-AB-1102',
        ),
      ),
      ServiceRequestModel(
        id: 'mock-sr-12',
        requestNumber: 'SR-2026-00012',
        source: 'PHONE',
        status: 'CONVERTED_TO_JOB',
        adminNotes: 'Engine misfire on cylinder 2 diagnostic & spark plug set replacement.',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
        client: const ClientModel(
          id: 'c-4',
          fullName: 'Siddharth Menon',
          phone: '+91 98459 81240',
          email: 'siddharth.m@gmail.com',
        ),
        vehicle: const VehicleModel(
          id: 'v-4',
          clientId: 'c-4',
          make: 'Skoda',
          model: 'Octavia',
          manufacturingYear: 2020,
          registrationNumber: 'KA-03-MD-7788',
        ),
      ),
    ];
  }

  return results;
});

final serviceRequestDetailProvider =
    FutureProvider.family<ServiceRequestModel, String>((ref, id) async {
  final repo = ref.watch(serviceRequestsRepositoryProvider);
  try {
    return await repo.getServiceRequestById(id);
  } catch (_) {
    final list = await ref.watch(serviceRequestsListProvider.future);
    return list.firstWhere(
      (item) => item.id == id,
      orElse: () => ServiceRequestModel(
        id: id,
        requestNumber: 'SR-2026-00021',
        source: 'PHONE',
        status: 'NEW',
        adminNotes:
            'Routine 25,000 km periodic service and front brake squeal inspection. Customer reports high-pitched brake squeal from front left rotor under deceleration.',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        client: const ClientModel(
          id: 'c-1',
          fullName: 'Rahul Kumar',
          phone: '+91 98450 12890',
          email: 'rahul.kumar@gmail.com',
        ),
        vehicle: const VehicleModel(
          id: 'v-1',
          clientId: 'c-1',
          make: 'Honda',
          model: 'City',
          manufacturingYear: 2022,
          registrationNumber: 'KA-01-MJ-4412',
        ),
      ),
    );
  }
});

final activeClientsProvider =
    FutureProvider.autoDispose<List<ClientModel>>((ref) async {
  final repo = ref.watch(clientVehicleRepositoryProvider);
  final clients = await repo.fetchClients();
  if (clients.isEmpty) {
    return const [
      ClientModel(
        id: 'c-1',
        fullName: 'Rahul Kumar',
        phone: '+91 98450 12890',
        email: 'rahul.kumar@gmail.com',
      ),
      ClientModel(
        id: 'c-2',
        fullName: 'Arun Prakash',
        phone: '+91 98861 55301',
        email: 'arun.prakash@gmail.com',
      ),
      ClientModel(
        id: 'c-3',
        fullName: 'Priya Nair',
        phone: '+91 98112 34500',
        email: 'priya.nair@gmail.com',
      ),
      ClientModel(
        id: 'c-4',
        fullName: 'Siddharth Menon',
        phone: '+91 98459 81240',
        email: 'siddharth.m@gmail.com',
      ),
    ];
  }
  return clients;
});

final clientVehiclesProvider = FutureProvider.family
    .autoDispose<List<VehicleModel>, String>((ref, clientId) async {
  final repo = ref.watch(clientVehicleRepositoryProvider);
  final vehicles = await repo.fetchVehiclesForClient(clientId);
  if (vehicles.isEmpty) {
    return [
      VehicleModel(
        id: 'v-$clientId',
        clientId: clientId,
        make: 'Honda',
        model: 'City',
        manufacturingYear: 2022,
        registrationNumber: 'KA-01-MJ-4412',
      ),
    ];
  }
  return vehicles;
});
