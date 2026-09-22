import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
      expect(find.text('Quotation Lifecycle'), findsOneWidget);
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
  });
}
