import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/data/models/service_request_model.dart';
import 'package:autotricks/features/service_requests/screens/service_request_detail_screen.dart';
import '../../helpers/mock_repositories.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A04 — Service Request Detail Screen Tests', () {
    testWidgets('Renders header, customer, vehicle, issue details, and action buttons', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const ServiceRequestDetailScreen(requestId: 'sr-1'),
        ),
      );
      await tester.pumpAndSettle();

      // Header
      expect(find.text('#SR-2026-00021'), findsOneWidget);
      // 'NEW' appears in badge and in the lifecycle timeline
      expect(find.text('NEW'), findsNWidgets(2));

      // Customer
      expect(find.text('Rahul Kumar'), findsOneWidget);
      expect(find.text('+91 98450 12890'), findsOneWidget);

      // Vehicle
      expect(find.textContaining('Honda City'), findsOneWidget);
      expect(find.text('KA-01-MJ-4412'), findsOneWidget);

      // Service Request Notes Card
      expect(find.text('SERVICE REQUEST'), findsOneWidget);
      expect(find.text('Routine 25k service + noticeable brake squeal.'), findsOneWidget);

      // Lifecycle Timeline Card & Actions
      expect(find.text('REQUEST LIFECYCLE'), findsOneWidget);
      expect(find.text('Review Request'), findsOneWidget);
      expect(find.text('Create Quote'), findsNothing); // Test 1: NEW request has no Create Quote
      expect(find.text('Cancel Request'), findsOneWidget);
    });

    testWidgets('1. NEW request: Create Quote action is NOT available', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const ServiceRequestDetailScreen(requestId: 'sr-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Review Request'), findsOneWidget);
      expect(find.text('Create Quote'), findsNothing);
    });

    testWidgets('2. UNDER_REVIEW + client + vehicle: Create Quote action IS available', (tester) async {
      final repo = MockServiceRequestsRepository();
      final sr = repo.items.first.copyWith(
        status: 'UNDER_REVIEW',
        clientId: 'c-1',
        vehicleId: 'v-1',
      );
      repo.items[0] = sr;

      await tester.pumpWidget(
        createTestWidget(
          child: const ServiceRequestDetailScreen(requestId: 'sr-1'),
          serviceRequestsRepo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Quote'), findsOneWidget);
      expect(find.text('Review Request'), findsNothing);
    });

    testWidgets('3. UNDER_REVIEW with missing client: creation blocked on tap', (tester) async {
      final repo = MockServiceRequestsRepository();
      final base = repo.items.first;
      final sr = ServiceRequestModel(
        id: base.id,
        requestNumber: base.requestNumber,
        source: base.source,
        status: 'UNDER_REVIEW',
        clientId: null,
        vehicleId: 'v-1',
        client: null,
        vehicle: base.vehicle,
        createdAt: base.createdAt,
        updatedAt: base.updatedAt,
      );
      repo.items[0] = sr;

      await tester.pumpWidget(
        createTestWidget(
          child: const ServiceRequestDetailScreen(requestId: 'sr-1'),
          serviceRequestsRepo: repo,
        ),
      );
      await tester.pumpAndSettle();

      final createBtn = find.text('Create Quote');
      expect(createBtn, findsOneWidget);

      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      // Should show toast blocking creation
      expect(find.textContaining('identified client and vehicle'), findsOneWidget);
    });

    testWidgets('4. UNDER_REVIEW with missing vehicle: creation blocked on tap', (tester) async {
      final repo = MockServiceRequestsRepository();
      final base = repo.items.first;
      final sr = ServiceRequestModel(
        id: base.id,
        requestNumber: base.requestNumber,
        source: base.source,
        status: 'UNDER_REVIEW',
        clientId: 'c-1',
        vehicleId: null,
        client: base.client,
        vehicle: null,
        createdAt: base.createdAt,
        updatedAt: base.updatedAt,
      );
      repo.items[0] = sr;

      await tester.pumpWidget(
        createTestWidget(
          child: const ServiceRequestDetailScreen(requestId: 'sr-1'),
          serviceRequestsRepo: repo,
        ),
      );
      await tester.pumpAndSettle();

      final createBtn = find.text('Create Quote');
      expect(createBtn, findsOneWidget);

      await tester.tap(createBtn);
      await tester.pumpAndSettle();

      // Should show toast blocking creation
      expect(find.textContaining('identified client and vehicle'), findsOneWidget);
    });

    testWidgets('5. QUOTATION_CREATED: Create Quote is NOT available', (tester) async {
      final repo = MockServiceRequestsRepository();
      final sr = repo.items.first.copyWith(
        status: 'QUOTATION_CREATED',
        clientId: 'c-1',
        vehicleId: 'v-1',
      );
      repo.items[0] = sr;

      await tester.pumpWidget(
        createTestWidget(
          child: const ServiceRequestDetailScreen(requestId: 'sr-1'),
          serviceRequestsRepo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Quote'), findsNothing);
      expect(find.text('Review Quote'), findsOneWidget);
    });

    testWidgets('6. QUOTATION_SENT: Create Quote is NOT available', (tester) async {
      final repo = MockServiceRequestsRepository();
      final sr = repo.items.first.copyWith(
        status: 'QUOTATION_SENT',
        clientId: 'c-1',
        vehicleId: 'v-1',
      );
      repo.items[0] = sr;

      await tester.pumpWidget(
        createTestWidget(
          child: const ServiceRequestDetailScreen(requestId: 'sr-1'),
          serviceRequestsRepo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Quote'), findsNothing);
      expect(find.text('View Quote'), findsOneWidget);
    });

    testWidgets('7. APPROVED: Create Quote is NOT available', (tester) async {
      final repo = MockServiceRequestsRepository();
      final sr = repo.items.first.copyWith(
        status: 'APPROVED',
        clientId: 'c-1',
        vehicleId: 'v-1',
      );
      repo.items[0] = sr;

      await tester.pumpWidget(
        createTestWidget(
          child: const ServiceRequestDetailScreen(requestId: 'sr-1'),
          serviceRequestsRepo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Quote'), findsNothing);
      expect(find.text('Create Service Job'), findsOneWidget);
    });

    testWidgets('8. CANCELLED: Create Quote is NOT available (read-only)', (tester) async {
      final repo = MockServiceRequestsRepository();
      final sr = repo.items.first.copyWith(
        status: 'CANCELLED',
        clientId: 'c-1',
        vehicleId: 'v-1',
      );
      repo.items[0] = sr;

      await tester.pumpWidget(
        createTestWidget(
          child: const ServiceRequestDetailScreen(requestId: 'sr-1'),
          serviceRequestsRepo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Quote'), findsNothing);
      expect(find.text('Review Request'), findsNothing);
      expect(find.text('Cancel Request'), findsNothing);
    });

    testWidgets('Tapping Review Request updates request status', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const ServiceRequestDetailScreen(requestId: 'sr-1'),
        ),
      );
      await tester.pumpAndSettle();

      final reviewButton = find.text('Review Request');
      expect(reviewButton, findsOneWidget);

      await tester.tap(reviewButton);
      await tester.pumpAndSettle();

      // Upon review transition, status becomes UNDER_REVIEW and action becomes Create Quote
      expect(find.text('UNDER REVIEW'), findsAtLeastNWidgets(1));
      expect(find.text('Create Quote'), findsOneWidget);
    });
  });
}
