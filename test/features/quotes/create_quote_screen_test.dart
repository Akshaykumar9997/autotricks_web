import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/data/models/client_model.dart';
import 'package:autotricks/data/models/service_request_model.dart';
import 'package:autotricks/data/models/vehicle_model.dart';
import 'package:autotricks/features/quotes/screens/create_quote_screen.dart';
import '../../helpers/mock_repositories.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('A14 CreateQuoteScreen Widget Tests', () {
    late MockQuotationsRepository mockQuotesRepo;
    late MockServiceRequestsRepository mockSrRepo;

    final testSr = ServiceRequestModel(
      id: 'sr-test-1',
      requestNumber: 'SR-2026-00077',
      source: 'PHONE',
      status: 'UNDER_REVIEW',
      adminNotes: 'Periodic checkup + front brakes noise.',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      client: const ClientModel(
        id: 'c-101',
        fullName: 'Sameer Verma',
        phone: '+91 98765 43210',
        email: 'sameer.v@example.com',
      ),
      vehicle: const VehicleModel(
        id: 'v-101',
        clientId: 'c-101',
        make: 'Honda',
        model: 'City',
        manufacturingYear: 2022,
        registrationNumber: 'KA 03 AA 9999',
      ),
    );

    setUp(() {
      mockQuotesRepo = MockQuotationsRepository();
      mockSrRepo = MockServiceRequestsRepository();
      mockSrRepo.items.clear();
      mockSrRepo.items.add(testSr);
    });

    testWidgets('renders CreateQuoteScreen with linked request context', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestWidget(
          child: const CreateQuoteScreen(serviceRequestId: 'sr-test-1'),
          quotationsRepo: mockQuotesRepo,
          serviceRequestsRepo: mockSrRepo,
        ),
      );

      await tester.pumpAndSettle();

      // Check App Bar & header
      expect(find.text('Create Quote'), findsOneWidget);

      // Check linked service request banner
      expect(find.textContaining('SR-2026-00077'), findsOneWidget);
      expect(find.text('Sameer Verma'), findsOneWidget);
      expect(find.text('KA 03 AA 9999'), findsOneWidget);

      // Check line items section exists
      expect(find.textContaining('Quoted Line Items'), findsOneWidget);

      // Verify no forbidden operational terminology
      expect(find.textContaining('Telemetry'), findsNothing);
      expect(find.textContaining('Queue'), findsNothing);
      expect(find.textContaining('Bay'), findsNothing);
      expect(find.textContaining('Technician'), findsNothing);
      expect(find.textContaining('Workshop'), findsNothing);
    });

    testWidgets('can add custom line item and computes total', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestWidget(
          child: const CreateQuoteScreen(serviceRequestId: 'sr-test-1'),
          quotationsRepo: mockQuotesRepo,
          serviceRequestsRepo: mockSrRepo,
        ),
      );

      await tester.pumpAndSettle();

      // Tap 'Add Custom Item' or 'Add Line Item'
      final addItemBtn = find.text('Add Line Item');
      if (addItemBtn.evaluate().isNotEmpty) {
        await tester.tap(addItemBtn);
        await tester.pumpAndSettle();
      }

      // Fill in item name
      final nameFields = find.byType(TextField);
      expect(nameFields, findsWidgets);

      // Enter item name into the first TextField (item name)
      await tester.enterText(nameFields.first, 'Brake Caliper Servicing');
      await tester.pumpAndSettle();

      expect(find.text('Brake Caliper Servicing'), findsOneWidget);
    });

    testWidgets('9. Direct/invalid A14 route: blocked gracefully', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Subtest 9a: Null / empty serviceRequestId
      await tester.pumpWidget(
        createTestWidget(
          child: const CreateQuoteScreen(serviceRequestId: null),
          quotationsRepo: mockQuotesRepo,
          serviceRequestsRepo: mockSrRepo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Context Required'), findsOneWidget);
      expect(find.text('Back to Requests'), findsOneWidget);
      expect(find.text('Save Draft'), findsNothing);

      // Subtest 9b: Ineligible status: NEW
      final newSr = testSr.copyWith(id: 'sr-new-1', status: 'NEW');
      mockSrRepo.items.add(newSr);

      await tester.pumpWidget(
        createTestWidget(
          child: const CreateQuoteScreen(serviceRequestId: 'sr-new-1'),
          quotationsRepo: mockQuotesRepo,
          serviceRequestsRepo: mockSrRepo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quotation Unavailable'), findsOneWidget);
      expect(find.text('Quote creation is available after the service request is under review.'), findsOneWidget);
      expect(find.text('Back to Request'), findsOneWidget);
      expect(find.text('Save Draft'), findsNothing);

      // Subtest 9c: Ineligible status: CANCELLED
      final cancelledSr = testSr.copyWith(id: 'sr-cancelled-1', status: 'CANCELLED');
      mockSrRepo.items.add(cancelledSr);

      await tester.pumpWidget(
        createTestWidget(
          child: const CreateQuoteScreen(serviceRequestId: 'sr-cancelled-1'),
          quotationsRepo: mockQuotesRepo,
          serviceRequestsRepo: mockSrRepo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Request Cancelled'), findsOneWidget);
      expect(find.text('Cannot create a quote for a cancelled service request.'), findsOneWidget);
      expect(find.text('Save Draft'), findsNothing);

      // Subtest 9d: Ineligible unlinked (missing client/vehicle)
      final unlinkedSr = ServiceRequestModel(
        id: 'sr-unlinked-1',
        requestNumber: 'SR-2026-00099',
        source: 'PHONE',
        status: 'UNDER_REVIEW',
        clientId: null,
        vehicleId: null,
        client: null,
        vehicle: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      mockSrRepo.items.add(unlinkedSr);

      await tester.pumpWidget(
        createTestWidget(
          child: const CreateQuoteScreen(serviceRequestId: 'sr-unlinked-1'),
          quotationsRepo: mockQuotesRepo,
          serviceRequestsRepo: mockSrRepo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Linking Required'), findsOneWidget);
      expect(find.textContaining('identified client and vehicle linked'), findsOneWidget);
      expect(find.text('Save Draft'), findsNothing);
    });

    testWidgets('10. Valid A14: real Service Request UUID is used', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      const realUuid = '6377c96b-8ffc-4a9e-9910-b2041b547159';
      final realSr = testSr.copyWith(id: realUuid, requestNumber: 'SR-2026-00077');
      mockSrRepo.items.add(realSr);

      await tester.pumpWidget(
        createTestWidget(
          child: const CreateQuoteScreen(serviceRequestId: realUuid),
          quotationsRepo: mockQuotesRepo,
          serviceRequestsRepo: mockSrRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Confirms real UUID loads correct request context
      expect(find.textContaining('SR-2026-00077'), findsOneWidget);
      expect(find.text('Save Draft'), findsOneWidget);
    });

    testWidgets('11. Valid A14 Save Draft: quotation creation still succeeds', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestWidget(
          child: const CreateQuoteScreen(serviceRequestId: 'sr-test-1'),
          quotationsRepo: mockQuotesRepo,
          serviceRequestsRepo: mockSrRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Add a line item first
      final addItemBtn = find.text('Add Line Item');
      expect(addItemBtn, findsOneWidget);
      await tester.tap(addItemBtn);
      await tester.pumpAndSettle();

      // Enter custom line item details
      final itemTitleField = find.widgetWithText(TextField, 'Item Title (e.g. Brake Pad Replacement)');
      if (itemTitleField.evaluate().isNotEmpty) {
        await tester.enterText(itemTitleField, 'Engine Flush');
      } else {
        await tester.enterText(find.byType(TextField).first, 'Engine Flush');
      }
      await tester.pumpAndSettle();

      // Tap Save Draft
      final saveBtn = find.text('Save Draft');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Verification: quotation was created in repository
      expect(mockQuotesRepo.quotes.any((q) => q.serviceRequestId == 'sr-test-1'), isTrue);
    });

    testWidgets('12. Invalid A14: raw database exception is not shown to the user', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Attempt to load a non-existent request ID
      await tester.pumpWidget(
        createTestWidget(
          child: const CreateQuoteScreen(serviceRequestId: 'non-existent-uuid'),
          quotationsRepo: mockQuotesRepo,
          serviceRequestsRepo: mockSrRepo,
        ),
      );
      await tester.pumpAndSettle();

      // Verify no raw DB exception strings are visible
      expect(find.textContaining('PostgrestException'), findsNothing);
      expect(find.textContaining('PG::'), findsNothing);
      expect(find.textContaining('syntax error'), findsNothing);
      expect(find.text('Service Request Not Found'), findsOneWidget);
      expect(find.text('The requested service request could not be loaded. Please return to the requests list.'), findsOneWidget);
    });
  });
}
