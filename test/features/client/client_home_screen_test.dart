import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/features/client/screens/client_home_screen.dart';
import '../../helpers/mock_repositories.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('C02 — Client Home Screen Tests', () {
    testWidgets('Renders client greeting, active request card, and vehicles preview', (tester) async {
      final clientRepo = MockClientPortalRepository();

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar & greeting
      expect(find.textContaining('Rahul', findRichText: true), findsOneWidget);
      expect(find.text('2 Vehicles Registered'), findsOneWidget);

      // Section titles
      expect(find.text('CURRENT SERVICE REQUEST'), findsOneWidget);
      expect(find.text('MY VEHICLES'), findsOneWidget);
      expect(find.text('RECENT ACTIVITY'), findsOneWidget);

      // Active Request content
      expect(find.text('Under Review'), findsWidgets);
      expect(find.text('SR-2026-00021'), findsOneWidget);

      // Vehicle preview
      expect(find.text('Honda City · 2022'), findsWidgets);
      expect(find.text('KA-01-MJ-4412'), findsWidgets);
    });

    testWidgets('CRITICAL: Never displays internal admin_notes or technician costing', (tester) async {
      final clientRepo = MockClientPortalRepository();

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Routine 25k service + noticeable brake squeal.'), findsNothing);
      expect(find.textContaining('internal_margin', findRichText: true), findsNothing);
      expect(find.textContaining('Admin Notes', findRichText: true), findsNothing);
    });

    testWidgets('Test 6: Client dashboard quotation summary reflects latest active revision', (tester) async {
      final clientRepo = MockClientPortalRepository();

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Should display quotation banner powered by clientQuotationsProvider
      expect(find.text('ACTION REQUIRED'), findsOneWidget);
      expect(find.text('Your Quotation is Ready for Review'), findsOneWidget);
      expect(find.textContaining('QT-2026-00037', findRichText: true), findsOneWidget);
      expect(find.text('Review Quotation'), findsOneWidget);
      expect(find.text('₹21000'), findsOneWidget);
    });
  });
}
