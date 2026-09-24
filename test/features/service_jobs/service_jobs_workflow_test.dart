import 'package:flutter_test/flutter_test.dart';
import '../../helpers/mock_repositories.dart';

void main() {
  group('Day 12 — Service Job Workflow & Lifecycle Tests', () {
    late MockServiceJobsRepository jobsRepo;

    setUp(() {
      jobsRepo = MockServiceJobsRepository();
    });

    test('1. Admin can create Service Job from accepted quote revision', () async {
      final result = await jobsRepo.createServiceJob(
        quotationRevisionId: 'rev-accepted-99',
        scheduledAt: DateTime.now().add(const Duration(days: 2)),
      );

      expect(result['success'], isTrue);
      expect(result['job_id'], isNotNull);
      expect(result['job_number'], startsWith('JOB-'));
      expect(result['status'], equals('SCHEDULED'));

      final job = await jobsRepo.getServiceJobById(result['job_id'] as String);
      expect(job.status, equals('SCHEDULED'));
      expect(job.statusHistory.length, equals(1));
      expect(job.statusHistory.first.toStatus, equals('SCHEDULED'));
      expect(job.workItems.isNotEmpty, isTrue);
    });

    test('2. Duplicate Service Job creation for same revision is idempotent / blocked', () async {
      final first = await jobsRepo.createServiceJob(
        quotationRevisionId: 'rev-dup-1',
      );
      final second = await jobsRepo.createServiceJob(
        quotationRevisionId: 'rev-dup-1',
      );

      expect(second['success'], isTrue);
      expect(second['job_id'], equals(first['job_id']));
      expect(second['job_number'], equals(first['job_number']));
    });

    test('3. Strictly sequential transitions: SCHEDULED -> VEHICLE_RECEIVED -> INSPECTION -> WORK_IN_PROGRESS -> QUALITY_CHECK -> READY_FOR_DELIVERY -> COMPLETED', () async {
      final res = await jobsRepo.createServiceJob(quotationRevisionId: 'rev-seq-test');
      final jobId = res['job_id'] as String;

      // 1. SCHEDULED -> VEHICLE_RECEIVED
      await jobsRepo.updateJobStatus(
        jobId: jobId,
        status: 'VEHICLE_RECEIVED',
        note: 'Customer dropped off vehicle at workshop',
      );
      var job = await jobsRepo.getServiceJobById(jobId);
      expect(job.status, equals('VEHICLE_RECEIVED'));

      // 2. VEHICLE_RECEIVED -> INSPECTION
      await jobsRepo.updateJobStatus(
        jobId: jobId,
        status: 'INSPECTION',
        note: 'Initial 40-point inspection started',
      );
      job = await jobsRepo.getServiceJobById(jobId);
      expect(job.status, equals('INSPECTION'));

      // 3. INSPECTION -> WORK_IN_PROGRESS
      await jobsRepo.updateJobStatus(
        jobId: jobId,
        status: 'WORK_IN_PROGRESS',
        note: 'Technician begun line items work',
      );
      job = await jobsRepo.getServiceJobById(jobId);
      expect(job.status, equals('WORK_IN_PROGRESS'));
      expect(job.startedAt, isNotNull);

      // 4. WORK_IN_PROGRESS -> QUALITY_CHECK
      await jobsRepo.updateJobStatus(
        jobId: jobId,
        status: 'QUALITY_CHECK',
        note: 'Service tasks done, QC supervisor testing',
      );
      job = await jobsRepo.getServiceJobById(jobId);
      expect(job.status, equals('QUALITY_CHECK'));

      // 5. QUALITY_CHECK -> READY_FOR_DELIVERY
      await jobsRepo.updateJobStatus(
        jobId: jobId,
        status: 'READY_FOR_DELIVERY',
        note: 'Road test passed, washed and ready',
      );
      job = await jobsRepo.getServiceJobById(jobId);
      expect(job.status, equals('READY_FOR_DELIVERY'));

      // Complete work items before COMPLETED
      await jobsRepo.completeAllWorkItems(jobId);

      // 6. READY_FOR_DELIVERY -> COMPLETED
      await jobsRepo.updateJobStatus(
        jobId: jobId,
        status: 'COMPLETED',
        note: 'Vehicle handed over to customer',
      );
      job = await jobsRepo.getServiceJobById(jobId);
      expect(job.status, equals('COMPLETED'));
      expect(job.completedAt, isNotNull);
      expect(job.isCompleted, isTrue);

      // Verify full status history trail
      final history = await jobsRepo.fetchJobStatusHistory(jobId);
      expect(history.length, equals(7)); // Initial + 6 transitions
    });

    test('4. Arbitrary forward jump is strictly rejected', () async {
      final res = await jobsRepo.createServiceJob(quotationRevisionId: 'rev-jump-fwd');
      final jobId = res['job_id'] as String;

      // Attempt jump from SCHEDULED directly to WORK_IN_PROGRESS
      expect(
        () => jobsRepo.updateJobStatus(
          jobId: jobId,
          status: 'WORK_IN_PROGRESS',
        ),
        throwsA(isA<Exception>()),
      );

      // Attempt jump from SCHEDULED directly to COMPLETED
      expect(
        () => jobsRepo.updateJobStatus(
          jobId: jobId,
          status: 'COMPLETED',
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('5. Backward transitions are strictly rejected', () async {
      final res = await jobsRepo.createServiceJob(quotationRevisionId: 'rev-back-jump');
      final jobId = res['job_id'] as String;

      await jobsRepo.updateJobStatus(jobId: jobId, status: 'VEHICLE_RECEIVED');
      await jobsRepo.updateJobStatus(jobId: jobId, status: 'INSPECTION');

      // Attempt to move back from INSPECTION to SCHEDULED or VEHICLE_RECEIVED
      expect(
        () => jobsRepo.updateJobStatus(jobId: jobId, status: 'VEHICLE_RECEIVED'),
        throwsA(isA<Exception>()),
      );
      expect(
        () => jobsRepo.updateJobStatus(jobId: jobId, status: 'SCHEDULED'),
        throwsA(isA<Exception>()),
      );
    });

    test('6. COMPLETED status is strictly terminal and cannot move backward or cancel', () async {
      final res = await jobsRepo.createServiceJob(quotationRevisionId: 'rev-terminal-test');
      final jobId = res['job_id'] as String;

      await jobsRepo.updateJobStatus(jobId: jobId, status: 'VEHICLE_RECEIVED');
      await jobsRepo.updateJobStatus(jobId: jobId, status: 'INSPECTION');
      await jobsRepo.updateJobStatus(jobId: jobId, status: 'WORK_IN_PROGRESS');
      await jobsRepo.updateJobStatus(jobId: jobId, status: 'QUALITY_CHECK');
      await jobsRepo.updateJobStatus(jobId: jobId, status: 'READY_FOR_DELIVERY');
      await jobsRepo.completeAllWorkItems(jobId);
      await jobsRepo.updateJobStatus(jobId: jobId, status: 'COMPLETED');

      // Attempt to move from COMPLETED back or to CANCELLED
      expect(
        () => jobsRepo.updateJobStatus(jobId: jobId, status: 'READY_FOR_DELIVERY'),
        throwsA(isA<Exception>()),
      );
      expect(
        () => jobsRepo.updateJobStatus(jobId: jobId, status: 'CANCELLED'),
        throwsA(isA<Exception>()),
      );
    });

    test('7. Cannot mark job COMPLETED when active work items are incomplete', () async {
      final res = await jobsRepo.createServiceJob(quotationRevisionId: 'rev-incomplete-items');
      final jobId = res['job_id'] as String;

      await jobsRepo.updateJobStatus(jobId: jobId, status: 'VEHICLE_RECEIVED');
      await jobsRepo.updateJobStatus(jobId: jobId, status: 'INSPECTION');
      await jobsRepo.updateJobStatus(jobId: jobId, status: 'WORK_IN_PROGRESS');
      await jobsRepo.updateJobStatus(jobId: jobId, status: 'QUALITY_CHECK');
      await jobsRepo.updateJobStatus(jobId: jobId, status: 'READY_FOR_DELIVERY');

      // Attempt to complete with pending work items
      expect(
        () => jobsRepo.updateJobStatus(jobId: jobId, status: 'COMPLETED'),
        throwsA(isA<Exception>()),
      );

      // Now complete all items
      await jobsRepo.completeAllWorkItems(jobId);

      // Completion should succeed now
      final completedRes = await jobsRepo.updateJobStatus(jobId: jobId, status: 'COMPLETED');
      expect(completedRes['success'], isTrue);
      expect(completedRes['status'], equals('COMPLETED'));
    });

    test('8. Individual work item status transitions update accurately', () async {
      final res = await jobsRepo.createServiceJob(quotationRevisionId: 'rev-work-items-test');
      final jobId = res['job_id'] as String;

      var items = await jobsRepo.fetchJobWorkItems(jobId);
      expect(items.isNotEmpty, isTrue);
      final firstItemId = items.first.id;

      // Update to IN_PROGRESS
      await jobsRepo.updateWorkItemStatus(itemId: firstItemId, status: 'IN_PROGRESS');
      items = await jobsRepo.fetchJobWorkItems(jobId);
      expect(items.first.status, equals('IN_PROGRESS'));

      // Update to COMPLETED
      await jobsRepo.updateWorkItemStatus(itemId: firstItemId, status: 'COMPLETED');
      items = await jobsRepo.fetchJobWorkItems(jobId);
      expect(items.first.status, equals('COMPLETED'));
    });
  });
}
