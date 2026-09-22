import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/data/models/quotation_model.dart';
import 'package:autotricks/design_system/components/auto_error_state.dart';
import 'package:autotricks/features/client/screens/client_accept_quote_screen.dart';
import 'package:autotricks/features/client/screens/client_quote_detail_screen.dart';
import 'package:autotricks/features/client/screens/client_quote_rejected_screen.dart';
import 'package:autotricks/features/client/screens/client_quotes_screen.dart';
import 'package:autotricks/features/client/screens/client_request_changes_screen.dart';
import '../../helpers/mock_repositories.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('C07 — My Quotes Screen Tests', () {
    testWidgets('Renders header, action banner, filter tabs, and quote cards',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      final clientRepo = MockClientPortalRepository();

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientQuotesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Title & Header
      expect(find.text('My Quotes'), findsOneWidget);
      expect(find.text('Vehicle Estimates'), findsOneWidget);

      // Action Required Banner
      expect(find.text('Action Required'), findsOneWidget);
      expect(find.textContaining('awaiting your review'), findsOneWidget);

      // Filter tabs: All (4), Active (3), Past Quotes (1)
      expect(find.text('All (4)'), findsOneWidget);
      expect(find.text('Active (3)'), findsOneWidget); // SENT, CHANGE_REQUESTED, ACCEPTED
      expect(find.text('Past Quotes (1)'), findsOneWidget); // REJECTED

      // Quote Cards
      expect(find.textContaining('QT-2026-00037'), findsOneWidget);
      expect(find.textContaining('QT-2026-00038'), findsOneWidget);
      expect(find.textContaining('QT-2026-00036'), findsOneWidget);
      expect(find.textContaining('QT-2026-00035'), findsOneWidget);
      expect(find.text('₹21000'), findsOneWidget);
    });

    testWidgets('Active filter includes SENT, CHANGE_REQUESTED, and ACCEPTED quotes',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      final clientRepo = MockClientPortalRepository();

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientQuotesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Active tab
      await tester.tap(find.text('Active (3)'));
      await tester.pumpAndSettle();

      // Active quotes must be visible
      expect(find.textContaining('QT-2026-00037'), findsOneWidget); // SENT
      expect(find.textContaining('QT-2026-00038'), findsOneWidget); // CHANGE_REQUESTED
      expect(find.textContaining('QT-2026-00036'), findsOneWidget); // ACCEPTED

      // REJECTED quote should NOT be in Active
      expect(find.textContaining('QT-2026-00035'), findsNothing);
    });

    testWidgets('Past Quotes filter includes REJECTED, SUPERSEDED, CANCELLED, EXPIRED quotes',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      final clientRepo = MockClientPortalRepository();

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientQuotesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Past Quotes tab
      await tester.ensureVisible(find.text('Past Quotes (1)'));
      await tester.tap(find.text('Past Quotes (1)'));
      await tester.pumpAndSettle();

      // Only REJECTED quote visible
      expect(find.textContaining('QT-2026-00035'), findsOneWidget);
      expect(find.textContaining('QT-2026-00037'), findsNothing);
      expect(find.textContaining('QT-2026-00038'), findsNothing);
      expect(find.textContaining('QT-2026-00036'), findsNothing);
    });

    testWidgets('CRITICAL: Never renders GST or VAT terminology', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      final clientRepo = MockClientPortalRepository();

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientQuotesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify no GST or VAT is rendered anywhere
      expect(find.textContaining('GST', findRichText: true), findsNothing);
      expect(find.textContaining('gst', findRichText: true), findsNothing);
      expect(find.textContaining('VAT', findRichText: true), findsNothing);
      expect(find.textContaining('vat', findRichText: true), findsNothing);
    });
  });

  group('C08 — Quote Detail Screen Tests', () {
    testWidgets('Renders quote header, line items, cost summary, and dynamic revision history',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      final clientRepo = MockClientPortalRepository();

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientQuoteDetailScreen(quotationId: 'q-client-1'),
        ),
      );
      await tester.pumpAndSettle();

      // Header info
      expect(find.text('QT-2026-00037'), findsWidgets);
      expect(find.text('Honda City · 2022'), findsWidgets);

      // Line items
      expect(find.text('QUOTATION ITEMS (2)'), findsOneWidget);
      expect(find.text('Engine Oil & Filter Replacement'), findsOneWidget);
      expect(find.text('Front Brake Pad Set & Rotor Skimming'), findsOneWidget);
      expect(find.text('₹5500'), findsOneWidget);
      expect(find.text('₹12500'), findsOneWidget);

      // Cost summary
      expect(find.text('COST SUMMARY'), findsOneWidget);
      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('₹18000'), findsOneWidget);
      expect(find.text('Tax'), findsOneWidget);
      expect(find.text('₹3000'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('₹21000'), findsWidgets);

      // Bottom actions
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Request Changes'), findsOneWidget);
      expect(find.text('Accept Quote'), findsOneWidget);

      // Verify zero GST / VAT
      expect(find.textContaining('GST', findRichText: true), findsNothing);
      expect(find.textContaining('VAT', findRichText: true), findsNothing);
    });

    testWidgets('Renders dynamic revision history with submitted change requests',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      final clientRepo = MockClientPortalRepository();

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientQuoteDetailScreen(quotationId: 'q-client-2'),
        ),
      );
      await tester.pumpAndSettle();

      // Dynamic revision history should show change request message
      expect(find.text('REVISION HISTORY'), findsOneWidget);
      expect(find.text('Revision 1'), findsWidgets);
      expect(
        find.text('“Please exclude tyre rotation as it was done recently.”'),
        findsOneWidget,
      );
    });
  });

  group('C09 — Request Quote Changes Screen Tests', () {
    testWidgets('Enforces validation and submits change request', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      final clientRepo = MockClientPortalRepository();

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientRequestChangesScreen(quotationId: 'q-client-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Request Changes'), findsOneWidget);
      expect(find.text('What would you like adjusted?'), findsOneWidget);
      expect(find.text('0 / 500'), findsOneWidget);

      // Submit button should initially be disabled
      final submitButton = find.widgetWithText(ElevatedButton, 'Submit Request');
      expect(tester.widget<ElevatedButton>(submitButton).enabled, isFalse);

      // Type valid change note
      await tester.enterText(
        find.byType(TextField),
        'Please check if ceramic brake pads are included in this estimate.',
      );
      await tester.pumpAndSettle();

      expect(tester.widget<ElevatedButton>(submitButton).enabled, isTrue);

      // Tap Submit Request
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify status changed in mock repo
      final updatedQuote = await clientRepo.getQuotationById('q-client-1');
      expect(updatedQuote.currentStatus, 'CHANGE_REQUESTED');
      expect(updatedQuote.latestRevision!.changeRequests.isNotEmpty, isTrue);
    });
  });

  group('C10 — Accept Quote + Consent Screen Tests', () {
    testWidgets('Enforces consent checkbox and legal disclaimer before acceptance',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      final clientRepo = MockClientPortalRepository();

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientAcceptQuoteScreen(quotationId: 'q-client-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Accept Quotation'), findsWidgets);
      expect(find.text('CLIENT ACCEPTANCE & CONSENT'), findsOneWidget);

      // Legal disclaimer check
      expect(
        find.textContaining('Digital signature authorization in the next step is required'),
        findsOneWidget,
      );
      expect(
        find.textContaining('does not automatically schedule, authorize, or start'),
        findsOneWidget,
      );

      // Accept button initially disabled
      final acceptButton = find.widgetWithText(ElevatedButton, 'Accept Quotation');
      expect(tester.widget<ElevatedButton>(acceptButton).enabled, isFalse);

      // Toggle consent checkbox
      await tester.tap(find.byType(Checkbox));
      await tester.pumpAndSettle();

      expect(tester.widget<ElevatedButton>(acceptButton).enabled, isTrue);

      // Tap Accept Quotation
      await tester.tap(acceptButton);
      await tester.pumpAndSettle();

      // Verify status updated to ACCEPTED
      final updatedQuote = await clientRepo.getQuotationById('q-client-1');
      expect(updatedQuote.currentStatus, 'ACCEPTED');
      expect(updatedQuote.latestRevision!.acceptedAt, isNotNull);
      expect(
        updatedQuote.latestRevision!.acceptanceConsentText,
        contains('I understand that digital signature authorization in the next step is required'),
      );
    });
  });

  group('C12 — Quote Rejected Screen Tests', () {
    testWidgets('Renders decline headline, strikethrough voided total, and reason',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      final clientRepo = MockClientPortalRepository();

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientQuoteRejectedScreen(quotationId: 'q-client-4'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Quotation Declined'), findsWidgets);
      expect(find.text('DECLINED'), findsOneWidget);
      expect(find.text('Voided Total'), findsOneWidget);
      expect(find.text('₹5000'), findsOneWidget);
      expect(find.text('“Postponed due to personal schedule.”'), findsOneWidget);
      expect(find.text('Back to Services'), findsOneWidget);
      expect(find.text('Contact AutoTricks'), findsOneWidget);
    });
  });

  group('Client Quotations Security & Isolation Tests', () {
    testWidgets('Draft revisions are never exposed to clients', (tester) async {
      final clientRepo = MockClientPortalRepository();

      // Add a draft revision to a new quote
      clientRepo.quotations.add(
        QuotationModel(
          id: 'q-draft-internal',
          quotationNumber: 'QT-2026-DRAFT',
          serviceRequestId: 'sr-client-1',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          revisions: [
            QuotationRevisionModel(
              id: 'rev-draft-1',
              quotationId: 'q-draft-internal',
              revisionNumber: 1,
              status: 'DRAFT',
              subtotal: 5000,
              total: 5000,
              createdAt: DateTime.now(),
            ),
          ],
        ),
      );

      final clientQuotes = await clientRepo.fetchClientQuotations();
      final hasDraft = clientQuotes.any((q) => q.currentStatus == 'DRAFT');
      expect(hasDraft, isFalse);
    });
  });

  group('Revision 2 Visibility & Multi-Revision Client Tests', () {
    late MockClientPortalRepository clientRepo;

    setUp(() {
      clientRepo = MockClientPortalRepository();

      // Configure multi-revision quotation replicating the exact scenario:
      // Revision 1: SUPERSEDED (subtotal: 20000, tax: 1000, total: 21000), change request: "the price is bit high"
      // Revision 2: SENT (subtotal: 10000, tax: 1000, total: 11000)
      final multiRevQuote = QuotationModel(
        id: 'q-client-multi-rev',
        quotationNumber: 'QT-2026-00037',
        serviceRequestId: 'sr-client-1',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 10)),
        serviceRequest: clientRepo.serviceRequests[0],
        revisions: [
          QuotationRevisionModel(
            id: 'rev-2-sent',
            quotationId: 'q-client-multi-rev',
            revisionNumber: 2,
            status: 'SENT',
            subtotal: 10000,
            discount: 0,
            tax: 1000,
            total: 11000,
            createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
            sentAt: DateTime.now().subtract(const Duration(minutes: 10)),
            items: [
              QuotationItemModel(
                id: 'item-r2-1',
                quotationRevisionId: 'rev-2-sent',
                name: 'Alto engine injector',
                description: 'Refurbished OEM fuel injector unit',
                quantity: 5,
                finalValue: 2000,
                lineTotal: 10000,
                createdAt: DateTime.now().subtract(const Duration(minutes: 15)),
                updatedAt: DateTime.now().subtract(const Duration(minutes: 15)),
              ),
            ],
          ),
          QuotationRevisionModel(
            id: 'rev-1-superseded',
            quotationId: 'q-client-multi-rev',
            revisionNumber: 1,
            status: 'SUPERSEDED',
            subtotal: 20000,
            discount: 0,
            tax: 1000,
            total: 21000,
            createdAt: DateTime.now().subtract(const Duration(hours: 3)),
            sentAt: DateTime.now().subtract(const Duration(hours: 2)),
            items: [
              QuotationItemModel(
                id: 'item-r1-1',
                quotationRevisionId: 'rev-1-superseded',
                name: 'Alto engine injector',
                description: 'Full injector assembly set',
                quantity: 10,
                finalValue: 2000,
                lineTotal: 20000,
                createdAt: DateTime.now().subtract(const Duration(hours: 3)),
                updatedAt: DateTime.now().subtract(const Duration(hours: 3)),
              ),
            ],
            changeRequests: [
              QuotationChangeRequestModel(
                id: 'cr-r1-1',
                quotationRevisionId: 'rev-1-superseded',
                clientId: '2bd5d7fb-3b55-48b1-931f-69896d3f0838',
                profileId: '907fcf18-982c-4b93-932f-f6ec7f5d3635',
                message: 'the price is bit high',
                status: 'ACCEPTED',
                createdAt: DateTime.now().subtract(const Duration(hours: 1)),
              ),
            ],
          ),
        ],
      );

      // Replace or set as first quotation
      clientRepo.quotations.removeWhere((q) => q.id == 'q-client-1');
      clientRepo.quotations.insert(0, multiRevQuote);
    });

    testWidgets('C07 shows Revision 2 as latest/current revision with correct amount and Rev badge',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientQuotesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Quotation number with Rev 2 tag
      expect(find.textContaining('QT-2026-00037'), findsOneWidget);
      expect(find.textContaining('Rev 2'), findsOneWidget);

      // Revision 2 amount (₹11000)
      expect(find.text('₹11000'), findsOneWidget);

      // Revision 2 status (Awaiting Review)
      expect(find.text('Awaiting Review'), findsWidgets);

      // Review Quote action button
      expect(find.widgetWithText(ElevatedButton, 'Review Quote'), findsWidgets);
    });

    testWidgets('C08 shows Revision 2 as Current and Revision 1 in dynamic revision history',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientQuoteDetailScreen(quotationId: 'q-client-multi-rev'),
        ),
      );
      await tester.pumpAndSettle();

      // Top Header: Revision 2 tag
      expect(find.text('Revision 2'), findsWidgets);

      // Items Section: Revision 2 items only
      expect(find.text('QUOTATION ITEMS (1)'), findsOneWidget);
      expect(find.text('Alto engine injector'), findsOneWidget);

      // Cost Summary: Revision 2 financials
      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('₹10000'), findsWidgets);
      expect(find.text('Tax'), findsOneWidget);
      expect(find.text('₹1000'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
      expect(find.text('₹11000'), findsWidgets);

      // Action buttons available for SENT Revision 2
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Request Changes'), findsOneWidget);
      expect(find.text('Accept Quote'), findsOneWidget);

      // Dynamic Revision History: Contains both Revision 2 (Current) and Revision 1 (Superseded)
      expect(find.text('REVISION HISTORY'), findsOneWidget);
      expect(find.text('Current'), findsOneWidget);
      expect(find.text('Superseded'), findsOneWidget);
      expect(find.text('“the price is bit high”'), findsOneWidget);
    });

    testWidgets('C08 shields un-sent DRAFT Revision 3 and continues displaying Revision 2',
        (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      // Add a DRAFT Revision 3 to the quotation
      final quote = clientRepo.quotations.firstWhere((q) => q.id == 'q-client-multi-rev');
      final updatedRevisions = List<QuotationRevisionModel>.from(quote.revisions)
        ..insert(
          0,
          QuotationRevisionModel(
            id: 'rev-3-draft',
            quotationId: 'q-client-multi-rev',
            revisionNumber: 3,
            status: 'DRAFT',
            subtotal: 5000,
            total: 5000,
            createdAt: DateTime.now(),
          ),
        );
      clientRepo.quotations[0] = QuotationModel(
        id: quote.id,
        quotationNumber: quote.quotationNumber,
        serviceRequestId: quote.serviceRequestId,
        createdAt: quote.createdAt,
        updatedAt: DateTime.now(),
        serviceRequest: quote.serviceRequest,
        revisions: updatedRevisions,
      );

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientQuoteDetailScreen(quotationId: 'q-client-multi-rev'),
        ),
      );
      await tester.pumpAndSettle();

      // Revision 3 (DRAFT) must NEVER appear
      expect(find.text('Revision 3'), findsNothing);
      expect(find.text('Draft'), findsNothing);

      // Revision 2 remains the visible current revision
      expect(find.text('Revision 2'), findsWidgets);
      expect(find.text('₹11000'), findsWidgets);
    });
  });

  group('Test 7: Repository / parsing failure produces clear error state instead of blank screen', () {
    testWidgets('C07 displays AutoErrorState on fetch failure', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      final throwingRepo = _ThrowingClientPortalRepository();

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: throwingRepo,
          child: const ClientQuotesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AutoErrorState), findsOneWidget);
      expect(find.text('Unable to Load Quotes'), findsOneWidget);
      expect(find.text('Unable to load your quotations. Please try again.'), findsOneWidget);
    });

    testWidgets('C08 displays AutoErrorState on quotation detail load failure', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.resetPhysicalSize);

      final throwingRepo = _ThrowingClientPortalRepository();

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: throwingRepo,
          child: const ClientQuoteDetailScreen(quotationId: 'failing-id'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(AutoErrorState), findsOneWidget);
      expect(find.text('Unable to Load Quotation'), findsOneWidget);
      expect(find.text('Unable to load quotation details. Please try again.'), findsOneWidget);
    });
  });
}

class _ThrowingClientPortalRepository extends MockClientPortalRepository {
  @override
  Future<List<QuotationModel>> fetchClientQuotations() async {
    throw Exception('PostgREST query or model deserialization failed');
  }

  @override
  Future<QuotationModel> getQuotationById(String id) async {
    throw Exception('PostgREST query or model deserialization failed');
  }
}
