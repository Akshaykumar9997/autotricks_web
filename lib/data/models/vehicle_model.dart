class VehicleModel {
  final String id;
  final String clientId;
  final String make;
  final String model;
  final int? manufacturingYear;
  final String? registrationNumber;
  final String? chassisNumber;

  const VehicleModel({
    required this.id,
    required this.clientId,
    required this.make,
    required this.model,
    this.manufacturingYear,
    this.registrationNumber,
    this.chassisNumber,
  });

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: json['id'] as String,
      clientId: json['client_id'] as String,
      make: json['make'] as String? ?? '',
      model: json['model'] as String? ?? '',
      manufacturingYear: json['manufacturing_year'] as int?,
      registrationNumber: json['registration_number'] as String?,
      chassisNumber: json['chassis_number'] as String?,
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
    };
  }
}
