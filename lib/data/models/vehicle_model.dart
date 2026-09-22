import 'client_model.dart';

class VehicleModel {
  final String id;
  final String clientId;
  final String make;
  final String model;
  final int? manufacturingYear;
  final String? registrationNumber;
  final String? chassisNumber;
  final ClientModel? client;

  const VehicleModel({
    required this.id,
    required this.clientId,
    required this.make,
    required this.model,
    this.manufacturingYear,
    this.registrationNumber,
    this.chassisNumber,
    this.client,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    ClientModel? clientObj;
    if (json['clients'] != null && json['clients'] is Map) {
      clientObj = ClientModel.fromJson(json['clients'] as Map<String, dynamic>);
    }

    return VehicleModel(
      id: json['id'] as String,
      clientId: json['client_id'] as String? ?? '',
      make: json['make'] as String? ?? '',
      model: json['model'] as String? ?? '',
      manufacturingYear: json['manufacturing_year'] as int?,
      registrationNumber: json['registration_number'] as String?,
      chassisNumber: json['chassis_number'] as String?,
      client: clientObj,
    );
  }

  String get displayName {
    final year = manufacturingYear != null ? ' · $manufacturingYear' : '';
    return '$make $model$year';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'make': make,
      'model': model,
      'manufacturing_year': manufacturingYear,
      'registration_number': registrationNumber,
      'chassis_number': chassisNumber,
      if (client != null) 'clients': client!.toJson(),
    };
  }

  VehicleModel copyWith({
    String? id,
    String? clientId,
    String? make,
    String? model,
    int? manufacturingYear,
    String? registrationNumber,
    String? chassisNumber,
    ClientModel? client,
  }) {
    return VehicleModel(
      id: id ?? this.id,
      clientId: clientId ?? this.clientId,
      make: make ?? this.make,
      model: model ?? this.model,
      manufacturingYear: manufacturingYear ?? this.manufacturingYear,
      registrationNumber: registrationNumber ?? this.registrationNumber,
      chassisNumber: chassisNumber ?? this.chassisNumber,
      client: client ?? this.client,
    );
  }
}
