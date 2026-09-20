import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autotricks/data/models/activity_item_model.dart';
import 'package:autotricks/data/models/client_model.dart';
import 'package:autotricks/data/models/product_model.dart';
import 'package:autotricks/data/models/service_job_summary_model.dart';
import 'package:autotricks/data/models/service_request_model.dart';
import 'package:autotricks/data/models/vehicle_model.dart';
import 'package:autotricks/data/repositories/auth_repository.dart';
import 'package:autotricks/data/repositories/client_vehicle_repository.dart';
import 'package:autotricks/data/repositories/home_repository.dart';
import 'package:autotricks/data/repositories/products_repository.dart';
import 'package:autotricks/data/repositories/service_requests_repository.dart';

class MockAuthRepository implements AuthRepository {
  bool failNextSignIn = false;
  UserProfile? currentUser;

  final _authStreamController = StreamController<AuthState>.broadcast();

  @override
  Stream<AuthState> get authStateChanges => _authStreamController.stream;

  @override
  UserProfile? getCurrentProfile() => currentUser;

  @override
  Future<UserProfile> signIn({
    required String email,
    required String password,
  }) async {
    if (failNextSignIn) {
      throw const AuthException('Invalid login credentials');
    }
    currentUser = UserProfile(
      id: 'usr-admin-1',
      email: email,
      fullName: 'Vikram Mehta',
      role: 'ADMIN',
    );
    return currentUser!;
  }

  @override
  Future<void> signOut() async {
    currentUser = null;
  }
}

class MockHomeRepository implements HomeRepository {
  @override
  Future<HomeDashboardData> fetchHomeData() async {
    return const HomeDashboardData(
      pendingRequestsCount: 3,
      awaitingQuotesCount: 5,
      approvedQuotesCount: 2,
      activeJobs: [
        ServiceJobSummaryModel(
          id: 'job-1',
          jobNumber: 'JOB-2026-0041',
          clientName: 'Rahul Kumar',
          vehicleTitle: 'Honda City · 2022',
          status: 'IN_PROGRESS',
          workItemsCompleted: 2,
          workItemsTotal: 5,
        ),
      ],
      recentActivities: [
        ActivityItemModel(
          id: 'act-1',
          title: 'Quotation sent for SR-2026-00015',
          subtitle: 'Sent to Priya Nair',
          timeAgo: '15m ago',
          icon: Icons.send_outlined,
        ),
      ],
    );
  }
}

class MockServiceRequestsRepository implements ServiceRequestsRepository {
  final List<ServiceRequestModel> items = [
    ServiceRequestModel(
      id: 'sr-1',
      requestNumber: 'SR-2026-00021',
      source: 'PHONE',
      status: 'NEW',
      adminNotes: 'Routine 25k service + noticeable brake squeal.',
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
      id: 'sr-2',
      requestNumber: 'SR-2026-00018',
      source: 'PHONE',
      status: 'UNDER_REVIEW',
      adminNotes: 'Suspension vibration over rough roads.',
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
  ];

  @override
  Future<List<ServiceRequestModel>> fetchServiceRequests({
    String? statusFilter,
    String? searchQuery,
  }) async {
    return items.where((i) {
      if (statusFilter != null && statusFilter != 'ALL') {
        if (i.status.toUpperCase() != statusFilter.toUpperCase()) return false;
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        final q = searchQuery.toLowerCase();
        final matchesNum = i.requestNumber.toLowerCase().contains(q);
        final matchesClient = (i.client?.fullName ?? '').toLowerCase().contains(q);
        final matchesVehicle =
            ('${i.vehicle?.make ?? ""} ${i.vehicle?.model ?? ""} ${i.vehicle?.registrationNumber ?? ""}')
                .toLowerCase()
                .contains(q);
        if (!matchesNum && !matchesClient && !matchesVehicle) return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<ServiceRequestModel> getServiceRequestById(String id) async {
    return items.firstWhere(
      (element) => element.id == id,
      orElse: () => items.first,
    );
  }

  @override
  Future<ServiceRequestModel> createServiceRequest({
    required String clientId,
    required String vehicleId,
    required String description,
  }) async {
    final newSr = ServiceRequestModel(
      id: 'sr-${DateTime.now().millisecondsSinceEpoch}',
      requestNumber: 'SR-2026-00099',
      source: 'PHONE',
      status: 'NEW',
      adminNotes: description,
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
    );
    items.add(newSr);
    return newSr;
  }

  @override
  Future<void> linkServiceRequest({
    required String requestId,
    required String clientId,
    required String vehicleId,
  }) async {}

  @override
  Future<void> updateStatus({
    required String requestId,
    required String status,
  }) async {
    final idx = items.indexWhere((i) => i.id == requestId);
    if (idx != -1) {
      final old = items[idx];
      items[idx] = ServiceRequestModel(
        id: old.id,
        requestNumber: old.requestNumber,
        source: old.source,
        status: status,
        adminNotes: old.adminNotes,
        createdAt: old.createdAt,
        updatedAt: DateTime.now(),
        client: old.client,
        vehicle: old.vehicle,
      );
    }
  }

  @override
  Future<void> cancelServiceRequest(String requestId) async {
    await updateStatus(requestId: requestId, status: 'CANCELLED');
  }
}

class MockClientVehicleRepository implements ClientVehicleRepository {
  final List<ClientModel> _clients = [
    const ClientModel(
      id: '2bd5d7fb-3b55-48b1-931f-69896d3f0838',
      fullName: 'Rahul Kumar',
      phone: '+91 98450 12890',
      email: 'rahul.kumar@gmail.com',
      address: '#42, 4th Cross, Indiranagar',
      city: 'Bengaluru',
      state: 'Karnataka',
      pincode: '560038',
      notes: 'Prefers phone call updates before 11 AM.',
      isActive: true,
      vehicles: [
        VehicleModel(
          id: 'edd54d25-b67b-4ac7-bd72-b5dc4daf8b24',
          clientId: '2bd5d7fb-3b55-48b1-931f-69896d3f0838',
          make: 'Honda',
          model: 'City',
          manufacturingYear: 2022,
          registrationNumber: 'KA-01-MJ-4412',
          chassisNumber: 'MAKGM6650NN102938',
        ),
      ],
    ),
    const ClientModel(
      id: '6282f38a-1455-4a94-a839-3e70587f473f',
      fullName: 'Arun Prakash',
      phone: '+91 98861 55301',
      email: 'arun.prakash@gmail.com',
      city: 'Bengaluru',
      state: 'Karnataka',
      isActive: true,
      vehicles: [
        VehicleModel(
          id: '353cb527-b7de-4de5-aec6-28bcfcb0bf78',
          clientId: '6282f38a-1455-4a94-a839-3e70587f473f',
          make: 'Toyota',
          model: 'Fortuner',
          manufacturingYear: 2021,
          registrationNumber: 'KA-05-NB-9921',
          chassisNumber: 'MBJ11AB40M0054321',
        ),
      ],
    ),
    const ClientModel(
      id: '8796ea16-9e54-47e6-9a41-940d8df1b928',
      fullName: 'Priya Nair',
      phone: '+91 99002 44119',
      email: 'priya.nair@gmail.com',
      city: 'Delhi',
      state: 'Delhi',
      isActive: true,
      vehicles: [
        VehicleModel(
          id: '9636a8dc-e606-43f0-ac3c-2ad927ed6e98',
          clientId: '8796ea16-9e54-47e6-9a41-940d8df1b928',
          make: 'Hyundai',
          model: 'Creta',
          manufacturingYear: 2023,
          registrationNumber: 'DL-03-CC-8844',
          chassisNumber: 'MALC381CLNM992100',
        ),
      ],
    ),
  ];

  final List<VehicleModel> _vehicles = [
    const VehicleModel(
      id: 'edd54d25-b67b-4ac7-bd72-b5dc4daf8b24',
      clientId: '2bd5d7fb-3b55-48b1-931f-69896d3f0838',
      make: 'Honda',
      model: 'City',
      manufacturingYear: 2022,
      registrationNumber: 'KA-01-MJ-4412',
      chassisNumber: 'MAKGM6650NN102938',
      client: ClientModel(
        id: '2bd5d7fb-3b55-48b1-931f-69896d3f0838',
        fullName: 'Rahul Kumar',
        phone: '+91 98450 12890',
        email: 'rahul.kumar@gmail.com',
      ),
    ),
    const VehicleModel(
      id: '353cb527-b7de-4de5-aec6-28bcfcb0bf78',
      clientId: '6282f38a-1455-4a94-a839-3e70587f473f',
      make: 'Toyota',
      model: 'Fortuner',
      manufacturingYear: 2021,
      registrationNumber: 'KA-05-NB-9921',
      chassisNumber: 'MBJ11AB40M0054321',
      client: ClientModel(
        id: '6282f38a-1455-4a94-a839-3e70587f473f',
        fullName: 'Arun Prakash',
        phone: '+91 98861 55301',
        email: 'arun.prakash@gmail.com',
      ),
    ),
    const VehicleModel(
      id: '9636a8dc-e606-43f0-ac3c-2ad927ed6e98',
      clientId: '8796ea16-9e54-47e6-9a41-940d8df1b928',
      make: 'Hyundai',
      model: 'Creta',
      manufacturingYear: 2023,
      registrationNumber: 'DL-03-CC-8844',
      chassisNumber: 'MALC381CLNM992100',
      client: ClientModel(
        id: '8796ea16-9e54-47e6-9a41-940d8df1b928',
        fullName: 'Priya Nair',
        phone: '+91 99002 44119',
        email: 'priya.nair@gmail.com',
      ),
    ),
  ];

  @override
  Future<List<ClientModel>> fetchClients({
    bool? activeOnly,
    String? searchQuery,
  }) async {
    var list = _clients;
    if (activeOnly != null) {
      list = list.where((c) => c.isActive == activeOnly).toList();
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      list = list.where((c) =>
          c.fullName.toLowerCase().contains(q) ||
          c.phone.toLowerCase().contains(q) ||
          (c.email?.toLowerCase().contains(q) ?? false)).toList();
    }
    return list;
  }

  @override
  Future<ClientModel> getClientById(String id) async {
    return _clients.firstWhere(
      (c) => c.id == id,
      orElse: () => _clients.first,
    );
  }

  @override
  Future<ClientModel> createClient({
    required String fullName,
    required String phone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? notes,
    bool isActive = true,
  }) async {
    final newClient = ClientModel(
      id: '00000000-0000-0000-0000-${(_clients.length + 1).toString().padLeft(12, '0')}',
      fullName: fullName,
      phone: phone,
      email: email,
      address: address,
      city: city,
      state: state,
      pincode: pincode,
      notes: notes,
      isActive: isActive,
    );
    _clients.add(newClient);
    return newClient;
  }

  @override
  Future<ClientModel> updateClient({
    required String id,
    required String fullName,
    required String phone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? notes,
    required bool isActive,
  }) async {
    final index = _clients.indexWhere((c) => c.id == id);
    final updated = ClientModel(
      id: id,
      fullName: fullName,
      phone: phone,
      email: email,
      address: address,
      city: city,
      state: state,
      pincode: pincode,
      notes: notes,
      isActive: isActive,
    );
    if (index >= 0) {
      _clients[index] = updated;
    }
    return updated;
  }

  @override
  Future<List<VehicleModel>> fetchVehicles({
    String? searchQuery,
    String? makeFilter,
  }) async {
    var list = _vehicles;
    if (makeFilter != null && makeFilter.isNotEmpty && makeFilter.toLowerCase() != 'all') {
      list = list.where((v) => v.make.toLowerCase() == makeFilter.toLowerCase()).toList();
    }
    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.trim().toLowerCase();
      list = list.where((v) =>
          v.make.toLowerCase().contains(q) ||
          v.model.toLowerCase().contains(q) ||
          (v.registrationNumber?.toLowerCase().contains(q) ?? false) ||
          (v.chassisNumber?.toLowerCase().contains(q) ?? false)).toList();
    }
    return list;
  }

  @override
  Future<List<VehicleModel>> fetchVehiclesForClient(String clientId) async {
    return _vehicles.where((v) => v.clientId == clientId).toList();
  }

  @override
  Future<VehicleModel> getVehicleById(String id) async {
    return _vehicles.firstWhere(
      (v) => v.id == id,
      orElse: () => _vehicles.first,
    );
  }

  @override
  Future<VehicleModel> createVehicle({
    required String clientId,
    required String make,
    required String model,
    int? manufacturingYear,
    required String chassisNumber,
    required String registrationNumber,
  }) async {
    final newVehicle = VehicleModel(
      id: '00000000-0000-0000-0001-${(_vehicles.length + 1).toString().padLeft(12, '0')}',
      clientId: clientId,
      make: make,
      model: model,
      manufacturingYear: manufacturingYear,
      chassisNumber: chassisNumber,
      registrationNumber: registrationNumber,
    );
    _vehicles.add(newVehicle);
    return newVehicle;
  }

  @override
  Future<VehicleModel> updateVehicle({
    required String id,
    required String make,
    required String model,
    int? manufacturingYear,
    required String chassisNumber,
    required String registrationNumber,
  }) async {
    final index = _vehicles.indexWhere((v) => v.id == id);
    if (index >= 0) {
      final old = _vehicles[index];
      final updated = old.copyWith(
        make: make,
        model: model,
        manufacturingYear: manufacturingYear,
        chassisNumber: chassisNumber,
        registrationNumber: registrationNumber,
      );
      _vehicles[index] = updated;
      return updated;
    }
    return getVehicleById(id);
  }

  @override
  Future<List<ServiceRequestModel>> fetchServiceRequestsForClient(String clientId) async {
    return [];
  }

  @override
  Future<List<ServiceRequestModel>> fetchServiceRequestsForVehicle(String vehicleId) async {
    return [];
  }
}

class MockProductsRepository implements ProductsRepository {
  final List<ProductModel> _products = [
    ProductModel(
      id: 'prd-1',
      name: 'Brake Pad Set (Front)',
      category: ProductCategories.braking,
      defaultPrice: 6000.0,
      description: 'High-performance ceramic front brake pad set formulated for reduced heat dissipation.',
      isActive: true,
      createdAt: DateTime(2026, 9, 10),
      updatedAt: DateTime(2026, 9, 12),
    ),
    ProductModel(
      id: 'prd-2',
      name: 'Synthetic Engine Oil (5W-30)',
      category: ProductCategories.fluidsAndLubricants,
      defaultPrice: 3850.0,
      description: 'Premium synthetic 4L can formulated for modern petrol/diesel turbo engines.',
      isActive: true,
      createdAt: DateTime(2026, 9, 10),
      updatedAt: DateTime(2026, 9, 11),
    ),
    ProductModel(
      id: 'prd-3',
      name: 'Cabin AC Carbon Filter',
      category: ProductCategories.filters,
      defaultPrice: 950.0,
      description: 'Activated charcoal anti-allergen pollen & dust filter designed for high particulate absorption.',
      isActive: true,
      createdAt: DateTime(2026, 9, 11),
      updatedAt: DateTime(2026, 9, 11),
    ),
    ProductModel(
      id: 'prd-4',
      name: 'Lower Control Arm Bushing Kit',
      category: ProductCategories.suspension,
      defaultPrice: 2400.0,
      description: 'Heavy duty polyurethane suspension bushing pair engineered to eliminate steering judder.',
      isActive: true,
      createdAt: DateTime(2026, 9, 12),
      updatedAt: DateTime(2026, 9, 12),
    ),
    ProductModel(
      id: 'prd-5',
      name: 'Spark Plug Set (Iridium)',
      category: ProductCategories.ignition,
      defaultPrice: 2200.0,
      description: 'Quad iridium core plugs (Discontinued supplier batch).',
      isActive: false,
      createdAt: DateTime(2026, 9, 8),
      updatedAt: DateTime(2026, 9, 9),
    ),
  ];

  @override
  Future<List<ProductModel>> fetchProducts({
    String? category,
    bool? activeOnly,
    String? searchQuery,
  }) async {
    var result = List<ProductModel>.from(_products);

    if (category != null && category.isNotEmpty && category != 'all') {
      result = result.where((p) => p.category == category).toList();
    }

    if (activeOnly != null) {
      result = result.where((p) => p.isActive == activeOnly).toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      result = result.where((p) {
        final matchesName = p.name.toLowerCase().contains(q);
        final matchesCat = (p.category ?? '').toLowerCase().contains(q);
        final matchesDesc = (p.description ?? '').toLowerCase().contains(q);
        return matchesName || matchesCat || matchesDesc;
      }).toList();
    }

    return result;
  }

  @override
  Future<ProductModel> getProductById(String id) async {
    final prod = _products.firstWhere(
      (p) => p.id == id,
      orElse: () => throw Exception('Product not found: $id'),
    );
    return prod;
  }

  @override
  Future<ProductModel> createProduct({
    required String name,
    required String category,
    required double defaultPrice,
    String? description,
    bool isActive = true,
  }) async {
    final newProduct = ProductModel(
      id: 'prd-${_products.length + 1}',
      name: name,
      category: category,
      defaultPrice: defaultPrice,
      description: description,
      isActive: isActive,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _products.add(newProduct);
    return newProduct;
  }

  @override
  Future<ProductModel> updateProduct({
    required String id,
    required String name,
    required String category,
    required double defaultPrice,
    String? description,
    required bool isActive,
  }) async {
    final index = _products.indexWhere((p) => p.id == id);
    if (index >= 0) {
      final old = _products[index];
      final updated = old.copyWith(
        name: name,
        category: category,
        defaultPrice: defaultPrice,
        description: description,
        isActive: isActive,
        updatedAt: DateTime.now(),
      );
      _products[index] = updated;
      return updated;
    }
    throw Exception('Product not found for update: $id');
  }

  @override
  Future<ProductModel> toggleProductStatus({
    required String id,
    required bool isActive,
  }) async {
    final index = _products.indexWhere((p) => p.id == id);
    if (index >= 0) {
      final old = _products[index];
      final updated = old.copyWith(
        isActive: isActive,
        updatedAt: DateTime.now(),
      );
      _products[index] = updated;
      return updated;
    }
    throw Exception('Product not found for status toggle: $id');
  }
}
