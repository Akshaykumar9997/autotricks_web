import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/features/clients/screens/client_list_screen.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A06 — Client List Screen Tests', () {
    testWidgets('Renders app bar, search bar, filter tabs, and client cards', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const ClientListScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Header & Navigation
      expect(find.text('Clients'), findsOneWidget);
      expect(find.text('New Client'), findsOneWidget);

      // Search & Filters
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);

      // Clients from MockClientVehicleRepository
      expect(find.text('Rahul Kumar'), findsOneWidget);
      expect(find.text('Arun Prakash'), findsOneWidget);
      expect(find.text('Priya Nair'), findsOneWidget);
    });

    testWidgets('Filters clients by search query', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const ClientListScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rahul Kumar'), findsOneWidget);
      expect(find.text('Arun Prakash'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Rahul');
      await tester.pumpAndSettle();

      expect(find.text('Rahul Kumar'), findsOneWidget);
      expect(find.text('Arun Prakash'), findsNothing);
    });

    testWidgets('Filters clients by status filter chip', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const ClientListScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Rahul Kumar'), findsOneWidget);

      // Tap Inactive filter (all mocks are active, so list becomes empty)
      await tester.tap(find.text('Inactive'));
      await tester.pumpAndSettle();

      expect(find.text('Rahul Kumar'), findsNothing);
      expect(find.textContaining('No clients match'), findsNothing);
      expect(find.text('No clients found'), findsOneWidget);
    });
  });
}
