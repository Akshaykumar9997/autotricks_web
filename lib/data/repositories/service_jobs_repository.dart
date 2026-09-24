import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/service_job_model.dart';

abstract class ServiceJobsRepository {
  /// Fetches a list of service jobs with optional status filter and search query.
  Future<List<ServiceJobModel>> fetchServiceJobs({
    String? statusFilter,
    String? searchQuery,
  });

  /// Fetches a single service job by its UUID, including vehicle, service request, client, work items, and history.
  Future<ServiceJobModel> getServiceJobById(String id);

  /// Fetches a service job linked to a specific service request UUID.
  Future<ServiceJobModel?> getServiceJobByRequestId(String requestId);

  /// Fetches a service job linked to a specific quotation revision UUID.
  Future<ServiceJobModel?> getServiceJobByRevisionId(String revisionId);

  /// Admin operation: creates a new Service Job from an accepted, signed quotation revision.
  Future<Map<String, dynamic>> createServiceJob({
    required String quotationRevisionId,
    DateTime? scheduledAt,
  });

  /// Admin operation: updates the service job status with strictly sequential transition validation.
  Future<Map<String, dynamic>> updateJobStatus({
    required String jobId,
    required String status,
    String? note,
  });

  /// Fetches the status transition history for a service job.
  Future<List<ServiceJobStatusHistoryModel>> fetchJobStatusHistory(String jobId);

  /// Fetches all work items for a service job.
  Future<List<ServiceWorkItemModel>> fetchJobWorkItems(String jobId);

  /// Updates status of an individual work item (e.g. PENDING -> IN_PROGRESS -> COMPLETED).
  Future<void> updateWorkItemStatus({
    required String itemId,
    required String status,
  });

  /// Marks all non-completed/non-cancelled work items as COMPLETED before job closure.
  Future<void> completeAllWorkItems(String jobId);
}

class SupabaseServiceJobsRepository implements ServiceJobsRepository {
  final SupabaseClient _client;

  SupabaseServiceJobsRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  static const String _serviceJobSelect = '''
    id,
    job_number,
    service_request_id,
    quotation_revision_id,
    vehicle_id,
    status,
    started_at,
    completed_at,
    scheduled_at,
    created_at,
    updated_at,
    vehicles (
      id,
      client_id,
      make,
      model,
      manufacturing_year,
      registration_number,
      chassis_number
    ),
    service_requests (
      id,
      request_number,
      client_id,
      vehicle_id,
      source,
      status,
      created_by,
      created_at,
      updated_at,
      original_submission,
      clients (
        id,
        full_name,
        phone,
        email,
        address,
        city,
        state,
        pincode
      )
    )
  ''';

  @override
  Future<List<ServiceJobModel>> fetchServiceJobs({
    String? statusFilter,
    String? searchQuery,
  }) async {
    try {
      var query = _client.from('service_jobs').select(_serviceJobSelect);

      if (statusFilter != null &&
          statusFilter.isNotEmpty &&
          statusFilter.toUpperCase() != 'ALL') {
        query = query.eq('status', statusFilter.toUpperCase());
      }

      final data = await query.order('created_at', ascending: false);
      final list = (data as List)
          .map((item) => ServiceJobModel.fromJson(item as Map<String, dynamic>))
          .toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final qLower = searchQuery.trim().toLowerCase();
        return list.where((j) {
          final jobNum = j.jobNumber.toLowerCase();
          final cust = j.customerName.toLowerCase();
          final veh = j.vehicleTitle.toLowerCase();
          final plate = j.vehiclePlate.toLowerCase();
          return jobNum.contains(qLower) ||
              cust.contains(qLower) ||
              veh.contains(qLower) ||
              plate.contains(qLower);
        }).toList();
      }

      return list;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ServiceJobModel> getServiceJobById(String id) async {
    try {
      final data = await _client
          .from('service_jobs')
          .select('''
            $_serviceJobSelect,
            service_work_items (
              id,
              service_job_id,
              quotation_item_id,
              name,
              description,
              quantity,
              source,
              status,
              approval_status,
              approximate_value,
              final_value,
              approved_value,
              decision_by_profile_id,
              decision_at,
              approval_note,
              created_at,
              updated_at
            ),
            service_job_status_history (
              id,
              service_job_id,
              from_status,
              to_status,
              changed_by_profile_id,
              note,
              created_at,
              profiles (
                id,
                full_name
              )
            )
          ''')
          .eq('id', id)
          .single();

      final model = ServiceJobModel.fromJson(data);
      // Sort work items and history
      final sortedItems = List<ServiceWorkItemModel>.from(model.workItems)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
      final sortedHistory = List<ServiceJobStatusHistoryModel>.from(model.statusHistory)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return model.copyWith(
        workItems: sortedItems,
        statusHistory: sortedHistory,
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ServiceJobModel?> getServiceJobByRequestId(String requestId) async {
    try {
      final data = await _client
          .from('service_jobs')
          .select(_serviceJobSelect)
          .eq('service_request_id', requestId)
          .maybeSingle();

      if (data == null) return null;
      return ServiceJobModel.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ServiceJobModel?> getServiceJobByRevisionId(String revisionId) async {
    try {
      final data = await _client
          .from('service_jobs')
          .select(_serviceJobSelect)
          .eq('quotation_revision_id', revisionId)
          .maybeSingle();

      if (data == null) return null;
      return ServiceJobModel.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> createServiceJob({
    required String quotationRevisionId,
    DateTime? scheduledAt,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_quotation_revision_id': quotationRevisionId,
      };
      if (scheduledAt != null) {
        params['p_scheduled_at'] = scheduledAt.toIso8601String();
      }

      final response = await _client.rpc(
        'admin_create_service_job',
        params: params,
      );

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> updateJobStatus({
    required String jobId,
    required String status,
    String? note,
  }) async {
    try {
      final params = <String, dynamic>{
        'p_service_job_id': jobId,
        'p_status': status,
      };
      if (note != null && note.trim().isNotEmpty) {
        params['p_note'] = note.trim();
      }

      final response = await _client.rpc(
        'admin_update_service_job_status',
        params: params,
      );

      return Map<String, dynamic>.from(response as Map);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<ServiceJobStatusHistoryModel>> fetchJobStatusHistory(String jobId) async {
    try {
      final data = await _client
          .from('service_job_status_history')
          .select('*, profiles(id, full_name)')
          .eq('service_job_id', jobId)
          .order('created_at', ascending: true);

      return (data as List)
          .map((item) => ServiceJobStatusHistoryModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<ServiceWorkItemModel>> fetchJobWorkItems(String jobId) async {
    try {
      final data = await _client
          .from('service_work_items')
          .select('*')
          .eq('service_job_id', jobId)
          .order('created_at', ascending: true);

      return (data as List)
          .map((item) => ServiceWorkItemModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> updateWorkItemStatus({
    required String itemId,
    required String status,
  }) async {
    try {
      await _client
          .from('service_work_items')
          .update({'status': status})
          .eq('id', itemId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> completeAllWorkItems(String jobId) async {
    try {
      await _client
          .from('service_work_items')
          .update({'status': 'COMPLETED'})
          .eq('service_job_id', jobId)
          .neq('status', 'CANCELLED');
    } catch (e) {
      rethrow;
    }
  }
}
