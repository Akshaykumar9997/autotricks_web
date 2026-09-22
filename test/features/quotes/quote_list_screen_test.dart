import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/features/quotes/screens/quote_list_screen.dart';
import '../../helpers/mock_repositories.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('A12 QuoteListScreen Widget Tests', () {
    late MockQuotationsRepository mockQuotesRepo;

    setUp(() {
      mockQuotesRepo = MockQuotationsRepository();
    });

    testWidgets('renders quote list with status filter chips and count metric', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestWidget(
          child: const QuoteListScreen(),
          quotationsRepo: mockQuotesRepo,
        ),
      );

      await tester.pumpAndSettle();

      // Check header title & count metric
      expect(find.text('Quotations'), findsWidgets);
      expect(find.textContaining('Total Quotes:'), findsOneWidget);

      // Verify no forbidden operational terminology
      expect(find.textContaining('Telemetry'), findsNothing);
      expect(find.textContaining('Queue'), findsNothing);
      expect(find.textContaining('Bay'), findsNothing);
      expect(find.textContaining('Technician'), findsNothing);
      expect(find.textContaining('Workshop'), findsNothing);

      // Verify initial status filter chips exist
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);
      expect(find.text('Viewed'), findsOneWidget);

      // Check quotes are listed
      expect(find.text('QT-2026-00012'), findsOneWidget);
      expect(find.text('QT-2026-00013'), findsOneWidget);
      expect(find.text('QT-2026-00014'), findsOneWidget);
      expect(find.text('QT-2026-00015'), findsOneWidget);
      expect(find.text('Rahul Kumar'), findsOneWidget);
      expect(find.text('Priya Nair'), findsOneWidget);
      expect(find.text('Amit Patel'), findsOneWidget);
      expect(find.text('Vikram Seth'), findsOneWidget);
    });

    testWidgets('filters quotations by status chip tap (Sent, Viewed, Cancelled, Draft)', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestWidget(
          child: const QuoteListScreen(),
          quotationsRepo: mockQuotesRepo,
        ),
      );

      await tester.pumpAndSettle();

      // All 9 status chips visible on wide surface
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Sent'), findsOneWidget);
      expect(find.text('Viewed'), findsOneWidget);
      expect(find.text('Change Requested'), findsOneWidget);
      expect(find.text('Accepted'), findsOneWidget);
      expect(find.text('Rejected'), findsOneWidget);
      expect(find.text('Expired'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);

      // 1. Tap 'Sent' status chip
      await tester.tap(find.text('Sent'));
      await tester.pumpAndSettle();

      expect(find.text('QT-2026-00013'), findsOneWidget);
      expect(find.text('QT-2026-00012'), findsNothing);
      expect(find.text('QT-2026-00014'), findsNothing);
      expect(find.text('QT-2026-00015'), findsNothing);

      // 2. Tap 'Viewed' status chip
      await tester.tap(find.text('Viewed'));
      await tester.pumpAndSettle();

      expect(find.text('QT-2026-00014'), findsOneWidget);
      expect(find.text('QT-2026-00012'), findsNothing);
      expect(find.text('QT-2026-00013'), findsNothing);
      expect(find.text('QT-2026-00015'), findsNothing);

      // 3. Tap 'Cancelled' status chip
      await tester.tap(find.text('Cancelled'));
      await tester.pumpAndSettle();

      expect(find.text('QT-2026-00015'), findsOneWidget);
      expect(find.text('QT-2026-00012'), findsNothing);
      expect(find.text('QT-2026-00013'), findsNothing);
      expect(find.text('QT-2026-00014'), findsNothing);

      // 4. Tap 'Draft' status chip
      await tester.tap(find.text('Draft'));
      await tester.pumpAndSettle();

      expect(find.text('QT-2026-00012'), findsOneWidget);
      expect(find.text('QT-2026-00013'), findsNothing);
      expect(find.text('QT-2026-00014'), findsNothing);
      expect(find.text('QT-2026-00015'), findsNothing);

      // 5. Tap 'All' to return to full list
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      expect(find.text('QT-2026-00012'), findsOneWidget);
      expect(find.text('QT-2026-00013'), findsOneWidget);
      expect(find.text('QT-2026-00014'), findsOneWidget);
      expect(find.text('QT-2026-00015'), findsOneWidget);
    });

    testWidgets('filters quotations by search query', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestWidget(
          child: const QuoteListScreen(),
          quotationsRepo: mockQuotesRepo,
        ),
      );

      await tester.pumpAndSettle();

      // Enter search query 'Rahul'
      await tester.enterText(find.byType(TextField), 'Rahul');
      await tester.pumpAndSettle();

      expect(find.text('QT-2026-00012'), findsOneWidget);
      expect(find.text('QT-2026-00013'), findsNothing);

      // Enter search query with no match
      await tester.enterText(find.byType(TextField), 'NonExistentPerson');
      await tester.pumpAndSettle();

      expect(find.text('No quotations found'), findsOneWidget);
    });
  });
}
