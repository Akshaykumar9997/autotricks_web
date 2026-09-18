import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/features/service_requests/screens/service_request_detail_screen.dart';
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
      expect(find.text('Cancel Request'), findsOneWidget);
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

      // Upon review transition, status becomes UNDER_REVIEW (in badge and timeline) and action becomes Create Quote
      expect(find.text('UNDER REVIEW'), findsNWidgets(2));
      expect(find.text('Create Quote'), findsOneWidget);
    });
  });
}
