import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/features/service_jobs/screens/service_job_detail_screen.dart';
import '../../helpers/mock_repositories.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('A24 — Admin Service Job Detail Screen Tests', () {
    late MockServiceJobsRepository jobsRepo;

    setUp(() {
      jobsRepo = MockServiceJobsRepository();
    });

    testWidgets('Renders Service Job details, header, stepper, vehicle, and work items', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestWidget(
          serviceJobsRepo: jobsRepo,
          child: const ServiceJobDetailScreen(jobId: 'job-admin-1'),
        ),
      );
      await tester.pumpAndSettle();

      // Verify Header & Job Number
      expect(find.text('JOB #JOB-202609-0001'), findsOneWidget);
      expect(find.text('Scheduled'), findsWidgets);

      // Verify Customer & Vehicle Context
      expect(find.text('Vikram Mehta'), findsOneWidget);
      expect(find.text('Honda City · 2022'), findsOneWidget);
      expect(find.text('KA-01-MJ-4412'), findsWidgets);

      // Verify Next Action Stepper Button
      expect(find.text('Mark Vehicle Received'), findsOneWidget);

      // Verify Work Items Card
      expect(find.text('Periodic Maintenance Service'), findsOneWidget);
      expect(find.text('Front Brake Pads Replacement'), findsOneWidget);

      // Verify Status History Card
      expect(find.text('STATUS HISTORY'), findsOneWidget);
      expect(find.text('Job created from accepted quotation'), findsOneWidget);
    });

    testWidgets('Tapping next action button opens confirmation dialog and advances status', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        createTestWidget(
          serviceJobsRepo: jobsRepo,
          child: const ServiceJobDetailScreen(jobId: 'job-admin-1'),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Mark Vehicle Received' button
      final receiveBtn = find.text('Mark Vehicle Received');
      expect(receiveBtn, findsOneWidget);
      await tester.tap(receiveBtn);
      await tester.pumpAndSettle();

      // Verify confirmation dialog opened
      expect(find.text('Confirm Status Update'), findsOneWidget);
      expect(find.text('Vehicle Received'), findsWidgets);

      // Confirm transition in dialog
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Update Status');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Job status should now be advanced to VEHICLE_RECEIVED
      expect(find.text('Start Inspection'), findsOneWidget);
    });
  });
}
