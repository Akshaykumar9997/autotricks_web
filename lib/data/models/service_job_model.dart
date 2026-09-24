import 'client_model.dart';
import 'quotation_model.dart';
import 'service_request_model.dart';
import 'vehicle_model.dart';

/// Full representation of a Service Job in the AutoTricks system.
class ServiceJobModel {
  final String id;
  final String jobNumber;
  final String serviceRequestId;
  final String quotationRevisionId;
  final String vehicleId;
  final String status;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final DateTime? scheduledAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Relational joins
  final VehicleModel? vehicle;
  final ClientModel? client;
  final ServiceRequestModel? serviceRequest;
  final QuotationModel? quotation;
  final List<ServiceWorkItemModel> workItems;
  final List<ServiceJobStatusHistoryModel> statusHistory;

  const ServiceJobModel({
    required this.id,
    required this.jobNumber,
    required this.serviceRequestId,
    required this.quotationRevisionId,
    required this.vehicleId,
    required this.status,
    this.startedAt,
    this.completedAt,
    this.scheduledAt,
    required this.createdAt,
    required this.updatedAt,
    this.vehicle,
    this.client,
    this.serviceRequest,
    this.quotation,
    this.workItems = const [],
    this.statusHistory = const [],
  });

  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';
  bool get isActive => !isCompleted && !isCancelled;

  String get vehicleTitle {
    if (vehicle != null) {
      final make = vehicle!.make;
      final model = vehicle!.model;
      final year = vehicle!.manufacturingYear;
      return '$make $model${year != null ? " · $year" : ""}';
    }
    return 'Vehicle';
  }

  String get vehiclePlate => vehicle?.registrationNumber ?? 'Unregistered';

  String get customerName => client?.fullName ?? 'Customer';

  int get completedItemsCount =>
      workItems.where((w) => w.status.toUpperCase() == 'COMPLETED').length;

  List<ServiceWorkItemModel> get quotationWorkItems =>
      workItems.where((w) => w.source == 'QUOTATION').toList();

  List<ServiceWorkItemModel> get additionalWorkItems =>
      workItems.where((w) => w.source == 'ADDITIONAL').toList();

  List<ServiceWorkItemModel> get pendingAdditionalWorkItems =>
      workItems.where((w) => w.source == 'ADDITIONAL' && w.approvalStatus == 'PENDING').toList();

  bool get hasPendingAdditionalWork => pendingAdditionalWorkItems.isNotEmpty;

  factory ServiceJobModel.fromJson(Map<String, dynamic> json) {
    // 1. Vehicle extraction
    VehicleModel? vehicle;
    if (json['vehicles'] is Map<String, dynamic>) {
      vehicle = VehicleModel.fromJson(json['vehicles'] as Map<String, dynamic>);
    }

    // 2. Service Request & Client extraction
    ServiceRequestModel? serviceRequest;
    ClientModel? client;
    if (json['service_requests'] is Map<String, dynamic>) {
      final srMap = json['service_requests'] as Map<String, dynamic>;
      serviceRequest = ServiceRequestModel.fromJson(srMap);
      if (srMap['clients'] is Map<String, dynamic>) {
        client = ClientModel.fromJson(srMap['clients'] as Map<String, dynamic>);
      }
    } else if (json['clients'] is Map<String, dynamic>) {
      client = ClientModel.fromJson(json['clients'] as Map<String, dynamic>);
    }

    // 3. Quotation extraction (if available via revision join)
    QuotationModel? quotation;
    if (json['quotation_revisions'] is Map<String, dynamic>) {
      final revMap = json['quotation_revisions'] as Map<String, dynamic>;
      if (revMap['quotations'] is Map<String, dynamic>) {
        quotation = QuotationModel.fromJson(revMap['quotations'] as Map<String, dynamic>);
      }
    }

    // 4. Work items extraction
    List<ServiceWorkItemModel> items = [];
    if (json['service_work_items'] is List) {
      items = (json['service_work_items'] as List)
          .map((item) => ServiceWorkItemModel.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    // 5. Status history extraction
    List<ServiceJobStatusHistoryModel> history = [];
    if (json['service_job_status_history'] is List) {
      history = (json['service_job_status_history'] as List)
          .map((h) => ServiceJobStatusHistoryModel.fromJson(h as Map<String, dynamic>))
          .toList();
    }

    return ServiceJobModel(
      id: json['id'] as String,
      jobNumber: json['job_number'] as String? ?? 'JOB-0000',
      serviceRequestId: json['service_request_id'] as String,
      quotationRevisionId: json['quotation_revision_id'] as String,
      vehicleId: json['vehicle_id'] as String,
      status: json['status'] as String? ?? 'SCHEDULED',
      startedAt: json['started_at'] != null ? DateTime.tryParse(json['started_at'].toString()) : null,
      completedAt: json['completed_at'] != null ? DateTime.tryParse(json['completed_at'].toString()) : null,
      scheduledAt: json['scheduled_at'] != null ? DateTime.tryParse(json['scheduled_at'].toString()) : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
      vehicle: vehicle,
      client: client,
      serviceRequest: serviceRequest,
      quotation: quotation,
      workItems: items,
      statusHistory: history,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'job_number': jobNumber,
      'service_request_id': serviceRequestId,
      'quotation_revision_id': quotationRevisionId,
      'vehicle_id': vehicleId,
      'status': status,
      'started_at': startedAt?.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
      'scheduled_at': scheduledAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ServiceJobModel copyWith({
    String? status,
    DateTime? startedAt,
    DateTime? completedAt,
    DateTime? scheduledAt,
    List<ServiceWorkItemModel>? workItems,
    List<ServiceJobStatusHistoryModel>? statusHistory,
  }) {
    return ServiceJobModel(
      id: id,
      jobNumber: jobNumber,
      serviceRequestId: serviceRequestId,
      quotationRevisionId: quotationRevisionId,
      vehicleId: vehicleId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      vehicle: vehicle,
      client: client,
      serviceRequest: serviceRequest,
      quotation: quotation,
      workItems: workItems ?? this.workItems,
      statusHistory: statusHistory ?? this.statusHistory,
    );
  }
}

/// Represents a status transition record in the service job's lifecycle history.
class ServiceJobStatusHistoryModel {
  final String id;
  final String serviceJobId;
  final String? fromStatus;
  final String toStatus;
  final String? changedByProfileId;
  final String? changedByName;
  final String? note;
  final DateTime createdAt;

  const ServiceJobStatusHistoryModel({
    required this.id,
    required this.serviceJobId,
    this.fromStatus,
    required this.toStatus,
    this.changedByProfileId,
    this.changedByName,
    this.note,
    required this.createdAt,
  });

  factory ServiceJobStatusHistoryModel.fromJson(Map<String, dynamic> json) {
    String? profileName;
    if (json['profiles'] is Map<String, dynamic>) {
      profileName = (json['profiles'] as Map<String, dynamic>)['full_name'] as String?;
    }

    return ServiceJobStatusHistoryModel(
      id: json['id'] as String,
      serviceJobId: json['service_job_id'] as String,
      fromStatus: json['from_status'] as String?,
      toStatus: json['to_status'] as String? ?? 'SCHEDULED',
      changedByProfileId: json['changed_by_profile_id'] as String?,
      changedByName: profileName,
      note: json['note'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service_job_id': serviceJobId,
      'from_status': fromStatus,
      'to_status': toStatus,
      'changed_by_profile_id': changedByProfileId,
      'note': note,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Represents an individual work item within a Service Job.
class ServiceWorkItemModel {
  final String id;
  final String serviceJobId;
  final String? quotationItemId;
  final String name;
  final String? description;
  final double quantity;
  final String source; // 'QUOTATION' | 'ADDITIONAL'
  final String status; // 'PENDING' | 'IN_PROGRESS' | 'COMPLETED' | 'ON_HOLD' | 'CANCELLED'
  final String approvalStatus; // 'NOT_REQUIRED' | 'PENDING' | 'APPROVED' | 'REJECTED'
  final double? approximateValue;
  final double? finalValue;
  final double? approvedValue;
  final String? decisionByProfileId;
  final DateTime? decisionAt;
  final String? approvalNote;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ServiceWorkItemModel({
    required this.id,
    required this.serviceJobId,
    this.quotationItemId,
    required this.name,
    this.description,
    this.quantity = 1.0,
    required this.source,
    this.status = 'PENDING',
    this.approvalStatus = 'NOT_REQUIRED',
    this.approximateValue,
    this.finalValue,
    this.approvedValue,
    this.decisionByProfileId,
    this.decisionAt,
    this.approvalNote,
    required this.createdAt,
    required this.updatedAt,
  });

  ServiceWorkItemModel copyWith({
    String? name,
    String? description,
    double? quantity,
    String? source,
    String? status,
    String? approvalStatus,
    double? approximateValue,
    double? finalValue,
    double? approvedValue,
    String? decisionByProfileId,
    DateTime? decisionAt,
    String? approvalNote,
    DateTime? updatedAt,
  }) {
    return ServiceWorkItemModel(
      id: id,
      serviceJobId: serviceJobId,
      quotationItemId: quotationItemId,
      name: name ?? this.name,
      description: description ?? this.description,
      quantity: quantity ?? this.quantity,
      source: source ?? this.source,
      status: status ?? this.status,
      approvalStatus: approvalStatus ?? this.approvalStatus,
      approximateValue: approximateValue ?? this.approximateValue,
      finalValue: finalValue ?? this.finalValue,
      approvedValue: approvedValue ?? this.approvedValue,
      decisionByProfileId: decisionByProfileId ?? this.decisionByProfileId,
      decisionAt: decisionAt ?? this.decisionAt,
      approvalNote: approvalNote ?? this.approvalNote,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }


  bool get isCompleted => status.toUpperCase() == 'COMPLETED';
  bool get isCancelled => status.toUpperCase() == 'CANCELLED';
  bool get isInProgress => status.toUpperCase() == 'IN_PROGRESS';
  bool get isPending => status.toUpperCase() == 'PENDING';

  bool get isQuotation => source.toUpperCase() == 'QUOTATION';
  bool get isAdditional => source.toUpperCase() == 'ADDITIONAL';
  bool get isApprovalPending => approvalStatus.toUpperCase() == 'PENDING';
  bool get isApproved => approvalStatus.toUpperCase() == 'APPROVED';
  bool get isRejected => approvalStatus.toUpperCase() == 'REJECTED';
  bool get canExecute => isQuotation || isApproved;

  factory ServiceWorkItemModel.fromJson(Map<String, dynamic> json) {
    return ServiceWorkItemModel(
      id: json['id'] as String,
      serviceJobId: json['service_job_id'] as String,
      quotationItemId: json['quotation_item_id'] as String?,
      name: json['name'] as String? ?? 'Work Item',
      description: json['description'] as String?,
      quantity: (json['quantity'] as num?)?.toDouble() ?? 1.0,
      source: json['source'] as String? ?? 'QUOTATION',
      status: json['status'] as String? ?? 'PENDING',
      approvalStatus: json['approval_status'] as String? ?? 'NOT_REQUIRED',
      approximateValue: (json['approximate_value'] as num?)?.toDouble(),
      finalValue: (json['final_value'] as num?)?.toDouble(),
      approvedValue: (json['approved_value'] as num?)?.toDouble(),
      decisionByProfileId: json['decision_by_profile_id'] as String?,
      decisionAt: json['decision_at'] != null ? DateTime.tryParse(json['decision_at'].toString()) : null,
      approvalNote: json['approval_note'] as String?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'service_job_id': serviceJobId,
      'quotation_item_id': quotationItemId,
      'name': name,
      'description': description,
      'quantity': quantity,
      'source': source,
      'status': status,
      'approval_status': approvalStatus,
      'approximate_value': approximateValue,
      'final_value': finalValue,
      'approved_value': approvedValue,
      'decision_by_profile_id': decisionByProfileId,
      'decision_at': decisionAt?.toIso8601String(),
      'approval_note': approvalNote,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
