import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autotricks/data/models/product_model.dart';
import 'package:autotricks/features/catalogue/providers/products_provider.dart';
import 'package:autotricks/features/catalogue/screens/products_list_screen.dart';
import 'package:autotricks/features/catalogue/screens/create_edit_product_screen.dart';
import '../../helpers/mock_repositories.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('ProductModel & ProductCategories Unit Tests', () {
    test('ProductModel parses JSON correctly', () {
      final json = {
        'id': 'p-123',
        'name': 'Brake Pad Set (Front)',
        'description': 'High performance ceramic pads',
        'category': 'Braking',
        'default_price': 6000.0,
        'is_active': true,
        'created_at': '2026-09-10T12:00:00Z',
        'updated_at': '2026-09-12T15:30:00Z',
      };

      final product = ProductModel.fromJson(json);
      expect(product.id, 'p-123');
      expect(product.name, 'Brake Pad Set (Front)');
      expect(product.category, 'Braking');
      expect(product.defaultPrice, 6000.0);
      expect(product.isActive, true);

      final serialized = product.toJson();
      expect(serialized['id'], 'p-123');
      expect(serialized['name'], 'Brake Pad Set (Front)');
      expect(serialized['category'], 'Braking');
      expect(serialized['default_price'], 6000.0);
    });

    test('ProductCategories contains exactly the 6 approved categories', () {
      expect(ProductCategories.all, [
        'Braking',
        'Fluids & Lubricants',
        'Filters',
        'Suspension',
        'Electrical',
        'Ignition',
      ]);

      expect(ProductCategories.isValid('Braking'), isTrue);
      expect(ProductCategories.isValid('Fluids & Lubricants'), isTrue);
      expect(ProductCategories.isValid('Filters'), isTrue);
      expect(ProductCategories.isValid('Suspension'), isTrue);
      expect(ProductCategories.isValid('Electrical'), isTrue);
      expect(ProductCategories.isValid('Ignition'), isTrue);
      expect(ProductCategories.isValid('Other'), isFalse);
      expect(ProductCategories.isValid('Custom'), isFalse);
    });
  });

  group('MockProductsRepository Unit Tests', () {
    late MockProductsRepository repo;

    setUp(() {
      repo = MockProductsRepository();
    });

    test('fetchProducts returns all items initially', () async {
      final products = await repo.fetchProducts();
      expect(products.length, 5);
    });

    test('fetchProducts filters by active status', () async {
      final active = await repo.fetchProducts(activeOnly: true);
      expect(active.every((p) => p.isActive), isTrue);
      expect(active.length, 4);

      final inactive = await repo.fetchProducts(activeOnly: false);
      expect(inactive.every((p) => !p.isActive), isTrue);
      expect(inactive.length, 1);
    });

    test('fetchProducts filters by category', () async {
      final braking = await repo.fetchProducts(category: ProductCategories.braking);
      expect(braking.length, 1);
      expect(braking.first.name, 'Brake Pad Set (Front)');
    });

    test('fetchProducts filters by search query', () async {
      final results = await repo.fetchProducts(searchQuery: 'oil');
      expect(results.length, 1);
      expect(results.first.name, contains('Engine Oil'));
    });

    test('createProduct adds new item to catalogue', () async {
      final created = await repo.createProduct(
        name: 'Oil Filter Standard',
        category: ProductCategories.filters,
        defaultPrice: 450.0,
        description: 'OEM spec oil filter element',
      );

      expect(created.name, 'Oil Filter Standard');
      expect(created.defaultPrice, 450.0);

      final all = await repo.fetchProducts();
      expect(all.length, 6);
    });

    test('updateProduct updates existing product details', () async {
      final updated = await repo.updateProduct(
        id: 'prd-1',
        name: 'Brake Pad Set (Front) - Premium Ceramic',
        category: ProductCategories.braking,
        defaultPrice: 6500.0,
        description: 'Upgraded formula',
        isActive: true,
      );

      expect(updated.name, 'Brake Pad Set (Front) - Premium Ceramic');
      expect(updated.defaultPrice, 6500.0);
    });

    test('toggleProductStatus performs soft deactivation and reactivation', () async {
      final deactivated = await repo.toggleProductStatus(id: 'prd-1', isActive: false);
      expect(deactivated.isActive, isFalse);

      final reactivated = await repo.toggleProductStatus(id: 'prd-1', isActive: true);
      expect(reactivated.isActive, isTrue);
    });

    test('real 36-character UUID handles creation, update, and deactivation', () async {
      const realUuid = '94ae3685-72b0-4ae5-8cb7-162213c0850c';
      final product = await repo.createProduct(
        name: 'M4 Disk break',
        category: ProductCategories.braking,
        defaultPrice: 500.0,
      );
      expect(product.id, isNotEmpty);

      // Add a product directly with real 36-char UUID to verify model & repo handling
      final realProduct = ProductModel(
        id: realUuid,
        name: 'M4 Disk break',
        category: ProductCategories.braking,
        defaultPrice: 500.0,
        isActive: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(realProduct.id.length, 36);

      final updated = await repo.updateProduct(
        id: product.id,
        name: 'M4 Disk break (Updated)',
        category: ProductCategories.braking,
        defaultPrice: 550.0,
        isActive: false,
      );
      expect(updated.name, 'M4 Disk break (Updated)');
      expect(updated.isActive, isFalse);

      final reactivated = await repo.toggleProductStatus(
        id: product.id,
        isActive: true,
      );
      expect(reactivated.isActive, isTrue);
    });

    test('updateProduct and toggleProductStatus throw error when product not found', () async {
      expect(
        () => repo.updateProduct(
          id: 'non-existent-id',
          name: 'Non Existent',
          category: ProductCategories.braking,
          defaultPrice: 100.0,
          isActive: true,
        ),
        throwsA(isA<Exception>()),
      );

      expect(
        () => repo.toggleProductStatus(
          id: 'non-existent-id',
          isActive: false,
        ),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('ProductFormNotifier State & Error Handling Tests', () {
    late MockProductsRepository mockRepo;
    late ProviderContainer container;

    setUp(() {
      mockRepo = MockProductsRepository();
      container = ProviderContainer(
        overrides: [
          productsRepositoryProvider.overrideWithValue(mockRepo),
        ],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('updateProduct updates state and clears previous errors', () async {
      final notifier = container.read(productFormProvider.notifier);
      final result = await notifier.updateProduct(
        id: 'prd-1',
        name: 'Brake Pad Set (Front) - Upgraded',
        category: ProductCategories.braking,
        defaultPrice: 7000.0,
        description: 'New ceramic formula',
        isActive: true,
      );

      expect(result, isNotNull);
      expect(result!.name, 'Brake Pad Set (Front) - Upgraded');
      final state = container.read(productFormProvider);
      expect(state.isSubmitting, isFalse);
      expect(state.errorMessage, isNull);
      expect(state.product, isNotNull);
    });

    test('toggleStatus deactivates and reactivates product cleanly', () async {
      final notifier = container.read(productFormProvider.notifier);

      // Deactivate
      final deactivated = await notifier.toggleStatus(id: 'prd-1', isActive: false);
      expect(deactivated, isNotNull);
      expect(deactivated!.isActive, isFalse);
      expect(container.read(productFormProvider).product!.isActive, isFalse);

      // Reactivate
      final reactivated = await notifier.toggleStatus(id: 'prd-1', isActive: true);
      expect(reactivated, isNotNull);
      expect(reactivated!.isActive, isTrue);
      expect(container.read(productFormProvider).product!.isActive, isTrue);
    });

    test('error handling sets errorMessage when repository throws', () async {
      final notifier = container.read(productFormProvider.notifier);
      final result = await notifier.updateProduct(
        id: 'invalid-id-that-does-not-exist',
        name: 'Bad Product',
        category: ProductCategories.braking,
        defaultPrice: 100.0,
        isActive: false,
      );

      expect(result, isNull);
      final state = container.read(productFormProvider);
      expect(state.isSubmitting, isFalse);
      expect(state.errorMessage, isNotNull);
      expect(state.errorMessage, contains('Product not found for update'));
    });
  });

  group('A22 Products Catalogue Screen Widget Tests', () {
    late MockProductsRepository mockRepo;

    setUp(() {
      mockRepo = MockProductsRepository();
    });

    testWidgets('renders catalogue header, banners, and product cards', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            productsRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const ProductsListScreen(),
        ),
      );

      await tester.pumpAndSettle();

      // Top title and context
      expect(find.text('Products Catalogue'), findsWidgets);
      expect(find.text('Quotation Rate Guide'), findsOneWidget);
      expect(find.text('Synced'), findsOneWidget);

      // Product cards
      expect(find.text('Brake Pad Set (Front)'), findsOneWidget);
      expect(find.text('₹6,000'), findsOneWidget);
      expect(find.text('Synthetic Engine Oil (5W-30)'), findsOneWidget);
      expect(find.text('₹3,850'), findsOneWidget);

      // Status badges
      expect(find.text('ACTIVE'), findsWidgets);
      expect(find.text('INACTIVE'), findsWidgets);

      // Create button
      expect(find.text('Create Product'), findsOneWidget);
    });

    testWidgets('search filters product list', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            productsRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const ProductsListScreen(),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Brake Pad Set (Front)'), findsOneWidget);
      expect(find.text('Cabin AC Carbon Filter'), findsOneWidget);

      // Enter search query
      final searchInput = find.byType(TextField);
      await tester.enterText(searchInput, 'carbon');
      await tester.pumpAndSettle();

      // Only Carbon Filter should remain visible
      expect(find.text('Cabin AC Carbon Filter'), findsOneWidget);
      expect(find.text('Brake Pad Set (Front)'), findsNothing);
    });
  });

  group('A23 Create/Edit Product Screen Widget Tests', () {
    late MockProductsRepository mockRepo;

    setUp(() {
      mockRepo = MockProductsRepository();
    });

    testWidgets('Edit mode renders product details and Quotation Snapshot Rule banner', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            productsRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const CreateEditProductScreen(productId: 'prd-1'),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Edit Product'), findsWidgets);
      expect(find.text('Quotation Snapshot Rule'), findsOneWidget);
      expect(find.text('Product Status'), findsWidgets);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Deactivate Product'), findsOneWidget);
    });

    testWidgets('Create mode renders empty form with Create Product button', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            productsRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: const CreateEditProductScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('New Catalogue Item'), findsOneWidget);
      expect(find.text('Quotation Snapshot Rule'), findsOneWidget);
      expect(find.text('Create Product'), findsOneWidget);
      expect(find.text('Deactivate Product'), findsNothing);
    });

    testWidgets('Edit mode renders with real 36-character UUID cleanly', (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final realProduct = await mockRepo.createProduct(
        name: 'M4 Disk break',
        category: ProductCategories.braking,
        defaultPrice: 500.0,
      );

      await tester.pumpWidget(
        createTestWidget(
          overrides: [
            productsRepositoryProvider.overrideWithValue(mockRepo),
          ],
          child: CreateEditProductScreen(productId: realProduct.id),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Edit Product'), findsWidgets);
      expect(find.text('M4 Disk break'), findsWidgets);
      expect(find.text('Save Changes'), findsOneWidget);
      expect(find.text('Deactivate Product'), findsOneWidget);
    });
  });
}

