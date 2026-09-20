import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/product_model.dart';

abstract class ProductsRepository {
  /// Fetches products with optional category, active status, and search query filters.
  Future<List<ProductModel>> fetchProducts({
    String? category,
    bool? activeOnly,
    String? searchQuery,
  });

  /// Fetches a single product by its UUID.
  Future<ProductModel> getProductById(String id);

  /// Creates a new product record in `public.products`.
  Future<ProductModel> createProduct({
    required String name,
    required String category,
    required double defaultPrice,
    String? description,
    bool isActive = true,
  });

  /// Updates an existing product record in `public.products`.
  Future<ProductModel> updateProduct({
    required String id,
    required String name,
    required String category,
    required double defaultPrice,
    String? description,
    required bool isActive,
  });

  /// Toggles the active status of a product (soft deactivate / reactivate).
  /// Preserves historical quotations by never executing a destructive DELETE.
  Future<ProductModel> toggleProductStatus({
    required String id,
    required bool isActive,
  });
}

class SupabaseProductsRepository implements ProductsRepository {
  final SupabaseClient _client;

  SupabaseProductsRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  @override
  Future<List<ProductModel>> fetchProducts({
    String? category,
    bool? activeOnly,
    String? searchQuery,
  }) async {
    try {
      var query = _client.from('products').select();

      if (category != null && category.isNotEmpty && category != 'all') {
        query = query.eq('category', category);
      }

      if (activeOnly != null) {
        query = query.eq('is_active', activeOnly);
      }

      final response = await query.order('name', ascending: true);
      final List<dynamic> data = response as List<dynamic>;

      var products = data
          .map((json) => ProductModel.fromJson(json as Map<String, dynamic>))
          .toList();

      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final q = searchQuery.toLowerCase().trim();
        products = products.where((p) {
          final matchesName = p.name.toLowerCase().contains(q);
          final matchesCat = (p.category ?? '').toLowerCase().contains(q);
          final matchesDesc = (p.description ?? '').toLowerCase().contains(q);
          return matchesName || matchesCat || matchesDesc;
        }).toList();
      }

      return products;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ProductModel> getProductById(String id) async {
    try {
      final response = await _client
          .from('products')
          .select()
          .eq('id', id)
          .single();

      return ProductModel.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ProductModel> createProduct({
    required String name,
    required String category,
    required double defaultPrice,
    String? description,
    bool isActive = true,
  }) async {
    try {
      final insertData = {
        'name': name.trim(),
        'category': category.trim(),
        'default_price': defaultPrice,
        'description': description?.trim().isEmpty == true ? null : description?.trim(),
        'is_active': isActive,
      };

      final response = await _client
          .from('products')
          .insert(insertData)
          .select()
          .single();

      return ProductModel.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ProductModel> updateProduct({
    required String id,
    required String name,
    required String category,
    required double defaultPrice,
    String? description,
    required bool isActive,
  }) async {
    try {
      // Note: updated_at is strictly managed by PostgreSQL trigger 'products_set_updated_at'
      // and column privileges for authenticated restrict UPDATE to allowed data columns.
      final updateData = {
        'name': name.trim(),
        'category': category.trim(),
        'default_price': defaultPrice,
        'description': description?.trim().isEmpty == true ? null : description?.trim(),
        'is_active': isActive,
      };

      final response = await _client
          .from('products')
          .update(updateData)
          .eq('id', id)
          .select()
          .single();

      return ProductModel.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<ProductModel> toggleProductStatus({
    required String id,
    required bool isActive,
  }) async {
    try {
      // Note: updated_at is strictly managed by PostgreSQL trigger 'products_set_updated_at'
      final updateData = {
        'is_active': isActive,
      };

      final response = await _client
          .from('products')
          .update(updateData)
          .eq('id', id)
          .select()
          .single();

      return ProductModel.fromJson(response);
    } catch (e) {
      rethrow;
    }
  }
}
