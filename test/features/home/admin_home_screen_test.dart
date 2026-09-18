import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/features/home/screens/admin_home_screen.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A02 — Admin Home Screen Tests', () {
    testWidgets('Renders greeter card, operations context, and operational quick actions', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const AdminHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ADMIN OPERATIONS'), findsOneWidget);
      expect(find.text('Good morning, Vikram'), findsOneWidget);
      expect(find.text('Admin Portal'), findsOneWidget);
      expect(find.text('Bangalore Central Hub'), findsNothing);
      expect(find.text('LIVE'), findsNothing);

      // Quick Actions
      expect(find.text('Create Request'), findsOneWidget);
      expect(find.text('Create Client'), findsOneWidget);
      expect(find.text('Create Vehicle'), findsOneWidget);
    });

    testWidgets('Renders Needs Attention section with pending items', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const AdminHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Needs Attention'), findsOneWidget);
      expect(find.textContaining('New Requests Pending Review'), findsOneWidget);
      expect(find.textContaining('Quotations Awaiting Client Response'), findsOneWidget);
    });

    testWidgets('Renders Active Service Jobs and Recent Activity', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const AdminHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Active Service Jobs'), findsOneWidget);
      expect(find.text('Recent Activity'), findsOneWidget);
      expect(find.text('JOB-2026-0041'), findsOneWidget);
      expect(find.text('Quotation sent for SR-2026-00015'), findsOneWidget);
    });
  });
}
