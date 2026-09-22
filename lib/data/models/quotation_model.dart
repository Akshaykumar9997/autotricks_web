
import 'service_request_model.dart';

/// Represents a quotation line item stored as a historical snapshot.
class QuotationItemModel {
  final String id;
  final String quotationRevisionId;
  final String? catalogueProductId;
  final String name;
  final String? description;
  final double quantity;
  final double? approximateValue;
  final double finalValue;
  final double lineTotal;
  final DateTime createdAt;
  final DateTime updatedAt;

  const QuotationItemModel({
    required this.id,
    required this.quotationRevisionId,
    this.catalogueProductId,
    required this.name,
    this.description,
    required this.quantity,
    this.approximateValue,
    required this.finalValue,
    required this.lineTotal,
    required this.createdAt,
    required this.updatedAt,
  });

  factory QuotationItemModel.fromJson(Map<String, dynamic> json) {
    return QuotationItemModel(
      id: json['id'] as String,
      quotationRevisionId: json['quotation_revision_id'] as String,
      catalogueProductId: json['catalogue_product_id'] as String?,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      approximateValue: (json['approximate_value'] as num?)?.toDouble(),
      finalValue: (json['final_value'] as num?)?.toDouble() ?? 0.0,
      lineTotal: (json['line_total'] as num?)?.toDouble() ?? 0.0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quotation_revision_id': quotationRevisionId,
      'catalogue_product_id': catalogueProductId,
      'name': name,
      'description': description,
      'quantity': quantity,
      'approximate_value': approximateValue,
      'final_value': finalValue,
      'line_total': lineTotal,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isFromCatalogue => catalogueProductId != null;
}

/// Represents a change request on a quotation revision.
class QuotationChangeRequestModel {
  final String id;
  final String quotationRevisionId;
  final String clientId;
  final String profileId;
  final String message;
  final String status;
  final String? adminResponse;
  final DateTime createdAt;
  final DateTime? respondedAt;

  const QuotationChangeRequestModel({
    required this.id,
    required this.quotationRevisionId,
    required this.clientId,
    required this.profileId,
    required this.message,
    required this.status,
    this.adminResponse,
    required this.createdAt,
    this.respondedAt,
  });

  factory QuotationChangeRequestModel.fromJson(Map<String, dynamic> json) {
    return QuotationChangeRequestModel(
      id: json['id'] as String,
      quotationRevisionId: json['quotation_revision_id'] as String,
      clientId: json['client_id'] as String,
      profileId: json['profile_id'] as String,
      message: json['message'] as String? ?? '',
      status: json['status'] as String? ?? 'PENDING',
      adminResponse: json['admin_response'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      respondedAt: json['responded_at'] != null
          ? DateTime.tryParse(json['responded_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quotation_revision_id': quotationRevisionId,
      'client_id': clientId,
      'profile_id': profileId,
      'message': message,
      'status': status,
      'admin_response': adminResponse,
      'created_at': createdAt.toIso8601String(),
      'responded_at': respondedAt?.toIso8601String(),
    };
  }
}

/// Represents an exact quotation revision.
class QuotationRevisionModel {
  final String id;
  final String quotationId;
  final int revisionNumber;
  final String status;
  final double subtotal;
  final double discount;
  final double tax;
  final double total;
  final String? notes;
  final String? terms;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? viewedAt;
  final DateTime? acceptedAt;
  final String? acceptedByProfileId;
  final String? acceptanceConsentText;
  final DateTime? rejectedAt;
  final String? rejectionReason;

  final List<QuotationItemModel> items;
  final List<QuotationChangeRequestModel> changeRequests;

  const QuotationRevisionModel({
    required this.id,
    required this.quotationId,
    required this.revisionNumber,
    required this.status,
    required this.subtotal,
    this.discount = 0.0,
    this.tax = 0.0,
    required this.total,
    this.notes,
    this.terms,
    this.createdBy,
    required this.createdAt,
    this.sentAt,
    this.viewedAt,
    this.acceptedAt,
    this.acceptedByProfileId,
    this.acceptanceConsentText,
    this.rejectedAt,
    this.rejectionReason,
    this.items = const [],
    this.changeRequests = const [],
  });

  factory QuotationRevisionModel.fromJson(Map<String, dynamic> json) {
    List<QuotationItemModel> parsedItems = [];
    if (json['quotation_items'] is List) {
      parsedItems = (json['quotation_items'] as List)
          .map((item) => QuotationItemModel.fromJson(item as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    List<QuotationChangeRequestModel> parsedChangeRequests = [];
    if (json['quotation_change_requests'] is List) {
      parsedChangeRequests = (json['quotation_change_requests'] as List)
          .map((cr) => QuotationChangeRequestModel.fromJson(cr as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    return QuotationRevisionModel(
      id: json['id'] as String,
      quotationId: json['quotation_id'] as String,
      revisionNumber: (json['revision_number'] as num?)?.toInt() ?? 1,
      status: json['status'] as String? ?? 'DRAFT',
      subtotal: (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] as num?)?.toDouble() ?? 0.0,
      notes: json['notes'] as String?,
      terms: json['terms'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      sentAt: json['sent_at'] != null
          ? DateTime.tryParse(json['sent_at'].toString())
          : null,
      viewedAt: json['viewed_at'] != null
          ? DateTime.tryParse(json['viewed_at'].toString())
          : null,
      acceptedAt: json['accepted_at'] != null
          ? DateTime.tryParse(json['accepted_at'].toString())
          : null,
      acceptedByProfileId: json['accepted_by_profile_id'] as String?,
      acceptanceConsentText: json['acceptance_consent_text'] as String?,
      rejectedAt: json['rejected_at'] != null
          ? DateTime.tryParse(json['rejected_at'].toString())
          : null,
      rejectionReason: json['rejection_reason'] as String?,
      items: parsedItems,
      changeRequests: parsedChangeRequests,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quotation_id': quotationId,
      'revision_number': revisionNumber,
      'status': status,
      'subtotal': subtotal,
      'discount': discount,
      'tax': tax,
      'total': total,
      'notes': notes,
      'terms': terms,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'sent_at': sentAt?.toIso8601String(),
      'viewed_at': viewedAt?.toIso8601String(),
      'accepted_at': acceptedAt?.toIso8601String(),
      'accepted_by_profile_id': acceptedByProfileId,
      'acceptance_consent_text': acceptanceConsentText,
      'rejected_at': rejectedAt?.toIso8601String(),
      'rejection_reason': rejectionReason,
      'quotation_items': items.map((i) => i.toJson()).toList(),
      'quotation_change_requests': changeRequests.map((cr) => cr.toJson()).toList(),
    };
  }

  bool get isDraft => status.toUpperCase() == 'DRAFT';
  bool get isSent => status.toUpperCase() == 'SENT';
  bool get isViewed => status.toUpperCase() == 'VIEWED';
  bool get isChangeRequested => status.toUpperCase() == 'CHANGE_REQUESTED';
  bool get isAccepted => status.toUpperCase() == 'ACCEPTED';
  bool get isRejected => status.toUpperCase() == 'REJECTED';
  bool get isExpired => status.toUpperCase() == 'EXPIRED';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';
  bool get isSuperseded => status.toUpperCase() == 'SUPERSEDED';
}

/// Represents the top-level Quotation document.
class QuotationModel {
  final String id;
  final String quotationNumber;
  final String serviceRequestId;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined relations
  final ServiceRequestModel? serviceRequest;
  final List<QuotationRevisionModel> revisions;

  const QuotationModel({
    required this.id,
    required this.quotationNumber,
    required this.serviceRequestId,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.serviceRequest,
    this.revisions = const [],
  });

  factory QuotationModel.fromJson(Map<String, dynamic> json) {
    List<QuotationRevisionModel> parsedRevisions = [];
    if (json['quotation_revisions'] is List) {
      parsedRevisions = (json['quotation_revisions'] as List)
          .map((r) => QuotationRevisionModel.fromJson(r as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.revisionNumber.compareTo(a.revisionNumber)); // latest first
    }

    ServiceRequestModel? parsedSr;
    if (json['service_requests'] != null && json['service_requests'] is Map<String, dynamic>) {
      parsedSr = ServiceRequestModel.fromJson(json['service_requests'] as Map<String, dynamic>);
    }

    return QuotationModel(
      id: json['id'] as String,
      quotationNumber: json['quotation_number'] as String? ?? '',
      serviceRequestId: json['service_request_id'] as String,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      serviceRequest: parsedSr,
      revisions: parsedRevisions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'quotation_number': quotationNumber,
      'service_request_id': serviceRequestId,
      'created_by': createdBy,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (serviceRequest != null)
        'service_requests': {
          'id': serviceRequest!.id,
          'request_number': serviceRequest!.requestNumber,
          'source': serviceRequest!.source,
          'status': serviceRequest!.status,
          'clients': serviceRequest!.client?.toJson(),
          'vehicles': serviceRequest!.vehicle?.toJson(),
        },
      'quotation_revisions': revisions.map((r) => r.toJson()).toList(),
    };
  }

  /// Returns the latest revision (highest revision_number).
  QuotationRevisionModel? get latestRevision {
    if (revisions.isEmpty) return null;
    return revisions.first;
  }

  /// Returns the current active revision (or latest draft/sent).
  QuotationRevisionModel? get currentRevision => latestRevision;

  String get currentStatus => currentRevision?.status ?? 'DRAFT';
  int get currentRevisionNumber => currentRevision?.revisionNumber ?? 1;
  double get totalAmount => currentRevision?.total ?? 0.0;

  String get customerName {
    if (serviceRequest?.client != null && serviceRequest!.client!.fullName.isNotEmpty) {
      return serviceRequest!.client!.fullName;
    }
    return serviceRequest?.customerName ?? 'Customer';
  }

  String get customerPhone {
    if (serviceRequest?.client != null && serviceRequest!.client!.phone.isNotEmpty) {
      return serviceRequest!.client!.phone;
    }
    return serviceRequest?.customerPhone ?? '';
  }

  String get vehicleTitle => serviceRequest?.vehicleTitle ?? 'Vehicle';
  String get vehiclePlate => serviceRequest?.vehiclePlate ?? '';
  String get serviceSummary => serviceRequest?.serviceDescription ?? '';
  String get requestNumber => serviceRequest?.requestNumber ?? '';
}

/// Helper model for constructing draft line items in A14 and editing in A15.
class DraftQuotationItemInput {
  final String? id;
  final String? catalogueProductId;
  final String name;
  final String? description;
  final double quantity;
  final double? approximateValue;
  final double finalValue;

  const DraftQuotationItemInput({
    this.id,
    this.catalogueProductId,
    required this.name,
    this.description,
    required this.quantity,
    this.approximateValue,
    required this.finalValue,
  });

  double get lineTotal => quantity * finalValue;

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'catalogue_product_id': catalogueProductId,
      'name': name,
      'description': description,
      'quantity': quantity,
      'approximate_value': approximateValue,
      'final_value': finalValue,
      'line_total': lineTotal,
    };
  }
}
