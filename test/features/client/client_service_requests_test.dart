import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/features/client/screens/client_service_request_detail_screen.dart';
import 'package:autotricks/features/client/screens/client_service_requests_screen.dart';
import '../../helpers/mock_repositories.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('C05 — Service Requests Screen Tests', () {
    testWidgets('Renders filter chips with accurate counts and dynamic status labels', (tester) async {
      final clientRepo = MockClientPortalRepository();

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientServiceRequestsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Service Requests'), findsOneWidget);

      // Filter chips with real counts:
      // Total: 4 (UNDER_REVIEW, CONVERTED_TO_JOB/WORK_IN_PROGRESS, CONVERTED_TO_JOB/COMPLETED, CANCELLED)
      // Active: 2 (UNDER_REVIEW, CONVERTED_TO_JOB/WORK_IN_PROGRESS)
      // Completed: 1 (CONVERTED_TO_JOB/COMPLETED)
      // Cancelled: 1 (CANCELLED)
      expect(find.text('All (4)'), findsOneWidget);
      expect(find.text('Active (2)'), findsOneWidget);
      expect(find.text('Completed (1)'), findsOneWidget);
      expect(find.text('Cancelled (1)'), findsOneWidget);

      // Dynamic customer status labels
      expect(find.text('Under Review'), findsOneWidget);
      expect(find.text('Service Started'), findsOneWidget);
      expect(find.text('Service Completed'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
    });

    testWidgets('Filtering to Completed shows only completed requests', (tester) async {
      final clientRepo = MockClientPortalRepository();

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientServiceRequestsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Completed filter chip
      await tester.tap(find.text('Completed (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Service Completed'), findsOneWidget);
      expect(find.text('Under Review'), findsNothing);
      expect(find.text('Service Started'), findsNothing);
    });

    testWidgets('Filtering to Cancelled shows only cancelled requests', (tester) async {
      final clientRepo = MockClientPortalRepository();

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientServiceRequestsScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on Cancelled filter chip
      await tester.tap(find.text('Cancelled (1)'));
      await tester.pumpAndSettle();

      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Under Review'), findsNothing);
      expect(find.text('Service Started'), findsNothing);
      expect(find.text('Service Completed'), findsNothing);
    });
  });

  group('C06 — Service Request Detail Screen Tests', () {
    const testRequestId = 'sr-client-1';

    testWidgets('Renders identifier, status explanation, vehicle info, and requested items', (tester) async {
      final clientRepo = MockClientPortalRepository();

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientServiceRequestDetailScreen(requestId: testRequestId),
        ),
      );
      await tester.pumpAndSettle();

      // Header & Request ID
      expect(find.text('Request Details'), findsOneWidget);
      expect(find.text('REQUEST ID'), findsOneWidget);
      expect(find.text('SR-2026-00021'), findsOneWidget);

      // Status banner
      expect(find.text('Under Review'), findsOneWidget);
      expect(find.text("We're reviewing your service request."), findsOneWidget);
      expect(find.textContaining('Our team is reviewing your vehicle service request'), findsOneWidget);

      // Vehicle Card
      expect(find.text('VEHICLE'), findsOneWidget);
      expect(find.text('Honda City · 2022'), findsOneWidget);
      expect(find.text('KA-01-MJ-4412'), findsOneWidget);
      expect(find.text('MAKGM2656N1028492'), findsOneWidget);

      // Service Request Details
      expect(find.text('SERVICE REQUEST DETAILS'), findsOneWidget);
      expect(find.text('Periodic Maintenance Service (PMS)'), findsOneWidget);
      expect(find.text('Front brake inspection & rotor check'), findsOneWidget);

      // Customer Symptom note
      expect(find.text('Reported Symptom'), findsOneWidget);
      expect(find.textContaining('Slight squeaking sound heard from front wheels'), findsOneWidget);

      // Upcoming Quotation Card
      expect(find.text('QUOTATION'), findsOneWidget);
      expect(find.text('Upcoming'), findsOneWidget);

      // Concierge support
      expect(find.text('Need help with your request?'), findsOneWidget);
      expect(find.text('Contact'), findsOneWidget);
    });

    testWidgets('CRITICAL: Never renders internal notes or internal technician information', (tester) async {
      final clientRepo = MockClientPortalRepository();

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientServiceRequestDetailScreen(requestId: testRequestId),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('admin_notes', findRichText: true), findsNothing);
      expect(find.textContaining('internal_margin', findRichText: true), findsNothing);
      expect(find.textContaining('technician_cost', findRichText: true), findsNothing);
    });
  });
}
