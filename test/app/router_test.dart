import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autotricks/app/app.dart';
import 'package:autotricks/features/auth/providers/auth_provider.dart';
import 'package:autotricks/features/client_portal/screens/client_portal_shell.dart';
import 'package:autotricks/features/dashboard/providers/dashboard_provider.dart';
import 'package:autotricks/features/dashboard/repositories/dashboard_repository.dart';
import 'package:autotricks/features/dashboard/screens/dashboard_screen.dart';

void main() {
  group('AutoTricks Routing & Role Protection Tests', () {
    testWidgets('ADMIN user reaches Admin Dashboard', (tester) async {
      final container = ProviderContainer(
        overrides: [
          dashboardRepositoryProvider.overrideWithValue(
            const MockDashboardRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Pre-authenticate as Admin
      container.read(authProvider.notifier).signInAsMockAdmin();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AutoTricksApp(),
        ),
      );

      // Fast forward past splash
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byType(ClientPortalShell), findsNothing);
    });

    testWidgets('CLIENT user is prevented from Admin Dashboard and routed to ClientPortalShell',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          dashboardRepositoryProvider.overrideWithValue(
            const MockDashboardRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Pre-authenticate as Client
      container.read(authProvider.notifier).signInAsMockClient(
            name: 'Rohit Sharma',
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const AutoTricksApp(),
        ),
      );

      // Fast forward past splash
      await tester.pump(const Duration(milliseconds: 2500));
      await tester.pumpAndSettle();

      // Client portal should be rendered, Admin Dashboard should NOT be exposed
      expect(find.byType(ClientPortalShell), findsOneWidget);
      expect(find.byType(DashboardScreen), findsNothing);
      expect(find.text('Welcome, Rohit Sharma'), findsOneWidget);
    });
  });
}
