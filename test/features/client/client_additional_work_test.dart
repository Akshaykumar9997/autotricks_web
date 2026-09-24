import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/data/models/service_job_model.dart';
import 'package:autotricks/features/client/screens/client_home_screen.dart';
import 'package:autotricks/features/client/screens/client_service_request_detail_screen.dart';
import '../../helpers/mock_repositories.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('Day 12 — Client Additional Work Authorization Tests', () {
    late MockClientPortalRepository clientRepo;

    setUp(() {
      clientRepo = MockClientPortalRepository();
    });

    testWidgets('ClientServiceRequestDetailScreen renders Additional Work card when additional work exists', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      final sampleJob = MockClientPortalRepository.createSampleJob(
        id: 'job-sr-link',
        jobNumber: 'JOB-202609-0088',
        serviceRequestId: 'sr-client-3',
        status: 'WORK_IN_PROGRESS',
      ).copyWith(
        workItems: [
          ServiceWorkItemModel(
            id: 'wi-quote-1',
            serviceJobId: 'job-sr-link',
            name: 'Original Oil Change',
            source: 'QUOTATION',
            status: 'IN_PROGRESS',
            createdAt: now,
            updatedAt: now,
          ),
          ServiceWorkItemModel(
            id: 'wi-add-1',
            serviceJobId: 'job-sr-link',
            name: 'Rear Brake Pad Replacement',
            description: 'Excessive rotor groove & worn pads found during multi-point check',
            quantity: 1,
            finalValue: 3200,
            approximateValue: 3000,
            source: 'ADDITIONAL',
            approvalStatus: 'PENDING',
            status: 'PENDING',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
      clientRepo.serviceJobs = [sampleJob];

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientServiceRequestDetailScreen(requestId: 'sr-client-3'),
        ),
      );
      await tester.pumpAndSettle();

      // Card Header & Banner
      expect(find.text('ADDITIONAL WORK DISCOVERED'), findsOneWidget);
      expect(find.text('1 Awaiting Authorization'), findsOneWidget);
      expect(
        find.text(
          'During vehicle inspection, our workshop discovered additional work items not covered by your signed quotation. Technicians cannot begin this work without your explicit authorization.',
        ),
        findsOneWidget,
      );

      // Pending Item Details
      expect(find.text('Rear Brake Pad Replacement'), findsOneWidget);
      expect(find.text('Excessive rotor groove & worn pads found during multi-point check'), findsOneWidget);
      expect(find.text('₹3200.00'), findsOneWidget);
      expect(find.text('Estimated: ₹3000.00'), findsOneWidget);

      // Decision buttons
      expect(find.text('Decline'), findsOneWidget);
      expect(find.text('Authorize'), findsOneWidget);
    });

    testWidgets('Client can authorize additional work via confirmation modal', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      final sampleJob = MockClientPortalRepository.createSampleJob(
        id: 'job-sr-link',
        jobNumber: 'JOB-202609-0088',
        serviceRequestId: 'sr-client-3',
        status: 'WORK_IN_PROGRESS',
      ).copyWith(
        workItems: [
          ServiceWorkItemModel(
            id: 'wi-add-auth',
            serviceJobId: 'job-sr-link',
            name: 'AC Condenser Cleaning',
            description: 'Fins blocked with dust, high head pressure',
            quantity: 1,
            finalValue: 1500,
            source: 'ADDITIONAL',
            approvalStatus: 'PENDING',
            status: 'PENDING',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
      clientRepo.serviceJobs = [sampleJob];

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientServiceRequestDetailScreen(requestId: 'sr-client-3'),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Authorize button
      final authBtn = find.text('Authorize');
      expect(authBtn, findsOneWidget);
      await tester.tap(authBtn);
      await tester.pumpAndSettle();

      // Verify modal content
      expect(find.text('Authorize Additional Work'), findsOneWidget);
      expect(find.text('Chargeable Price:'), findsOneWidget);
      expect(find.text('₹1500.00'), findsWidgets);

      // Confirm in dialog
      final confirmBtn = find.widgetWithText(ElevatedButton, 'Confirm Authorization');
      expect(confirmBtn, findsOneWidget);
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      // Item should now appear in DECIDED ITEMS as AUTHORIZED
      expect(find.text('DECIDED ITEMS (1)'), findsOneWidget);
      expect(find.text('AUTHORIZED'), findsOneWidget);
      expect(find.text('All Decided'), findsOneWidget);
    });

    testWidgets('Client can decline additional work with reason note', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      final sampleJob = MockClientPortalRepository.createSampleJob(
        id: 'job-sr-link',
        jobNumber: 'JOB-202609-0088',
        serviceRequestId: 'sr-client-3',
        status: 'WORK_IN_PROGRESS',
      ).copyWith(
        workItems: [
          ServiceWorkItemModel(
            id: 'wi-add-dec',
            serviceJobId: 'job-sr-link',
            name: 'Engine Bay Detailing',
            description: 'Cosmetic engine compartment wash',
            quantity: 1,
            finalValue: 900,
            source: 'ADDITIONAL',
            approvalStatus: 'PENDING',
            status: 'PENDING',
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
      clientRepo.serviceJobs = [sampleJob];

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientServiceRequestDetailScreen(requestId: 'sr-client-3'),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Decline button
      final declineBtn = find.text('Decline');
      expect(declineBtn, findsOneWidget);
      await tester.tap(declineBtn);
      await tester.pumpAndSettle();

      // Verify decline modal content
      expect(find.text('Decline Additional Work'), findsOneWidget);
      expect(find.text('AutoTricks technicians will NOT perform "Engine Bay Detailing".'), findsOneWidget);

      // Enter optional reason
      final reasonField = find.widgetWithText(TextField, 'e.g. Will address in future service...');
      expect(reasonField, findsOneWidget);
      await tester.enterText(reasonField, 'Not needed at this time');

      // Confirm decline
      final confirmDeclineBtn = find.widgetWithText(ElevatedButton, 'Confirm Decline');
      expect(confirmDeclineBtn, findsOneWidget);
      await tester.tap(confirmDeclineBtn);
      await tester.pumpAndSettle();

      // Item should now appear in DECIDED ITEMS as DECLINED with note
      expect(find.text('DECIDED ITEMS (1)'), findsOneWidget);
      expect(find.text('DECLINED'), findsOneWidget);
      expect(find.text('Your note: "Not needed at this time"'), findsOneWidget);
    });

    testWidgets('ClientHomeScreen shows Action Required alert banner when active job has pending additional work', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      final sampleJob = MockClientPortalRepository.createSampleJob(
        id: 'job-client-with-add',
        jobNumber: 'JOB-202609-0099',
        status: 'WORK_IN_PROGRESS',
      ).copyWith(
        workItems: [
          ServiceWorkItemModel(
            id: 'wi-quote-regular',
            serviceJobId: 'job-client-with-add',
            name: 'Periodic Service',
            source: 'QUOTATION',
            status: 'IN_PROGRESS',
            createdAt: now,
            updatedAt: now,
          ),
          ServiceWorkItemModel(
            id: 'wi-pending-work',
            serviceJobId: 'job-client-with-add',
            name: 'Transmission Fluid Flush',
            source: 'ADDITIONAL',
            approvalStatus: 'PENDING',
            status: 'PENDING',
            finalValue: 2800,
            createdAt: now,
            updatedAt: now,
          ),
        ],
      );
      clientRepo.serviceJobs = [sampleJob];

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Action Required: Additional Work'), findsOneWidget);
      expect(find.text('1 new item(s) awaiting your authorization.'), findsOneWidget);
    });
  });
}
