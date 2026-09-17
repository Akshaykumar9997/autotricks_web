import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autotricks/app/theme/app_theme.dart';
import 'package:autotricks/features/auth/providers/auth_provider.dart';
import 'package:autotricks/features/dashboard/providers/dashboard_provider.dart';
import 'package:autotricks/features/dashboard/repositories/dashboard_repository.dart';
import 'package:autotricks/features/dashboard/screens/dashboard_screen.dart';

void main() {
  group('Mobile Viewport Responsive Verification', () {
    const viewports = [
      Size(360, 740), // Compact Android
      Size(375, 812), // iPhone SE / Mini
      Size(390, 844), // iPhone 14
      Size(430, 932), // iPhone 14 Pro Max / Large Mobile
    ];

    for (final viewport in viewports) {
      testWidgets('Dashboard renders without overflow at ${viewport.width}x${viewport.height}',
          (tester) async {
        // Set physical and logical size
        tester.view.physicalSize = viewport;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer(
          overrides: [
            dashboardRepositoryProvider.overrideWithValue(
              const MockDashboardRepository(),
            ),
          ],
        );
        addTearDown(container.dispose);

        container.read(authProvider.notifier).signInAsMockAdmin();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: Builder(
              builder: (context) => MaterialApp(
                theme: AppTheme.darkTheme(context),
                home: const DashboardScreen(),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Verify key widgets are present
        expect(find.text("Today's Workshop Progress"), findsOneWidget);
        expect(find.text('72%'), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
        expect(find.text('9'), findsOneWidget);
        expect(find.text('4'), findsOneWidget);

        final exception = tester.takeException();
        if (exception != null) {
          debugPrint('Caught exception in responsive test: $exception');
        }
        expect(exception, isNull);
      });
    }
  });
}
