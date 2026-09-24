import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/data/models/service_job_model.dart';
import 'package:autotricks/features/service_jobs/screens/service_job_detail_screen.dart';
import '../../helpers/mock_repositories.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('Additional Work — Admin Workflow & UI Guards', () {
    late MockServiceJobsRepository jobsRepo;

    setUp(() {
      jobsRepo = MockServiceJobsRepository();
    });

    testWidgets('Add Additional Work button is visible during INSPECTION and WORK_IN_PROGRESS', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Advance job to INSPECTION
      jobsRepo.jobs[0] = jobsRepo.jobs[0].copyWith(status: 'INSPECTION');

      await tester.pumpWidget(
        createTestWidget(
          serviceJobsRepo: jobsRepo,
          child: const ServiceJobDetailScreen(jobId: 'job-admin-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Additional Work'), findsOneWidget);
    });

    testWidgets('Add Additional Work button is NOT visible when SCHEDULED', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Job is in SCHEDULED status by default
      await tester.pumpWidget(
        createTestWidget(
          serviceJobsRepo: jobsRepo,
          child: const ServiceJobDetailScreen(jobId: 'job-admin-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Add Additional Work'), findsNothing);
    });

    testWidgets('Admin can add additional work via dialog', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      jobsRepo.jobs[0] = jobsRepo.jobs[0].copyWith(status: 'WORK_IN_PROGRESS');

      await tester.pumpWidget(
        createTestWidget(
          serviceJobsRepo: jobsRepo,
          child: const ServiceJobDetailScreen(jobId: 'job-admin-1'),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Add Additional Work' button
      final addBtn = find.text('Add Additional Work');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Fill in dialog form
      final nameField = find.widgetWithText(TextFormField, 'e.g. Rear Brake Disc Replacement');
      expect(nameField, findsOneWidget);
      await tester.enterText(nameField, 'Rear Brake Rotors');

      final descField = find.widgetWithText(TextFormField, 'Discovered during inspection; describe reason & scope...');
      expect(descField, findsOneWidget);
      await tester.enterText(descField, 'Rotors worn beyond safe limits');

      final finalValField = find.widgetWithText(TextFormField, 'Final price presented to client for approval');
      expect(finalValField, findsOneWidget);
      await tester.enterText(finalValField, '4500');

      // Tap Add Work Item
      final submitBtn = find.widgetWithText(ElevatedButton, 'Add Work Item');
      expect(submitBtn, findsOneWidget);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Verify the new item is now displayed in ADDITIONAL WORK section
      expect(find.text('ADDITIONAL WORK (1)'), findsOneWidget);
      expect(find.text('Rear Brake Rotors'), findsOneWidget);
      expect(find.text('PENDING CLIENT APPROVAL'), findsOneWidget);
      expect(find.text('Quoted: ₹4500.00'), findsOneWidget);
    });

    testWidgets('Unapproved additional work displays lock icon and cannot be executed', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      jobsRepo.jobs[0] = jobsRepo.jobs[0].copyWith(
        status: 'WORK_IN_PROGRESS',
        workItems: [
          ...jobsRepo.jobs[0].workItems,
          ServiceWorkItemModel(
            id: 'wi-pending-1',
            serviceJobId: 'job-admin-1',
            name: 'Cabin Air Filter Replacement',
            description: 'Severe clogging detected',
            quantity: 1,
            finalValue: 1200,
            source: 'ADDITIONAL',
            approvalStatus: 'PENDING',
            status: 'PENDING',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      await tester.pumpWidget(
        createTestWidget(
          serviceJobsRepo: jobsRepo,
          child: const ServiceJobDetailScreen(jobId: 'job-admin-1'),
        ),
      );
      await tester.pumpAndSettle();

      // Verify lock icon is shown for pending item
      expect(find.byIcon(Icons.lock_clock_outlined), findsOneWidget);
      expect(find.text('PENDING CLIENT APPROVAL'), findsOneWidget);
    });

    testWidgets('Approved additional work displays APPROVED badge and can be executed', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      jobsRepo.jobs[0] = jobsRepo.jobs[0].copyWith(
        status: 'WORK_IN_PROGRESS',
        workItems: [
          ServiceWorkItemModel(
            id: 'wi-approved-1',
            serviceJobId: 'job-admin-1',
            name: 'Wiper Blades Replacement',
            description: 'Streaking wipers replaced',
            quantity: 2,
            finalValue: 800,
            approvedValue: 800,
            source: 'ADDITIONAL',
            approvalStatus: 'APPROVED',
            status: 'PENDING',
            decisionAt: now,
            approvalNote: 'Approved by customer',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      await tester.pumpWidget(
        createTestWidget(
          serviceJobsRepo: jobsRepo,
          child: const ServiceJobDetailScreen(jobId: 'job-admin-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ADDITIONAL WORK (1)'), findsOneWidget);
      expect(find.text('APPROVED'), findsOneWidget);
      expect(find.text('Client Note: "Approved by customer"'), findsOneWidget);

      // Interactive checkbox is available for approved item
      final checkbox = find.byIcon(Icons.check_box_outline_blank_rounded);
      expect(checkbox, findsOneWidget);

      await tester.tap(checkbox);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_box_rounded), findsOneWidget);
    });

    testWidgets('Rejected additional work displays REJECTED badge and block icon', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      jobsRepo.jobs[0] = jobsRepo.jobs[0].copyWith(
        status: 'WORK_IN_PROGRESS',
        workItems: [
          ServiceWorkItemModel(
            id: 'wi-rejected-1',
            serviceJobId: 'job-admin-1',
            name: 'Engine Flush',
            description: 'Optional carbon cleaning',
            quantity: 1,
            finalValue: 2500,
            source: 'ADDITIONAL',
            approvalStatus: 'REJECTED',
            status: 'CANCELLED',
            decisionAt: now,
            approvalNote: 'Declined for this service',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      await tester.pumpWidget(
        createTestWidget(
          serviceJobsRepo: jobsRepo,
          child: const ServiceJobDetailScreen(jobId: 'job-admin-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('REJECTED'), findsOneWidget);
      expect(find.byIcon(Icons.block_rounded), findsOneWidget);
      expect(find.text('Client Note: "Declined for this service"'), findsOneWidget);
    });

    testWidgets('Completing job is blocked when pending additional work exists', (tester) async {
      await tester.binding.setSurfaceSize(const Size(430, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      // Job in READY_FOR_DELIVERY status with a pending additional item
      jobsRepo.jobs[0] = jobsRepo.jobs[0].copyWith(
        status: 'READY_FOR_DELIVERY',
        workItems: [
          ServiceWorkItemModel(
            id: 'wi-quotation-done',
            serviceJobId: 'job-admin-1',
            name: 'Quotation Task',
            source: 'QUOTATION',
            status: 'COMPLETED',
            createdAt: now,
            updatedAt: now,
          ),
          ServiceWorkItemModel(
            id: 'wi-pending-blocker',
            serviceJobId: 'job-admin-1',
            name: 'Pending Extra Task',
            source: 'ADDITIONAL',
            approvalStatus: 'PENDING',
            status: 'PENDING',
            finalValue: 1500,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );

      await tester.pumpWidget(
        createTestWidget(
          serviceJobsRepo: jobsRepo,
          child: const ServiceJobDetailScreen(jobId: 'job-admin-1'),
        ),
      );
      await tester.pumpAndSettle();

      // Tap 'Mark Completed'
      final completeBtn = find.text('Mark Completed');
      expect(completeBtn, findsOneWidget);
      await tester.tap(completeBtn);
      await tester.pumpAndSettle();

      // Verify blocking dialog is displayed
      expect(find.text('Pending Additional Work'), findsOneWidget);
      expect(
        find.text(
          'Cannot complete the service job while additional work is awaiting client approval. All additional work items must be resolved (approved or rejected) before the job can be completed.',
        ),
        findsOneWidget,
      );

      // Dismiss dialog
      await tester.tap(find.text('Understood'));
      await tester.pumpAndSettle();

      // Status should remain READY_FOR_DELIVERY
      expect(find.text('Mark Completed'), findsOneWidget);
    });
  });
}
