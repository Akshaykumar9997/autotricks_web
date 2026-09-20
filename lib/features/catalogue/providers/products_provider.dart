import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/product_model.dart';
import '../../../data/repositories/products_repository.dart';

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return SupabaseProductsRepository();
});

/// State for Product Catalogue search and category/status filter
class ProductFilterState {
  final String status; // 'ALL', 'ACTIVE', 'INACTIVE'
  final String category; // 'ALL', or one of ProductCategories.all
  final String searchQuery;

  const ProductFilterState({
    this.status = 'ALL',
    this.category = 'ALL',
    this.searchQuery = '',
  });

  ProductFilterState copyWith({
    String? status,
    String? category,
    String? searchQuery,
  }) {
    return ProductFilterState(
      status: status ?? this.status,
      category: category ?? this.category,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class ProductFilterNotifier extends Notifier<ProductFilterState> {
  @override
  ProductFilterState build() => const ProductFilterState();

  void setStatus(String status) {
    state = state.copyWith(status: status);
  }

  void setCategory(String category) {
    state = state.copyWith(category: category);
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  void reset() {
    state = const ProductFilterState();
  }
}

final productFilterProvider =
    NotifierProvider<ProductFilterNotifier, ProductFilterState>(
  ProductFilterNotifier.new,
);

/// Raw list of all products from Supabase
final allProductsProvider =
    FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final repo = ref.watch(productsRepositoryProvider);
  return repo.fetchProducts();
});

/// Filtered list of products applying category, status, and search filters
final productsListProvider =
    FutureProvider.autoDispose<List<ProductModel>>((ref) async {
  final allProducts = await ref.watch(allProductsProvider.future);
  final filter = ref.watch(productFilterProvider);

  return allProducts.where((p) {
    // 1. Status Filter
    if (filter.status == 'ACTIVE' && !p.isActive) return false;
    if (filter.status == 'INACTIVE' && p.isActive) return false;

    // 2. Category Filter
    if (filter.category != 'ALL' && p.category != filter.category) {
      return false;
    }

    // 3. Search Query Filter
    if (filter.searchQuery.trim().isNotEmpty) {
      final q = filter.searchQuery.toLowerCase().trim();
      final matchesName = p.name.toLowerCase().contains(q);
      final matchesCat = (p.category ?? '').toLowerCase().contains(q);
      final matchesDesc = (p.description ?? '').toLowerCase().contains(q);
      if (!matchesName && !matchesCat && !matchesDesc) return false;
    }

    return true;
  }).toList();
});

/// Metrics provider for header chips (All, Active, Inactive counts)
class ProductMetrics {
  final int totalCount;
  final int activeCount;
  final int inactiveCount;

  const ProductMetrics({
    required this.totalCount,
    required this.activeCount,
    required this.inactiveCount,
  });
}

final productMetricsProvider =
    Provider.autoDispose<AsyncValue<ProductMetrics>>((ref) {
  final allProductsAsync = ref.watch(allProductsProvider);

  return allProductsAsync.whenData((products) {
    final active = products.where((p) => p.isActive).length;
    final inactive = products.where((p) => !p.isActive).length;
    return ProductMetrics(
      totalCount: products.length,
      activeCount: active,
      inactiveCount: inactive,
    );
  });
});

/// Fetches a single product by its UUID
final productDetailProvider =
    FutureProvider.autoDispose.family<ProductModel, String>((ref, id) async {
  final repo = ref.watch(productsRepositoryProvider);
  return repo.getProductById(id);
});

/// Form submission state for Product creation / updating
class ProductFormState {
  final bool isSubmitting;
  final String? errorMessage;
  final ProductModel? product;

  const ProductFormState({
    this.isSubmitting = false,
    this.errorMessage,
    this.product,
  });

  ProductFormState copyWith({
    bool? isSubmitting,
    String? errorMessage,
    ProductModel? product,
  }) {
    return ProductFormState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      product: product ?? this.product,
    );
  }
}

class ProductFormNotifier extends Notifier<ProductFormState> {
  @override
  ProductFormState build() => const ProductFormState();

  Future<ProductModel?> createProduct({
    required String name,
    required String category,
    required double defaultPrice,
    String? description,
    bool isActive = true,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final repo = ref.read(productsRepositoryProvider);
      final created = await repo.createProduct(
        name: name,
        category: category,
        defaultPrice: defaultPrice,
        description: description,
        isActive: isActive,
      );

      // Invalidate catalogue lists so UI updates instantly
      ref.invalidate(allProductsProvider);

      state = ProductFormState(isSubmitting: false, product: created);
      return created;
    } catch (e) {
      state = ProductFormState(
        isSubmitting: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  Future<ProductModel?> updateProduct({
    required String id,
    required String name,
    required String category,
    required double defaultPrice,
    String? description,
    required bool isActive,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final repo = ref.read(productsRepositoryProvider);
      final updated = await repo.updateProduct(
        id: id,
        name: name,
        category: category,
        defaultPrice: defaultPrice,
        description: description,
        isActive: isActive,
      );

      // Invalidate catalogue lists and detail provider
      ref.invalidate(allProductsProvider);
      ref.invalidate(productDetailProvider(id));

      state = ProductFormState(isSubmitting: false, product: updated);
      return updated;
    } catch (e) {
      state = ProductFormState(
        isSubmitting: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }

  Future<ProductModel?> toggleStatus({
    required String id,
    required bool isActive,
  }) async {
    state = state.copyWith(isSubmitting: true, errorMessage: null);
    try {
      final repo = ref.read(productsRepositoryProvider);
      final updated = await repo.toggleProductStatus(
        id: id,
        isActive: isActive,
      );

      ref.invalidate(allProductsProvider);
      ref.invalidate(productDetailProvider(id));

      state = ProductFormState(isSubmitting: false, product: updated);
      return updated;
    } catch (e) {
      state = ProductFormState(
        isSubmitting: false,
        errorMessage: e.toString(),
      );
      return null;
    }
  }
}

final productFormProvider =
    NotifierProvider<ProductFormNotifier, ProductFormState>(
  ProductFormNotifier.new,
);
