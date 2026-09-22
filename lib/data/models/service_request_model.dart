import 'client_model.dart';
import 'vehicle_model.dart';

class ServiceRequestModel {
  final String id;
  final String requestNumber;
  final String? clientId;
  final String? vehicleId;
  final String source; // 'WEBSITE' or 'PHONE'
  final String status;
  final Map<String, dynamic>? originalSubmission;
  final String? adminNotes;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Joined relational data
  final ClientModel? client;
  final VehicleModel? vehicle;

  const ServiceRequestModel({
    required this.id,
    required this.requestNumber,
    this.clientId,
    this.vehicleId,
    required this.source,
    required this.status,
    this.originalSubmission,
    this.adminNotes,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.client,
    this.vehicle,
  });

  factory ServiceRequestModel.fromJson(Map<String, dynamic> json) {
    return ServiceRequestModel(
      id: json['id'] as String,
      requestNumber: json['request_number'] as String? ?? '',
      clientId: json['client_id'] as String?,
      vehicleId: json['vehicle_id'] as String?,
      source: json['source'] as String? ?? 'PHONE',
      status: json['status'] as String? ?? 'NEW',
      originalSubmission: json['original_submission'] is Map<String, dynamic>
          ? json['original_submission'] as Map<String, dynamic>
          : null,
      adminNotes: json['admin_notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      client: json['clients'] != null && json['clients'] is Map<String, dynamic>
          ? ClientModel.fromJson(json['clients'] as Map<String, dynamic>)
          : null,
      vehicle: json['vehicles'] != null && json['vehicles'] is Map<String, dynamic>
          ? VehicleModel.fromJson(json['vehicles'] as Map<String, dynamic>)
          : null,
    );
  }

  // Display getters
  String get customerName {
    if (client != null && client!.fullName.isNotEmpty) {
      return client!.fullName;
    }
    if (originalSubmission != null && originalSubmission!['client_name'] != null) {
      return originalSubmission!['client_name'].toString();
    }
    return 'Customer';
  }

  String get customerPhone {
    if (client != null && client!.phone.isNotEmpty) {
      return client!.phone;
    }
    if (originalSubmission != null && originalSubmission!['client_phone'] != null) {
      return originalSubmission!['client_phone'].toString();
    }
    return '';
  }

  String get customerEmail {
    if (client != null && client!.email != null) {
      return client!.email!;
    }
    if (originalSubmission != null && originalSubmission!['client_email'] != null) {
      return originalSubmission!['client_email'].toString();
    }
    return '';
  }

  String get vehicleTitle {
    if (vehicle != null) {
      return vehicle!.displayName;
    }
    if (originalSubmission != null) {
      final make = originalSubmission!['vehicle_make']?.toString() ?? '';
      final model = originalSubmission!['vehicle_model']?.toString() ?? '';
      final year = originalSubmission!['manufacturing_year']?.toString();
      if (make.isNotEmpty || model.isNotEmpty) {
        return '$make $model${year != null ? " · $year" : ""}'.trim();
      }
    }
    return 'Vehicle';
  }

  String get vehiclePlate {
    if (vehicle?.registrationNumber != null &&
        vehicle!.registrationNumber!.isNotEmpty) {
      return vehicle!.registrationNumber!;
    }
    if (originalSubmission != null &&
        originalSubmission!['registration_number'] != null) {
      return originalSubmission!['registration_number'].toString();
    }
    return '';
  }

  String get serviceDescription {
    if (adminNotes != null && adminNotes!.isNotEmpty) {
      return adminNotes!;
    }
    if (originalSubmission != null) {
      final desc = originalSubmission!['service_description'] ??
          originalSubmission!['description'];
      if (desc != null && desc.toString().isNotEmpty) {
        return desc.toString();
      }
    }
    return 'Periodic maintenance and diagnostic check.';
  }

  String? get effectiveClientId => clientId ?? client?.id;
  String? get effectiveVehicleId => vehicleId ?? vehicle?.id;
  bool get isLinked => effectiveClientId != null && effectiveVehicleId != null;

  ServiceRequestModel copyWith({
    String? id,
    String? requestNumber,
    String? clientId,
    String? vehicleId,
    String? source,
    String? status,
    Map<String, dynamic>? originalSubmission,
    String? adminNotes,
    String? createdBy,
    DateTime? createdAt,
    DateTime? updatedAt,
    ClientModel? client,
    VehicleModel? vehicle,
  }) {
    return ServiceRequestModel(
      id: id ?? this.id,
      requestNumber: requestNumber ?? this.requestNumber,
      clientId: clientId ?? this.clientId,
      vehicleId: vehicleId ?? this.vehicleId,
      source: source ?? this.source,
      status: status ?? this.status,
      originalSubmission: originalSubmission ?? this.originalSubmission,
      adminNotes: adminNotes ?? this.adminNotes,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      client: client ?? this.client,
      vehicle: vehicle ?? this.vehicle,
    );
  }
}
