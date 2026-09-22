import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/client_model.dart';
import '../models/quotation_model.dart';
import '../models/service_request_model.dart';
import '../models/vehicle_model.dart';

abstract class ClientPortalRepository {
  Future<ClientModel?> fetchClientProfile();
  Future<List<VehicleModel>> fetchClientVehicles();
  Future<VehicleModel> getVehicleById(String vehicleId);
  Future<List<ServiceRequestModel>> fetchClientServiceRequests();
  Future<List<ServiceRequestModel>> fetchServiceRequestsForVehicle(String vehicleId);
  Future<ServiceRequestModel> getServiceRequestById(String requestId);

  // Day 10 Quotation Methods
  Future<List<QuotationModel>> fetchClientQuotations();
  Future<QuotationModel> getQuotationById(String id);
  Future<QuotationModel?> getQuotationByServiceRequestId(String serviceRequestId);
  Future<void> markQuotationViewed(String revisionId);
  Future<void> requestQuotationChange({required String revisionId, required String message});
  Future<void> acceptQuotationRevision({required String revisionId, required String consentText});
  Future<void> rejectQuotationRevision({required String revisionId, required String reason});
}

class SupabaseClientPortalRepository implements ClientPortalRepository {
  final SupabaseClient _client;

  SupabaseClientPortalRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

  @override
  Future<ClientModel?> fetchClientProfile() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      // 1. Get client_id from profiles
      final profile = await _client
          .from('profiles')
          .select('client_id, full_name')
          .eq('id', user.id)
          .maybeSingle();

      final clientId = profile?['client_id']?.toString();
      if (clientId == null) return null;

      // 2. Fetch client record from clients table (RLS enforced)
      final clientData = await _client
          .from('clients')
          .select('id, full_name, phone, email, address, city, state, pincode, is_active, created_at, updated_at')
          .eq('id', clientId)
          .maybeSingle();

      if (clientData != null) {
        return ClientModel.fromJson(clientData);
      }
      return null;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<VehicleModel>> fetchClientVehicles() async {
    try {
      // RLS on vehicles table automatically enforces client_id = current_client_id()
      final data = await _client
          .from('vehicles')
          .select('id, client_id, make, model, manufacturing_year, registration_number, chassis_number, created_at, updated_at')
          .order('created_at', ascending: false);

      return (data as List)
          .map((item) => VehicleModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<VehicleModel> getVehicleById(String vehicleId) async {
    try {
      // RLS enforces that this vehicle belongs to the authenticated client
      final data = await _client
          .from('vehicles')
          .select('id, client_id, make, model, manufacturing_year, registration_number, chassis_number, created_at, updated_at')
          .eq('id', vehicleId)
          .maybeSingle();

      if (data == null) {
        throw Exception('Vehicle not found or you do not have permission to view it.');
      }

      return VehicleModel.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<ServiceRequestModel>> fetchClientServiceRequests() async {
    try {
      // Joins vehicles and service_jobs to support dynamic status and Completed filter
      // Excludes admin_notes and audit logs at the query projection level
      final data = await _client
          .from('service_requests')
          .select(
            'id, request_number, client_id, vehicle_id, source, status, original_submission, created_at, updated_at, '
            'vehicles(id, client_id, make, model, manufacturing_year, registration_number, chassis_number), '
            'service_jobs(id, job_number, status, started_at, completed_at)',
          )
          .order('created_at', ascending: false);

      return (data as List)
          .map((item) => ServiceRequestModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<ServiceRequestModel>> fetchServiceRequestsForVehicle(String vehicleId) async {
    try {
      final data = await _client
          .from('service_requests')
          .select(
            'id, request_number, client_id, vehicle_id, source, status, original_submission, created_at, updated_at, '
            'vehicles(id, client_id, make, model, manufacturing_year, registration_number, chassis_number), '
            'service_jobs(id, job_number, status, started_at, completed_at)',
          )
          .eq('vehicle_id', vehicleId)
          .order('created_at', ascending: false);

      return (data as List)
          .map((item) => ServiceRequestModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ServiceRequestModel> getServiceRequestById(String requestId) async {
    try {
      final data = await _client
          .from('service_requests')
          .select(
            'id, request_number, client_id, vehicle_id, source, status, original_submission, created_at, updated_at, '
            'vehicles(id, client_id, make, model, manufacturing_year, registration_number, chassis_number), '
            'service_jobs(id, job_number, status, started_at, completed_at)',
          )
          .eq('id', requestId)
          .maybeSingle();

      if (data == null) {
        throw Exception('Service request not found or you do not have permission to view it.');
      }

      return ServiceRequestModel.fromJson(data);
    } catch (e) {
      rethrow;
    }
  }

  static const String _quotationSelectQuery = '''
    id,
    quotation_number,
    service_request_id,
    created_by,
    created_at,
    updated_at,
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
        pincode,
        is_active
      ),
      vehicles (
        id,
        client_id,
        make,
        model,
        manufacturing_year,
        chassis_number,
        registration_number
      )
    ),
    quotation_revisions (
      id,
      quotation_id,
      revision_number,
      status,
      subtotal,
      discount,
      tax,
      total,
      notes,
      terms,
      created_by,
      created_at,
      updated_at,
      sent_at,
      accepted_at,
      accepted_by_profile_id,
      acceptance_consent_text,
      rejected_at,
      rejection_reason,
      quotation_items (
        id,
        quotation_revision_id,
        catalogue_product_id,
        name,
        description,
        quantity,
        approximate_value,
        final_value,
        line_total,
        created_at,
        updated_at
      ),
      quotation_change_requests (
        id,
        quotation_revision_id,
        client_id,
        profile_id,
        message,
        status,
        admin_response,
        created_at,
        responded_at
      )
    )
  ''';

  /// Ensures clients never see DRAFT revisions, and all visible revisions
  /// are strictly sorted with the latest revision (highest revision_number) first.
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
    try {
      final response = await _client
          .from('quotations')
          .select(_quotationSelectQuery)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      final list = data
          .map((json) => QuotationModel.fromJson(json as Map<String, dynamic>))
          .map(_sanitizeClientQuotation)
          .where((quote) => quote.revisions.isNotEmpty)
          .toList();

      return list;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<QuotationModel> getQuotationById(String id) async {
    try {
      final response = await _client
          .from('quotations')
          .select(_quotationSelectQuery)
          .eq('id', id)
          .single();

      final model = QuotationModel.fromJson(response);
      return _sanitizeClientQuotation(model);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<QuotationModel?> getQuotationByServiceRequestId(String serviceRequestId) async {
    try {
      final response = await _client
          .from('quotations')
          .select(_quotationSelectQuery)
          .eq('service_request_id', serviceRequestId)
          .maybeSingle();

      if (response == null) return null;
      final model = QuotationModel.fromJson(response);
      final sanitized = _sanitizeClientQuotation(model);
      return sanitized.revisions.isNotEmpty ? sanitized : null;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> markQuotationViewed(String revisionId) async {
    try {
      await _client.rpc(
        'client_mark_quotation_viewed',
        params: {'p_revision_id': revisionId},
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> requestQuotationChange({
    required String revisionId,
    required String message,
  }) async {
    try {
      await _client.rpc(
        'client_request_quotation_change',
        params: {
          'p_revision_id': revisionId,
          'p_message': message.trim(),
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> acceptQuotationRevision({
    required String revisionId,
    required String consentText,
  }) async {
    try {
      await _client.rpc(
        'client_accept_quotation_revision',
        params: {
          'p_revision_id': revisionId,
          'p_consent_given': true,
          'p_consent_text': consentText.trim(),
        },
      );
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<void> rejectQuotationRevision({
    required String revisionId,
    required String reason,
  }) async {
    try {
      await _client.rpc(
        'client_reject_quotation_revision',
        params: {
          'p_revision_id': revisionId,
          'p_reason': reason.trim(),
        },
      );
    } catch (e) {
      rethrow;
    }
  }
}

