/// Product model representing physical catalogue items used for quotations.
/// Maps directly to `public.products` in Supabase.
class ProductModel {
  final String id;
  final String name;
  final String? description;
  final String? category;
  final double defaultPrice;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ProductModel({
    required this.id,
    required this.name,
    this.description,
    this.category,
    required this.defaultPrice,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      category: json['category'] as String?,
      defaultPrice: (json['default_price'] is num)
          ? (json['default_price'] as num).toDouble()
          : double.tryParse(json['default_price']?.toString() ?? '0') ?? 0.0,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category': category,
      'default_price': defaultPrice,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  ProductModel copyWith({
    String? id,
    String? name,
    String? description,
    String? category,
    double? defaultPrice,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ProductModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      category: category ?? this.category,
      defaultPrice: defaultPrice ?? this.defaultPrice,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ProductModel &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

/// Approved canonical catalogue categories per DESIGN.md & Stitch A22/A23.
class ProductCategories {
  static const braking = 'Braking';
  static const fluidsAndLubricants = 'Fluids & Lubricants';
  static const filters = 'Filters';
  static const suspension = 'Suspension';
  static const electrical = 'Electrical';
  static const ignition = 'Ignition';

  static const List<String> all = [
    braking,
    fluidsAndLubricants,
    filters,
    suspension,
    electrical,
    ignition,
  ];

  /// Helper to validate if category is one of the approved set
  static bool isValid(String? cat) => cat != null && all.contains(cat);
}
