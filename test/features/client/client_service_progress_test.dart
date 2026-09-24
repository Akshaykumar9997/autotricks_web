import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/features/client/components/service_progress_tracker.dart';
import 'package:autotricks/features/client/screens/client_home_screen.dart';
import 'package:autotricks/features/client/screens/client_service_request_detail_screen.dart';
import '../../helpers/mock_repositories.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('Day 12 — Client Live Service Progress Tests', () {
    testWidgets('ServiceProgressTracker renders all 7 steps with correct state badges', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ServiceProgressTracker(currentStatus: 'WORK_IN_PROGRESS'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify all 7 steps appear
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.text('Vehicle Received'), findsOneWidget);
      expect(find.text('Inspection'), findsOneWidget);
      expect(find.text('Work In Progress'), findsOneWidget);
      expect(find.text('Quality Check'), findsOneWidget);
      expect(find.text('Ready for Delivery'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);

      // Verify checkmarks for past steps (Scheduled, Vehicle Received, Inspection = 3 check icons)
      expect(find.byIcon(Icons.check), findsNWidgets(3));

      // Verify active badge for Work In Progress
      expect(find.text('Active'), findsOneWidget);
    });

    testWidgets('ClientHomeScreen renders Active Service Job card when job is active', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final clientRepo = MockClientPortalRepository();
      clientRepo.serviceJobs = [
        MockClientPortalRepository.createSampleJob(
          id: 'job-client-active',
          jobNumber: 'JOB-202609-0099',
          status: 'WORK_IN_PROGRESS',
        ),
      ];

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Active Service section header
      expect(find.text('YOUR ACTIVE SERVICE'), findsOneWidget);
      expect(find.text('JOB #JOB-202609-0099'), findsOneWidget);
      expect(find.text('Work In Progress'), findsWidgets);
      expect(find.text('Honda City · 2022'), findsWidgets);

      // Tracker is rendered inside active service card
      expect(find.byType(ServiceProgressTracker), findsOneWidget);
    });

    testWidgets('ClientServiceRequestDetailScreen renders Live Progress Tracker when converted to job', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final clientRepo = MockClientPortalRepository();
      final sampleJob = MockClientPortalRepository.createSampleJob(
        id: 'job-sr-link',
        jobNumber: 'JOB-202609-0088',
        serviceRequestId: 'sr-client-3',
        status: 'WORK_IN_PROGRESS',
      );
      clientRepo.serviceJobs = [sampleJob];

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientServiceRequestDetailScreen(requestId: 'sr-client-3'),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Live Progress card
      expect(find.text('LIVE SERVICE PROGRESS'), findsOneWidget);
      expect(find.text('JOB-202609-0088'), findsOneWidget);
      expect(find.byType(ServiceProgressTracker), findsOneWidget);
      expect(find.text('Service Tasks'), findsOneWidget);
    });

    testWidgets('Realtime trigger fires listener and refreshes client view', (tester) async {
      final clientRepo = MockClientPortalRepository();
      var triggerCount = 0;

      final channel = clientRepo.subscribeToClientJobs(() {
        triggerCount++;
      });

      expect(channel, isNotNull);
      expect(triggerCount, equals(0));

      // Trigger realtime event
      clientRepo.triggerJobChanged();
      expect(triggerCount, equals(1));
    });
  });
}
