class ClientModel {
  final String id;
  final String fullName;
  final String phone;
  final String? email;
  final String? address;
  final String? city;
  final String? state;
  final String? pincode;
  final bool isActive;

  const ClientModel({
    required this.id,
    required this.fullName,
    required this.phone,
    this.email,
    this.address,
    this.city,
    this.state,
    this.pincode,
    this.isActive = true,
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['id'] as String,
      fullName: json['full_name'] as String? ?? 'Unnamed Client',
      phone: json['phone'] as String? ?? '',
      email: json['email'] as String?,
      address: json['address'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
      isActive: json['is_active'] as bool? ?? true,
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
      'is_active': isActive,
    };
  }
}
