import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/features/auth/screens/login_screen.dart';
import 'package:autotricks/features/home/screens/admin_home_screen.dart';
import 'package:autotricks/features/service_requests/screens/create_service_request_screen.dart';
import 'package:autotricks/features/service_requests/screens/service_request_detail_screen.dart';
import 'package:autotricks/features/service_requests/screens/service_requests_list_screen.dart';
import '../helpers/test_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const deviceWidths = [360.0, 375.0, 390.0, 430.0];

  group('Responsive Layout Verification (360px, 375px, 390px, 430px)', () {
    for (final width in deviceWidths) {
      testWidgets('A01 LoginScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(child: const LoginScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sign In'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('A02 AdminHomeScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(child: const AdminHomeScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Create Request'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('A03 ServiceRequestsListScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(child: const ServiceRequestsListScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Requests'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('A04 ServiceRequestDetailScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(child: const ServiceRequestDetailScreen(requestId: 'sr-1')),
        );
        await tester.pumpAndSettle();

        expect(find.text('#SR-2026-00021'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('A05 CreateServiceRequestScreen adapts cleanly to width ${width.toInt()}px without overflow', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await tester.pumpWidget(
          createTestWidget(child: const CreateServiceRequestScreen()),
        );
        await tester.pumpAndSettle();

        expect(find.text('Create Service Request'), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });
    }
  });
}
