import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/data/models/quotation_model.dart';
import 'package:autotricks/features/quotes/screens/quote_detail_screen.dart';
import '../../helpers/mock_repositories.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('A13 QuoteDetailScreen Widget Tests', () {
    late MockQuotationsRepository mockQuotesRepo;

    setUp(() {
      mockQuotesRepo = MockQuotationsRepository();
    });

    testWidgets('renders quote detail with line items, client, and financial summary', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestWidget(
          child: const QuoteDetailScreen(quotationId: 'quote-1'),
          quotationsRepo: mockQuotesRepo,
        ),
      );

      await tester.pumpAndSettle();

      // Verify header & quote number
      expect(find.text('QT-2026-00012'), findsWidgets);
      expect(find.textContaining('Revision 1'), findsWidgets);

      // Verify customer & vehicle information
      expect(find.text('Rahul Kumar'), findsOneWidget);
      expect(find.text('+91 98450 12890'), findsOneWidget);
      expect(find.text('KA 01 MJ 5022'), findsOneWidget);

      // Verify line items are rendered from snapshot
      expect(find.textContaining('Synthetic Engine Oil (5W-30)'), findsOneWidget);
      expect(find.textContaining('Front Ceramic Brake Pad Set'), findsOneWidget);
      expect(find.textContaining('Comprehensive Brake System Overhaul Labour'), findsOneWidget);

      // Verify financial breakdown shows exact stored tax without hardcoded rates
      expect(find.text('Subtotal'), findsOneWidget);
      expect(find.text('Discount'), findsOneWidget);
      expect(find.text('Tax'), findsOneWidget);
      expect(find.text('+₹3150'), findsOneWidget); // Actual stored tax on quote-1 revision
      expect(find.text('TOTAL QUOTATION VALUE'), findsOneWidget);

      // Verify NO hardcoded tax percentages or labels
      expect(find.textContaining('18%'), findsNothing);
      expect(find.textContaining('GST'), findsNothing);
      expect(find.textContaining('VAT'), findsNothing);

      // Verify notes & terms
      expect(find.textContaining('Standard 25,000 km periodic inspection'), findsOneWidget);
      expect(find.textContaining('Prices valid for 15 days.'), findsOneWidget);

      // Verify quotation lifecycle timeline exists
      expect(find.textContaining('Quotation Lifecycle'), findsOneWidget);
      expect(find.text('DRAFT CREATED'), findsOneWidget);

      // Verify Day 8 status-driven actions for DRAFT quote
      expect(find.text('Edit Quote'), findsWidgets);
      expect(find.text('Send Quote'), findsOneWidget);

      // Verify forbidden operational terminology is absent
      expect(find.textContaining('Telemetry'), findsNothing);
      expect(find.textContaining('Queue'), findsNothing);
      expect(find.textContaining('Bay'), findsNothing);
      expect(find.textContaining('Technician'), findsNothing);
      expect(find.textContaining('Workshop'), findsNothing);
    });

    testWidgets('renders sent quote detail accurately', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestWidget(
          child: const QuoteDetailScreen(quotationId: 'quote-2'),
          quotationsRepo: mockQuotesRepo,
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('QT-2026-00013'), findsWidgets);
      expect(find.text('Priya Nair'), findsOneWidget);
      expect(find.textContaining('AC Gas R134a Recharge'), findsOneWidget);
    });

    testWidgets('Quotation lifecycle is revision-aware and allows switching active revision', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Construct a quote with Revision 1 (SUPERSEDED) and Revision 2 (ACCEPTED)
      final multiRevQuote = QuotationModel(
        id: 'quote-multi-rev',
        quotationNumber: 'QT-2026-00038',
        serviceRequestId: 'sr-1',
        createdBy: 'usr-admin-1',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
        revisions: [
          QuotationRevisionModel(
            id: 'rev-2-id',
            quotationId: 'quote-multi-rev',
            revisionNumber: 2,
            status: 'ACCEPTED',
            subtotal: 20000,
            discount: 0,
            tax: 3600,
            total: 23600,
            createdAt: DateTime.now().subtract(const Duration(days: 1)),
            sentAt: DateTime.now().subtract(const Duration(hours: 12)),
            acceptedAt: DateTime.now().subtract(const Duration(hours: 2)),
            items: [],
          ),
          QuotationRevisionModel(
            id: 'rev-1-id',
            quotationId: 'quote-multi-rev',
            revisionNumber: 1,
            status: 'SUPERSEDED',
            subtotal: 10000,
            discount: 0,
            tax: 1800,
            total: 11800,
            createdAt: DateTime.now().subtract(const Duration(days: 2)),
            sentAt: DateTime.now().subtract(const Duration(days: 2)),
            items: [],
          ),
        ],
      );

      final repo = MockQuotationsRepository(initialQuotes: [multiRevQuote]);

      await tester.pumpWidget(
        createTestWidget(
          child: const QuoteDetailScreen(quotationId: 'quote-multi-rev'),
          quotationsRepo: repo,
        ),
      );
      await tester.pumpAndSettle();

      // 1. Initial State: Revision 2 is active (ACCEPTED)
      expect(find.textContaining('Quotation Lifecycle · Revision 2'), findsOneWidget);
      expect(find.text('ACCEPTED / SIGNED'), findsOneWidget);
      expect(find.textContaining('Client signed & accepted'), findsWidgets);
      expect(find.text('Quotation Accepted · Locked'), findsOneWidget);

      // 2. Tap Revision 1 in the Revision History card
      final rev1HistoryTile = find.text('Revision 1');
      expect(rev1HistoryTile, findsOneWidget);
      await tester.tap(rev1HistoryTile);
      await tester.pumpAndSettle();

      // 3. Screen now displays Revision 1's actual lifecycle
      expect(find.textContaining('Quotation Lifecycle · Revision 1'), findsOneWidget);
      expect(find.text('SUPERSEDED'), findsWidgets);
      expect(find.text('Superseded by Revision 2'), findsOneWidget);
      expect(find.text('Viewing Revision 1 (SUPERSEDED)'), findsOneWidget);
      expect(find.text('View Current (R2)'), findsOneWidget);

      // 4. Tap 'View Current (R2)' button in bottom bar to switch back
      final viewCurrentBtn = find.text('View Current (R2)');
      await tester.tap(viewCurrentBtn);
      await tester.pumpAndSettle();

      // 5. Returned to Revision 2's lifecycle
      expect(find.textContaining('Quotation Lifecycle · Revision 2'), findsOneWidget);
      expect(find.text('ACCEPTED / SIGNED'), findsOneWidget);
    });
  });
}
