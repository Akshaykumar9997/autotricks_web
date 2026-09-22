import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/quotation_model.dart';

abstract class QuotationsRepository {
  /// Fetches quotations with optional status filter and search query.
  Future<List<QuotationModel>> fetchQuotations({
    String? statusFilter,
    String? searchQuery,
  });

  /// Fetches a single quotation by its primary database UUID.
  Future<QuotationModel> getQuotationById(String id);

  /// Fetches a quotation linked to a specific service request UUID.
  Future<QuotationModel?> getQuotationByServiceRequestId(String serviceRequestId);

  /// Creates a new draft quotation using the finalized Supabase RPC and tables.
  Future<QuotationModel> createDraftQuotation({
    required String serviceRequestId,
    required List<DraftQuotationItemInput> items,
    double discount = 0,
    double tax = 0,
    String? notes,
    String? terms,
  });

  /// Fetches items snapshot for a specific revision.
  Future<List<QuotationItemModel>> fetchRevisionItems(String revisionId);

  /// Creates a new revision from the highest previous revision of a quotation.
  Future<Map<String, dynamic>> createQuotationRevision(String quotationId);

  /// Sends a DRAFT revision to the client and advances service request to QUOTATION_SENT.
  Future<Map<String, dynamic>> sendQuotationRevision(String revisionId);

  /// Updates an existing DRAFT revision's items, discount, tax, notes, and terms.
  Future<void> updateDraftRevision({
    required String revisionId,
    required List<DraftQuotationItemInput> items,
    double discount = 0,
    double tax = 0,
    String? notes,
    String? terms,
  });

  /// Responds to a client change request via the approved backend workflow.
  Future<Map<String, dynamic>> respondChangeRequest({
    required String changeRequestId,
    required String status,
    String? response,
  });

  /// Closes a quotation revision as CANCELLED or EXPIRED (backend completeness).
  Future<Map<String, dynamic>> closeQuotationRevision({
    required String revisionId,
    required String status,
  });
}

class SupabaseQuotationsRepository implements QuotationsRepository {
  final SupabaseClient _client;

  SupabaseQuotationsRepository([SupabaseClient? client])
      : _client = client ?? Supabase.instance.client;

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

  @override
  Future<List<QuotationModel>> fetchQuotations({
    String? statusFilter,
    String? searchQuery,
  }) async {
    try {
      final response = await _client
          .from('quotations')
          .select(_quotationSelectQuery)
          .order('created_at', ascending: false);

      final List<dynamic> data = response as List<dynamic>;
      var list = data
          .map((json) => QuotationModel.fromJson(json as Map<String, dynamic>))
          .toList();

      // 1. Status Filtering based on current active revision status
      if (statusFilter != null &&
          statusFilter.isNotEmpty &&
          statusFilter.toUpperCase() != 'ALL') {
        final targetStatus = _normalizeStatus(statusFilter);
        list = list.where((q) {
          final qStatus = q.currentStatus.toUpperCase();
          return qStatus == targetStatus;
        }).toList();
      }

      // 2. Search Query Filtering
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.trim().toLowerCase();
        list = list.where((quote) {
          final qNum = quote.quotationNumber.toLowerCase();
          final cust = quote.customerName.toLowerCase();
          final veh = quote.vehicleTitle.toLowerCase();
          final plate = quote.vehiclePlate.toLowerCase();
          final sSummary = quote.serviceSummary.toLowerCase();
          final reqNum = quote.requestNumber.toLowerCase();

          return qNum.contains(q) ||
              cust.contains(q) ||
              veh.contains(q) ||
              plate.contains(q) ||
              sSummary.contains(q) ||
              reqNum.contains(q);
        }).toList();
      }

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

      return QuotationModel.fromJson(response);
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
      return QuotationModel.fromJson(response);
    } catch (e) {
      rethrow;
    }
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
    try {
      // 1. Invoke the approved, hardened RPC
      final dynamic rpcResult = await _client.rpc(
        'admin_create_quotation',
        params: {
          'p_service_request_id': serviceRequestId,
          if (notes != null && notes.trim().isNotEmpty)
            'p_notes': notes.trim()
          else
            'p_notes': null,
          if (terms != null && terms.trim().isNotEmpty)
            'p_terms': terms.trim()
          else
            'p_terms': null,
        },
      );

      final Map<String, dynamic> creationInfo =
          Map<String, dynamic>.from(rpcResult as Map);
      final String quotationId = creationInfo['quotation_id'] as String;
      final String revisionId = creationInfo['revision_id'] as String;

      // 2. Insert line items if present
      if (items.isNotEmpty) {
        final List<Map<String, dynamic>> itemsPayload = items.map((item) {
          return {
            'quotation_revision_id': revisionId,
            'catalogue_product_id': item.catalogueProductId,
            'name': item.name.trim(),
            if (item.description != null && item.description!.trim().isNotEmpty)
              'description': item.description!.trim()
            else
              'description': null,
            'quantity': item.quantity,
            if (item.approximateValue != null)
              'approximate_value': item.approximateValue,
            'final_value': item.finalValue,
          };
        }).toList();

        await _client.from('quotation_items').insert(itemsPayload);
      }

      // 3. Update revision discount, tax, notes, and terms if modified
      if (discount > 0 || tax > 0 || notes != null || terms != null) {
        final updatePayload = <String, dynamic>{
          'discount': discount,
          'tax': tax,
          if (notes != null) 'notes': notes.trim(),
          if (terms != null) 'terms': terms.trim(),
        };

        await _client
            .from('quotation_revisions')
            .update(updatePayload)
            .eq('id', revisionId);
      }

      // 4. Return the fully hydrated QuotationModel
      return await getQuotationById(quotationId);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<List<QuotationItemModel>> fetchRevisionItems(String revisionId) async {
    try {
      final response = await _client
          .from('quotation_items')
          .select()
          .eq('quotation_revision_id', revisionId)
          .order('created_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data
          .map((item) => QuotationItemModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> createQuotationRevision(String quotationId) async {
    try {
      final dynamic rpcResult = await _client.rpc(
        'admin_create_quotation_revision',
        params: {
          'p_quotation_id': quotationId,
        },
      );

      return Map<String, dynamic>.from(rpcResult as Map);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> sendQuotationRevision(String revisionId) async {
    try {
      final dynamic rpcResult = await _client.rpc(
        'admin_send_quotation_revision',
        params: {
          'p_revision_id': revisionId,
        },
      );

      return Map<String, dynamic>.from(rpcResult as Map);
    } catch (e) {
      rethrow;
    }
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
    try {
      // 1. Update quotation_revisions metadata
      final updatePayload = <String, dynamic>{
        'discount': discount,
        'tax': tax,
        if (notes != null) 'notes': notes.trim().isNotEmpty ? notes.trim() : null,
        if (terms != null) 'terms': terms.trim().isNotEmpty ? terms.trim() : null,
      };

      await _client
          .from('quotation_revisions')
          .update(updatePayload)
          .eq('id', revisionId);

      // 2. Synchronize line items
      final existingRows = await _client
          .from('quotation_items')
          .select('id')
          .eq('quotation_revision_id', revisionId);

      final existingIds = (existingRows as List<dynamic>)
          .map((r) => (r as Map<String, dynamic>)['id'] as String)
          .toSet();

      final inputIds = items
          .where((item) => item.id != null)
          .map((item) => item.id!)
          .toSet();

      // 2a. Delete items removed from the draft
      final toDeleteIds = existingIds.difference(inputIds);
      if (toDeleteIds.isNotEmpty) {
        await _client
            .from('quotation_items')
            .delete()
            .eq('quotation_revision_id', revisionId)
            .filter('id', 'in', toDeleteIds.toList());
      }

      // 2b. Update existing items
      for (final item in items.where((i) => i.id != null && existingIds.contains(i.id))) {
        await _client.from('quotation_items').update({
          'catalogue_product_id': item.catalogueProductId,
          'name': item.name.trim(),
          'description': item.description?.trim().isNotEmpty == true
              ? item.description!.trim()
              : null,
          'quantity': item.quantity,
          'approximate_value': item.approximateValue,
          'final_value': item.finalValue,
        }).eq('id', item.id!);
      }

      // 2c. Insert newly added items
      final toInsertItems = items
          .where((i) => i.id == null || !existingIds.contains(i.id))
          .map((item) => {
                'quotation_revision_id': revisionId,
                'catalogue_product_id': item.catalogueProductId,
                'name': item.name.trim(),
                if (item.description != null && item.description!.trim().isNotEmpty)
                  'description': item.description!.trim()
                else
                  'description': null,
                'quantity': item.quantity,
                if (item.approximateValue != null)
                  'approximate_value': item.approximateValue,
                'final_value': item.finalValue,
              })
          .toList();

      if (toInsertItems.isNotEmpty) {
        await _client.from('quotation_items').insert(toInsertItems);
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> respondChangeRequest({
    required String changeRequestId,
    required String status,
    String? response,
  }) async {
    try {
      final dynamic rpcResult = await _client.rpc(
        'admin_respond_quotation_change_request',
        params: {
          'p_change_request_id': changeRequestId,
          'p_status': status,
          if (response != null && response.trim().isNotEmpty)
            'p_response': response.trim()
          else
            'p_response': null,
        },
      );

      return Map<String, dynamic>.from(rpcResult as Map);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> closeQuotationRevision({
    required String revisionId,
    required String status,
  }) async {
    try {
      final dynamic rpcResult = await _client.rpc(
        'admin_close_quotation_revision',
        params: {
          'p_revision_id': revisionId,
          'p_status': status,
        },
      );

      return Map<String, dynamic>.from(rpcResult as Map);
    } catch (e) {
      rethrow;
    }
  }

  String _normalizeStatus(String raw) {
    final cleaned = raw.trim().toUpperCase().replaceAll(' ', '_');
    return cleaned;
  }
}
