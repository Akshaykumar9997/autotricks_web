import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/features/service_requests/screens/service_requests_list_screen.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A03 — Service Requests List Screen Tests', () {
    testWidgets('Renders app bar, search bar, filter tabs, and request cards', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const ServiceRequestsListScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Top bar & Search
      expect(find.text('Requests'), findsOneWidget);
      expect(find.text('ADMIN OPERATIONS'), findsOneWidget);
      expect(find.text('Search request #, customer, vehicle...'), findsOneWidget);

      // Filter tabs
      expect(find.text('All'), findsOneWidget);
      expect(find.text('New'), findsOneWidget);
      expect(find.text('Under Review'), findsOneWidget);

      // Request Cards from mock repository
      expect(find.text('#SR-2026-00021'), findsOneWidget);
      expect(find.text('Rahul Kumar'), findsOneWidget);
      expect(find.text('Honda City · 2022'), findsOneWidget);
      expect(find.text('Review Request'), findsOneWidget);

      // FAB
      expect(find.text('Create Request'), findsOneWidget);
    });

    testWidgets('Filters requests by search query', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const ServiceRequestsListScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('#SR-2026-00021'), findsOneWidget);
      expect(find.text('#SR-2026-00018'), findsOneWidget);

      // Type in search field
      final searchInput = find.byType(TextField);
      await tester.enterText(searchInput, 'Fortuner');
      await tester.pumpAndSettle();

      // SR-21 (Honda City) should be filtered out, SR-18 (Fortuner) remains
      expect(find.text('#SR-2026-00021'), findsNothing);
      expect(find.text('#SR-2026-00018'), findsOneWidget);
    });

    testWidgets('Filters requests by status chip', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const ServiceRequestsListScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Under Review' chip
      await tester.tap(find.text('Under Review'));
      await tester.pumpAndSettle();

      // Only Under Review item should be visible
      expect(find.text('#SR-2026-00018'), findsOneWidget);
      expect(find.text('#SR-2026-00021'), findsNothing);
    });
  });
}
