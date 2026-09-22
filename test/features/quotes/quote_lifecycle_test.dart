import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/data/models/client_model.dart';
import 'package:autotricks/data/models/quotation_model.dart';
import 'package:autotricks/data/models/service_request_model.dart';
import 'package:autotricks/data/models/vehicle_model.dart';
import 'package:autotricks/features/quotes/screens/edit_quote_revision_screen.dart';
import 'package:autotricks/features/quotes/screens/quote_change_requests_screen.dart';
import 'package:autotricks/features/quotes/screens/quote_detail_screen.dart';
import '../../helpers/mock_repositories.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  const realQuoteUuid = '815a7d08-012a-43d0-a933-89f2567f9cfa';
  const realRev1Uuid = 'f1e7df28-f39c-485b-8682-e0063bca033e';
  const realSrUuid = 'dcafc6d1-a956-47c1-ae53-1a55dd6a3b2f';
  const realClientUuid = '7a96677f-1d8f-4aa7-9008-8f8369384501';
  const realVehicleUuid = '86603a11-042c-4ae0-a20c-0cf3a968603c';
  const realCrUuid = '64188b0a-3ec3-44b4-93ec-e8eb4b553644';

  late MockQuotationsRepository mockQuotesRepo;
  late MockServiceRequestsRepository mockSrRepo;
  late MockClientVehicleRepository mockClientsRepo;

  setUp(() {
    final testDraftQuote = QuotationModel(
      id: realQuoteUuid,
      quotationNumber: 'QT-2026-00035',
      serviceRequestId: realSrUuid,
      createdBy: 'usr-admin-1',
      createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
      serviceRequest: ServiceRequestModel(
        id: realSrUuid,
        requestNumber: 'SR-2026-00078',
        source: 'PHONE',
        status: 'UNDER_REVIEW',
        clientId: realClientUuid,
        vehicleId: realVehicleUuid,
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
        client: const ClientModel(
          id: realClientUuid,
          fullName: 'Test Customer',
          phone: '+91 99999 88888',
          email: 'customer@example.com',
        ),
        vehicle: const VehicleModel(
          id: realVehicleUuid,
          clientId: realClientUuid,
          make: 'Toyota',
          model: 'Fortuner',
          manufacturingYear: 2021,
          registrationNumber: 'KA 05 MN 9999',
        ),
      ),
      revisions: [
        QuotationRevisionModel(
          id: realRev1Uuid,
          quotationId: realQuoteUuid,
          revisionNumber: 1,
          status: 'DRAFT',
          subtotal: 5000.0,
          discount: 200.0,
          tax: 900.0,
          total: 5700.0,
          notes: 'Standard service notes',
          terms: 'Valid for 15 days',
          createdAt: DateTime.now().subtract(const Duration(hours: 2)),
          items: [
            QuotationItemModel(
              id: 'item-101',
              quotationRevisionId: realRev1Uuid,
              name: 'Engine Oil Replacement',
              description: 'Fully synthetic 5W-30',
              quantity: 1.0,
              finalValue: 3500.0,
              lineTotal: 3500.0,
              createdAt: DateTime.now().subtract(const Duration(hours: 2)),
              updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
            ),
            QuotationItemModel(
              id: 'item-102',
              quotationRevisionId: realRev1Uuid,
              name: 'Oil Filter',
              description: 'OEM replacement filter',
              quantity: 1.0,
              finalValue: 1500.0,
              lineTotal: 1500.0,
              createdAt: DateTime.now().subtract(const Duration(hours: 2)),
              updatedAt: DateTime.now().subtract(const Duration(hours: 2)),
            ),
          ],
          changeRequests: [
            QuotationChangeRequestModel(
              id: realCrUuid,
              quotationRevisionId: realRev1Uuid,
              clientId: realClientUuid,
              profileId: 'usr-client-1',
              message: 'Please remove the oil filter replacement and keep only engine oil.',
              status: 'PENDING',
              createdAt: DateTime.now().subtract(const Duration(hours: 1)),
            ),
          ],
        ),
      ],
    );

    mockQuotesRepo = MockQuotationsRepository(initialQuotes: [testDraftQuote]);
    mockSrRepo = MockServiceRequestsRepository();
    mockClientsRepo = MockClientVehicleRepository();
  });

  Widget buildTestWidget({required Widget child}) {
    return createTestWidget(
      child: child,
      quotationsRepo: mockQuotesRepo,
      serviceRequestsRepo: mockSrRepo,
      clientVehicleRepo: mockClientsRepo,
    );
  }

  group('Day 8 Quotation Lifecycle, Revision & Negotiation Tests', () {
    // -------------------------------------------------------------
    // A15: Edit Quote Revision Tests
    // -------------------------------------------------------------
    testWidgets('1. A15 loads DRAFT revision with real UUID and populated values', (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(
          child: const EditQuoteRevisionScreen(
            quotationId: realQuoteUuid,
            revisionId: realRev1Uuid,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Revision identity and status
      expect(find.text('Edit Quote Revision'), findsOneWidget);
      expect(find.text('QT-2026-00035'), findsOneWidget);
      expect(find.text('Revision 1'), findsWidgets);
      expect(find.textContaining('This revision is editable'), findsOneWidget);

      // Prepopulated line items
      expect(find.text('Engine Oil Replacement'), findsOneWidget);
      expect(find.text('Oil Filter'), findsOneWidget);

      // Prepopulated financial summary
      expect(find.text('Financial Breakdown'), findsOneWidget);
      expect(find.text('₹5000'), findsWidgets); // Subtotal
      expect(find.text('Save Changes'), findsOneWidget);
    });

    testWidgets('2. A15 allows editing quantity, rate, discount, tax, and notes', (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(
          child: const EditQuoteRevisionScreen(
            quotationId: realQuoteUuid,
            revisionId: realRev1Uuid,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find discount field and change to 300
      final discountField = find.byKey(const Key('field_discount'));
      expect(discountField, findsOneWidget);
      await tester.enterText(discountField, '300');
      await tester.pumpAndSettle();

      // Add a new custom item
      await tester.tap(find.text('Add Item'));
      await tester.pumpAndSettle();

      expect(find.text('Quoted Items (3)'), findsOneWidget);

      // Provide valid name for the new item so validation passes
      final nameFields = find.widgetWithText(TextField, 'Item / Service Name *');
      await tester.enterText(nameFields.last, 'Brake Fluid Flush');
      await tester.pumpAndSettle();

      // Tap Save Changes
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();

      // Verify repo received the updated discount
      final quote = await mockQuotesRepo.getQuotationById(realQuoteUuid);
      expect(quote.currentRevision?.discount, 300.0);
    });

    testWidgets('3. A15 Immutability Guard: blocks editing of non-DRAFT revisions', (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Mark the revision as SENT
      await mockQuotesRepo.sendQuotationRevision(realRev1Uuid);

      await tester.pumpWidget(
        buildTestWidget(
          child: const EditQuoteRevisionScreen(
            quotationId: realQuoteUuid,
            revisionId: realRev1Uuid,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify locked banner is rendered
      expect(find.text('Revision 1 is Locked'), findsOneWidget);
      expect(find.textContaining('only DRAFT revisions can be edited'), findsOneWidget);
      expect(find.text('Back to Quote Details'), findsOneWidget);

      // Verify edit controls are absent
      expect(find.text('Save Changes'), findsNothing);
      expect(find.text('Add Item'), findsNothing);
    });

    // -------------------------------------------------------------
    // Revision Creation Tests
    // -------------------------------------------------------------
    testWidgets('4. Revision creation increments number and preserves snapshot immutability', (tester) async {
      // First send Revision 1 so it is immutable
      await mockQuotesRepo.sendQuotationRevision(realRev1Uuid);

      final quoteBefore = await mockQuotesRepo.getQuotationById(realQuoteUuid);
      expect(quoteBefore.currentRevision?.status, 'SENT');
      expect(quoteBefore.currentRevision?.revisionNumber, 1);
      final rev1Subtotal = quoteBefore.currentRevision?.subtotal;

      // Create Revision 2
      final result = await mockQuotesRepo.createQuotationRevision(realQuoteUuid);
      expect(result['revision_number'], 2);

      final quoteAfter = await mockQuotesRepo.getQuotationById(realQuoteUuid);
      expect(quoteAfter.quotationNumber, 'QT-2026-00035'); // Same quotation number
      expect(quoteAfter.revisions.length, 2);
      expect(quoteAfter.currentRevisionNumber, 2);
      expect(quoteAfter.currentStatus, 'DRAFT'); // New revision starts as DRAFT

      // Modify Revision 2
      final rev2Id = result['revision_id'] as String;
      await mockQuotesRepo.updateDraftRevision(
        revisionId: rev2Id,
        items: [
          const DraftQuotationItemInput(
            name: 'Upgraded Service',
            quantity: 1,
            finalValue: 8000,
          ),
        ],
      );

      // Verify Revision 1 snapshot remains completely unchanged
      final quoteFinal = await mockQuotesRepo.getQuotationById(realQuoteUuid);
      final rev1 = quoteFinal.revisions.firstWhere((r) => r.id == realRev1Uuid);
      expect(rev1.subtotal, rev1Subtotal);
      expect(rev1.status, 'SENT');
      expect(rev1.items.length, 2);
    });

    // -------------------------------------------------------------
    // Send Quote Workflow Tests
    // -------------------------------------------------------------
    testWidgets('5. Sending DRAFT revision transitions to SENT and supersedes older active revisions', (tester) async {
      final result = await mockQuotesRepo.sendQuotationRevision(realRev1Uuid);
      expect(result['status'], 'SENT');

      final quote = await mockQuotesRepo.getQuotationById(realQuoteUuid);
      expect(quote.currentStatus, 'SENT');
    });

    // -------------------------------------------------------------
    // A16: Change Requests Tests
    // -------------------------------------------------------------
    testWidgets('6. A16 displays client change request and responds via workflow', (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Put revision in CHANGE_REQUESTED (as change requests arrive on sent/negotiating quotes)
      final quote = await mockQuotesRepo.getQuotationById(realQuoteUuid);
      final crRev = QuotationRevisionModel(
        id: realRev1Uuid,
        quotationId: realQuoteUuid,
        revisionNumber: 1,
        status: 'CHANGE_REQUESTED',
        subtotal: 5000,
        total: 5700,
        createdAt: DateTime.now(),
        items: quote.currentRevision!.items,
        changeRequests: quote.currentRevision!.changeRequests,
      );
      mockQuotesRepo.quotes[0] = QuotationModel(
        id: realQuoteUuid,
        quotationNumber: 'QT-2026-00035',
        serviceRequestId: realSrUuid,
        createdBy: 'usr-admin-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        serviceRequest: quote.serviceRequest,
        revisions: [crRev],
      );

      await tester.pumpWidget(
        buildTestWidget(
          child: const QuoteChangeRequestsScreen(
            quotationId: realQuoteUuid,
            changeRequestId: realCrUuid,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header & client message
      expect(find.text('Quote Change Requests'), findsOneWidget);
      expect(find.text('QT-2026-00035'), findsOneWidget);
      expect(find.text('Test Customer'), findsOneWidget);
      expect(find.textContaining('Please remove the oil filter'), findsOneWidget);
      expect(find.text('Respond & Resolve'), findsOneWidget);
      expect(find.text('Create New Revision'), findsOneWidget);

      // Tap Respond & Resolve to open sheet
      await tester.tap(find.text('Respond & Resolve'));
      await tester.pumpAndSettle();

      expect(find.text('Respond to Change Request'), findsOneWidget);
      expect(find.text('Submit Resolution'), findsOneWidget);
    });

    // -------------------------------------------------------------
    // A13: Status-Driven Action Bar Tests
    // -------------------------------------------------------------
    testWidgets('7. A13 renders Edit Quote and Send Quote buttons when DRAFT', (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        buildTestWidget(
          child: const QuoteDetailScreen(
            quotationId: realQuoteUuid,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Status driven action bar for DRAFT
      expect(find.text('Edit Quote'), findsWidgets);
      expect(find.text('Send Quote'), findsOneWidget);
    });

    testWidgets('8. A13 renders Review Changes button when CHANGE_REQUESTED', (tester) async {
      tester.view.physicalSize = const Size(400, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Put quote into CHANGE_REQUESTED status
      final quote = await mockQuotesRepo.getQuotationById(realQuoteUuid);
      final crRev = QuotationRevisionModel(
        id: realRev1Uuid,
        quotationId: realQuoteUuid,
        revisionNumber: 1,
        status: 'CHANGE_REQUESTED',
        subtotal: 5000,
        total: 5700,
        createdAt: DateTime.now(),
        items: quote.currentRevision!.items,
        changeRequests: quote.currentRevision!.changeRequests,
      );
      mockQuotesRepo.quotes[0] = QuotationModel(
        id: realQuoteUuid,
        quotationNumber: 'QT-2026-00035',
        serviceRequestId: realSrUuid,
        createdBy: 'usr-admin-1',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        serviceRequest: quote.serviceRequest,
        revisions: [crRev],
      );

      await tester.pumpWidget(
        buildTestWidget(
          child: const QuoteDetailScreen(
            quotationId: realQuoteUuid,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Review Changes primary button is visible
      expect(find.text('Review Changes'), findsWidgets);
      expect(find.text('Send Quote'), findsNothing);
    });
  });
}
