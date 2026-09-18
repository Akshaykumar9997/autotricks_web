import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:autotricks/data/models/activity_item_model.dart';
import 'package:autotricks/data/models/client_model.dart';
import 'package:autotricks/data/models/service_job_summary_model.dart';
import 'package:autotricks/data/models/service_request_model.dart';
import 'package:autotricks/data/models/vehicle_model.dart';
import 'package:autotricks/data/repositories/auth_repository.dart';
import 'package:autotricks/data/repositories/client_vehicle_repository.dart';
import 'package:autotricks/data/repositories/home_repository.dart';
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
  @override
  Future<List<ClientModel>> fetchClients() async {
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
    ];
  }

  @override
  Future<List<VehicleModel>> fetchVehiclesForClient(String clientId) async {
    return const [
      VehicleModel(
        id: 'v-1',
        clientId: 'c-1',
        make: 'Honda',
        model: 'City',
        manufacturingYear: 2022,
        registrationNumber: 'KA-01-MJ-4412',
      ),
    ];
  }
}
