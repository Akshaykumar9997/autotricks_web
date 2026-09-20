import 'vehicle_model.dart';

class ClientModel {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final String? notes;
  final bool isActive;
  final List<VehicleModel> vehicles;

  const ClientModel({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.notes,
    this.isActive = true,
    this.vehicles = const [],
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    var vehiclesList = <VehicleModel>[];
    if (json['vehicles'] != null && json['vehicles'] is List) {
      vehiclesList = (json['vehicles'] as List)
          .map((v) => VehicleModel.fromJson(v as Map<String, dynamic>))
          .toList();
    }

    return ClientModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'Unnamed Client',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
      notes: json['notes'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      vehicles: vehiclesList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'email': email,
      'address': address,
      'city': city,
      'state': state,
      'pincode': pincode,
      'notes': notes,
      'is_active': isActive,
      'vehicles': vehicles.map((v) => v.toJson()).toList(),
    };
  }

  ClientModel copyWith({
    String? id,
    String? fullName,
    String? phone,
    String? email,
    String? address,
    String? city,
    String? state,
    String? pincode,
    String? notes,
    bool? isActive,
    List<VehicleModel>? vehicles,
  }) {
    return ClientModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      address: address ?? this.address,
      city: city ?? this.city,
      state: state ?? this.state,
      pincode: pincode ?? this.pincode,
      notes: notes ?? this.notes,
      isActive: isActive ?? this.isActive,
      vehicles: vehicles ?? this.vehicles,
    );
  }
}
