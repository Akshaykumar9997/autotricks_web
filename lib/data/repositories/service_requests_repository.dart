import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/service_request_model.dart';

abstract class ServiceRequestsRepository {
  Future<List<ServiceRequestModel>> fetchServiceRequests({
    String? statusFilter,
    String? searchQuery,
  });

  Future<ServiceRequestModel> getServiceRequestById(String id);

  Future<ServiceRequestModel> createServiceRequest({
    required String clientId,
    required String vehicleId,
    required String description,
  });

  Future<void> linkServiceRequest({
    required String requestId,
    required String clientId,
    required String vehicleId,
  });

  Future<void> updateStatus({
    required String requestId,
    required String status,
  });

  Future<void> cancelServiceRequest(String requestId);
}

class SupabaseServiceRequestsRepository implements ServiceRequestsRepository {
  final SupabaseClient _client;

  SupabaseServiceRequestsRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<ServiceRequestModel>> fetchServiceRequests({
    String? statusFilter,
    String? searchQuery,
  }) async {
    try {
      var query = _client
          .from('admin_service_requests')
          .select('*, vehicles(*), clients(id, full_name, phone, email, address, city, state, pincode, is_active)');

      if (statusFilter != null &&
          statusFilter.isNotEmpty &&
          statusFilter.toUpperCase() != 'ALL') {
        query = query.eq('status', statusFilter.toUpperCase());
      }

      final data = await query.order('created_at', ascending: false);
      final list = (data as List)
          .map((item) => ServiceRequestModel.fromJson(item as Map<String, dynamic>))
          .toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final queryLower = searchQuery.trim().toLowerCase();
        return list.where((sr) {
          final reqNum = sr.requestNumber.toLowerCase();
          final cust = sr.customerName.toLowerCase();
          final veh = sr.vehicleTitle.toLowerCase();
          final plate = sr.vehiclePlate.toLowerCase();
          final desc = sr.serviceDescription.toLowerCase();
          return reqNum.contains(queryLower) ||
              cust.contains(queryLower) ||
              veh.contains(queryLower) ||
              plate.contains(queryLower) ||
              desc.contains(queryLower);
        }).toList();
      }

      return list;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ServiceRequestModel> getServiceRequestById(String id) async {
    final data = await _client
        .from('admin_service_requests')
        .select('*, vehicles(*), clients(id, full_name, phone, email, address, city, state, pincode, is_active)')
        .eq('id', id)
        .single();

    return ServiceRequestModel.fromJson(data);
  }

  @override
  Future<ServiceRequestModel> createServiceRequest({
    required String clientId,
    required String vehicleId,
    required String description,
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('Authentication required to create a service request.');
    }

    final insertData = {
      'client_id': clientId,
      'vehicle_id': vehicleId,
      'source': 'PHONE',
      'admin_notes': description,
      'created_by': currentUserId,
    };

    final response = await _client
        .from('service_requests')
        .insert(insertData)
        .select('id, request_number, client_id, vehicle_id, source, status, created_at, updated_at')
        .single();

    final newId = response['id'] as String;
    return await getServiceRequestById(newId);
  }

  @override
  Future<void> linkServiceRequest({
    required String requestId,
    required String clientId,
    required String vehicleId,
  }) async {
    // Calls the approved database RPC
    await _client.rpc('admin_link_service_request', params: {
      'p_service_request_id': requestId,
      'p_client_id': clientId,
      'p_vehicle_id': vehicleId,
    });
  }

  @override
  Future<void> updateStatus({
    required String requestId,
    required String status,
  }) async {
    await _client
        .from('service_requests')
        .update({'status': status})
        .eq('id', requestId);
  }

  @override
  Future<void> cancelServiceRequest(String requestId) async {
    await updateStatus(requestId: requestId, status: 'CANCELLED');
  }
}
