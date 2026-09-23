import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autotricks/data/models/activity_item_model.dart';
import 'package:autotricks/data/models/client_model.dart';
import 'package:autotricks/data/models/product_model.dart';
import 'package:autotricks/data/models/quotation_model.dart';
import 'package:autotricks/data/models/service_job_summary_model.dart';
import 'package:autotricks/data/models/service_request_model.dart';
import 'package:autotricks/data/models/vehicle_model.dart';
import 'package:autotricks/data/repositories/auth_repository.dart';
import 'package:autotricks/data/repositories/client_portal_repository.dart';
import 'package:autotricks/data/repositories/client_vehicle_repository.dart';
import 'package:autotricks/data/repositories/home_repository.dart';
import 'package:autotricks/data/repositories/products_repository.dart';
import 'package:autotricks/data/repositories/quotations_repository.dart';
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
  Future<UserProfile?> refreshCurrentProfile() async => currentUser;

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
      clientId: 'c-1',
      vehicleId: 'v-1',
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
      orElse: () => throw Exception('Service request not found: $id'),
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

class MockQuotationsRepository implements QuotationsRepository {
  final List<QuotationModel> quotes;

  MockQuotationsRepository({List<QuotationModel>? initialQuotes})
      : quotes = initialQuotes ?? [
          QuotationModel(
            id: 'quote-1',
            quotationNumber: 'QT-2026-00012',
            serviceRequestId: 'sr-1',
            createdBy: 'usr-admin-1',
            createdAt: DateTime.now().subtract(const Duration(hours: 3)),
            updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
            serviceRequest: ServiceRequestModel(
              id: 'sr-1',
              requestNumber: 'SR-2026-00021',
              source: 'PHONE',
              status: 'UNDER_REVIEW',
              adminNotes: 'Routine 25k service + noticeable brake squeal.',
              createdAt: DateTime.now().subtract(const Duration(hours: 4)),
              updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
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
                registrationNumber: 'KA 01 MJ 5022',
              ),
            ),
            revisions: [
              QuotationRevisionModel(
                id: 'rev-1',
                quotationId: 'quote-1',
                revisionNumber: 1,
                status: 'DRAFT',
                subtotal: 18500.00,
                discount: 1000.00,
                tax: 3150.00,
                total: 20650.00,
                notes: 'Standard 25,000 km periodic inspection + brake overhaul.',
                terms: 'Prices valid for 15 days.',
                createdAt: DateTime.now().subtract(const Duration(hours: 3)),
                items: [
                  QuotationItemModel(
                    id: 'item-1',
                    quotationRevisionId: 'rev-1',
                    catalogueProductId: 'prd-1',
                    name: 'Synthetic Engine Oil (5W-30)',
                    description: 'Full synthetic 4.5L drain & fill',
                    quantity: 1,
                    finalValue: 4500.00,
                    lineTotal: 4500.00,
                    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
                    updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
                  ),
                  QuotationItemModel(
                    id: 'item-2',
                    quotationRevisionId: 'rev-1',
                    name: 'Front Ceramic Brake Pad Set',
                    description: 'OEM replacement ceramic pads',
                    quantity: 1,
                    finalValue: 6500.00,
                    lineTotal: 6500.00,
                    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
                    updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
                  ),
                  QuotationItemModel(
                    id: 'item-3',
                    quotationRevisionId: 'rev-1',
                    name: 'Comprehensive Brake System Overhaul Labour',
                    description: 'Caliper servicing, disc skimming, bleeding',
                    quantity: 1,
                    finalValue: 7500.00,
                    lineTotal: 7500.00,
                    createdAt: DateTime.now().subtract(const Duration(hours: 3)),
                    updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
                  ),
                ],
              ),
            ],
          ),
          QuotationModel(
            id: 'quote-2',
            quotationNumber: 'QT-2026-00013',
            serviceRequestId: 'sr-2',
            createdBy: 'usr-admin-1',
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
            updatedAt: DateTime.now().subtract(const Duration(days: 1)),
            serviceRequest: ServiceRequestModel(
              id: 'sr-2',
              requestNumber: 'SR-2026-00015',
              source: 'APP',
              status: 'QUOTATION_SENT',
              adminNotes: 'AC gas recharge and periodic check.',
              createdAt: DateTime.now().subtract(const Duration(days: 1)),
              updatedAt: DateTime.now().subtract(const Duration(days: 1)),
              client: const ClientModel(
                id: 'c-2',
                fullName: 'Priya Nair',
                phone: '+91 98111 22334',
                email: 'priya.nair@example.com',
              ),
              vehicle: const VehicleModel(
                id: 'v-2',
                clientId: 'c-2',
                make: 'Hyundai',
                model: 'Creta',
                manufacturingYear: 2021,
                registrationNumber: 'DL 03 CA 1001',
              ),
            ),
            revisions: [
              QuotationRevisionModel(
                id: 'rev-2',
                quotationId: 'quote-2',
                revisionNumber: 1,
                status: 'SENT',
                subtotal: 12000.00,
                discount: 0.0,
                tax: 2160.00,
                total: 14160.00,
                notes: 'AC servicing and gas recharge.',
                terms: 'Standard terms apply.',
                createdAt: DateTime.now().subtract(const Duration(days: 1)),
                sentAt: DateTime.now().subtract(const Duration(days: 1)),
                items: [
                  QuotationItemModel(
                    id: 'item-201',
                    quotationRevisionId: 'rev-2',
                    name: 'AC Gas R134a Recharge',
                    quantity: 1,
                    finalValue: 2500.00,
                    lineTotal: 2500.00,
                    createdAt: DateTime.now().subtract(const Duration(days: 1)),
                    updatedAt: DateTime.now().subtract(const Duration(days: 1)),
                  ),
                ],
              ),
            ],
          ),
          QuotationModel(
            id: 'quote-3',
            quotationNumber: 'QT-2026-00014',
            serviceRequestId: 'sr-3',
            createdBy: 'usr-admin-1',
            createdAt: DateTime.now().subtract(const Duration(hours: 12)),
            updatedAt: DateTime.now().subtract(const Duration(hours: 12)),
            serviceRequest: ServiceRequestModel(
              id: 'sr-3',
              requestNumber: 'SR-2026-00016',
              source: 'MANUAL',
              status: 'QUOTATION_SENT',
              adminNotes: 'Tyre replacement and wheel balancing.',
              createdAt: DateTime.now().subtract(const Duration(days: 2)),
              updatedAt: DateTime.now().subtract(const Duration(hours: 12)),
              client: const ClientModel(
                id: 'c-3',
                fullName: 'Amit Patel',
                phone: '+91 99000 11223',
                email: 'amit.patel@example.com',
              ),
              vehicle: const VehicleModel(
                id: 'v-3',
                clientId: 'c-3',
                make: 'Toyota',
                model: 'Innova Crysta',
                manufacturingYear: 2020,
                registrationNumber: 'MH 02 EE 4004',
              ),
            ),
            revisions: [
              QuotationRevisionModel(
                id: 'rev-3',
                quotationId: 'quote-3',
                revisionNumber: 1,
                status: 'VIEWED',
                subtotal: 8000.00,
                discount: 500.0,
                tax: 1350.00,
                total: 8850.00,
                notes: 'Client opened quotation in portal.',
                terms: 'Standard terms apply.',
                createdAt: DateTime.now().subtract(const Duration(hours: 12)),
                sentAt: DateTime.now().subtract(const Duration(hours: 14)),
                viewedAt: DateTime.now().subtract(const Duration(hours: 10)),
                items: [
                  QuotationItemModel(
                    id: 'item-301',
                    quotationRevisionId: 'rev-3',
                    name: 'Wheel Alignment & Balancing',
                    quantity: 1,
                    finalValue: 1500.00,
                    lineTotal: 1500.00,
                    createdAt: DateTime.now().subtract(const Duration(hours: 12)),
                    updatedAt: DateTime.now().subtract(const Duration(hours: 12)),
                  ),
                ],
              ),
            ],
          ),
          QuotationModel(
            id: 'quote-4',
            quotationNumber: 'QT-2026-00015',
            serviceRequestId: 'sr-4',
            createdBy: 'usr-admin-1',
            createdAt: DateTime.now().subtract(const Duration(days: 3)),
            updatedAt: DateTime.now().subtract(const Duration(days: 2)),
            serviceRequest: ServiceRequestModel(
              id: 'sr-4',
              requestNumber: 'SR-2026-00017',
              source: 'MANUAL',
              status: 'CANCELLED',
              adminNotes: 'Customer declined service.',
              createdAt: DateTime.now().subtract(const Duration(days: 4)),
              updatedAt: DateTime.now().subtract(const Duration(days: 2)),
              client: const ClientModel(
                id: 'c-4',
                fullName: 'Vikram Seth',
                phone: '+91 97777 88899',
                email: 'vikram.seth@example.com',
              ),
              vehicle: const VehicleModel(
                id: 'v-4',
                clientId: 'c-4',
                make: 'Maruti Suzuki',
                model: 'Swift',
                manufacturingYear: 2018,
                registrationNumber: 'DL 08 BX 9988',
              ),
            ),
            revisions: [
              QuotationRevisionModel(
                id: 'rev-4',
                quotationId: 'quote-4',
                revisionNumber: 1,
                status: 'CANCELLED',
                subtotal: 5000.00,
                discount: 0.0,
                tax: 900.00,
                total: 5900.00,
                notes: 'Cancelled per client request.',
                terms: 'Standard terms apply.',
                createdAt: DateTime.now().subtract(const Duration(days: 3)),
                items: [
                  QuotationItemModel(
                    id: 'item-401',
                    quotationRevisionId: 'rev-4',
                    name: 'General Inspection',
                    quantity: 1,
                    finalValue: 5000.00,
                    lineTotal: 5000.00,
                    createdAt: DateTime.now().subtract(const Duration(days: 3)),
                    updatedAt: DateTime.now().subtract(const Duration(days: 3)),
                  ),
                ],
              ),
            ],
          ),
        ];

  @override
  Future<List<QuotationModel>> fetchQuotations({
    String? statusFilter,
    String? searchQuery,
  }) async {
    var result = List<QuotationModel>.from(quotes);

    if (statusFilter != null && statusFilter.isNotEmpty && statusFilter.toUpperCase() != 'ALL') {
      final normalized = statusFilter.trim().toUpperCase().replaceAll(' ', '_');
      result = result.where((q) => q.currentStatus.toUpperCase().replaceAll(' ', '_') == normalized).toList();
    }

    if (searchQuery != null && searchQuery.trim().isNotEmpty) {
      final q = searchQuery.toLowerCase().trim();
      result = result.where((quote) {
        final matchesNum = quote.quotationNumber.toLowerCase().contains(q);
        final matchesClient = quote.customerName.toLowerCase().contains(q);
        final matchesPlate = quote.vehiclePlate.toLowerCase().contains(q);
        final matchesSR = quote.requestNumber.toLowerCase().contains(q);
        return matchesNum || matchesClient || matchesPlate || matchesSR;
      }).toList();
    }

    return result;
  }

  @override
  Future<QuotationModel> getQuotationById(String id) async {
    final quote = quotes.firstWhere(
      (q) => q.id == id,
      orElse: () => throw Exception('Quotation not found: $id'),
    );
    return quote;
  }

  @override
  Future<QuotationModel?> getQuotationByServiceRequestId(String serviceRequestId) async {
    final matches = quotes.where((q) => q.serviceRequestId == serviceRequestId).toList();
    if (matches.isEmpty) return null;
    return matches.first;
  }

  @override
  Future<QuotationModel> createDraftQuotation({
    required String serviceRequestId,
    required List<DraftQuotationItemInput> items,
    double discount = 0,
    double tax = 0,
    String? notes,
    String? terms,
  }) async {
    final subtotal = items.fold(0.0, (sum, it) => sum + it.lineTotal);
    final total = (subtotal - discount + tax).clamp(0.0, double.infinity);

    final newId = 'quote-${quotes.length + 1}';
    final newRevId = 'rev-${quotes.length + 1}-1';
    final quotationNumber = 'QT-2026-${(quotes.length + 1).toString().padLeft(5, '0')}';

    final revisionItems = items.asMap().entries.map((e) {
      final idx = e.key;
      final input = e.value;
      return QuotationItemModel(
        id: 'item-$newRevId-$idx',
        quotationRevisionId: newRevId,
        catalogueProductId: input.catalogueProductId,
        name: input.name,
        description: input.description,
        quantity: input.quantity,
        finalValue: input.finalValue,
        lineTotal: input.lineTotal,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }).toList();

    final revision = QuotationRevisionModel(
      id: newRevId,
      quotationId: newId,
      revisionNumber: 1,
      status: 'DRAFT',
      subtotal: subtotal,
      discount: discount,
      tax: tax,
      total: total,
      notes: notes,
      terms: terms,
      createdAt: DateTime.now(),
      items: revisionItems,
    );

    final newQuote = QuotationModel(
      id: newId,
      quotationNumber: quotationNumber,
      serviceRequestId: serviceRequestId,
      createdBy: 'usr-admin-1',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      serviceRequest: ServiceRequestModel(
        id: serviceRequestId,
        requestNumber: 'SR-2026-00021',
        source: 'PHONE',
        status: 'UNDER_REVIEW',
        adminNotes: 'Quoted by admin',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        client: const ClientModel(
          id: 'c-1',
          fullName: 'Rahul Kumar',
          phone: '+91 98450 12890',
        ),
        vehicle: const VehicleModel(
          id: 'v-1',
          clientId: 'c-1',
          make: 'Honda',
          model: 'City',
          registrationNumber: 'KA 01 MJ 5022',
        ),
      ),
      revisions: [revision],
    );

    quotes.insert(0, newQuote);
    return newQuote;
  }

  @override
  Future<List<QuotationItemModel>> fetchRevisionItems(String revisionId) async {
    for (final q in quotes) {
      for (final rev in q.revisions) {
        if (rev.id == revisionId) {
          return rev.items;
        }
      }
    }
    return [];
  }

  @override
  Future<Map<String, dynamic>> createQuotationRevision(String quotationId) async {
    final quoteIndex = quotes.indexWhere((q) => q.id == quotationId);
    if (quoteIndex == -1) throw Exception('Quotation not found: $quotationId');

    final quote = quotes[quoteIndex];
    final latestRev = quote.currentRevision;
    final nextRevNum = (latestRev?.revisionNumber ?? 0) + 1;
    final newRevId = 'rev-${quote.id}-$nextRevNum';

    final copiedItems = (latestRev?.items ?? []).map((it) {
      return QuotationItemModel(
        id: 'item-$newRevId-${it.id}',
        quotationRevisionId: newRevId,
        catalogueProductId: it.catalogueProductId,
        name: it.name,
        description: it.description,
        quantity: it.quantity,
        finalValue: it.finalValue,
        lineTotal: it.lineTotal,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }).toList();

    final newRevision = QuotationRevisionModel(
      id: newRevId,
      quotationId: quote.id,
      revisionNumber: nextRevNum,
      status: 'DRAFT',
      subtotal: latestRev?.subtotal ?? 0.0,
      discount: latestRev?.discount ?? 0.0,
      tax: latestRev?.tax ?? 0.0,
      total: latestRev?.total ?? 0.0,
      notes: latestRev?.notes,
      terms: latestRev?.terms,
      createdAt: DateTime.now(),
      items: copiedItems,
    );

    final updatedRevisions = [newRevision, ...quote.revisions];
    quotes[quoteIndex] = QuotationModel(
      id: quote.id,
      quotationNumber: quote.quotationNumber,
      serviceRequestId: quote.serviceRequestId,
      createdBy: quote.createdBy,
      createdAt: quote.createdAt,
      updatedAt: DateTime.now(),
      serviceRequest: quote.serviceRequest,
      revisions: updatedRevisions,
    );

    return {
      'revision_id': newRevId,
      'revision_number': nextRevNum,
      'copied_from_revision_id': latestRev?.id,
    };
  }

  @override
  Future<Map<String, dynamic>> sendQuotationRevision(String revisionId) async {
    for (int qIdx = 0; qIdx < quotes.length; qIdx++) {
      final quote = quotes[qIdx];
      final revIndex = quote.revisions.indexWhere((r) => r.id == revisionId);
      if (revIndex != -1) {
        final targetRev = quote.revisions[revIndex];
        final updatedRevisions = quote.revisions.map((r) {
          if (r.id == revisionId) {
            return QuotationRevisionModel(
              id: r.id,
              quotationId: r.quotationId,
              revisionNumber: r.revisionNumber,
              status: 'SENT',
              subtotal: r.subtotal,
              discount: r.discount,
              tax: r.tax,
              total: r.total,
              notes: r.notes,
              terms: r.terms,
              createdAt: r.createdAt,
              sentAt: DateTime.now(),
              items: r.items,
              changeRequests: r.changeRequests,
            );
          } else if (['SENT', 'VIEWED', 'CHANGE_REQUESTED', 'ACCEPTED'].contains(r.status)) {
            return QuotationRevisionModel(
              id: r.id,
              quotationId: r.quotationId,
              revisionNumber: r.revisionNumber,
              status: 'SUPERSEDED',
              subtotal: r.subtotal,
              discount: r.discount,
              tax: r.tax,
              total: r.total,
              notes: r.notes,
              terms: r.terms,
              createdAt: r.createdAt,
              sentAt: r.sentAt,
              items: r.items,
              changeRequests: r.changeRequests,
            );
          }
          return r;
        }).toList();

        quotes[qIdx] = QuotationModel(
          id: quote.id,
          quotationNumber: quote.quotationNumber,
          serviceRequestId: quote.serviceRequestId,
          createdBy: quote.createdBy,
          createdAt: quote.createdAt,
          updatedAt: DateTime.now(),
          serviceRequest: quote.serviceRequest,
          revisions: updatedRevisions,
        );

        return {'revision_id': targetRev.id, 'status': 'SENT'};
      }
    }
    throw Exception('Revision not found: $revisionId');
  }

  @override
  Future<void> updateDraftRevision({
    required String revisionId,
    required List<DraftQuotationItemInput> items,
    double discount = 0,
    double tax = 0,
    String? notes,
    String? terms,
  }) async {
    for (int qIdx = 0; qIdx < quotes.length; qIdx++) {
      final quote = quotes[qIdx];
      final revIndex = quote.revisions.indexWhere((r) => r.id == revisionId);
      if (revIndex != -1) {
        final subtotal = items.fold(0.0, (sum, it) => sum + it.lineTotal);
        final total = (subtotal - discount + tax).clamp(0.0, double.infinity);

        final newItems = items.asMap().entries.map((e) {
          final idx = e.key;
          final it = e.value;
          return QuotationItemModel(
            id: it.id ?? 'item-$revisionId-$idx',
            quotationRevisionId: revisionId,
            catalogueProductId: it.catalogueProductId,
            name: it.name,
            description: it.description,
            quantity: it.quantity,
            finalValue: it.finalValue,
            lineTotal: it.lineTotal,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
        }).toList();

        final updatedRev = QuotationRevisionModel(
          id: revisionId,
          quotationId: quote.id,
          revisionNumber: quote.revisions[revIndex].revisionNumber,
          status: quote.revisions[revIndex].status,
          subtotal: subtotal,
          discount: discount,
          tax: tax,
          total: total,
          notes: notes,
          terms: terms,
          createdAt: quote.revisions[revIndex].createdAt,
          items: newItems,
          changeRequests: quote.revisions[revIndex].changeRequests,
        );

        final updatedRevisions = List<QuotationRevisionModel>.from(quote.revisions);
        updatedRevisions[revIndex] = updatedRev;

        quotes[qIdx] = QuotationModel(
          id: quote.id,
          quotationNumber: quote.quotationNumber,
          serviceRequestId: quote.serviceRequestId,
          createdBy: quote.createdBy,
          createdAt: quote.createdAt,
          updatedAt: DateTime.now(),
          serviceRequest: quote.serviceRequest,
          revisions: updatedRevisions,
        );
        return;
      }
    }
    throw Exception('Revision not found: $revisionId');
  }

  @override
  Future<Map<String, dynamic>> respondChangeRequest({
    required String changeRequestId,
    required String status,
    String? response,
  }) async {
    for (int qIdx = 0; qIdx < quotes.length; qIdx++) {
      final quote = quotes[qIdx];
      for (int rIdx = 0; rIdx < quote.revisions.length; rIdx++) {
        final rev = quote.revisions[rIdx];
        final crIndex = rev.changeRequests.indexWhere((cr) => cr.id == changeRequestId);
        if (crIndex != -1) {
          final oldCr = rev.changeRequests[crIndex];
          final updatedCr = QuotationChangeRequestModel(
            id: oldCr.id,
            quotationRevisionId: oldCr.quotationRevisionId,
            clientId: oldCr.clientId,
            profileId: oldCr.profileId,
            message: oldCr.message,
            status: status,
            adminResponse: response,
            createdAt: oldCr.createdAt,
            respondedAt: DateTime.now(),
          );

          final updatedCrs = List<QuotationChangeRequestModel>.from(rev.changeRequests);
          updatedCrs[crIndex] = updatedCr;

          final updatedRev = QuotationRevisionModel(
            id: rev.id,
            quotationId: rev.quotationId,
            revisionNumber: rev.revisionNumber,
            status: rev.status,
            subtotal: rev.subtotal,
            discount: rev.discount,
            tax: rev.tax,
            total: rev.total,
            notes: rev.notes,
            terms: rev.terms,
            createdAt: rev.createdAt,
            sentAt: rev.sentAt,
            items: rev.items,
            changeRequests: updatedCrs,
          );

          final updatedRevisions = List<QuotationRevisionModel>.from(quote.revisions);
          updatedRevisions[rIdx] = updatedRev;

          quotes[qIdx] = QuotationModel(
            id: quote.id,
            quotationNumber: quote.quotationNumber,
            serviceRequestId: quote.serviceRequestId,
            createdBy: quote.createdBy,
            createdAt: quote.createdAt,
            updatedAt: DateTime.now(),
            serviceRequest: quote.serviceRequest,
            revisions: updatedRevisions,
          );

          return {'change_request_id': changeRequestId, 'status': status};
        }
      }
    }
    throw Exception('Change request not found: $changeRequestId');
  }

  @override
  Future<Map<String, dynamic>> closeQuotationRevision({
    required String revisionId,
    required String status,
  }) async {
    for (int qIdx = 0; qIdx < quotes.length; qIdx++) {
      final quote = quotes[qIdx];
      final revIndex = quote.revisions.indexWhere((r) => r.id == revisionId);
      if (revIndex != -1) {
        final updatedRev = QuotationRevisionModel(
          id: revisionId,
          quotationId: quote.id,
          revisionNumber: quote.revisions[revIndex].revisionNumber,
          status: status,
          subtotal: quote.revisions[revIndex].subtotal,
          discount: quote.revisions[revIndex].discount,
          tax: quote.revisions[revIndex].tax,
          total: quote.revisions[revIndex].total,
          notes: quote.revisions[revIndex].notes,
          terms: quote.revisions[revIndex].terms,
          createdAt: quote.revisions[revIndex].createdAt,
          items: quote.revisions[revIndex].items,
          changeRequests: quote.revisions[revIndex].changeRequests,
        );
        final updatedRevisions = List<QuotationRevisionModel>.from(quote.revisions);
        updatedRevisions[revIndex] = updatedRev;

        quotes[qIdx] = QuotationModel(
          id: quote.id,
          quotationNumber: quote.quotationNumber,
          serviceRequestId: quote.serviceRequestId,
          createdBy: quote.createdBy,
          createdAt: quote.createdAt,
          updatedAt: DateTime.now(),
          serviceRequest: quote.serviceRequest,
          revisions: updatedRevisions,
        );

        return {'revision_id': revisionId, 'status': status};
      }
    }
    throw Exception('Revision not found: $revisionId');
  }

  @override
  Future<String?> getSignedQuotationPdfUrl({
    required String revisionId,
    required String storagePath,
  }) async {
    return 'https://mock.storage/signed.pdf';
  }

  @override
  Future<String?> getUnsignedQuotationPdfUrl({
    required String revisionId,
    required String storagePath,
  }) async {
    return 'https://mock.storage/unsigned.pdf';
  }
}

class MockClientPortalRepository implements ClientPortalRepository {
  ClientModel? clientProfile = const ClientModel(
    id: '2bd5d7fb-3b55-48b1-931f-69896d3f0838',
    fullName: 'Rahul Kumar',
    phone: '+91 98450 12890',
    email: 'rahul.kumar@gmail.com',
    address: '12, MG Road, Indiranagar',
    city: 'Bengaluru',
    state: 'Karnataka',
    pincode: '560038',
    isActive: true,
  );

  List<VehicleModel> vehicles = [
    const VehicleModel(
      id: 'edd54d25-b67b-4ac7-bd72-b5dc4daf8b24',
      clientId: '2bd5d7fb-3b55-48b1-931f-69896d3f0838',
      make: 'Honda',
      model: 'City',
      manufacturingYear: 2022,
      registrationNumber: 'KA-01-MJ-4412',
      chassisNumber: 'MAKGM2656N1028492',
    ),
    const VehicleModel(
      id: 'v-client-2',
      clientId: '2bd5d7fb-3b55-48b1-931f-69896d3f0838',
      make: 'Hyundai',
      model: 'Creta',
      manufacturingYear: 2021,
      registrationNumber: 'KA-05-NB-7821',
      chassisNumber: 'MALH351BLM1098234',
    ),
  ];

  late List<ServiceRequestModel> serviceRequests = [
    ServiceRequestModel(
      id: 'sr-client-1',
      requestNumber: 'SR-2026-00021',
      source: 'PORTAL',
      status: 'UNDER_REVIEW',
      clientId: '2bd5d7fb-3b55-48b1-931f-69896d3f0838',
      vehicleId: 'edd54d25-b67b-4ac7-bd72-b5dc4daf8b24',
      originalSubmission: {
        'requested_items': [
          'Periodic Maintenance Service (PMS)',
          'Front brake inspection & rotor check',
        ],
        'reported_symptom':
            'Slight squeaking sound heard from front wheels when braking at low speeds.',
        'description': 'Comprehensive 40-point vehicle wellness inspection',
      },
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      updatedAt: DateTime.now().subtract(const Duration(minutes: 12)),
      vehicle: const VehicleModel(
        id: 'edd54d25-b67b-4ac7-bd72-b5dc4daf8b24',
        clientId: '2bd5d7fb-3b55-48b1-931f-69896d3f0838',
        make: 'Honda',
        model: 'City',
        manufacturingYear: 2022,
        registrationNumber: 'KA-01-MJ-4412',
        chassisNumber: 'MAKGM2656N1028492',
      ),
    ),
    ServiceRequestModel(
      id: 'sr-client-2',
      requestNumber: 'SR-2026-00022',
      source: 'PORTAL',
      status: 'CONVERTED_TO_JOB',
      clientId: '2bd5d7fb-3b55-48b1-931f-69896d3f0838',
      vehicleId: 'edd54d25-b67b-4ac7-bd72-b5dc4daf8b24',
      jobId: 'job-client-2',
      jobNumber: 'JOB-2026-0012',
      jobStatus: 'WORK_IN_PROGRESS',
      originalSubmission: {
        'requested_items': ['Wheel alignment & balancing'],
        'description': 'Wheel alignment & 4-wheel balancing',
      },
      createdAt: DateTime.now().subtract(const Duration(days: 3)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 4)),
      vehicle: const VehicleModel(
        id: 'edd54d25-b67b-4ac7-bd72-b5dc4daf8b24',
        clientId: '2bd5d7fb-3b55-48b1-931f-69896d3f0838',
        make: 'Honda',
        model: 'City',
        manufacturingYear: 2022,
        registrationNumber: 'KA-01-MJ-4412',
        chassisNumber: 'MAKGM2656N1028492',
      ),
    ),
    ServiceRequestModel(
      id: 'sr-client-3',
      requestNumber: 'SR-2026-00023',
      source: 'PORTAL',
      status: 'CONVERTED_TO_JOB',
      clientId: '2bd5d7fb-3b55-48b1-931f-69896d3f0838',
      vehicleId: 'edd54d25-b67b-4ac7-bd72-b5dc4daf8b24',
      jobId: 'job-client-3',
      jobNumber: 'JOB-2026-0008',
      jobStatus: 'COMPLETED',
      originalSubmission: {
        'requested_items': ['Synthetic oil change & filter replacement'],
        'description': 'Routine oil service',
      },
      createdAt: DateTime.now().subtract(const Duration(days: 14)),
      updatedAt: DateTime.now().subtract(const Duration(days: 12)),
      vehicle: const VehicleModel(
        id: 'edd54d25-b67b-4ac7-bd72-b5dc4daf8b24',
        clientId: '2bd5d7fb-3b55-48b1-931f-69896d3f0838',
        make: 'Honda',
        model: 'City',
        manufacturingYear: 2022,
        registrationNumber: 'KA-01-MJ-4412',
        chassisNumber: 'MAKGM2656N1028492',
      ),
    ),
    ServiceRequestModel(
      id: 'sr-client-4',
      requestNumber: 'SR-2026-00024',
      source: 'PORTAL',
      status: 'CANCELLED',
      clientId: '2bd5d7fb-3b55-48b1-931f-69896d3f0838',
      vehicleId: 'v-client-2',
      originalSubmission: {
        'requested_items': ['AC cooling check'],
        'description': 'AC cooling check',
      },
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
      updatedAt: DateTime.now().subtract(const Duration(days: 29)),
      vehicle: const VehicleModel(
        id: 'v-client-2',
        clientId: '2bd5d7fb-3b55-48b1-931f-69896d3f0838',
        make: 'Hyundai',
        model: 'Creta',
        manufacturingYear: 2021,
        registrationNumber: 'KA-05-NB-7821',
        chassisNumber: 'MALH351BLM1098234',
      ),
    ),
  ];

  @override
  Future<ClientModel?> fetchClientProfile() async => clientProfile;

  @override
  Future<List<VehicleModel>> fetchClientVehicles() async => vehicles;

  @override
  Future<VehicleModel> getVehicleById(String vehicleId) async {
    final match = vehicles.where((v) => v.id == vehicleId).toList();
    if (match.isEmpty) {
      throw Exception('Vehicle not found: $vehicleId');
    }
    return match.first;
  }

  @override
  Future<List<ServiceRequestModel>> fetchClientServiceRequests() async =>
      serviceRequests;

  @override
  Future<List<ServiceRequestModel>> fetchServiceRequestsForVehicle(
      String vehicleId) async {
    return serviceRequests.where((sr) => sr.vehicleId == vehicleId).toList();
  }

  @override
  Future<ServiceRequestModel> getServiceRequestById(String requestId) async {
    final match = serviceRequests.where((sr) => sr.id == requestId).toList();
    if (match.isEmpty) {
      throw Exception('Service request not found: $requestId');
    }
    return match.first;
  }

  late List<QuotationModel> quotations = [
    QuotationModel(
      id: 'q-client-1',
      quotationNumber: 'QT-2026-00037',
      serviceRequestId: 'sr-client-quote-ready',
      createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      serviceRequest: ServiceRequestModel(
        id: 'sr-client-quote-ready',
        requestNumber: 'SR-2026-00075',
        source: 'PORTAL',
        status: 'QUOTATION_SENT',
        clientId: '2bd5d7fb-3b55-48b1-931f-69896d3f0838',
        vehicleId: 'edd54d25-b67b-4ac7-bd72-b5dc4daf8b24',
        createdAt: DateTime.now().subtract(const Duration(hours: 4)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
        vehicle: vehicles[0],
      ),
      revisions: [
        QuotationRevisionModel(
          id: 'rev-client-1',
          quotationId: 'q-client-1',
          revisionNumber: 1,
          status: 'SENT',
          subtotal: 18000,
          discount: 0,
          tax: 3000,
          total: 21000,
          notes: 'Standard OEM parts will be installed.',
          terms: 'Standard AutoTricks warranty applies.',
          createdAt: DateTime.now().subtract(const Duration(hours: 1)),
          sentAt: DateTime.now().subtract(const Duration(hours: 1)),
          items: [
            QuotationItemModel(
              id: 'item-1',
              quotationRevisionId: 'rev-client-1',
              name: 'Engine Oil & Filter Replacement',
              description: 'Full synthetic 5W-30 engine oil with OEM filter',
              quantity: 1,
              finalValue: 5500,
              lineTotal: 5500,
              createdAt: DateTime.now().subtract(const Duration(hours: 1)),
              updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
            ),
            QuotationItemModel(
              id: 'item-2',
              quotationRevisionId: 'rev-client-1',
              name: 'Front Brake Pad Set & Rotor Skimming',
              description: 'OEM ceramic pads with precision rotor resurfacing',
              quantity: 1,
              finalValue: 12500,
              lineTotal: 12500,
              createdAt: DateTime.now().subtract(const Duration(hours: 1)),
              updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
            ),
          ],
        ),
      ],
    ),
    QuotationModel(
      id: 'q-client-2',
      quotationNumber: 'QT-2026-00038',
      serviceRequestId: 'sr-client-2',
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      serviceRequest: serviceRequests[1],
      revisions: [
        QuotationRevisionModel(
          id: 'rev-client-2',
          quotationId: 'q-client-2',
          revisionNumber: 1,
          status: 'CHANGE_REQUESTED',
          subtotal: 7500,
          discount: 0,
          tax: 1000,
          total: 8500,
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
          sentAt: DateTime.now().subtract(const Duration(days: 2)),
          items: [
            QuotationItemModel(
              id: 'item-3',
              quotationRevisionId: 'rev-client-2',
              name: 'Wheel Alignment & 4-Wheel Balancing',
              description: 'Laser alignment and dynamic balancing',
              quantity: 1,
              finalValue: 7500,
              lineTotal: 7500,
              createdAt: DateTime.now().subtract(const Duration(days: 2)),
              updatedAt: DateTime.now().subtract(const Duration(days: 2)),
            ),
          ],
          changeRequests: [
            QuotationChangeRequestModel(
              id: 'cr-1',
              quotationRevisionId: 'rev-client-2',
              clientId: '2bd5d7fb-3b55-48b1-931f-69896d3f0838',
              profileId: 'prof-client-1',
              message: 'Please exclude tyre rotation as it was done recently.',
              status: 'PENDING',
              createdAt: DateTime.now().subtract(const Duration(days: 1)),
            ),
          ],
        ),
      ],
    ),
    QuotationModel(
      id: 'q-client-3',
      quotationNumber: 'QT-2026-00036',
      serviceRequestId: 'sr-client-3',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
      updatedAt: DateTime.now().subtract(const Duration(days: 9)),
      serviceRequest: serviceRequests[2],
      revisions: [
        QuotationRevisionModel(
          id: 'rev-client-3',
          quotationId: 'q-client-3',
          revisionNumber: 1,
          status: 'ACCEPTED',
          subtotal: 12000,
          discount: 0,
          tax: 2000,
          total: 14000,
          createdAt: DateTime.now().subtract(const Duration(days: 10)),
          sentAt: DateTime.now().subtract(const Duration(days: 10)),
          acceptedAt: DateTime.now().subtract(const Duration(days: 9)),
          acceptanceConsentText:
              'I confirm that I have reviewed Revision 1 and agree to the quoted scope, pricing, and terms.',
          items: [
            QuotationItemModel(
              id: 'item-4',
              quotationRevisionId: 'rev-client-3',
              name: 'Comprehensive Periodic Maintenance',
              description: 'Scheduled PMS package',
              quantity: 1,
              finalValue: 12000,
              lineTotal: 12000,
              createdAt: DateTime.now().subtract(const Duration(days: 10)),
              updatedAt: DateTime.now().subtract(const Duration(days: 10)),
            ),
          ],
        ),
      ],
    ),
    QuotationModel(
      id: 'q-client-4',
      quotationNumber: 'QT-2026-00035',
      serviceRequestId: 'sr-client-4',
      createdAt: DateTime.now().subtract(const Duration(days: 25)),
      updatedAt: DateTime.now().subtract(const Duration(days: 24)),
      serviceRequest: serviceRequests[3],
      revisions: [
        QuotationRevisionModel(
          id: 'rev-client-4',
          quotationId: 'q-client-4',
          revisionNumber: 1,
          status: 'REJECTED',
          subtotal: 4500,
          discount: 0,
          tax: 500,
          total: 5000,
          createdAt: DateTime.now().subtract(const Duration(days: 25)),
          sentAt: DateTime.now().subtract(const Duration(days: 25)),
          rejectedAt: DateTime.now().subtract(const Duration(days: 24)),
          rejectionReason: 'Postponed due to personal schedule.',
          items: [
            QuotationItemModel(
              id: 'item-5',
              quotationRevisionId: 'rev-client-4',
              name: 'AC Gas Refill & Filter Replacement',
              description: 'R134a refrigerant charge with cabin air filter',
              quantity: 1,
              finalValue: 4500,
              lineTotal: 4500,
              createdAt: DateTime.now().subtract(const Duration(days: 25)),
              updatedAt: DateTime.now().subtract(const Duration(days: 25)),
            ),
          ],
        ),
      ],
    ),
  ];

  QuotationModel _sanitizeClientQuotation(QuotationModel quote) {
    final clientRevisions = quote.revisions.where((r) => !r.isDraft).toList()
      ..sort((a, b) => b.revisionNumber.compareTo(a.revisionNumber));
    return QuotationModel(
      id: quote.id,
      quotationNumber: quote.quotationNumber,
      serviceRequestId: quote.serviceRequestId,
      createdBy: quote.createdBy,
      createdAt: quote.createdAt,
      updatedAt: quote.updatedAt,
      serviceRequest: quote.serviceRequest,
      revisions: clientRevisions,
    );
  }

  @override
  Future<List<QuotationModel>> fetchClientQuotations() async {
    return quotations
        .map(_sanitizeClientQuotation)
        .where((q) => q.revisions.isNotEmpty)
        .toList();
  }

  @override
  Future<QuotationModel> getQuotationById(String id) async {
    final match = quotations.where((q) => q.id == id).toList();
    if (match.isEmpty) {
      throw Exception('Quotation not found: $id');
    }
    return _sanitizeClientQuotation(match.first);
  }

  @override
  Future<QuotationModel?> getQuotationByServiceRequestId(String serviceRequestId) async {
    final match = quotations.where((q) => q.serviceRequestId == serviceRequestId).toList();
    if (match.isEmpty) return null;
    final sanitized = _sanitizeClientQuotation(match.first);
    return sanitized.revisions.isNotEmpty ? sanitized : null;
  }

  @override
  Future<void> markQuotationViewed(String revisionId) async {
    for (int i = 0; i < quotations.length; i++) {
      final q = quotations[i];
      final revIndex = q.revisions.indexWhere((r) => r.id == revisionId);
      if (revIndex != -1) {
        final rev = q.revisions[revIndex];
        if (rev.status == 'SENT') {
          final updatedRev = QuotationRevisionModel(
            id: rev.id,
            quotationId: rev.quotationId,
            revisionNumber: rev.revisionNumber,
            status: 'VIEWED',
            subtotal: rev.subtotal,
            discount: rev.discount,
            tax: rev.tax,
            total: rev.total,
            notes: rev.notes,
            terms: rev.terms,
            createdBy: rev.createdBy,
            createdAt: rev.createdAt,
            sentAt: rev.sentAt,
            viewedAt: DateTime.now(),
            acceptedAt: rev.acceptedAt,
            acceptedByProfileId: rev.acceptedByProfileId,
            acceptanceConsentText: rev.acceptanceConsentText,
            rejectedAt: rev.rejectedAt,
            rejectionReason: rev.rejectionReason,
            items: rev.items,
            changeRequests: rev.changeRequests,
          );
          final updatedRevisions = List<QuotationRevisionModel>.from(q.revisions);
          updatedRevisions[revIndex] = updatedRev;
          quotations[i] = QuotationModel(
            id: q.id,
            quotationNumber: q.quotationNumber,
            serviceRequestId: q.serviceRequestId,
            createdBy: q.createdBy,
            createdAt: q.createdAt,
            updatedAt: DateTime.now(),
            serviceRequest: q.serviceRequest,
            revisions: updatedRevisions,
          );
        }
        return;
      }
    }
  }

  @override
  Future<void> requestQuotationChange({
    required String revisionId,
    required String message,
  }) async {
    for (int i = 0; i < quotations.length; i++) {
      final q = quotations[i];
      final revIndex = q.revisions.indexWhere((r) => r.id == revisionId);
      if (revIndex != -1) {
        final rev = q.revisions[revIndex];
        final newCr = QuotationChangeRequestModel(
          id: 'cr-${DateTime.now().millisecondsSinceEpoch}',
          quotationRevisionId: revisionId,
          clientId: '2bd5d7fb-3b55-48b1-931f-69896d3f0838',
          profileId: 'prof-client-1',
          message: message,
          status: 'PENDING',
          createdAt: DateTime.now(),
        );
        final updatedRev = QuotationRevisionModel(
          id: rev.id,
          quotationId: rev.quotationId,
          revisionNumber: rev.revisionNumber,
          status: 'CHANGE_REQUESTED',
          subtotal: rev.subtotal,
          discount: rev.discount,
          tax: rev.tax,
          total: rev.total,
          notes: rev.notes,
          terms: rev.terms,
          createdBy: rev.createdBy,
          createdAt: rev.createdAt,
          sentAt: rev.sentAt,
          viewedAt: rev.viewedAt,
          acceptedAt: rev.acceptedAt,
          acceptedByProfileId: rev.acceptedByProfileId,
          acceptanceConsentText: rev.acceptanceConsentText,
          rejectedAt: rev.rejectedAt,
          rejectionReason: rev.rejectionReason,
          items: rev.items,
          changeRequests: [newCr, ...rev.changeRequests],
        );
        final updatedRevisions = List<QuotationRevisionModel>.from(q.revisions);
        updatedRevisions[revIndex] = updatedRev;
        quotations[i] = QuotationModel(
          id: q.id,
          quotationNumber: q.quotationNumber,
          serviceRequestId: q.serviceRequestId,
          createdBy: q.createdBy,
          createdAt: q.createdAt,
          updatedAt: DateTime.now(),
          serviceRequest: q.serviceRequest,
          revisions: updatedRevisions,
        );
        return;
      }
    }
  }

  @override
  Future<void> acceptQuotationRevision({
    required String revisionId,
    required String consentText,
  }) async {
    throw UnsupportedError(
      'Direct quotation acceptance without signature is forbidden. Digital signature is mandatory.',
    );
  }

  @override
  Future<void> rejectQuotationRevision({
    required String revisionId,
    required String reason,
  }) async {
    for (int i = 0; i < quotations.length; i++) {
      final q = quotations[i];
      final revIndex = q.revisions.indexWhere((r) => r.id == revisionId);
      if (revIndex != -1) {
        final rev = q.revisions[revIndex];
        final updatedRev = QuotationRevisionModel(
          id: rev.id,
          quotationId: rev.quotationId,
          revisionNumber: rev.revisionNumber,
          status: 'REJECTED',
          subtotal: rev.subtotal,
          discount: rev.discount,
          tax: rev.tax,
          total: rev.total,
          notes: rev.notes,
          terms: rev.terms,
          createdBy: rev.createdBy,
          createdAt: rev.createdAt,
          sentAt: rev.sentAt,
          viewedAt: rev.viewedAt,
          acceptedAt: null,
          acceptedByProfileId: null,
          acceptanceConsentText: null,
          rejectedAt: DateTime.now(),
          rejectionReason: reason,
          items: rev.items,
          changeRequests: rev.changeRequests,
        );
        final updatedRevisions = List<QuotationRevisionModel>.from(q.revisions);
        updatedRevisions[revIndex] = updatedRev;
        quotations[i] = QuotationModel(
          id: q.id,
          quotationNumber: q.quotationNumber,
          serviceRequestId: q.serviceRequestId,
          createdBy: q.createdBy,
          createdAt: q.createdAt,
          updatedAt: DateTime.now(),
          serviceRequest: q.serviceRequest,
          revisions: updatedRevisions,
        );
        return;
      }
    }
  }

  @override
  Future<Map<String, dynamic>> signQuotationRevision({
    required String revisionId,
    required String consentText,
    required Uint8List signatureBytes,
  }) async {
    for (int i = 0; i < quotations.length; i++) {
      final q = quotations[i];
      final revIndex = q.revisions.indexWhere((r) => r.id == revisionId);
      if (revIndex != -1) {
        final rev = q.revisions[revIndex];
        final now = DateTime.now();
        final sig = QuotationSignatureModel(
          id: 'sig-${now.millisecondsSinceEpoch}',
          quotationRevisionId: rev.id,
          clientId: q.serviceRequest?.clientId ?? "c-1",
          profileId: 'prof-client-1',
          signatureFile: 'signatures/${q.serviceRequest?.clientId ?? "c-1"}/${rev.id}/signature.png',
          signatureMethod: 'DRAWN',
          consentText: consentText,
          acceptedAt: now,
          signedAt: now,
          createdAt: now,
        );
        final signedDoc = DocumentModel(
          id: 'doc-${now.millisecondsSinceEpoch}',
          clientId: q.serviceRequest?.clientId ?? "c-1",
          quotationRevisionId: rev.id,
          documentType: 'SIGNED_QUOTATION_PDF',
          storagePath: 'signed-quotation-pdfs/${q.serviceRequest?.clientId ?? "c-1"}/${q.id}/revision-${rev.revisionNumber}-signed.pdf',
          createdAt: now,
        );
        final updatedRev = QuotationRevisionModel(
          id: rev.id,
          quotationId: rev.quotationId,
          revisionNumber: rev.revisionNumber,
          status: 'ACCEPTED',
          subtotal: rev.subtotal,
          discount: rev.discount,
          tax: rev.tax,
          total: rev.total,
          notes: rev.notes,
          terms: rev.terms,
          createdBy: rev.createdBy,
          createdAt: rev.createdAt,
          sentAt: rev.sentAt,
          viewedAt: rev.viewedAt,
          acceptedAt: now,
          acceptedByProfileId: 'prof-client-1',
          acceptanceConsentText: consentText,
          rejectedAt: null,
          rejectionReason: null,
          items: rev.items,
          changeRequests: rev.changeRequests,
          signature: sig,
          documents: [signedDoc],
        );
        final updatedRevisions = List<QuotationRevisionModel>.from(q.revisions);
        updatedRevisions[revIndex] = updatedRev;

        ServiceRequestModel? updatedSr;
        if (q.serviceRequest != null) {
          final newSr = ServiceRequestModel(
            id: q.serviceRequest!.id,
            requestNumber: q.serviceRequest!.requestNumber,
            source: q.serviceRequest!.source,
            status: 'APPROVED',
            clientId: q.serviceRequest!.clientId,
            vehicleId: q.serviceRequest!.vehicleId,
            adminNotes: q.serviceRequest!.adminNotes,
            createdAt: q.serviceRequest!.createdAt,
            updatedAt: now,
            client: q.serviceRequest!.client,
            vehicle: q.serviceRequest!.vehicle,
          );
          updatedSr = newSr;
          final srIdx = serviceRequests.indexWhere((sr) => sr.id == newSr.id);
          if (srIdx != -1) {
            serviceRequests[srIdx] = newSr;
          } else {
            serviceRequests.add(newSr);
          }
        }

        quotations[i] = QuotationModel(
          id: q.id,
          quotationNumber: q.quotationNumber,
          serviceRequestId: q.serviceRequestId,
          createdBy: q.createdBy,
          createdAt: q.createdAt,
          updatedAt: now,
          serviceRequest: updatedSr,
          revisions: updatedRevisions,
        );

        return {
          'success': true,
          'status': 'ACCEPTED',
          'signed_pdf_url': 'https://mock.storage/signed.pdf',
        };
      }
    }
    throw Exception('Revision not found: $revisionId');
  }

  @override
  Future<String?> getSignedQuotationPdfUrl({
    required String revisionId,
    required String storagePath,
  }) async {
    return 'https://mock.storage/signed.pdf';
  }

  @override
  Future<String?> getUnsignedQuotationPdfUrl({
    required String revisionId,
    required String storagePath,
  }) async {
    return 'https://mock.storage/unsigned.pdf';
  }
}


