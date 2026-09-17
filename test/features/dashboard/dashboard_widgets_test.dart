import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autotricks/features/auth/providers/auth_provider.dart';
import 'package:autotricks/features/dashboard/models/dashboard_metrics.dart';
import 'package:autotricks/features/dashboard/providers/dashboard_provider.dart';
import 'package:autotricks/features/dashboard/repositories/dashboard_repository.dart';
import 'package:autotricks/features/dashboard/screens/dashboard_screen.dart';
import 'package:autotricks/features/dashboard/widgets/mechanic_hero_visual.dart';
import 'package:autotricks/features/dashboard/widgets/workshop_progress_card.dart';

void main() {
  group('Dashboard Components Tests', () {
    testWidgets('WorkshopProgressCard displays 72% and 3 core metrics',
        (tester) async {
      final testMetrics = DashboardMetrics.referenceBaseline();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WorkshopProgressCard(metrics: testMetrics),
          ),
        ),
      );

      expect(find.text("Today's Workshop Progress"), findsOneWidget);
      expect(find.text('72%'), findsOneWidget);
      expect(find.text('On Track'), findsOneWidget);
      expect(find.text('Keep up the great work!'), findsOneWidget);

      // Core 3 Metrics: OPEN (12), IN SERVICE (9), READY (4)
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);

      expect(find.text('9'), findsOneWidget);
      expect(find.text('In Service'), findsOneWidget);

      expect(find.text('4'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
    });

    testWidgets('MechanicHeroVisual renders automotive layers and motto',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MechanicHeroVisual(),
            ),
          ),
        ),
      );

      expect(find.text('SERVICE TODAY'), findsOneWidget);
      expect(find.text('A BETTER TOMORROW'), findsOneWidget);
      expect(find.text('LIVE BAY 01'), findsOneWidget);
    });

    testWidgets('DashboardScreen renders greeting bar and complete dashboard layout',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          dashboardRepositoryProvider.overrideWithValue(
            const MockDashboardRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      // Sign in as Admin Alex
      container.read(authProvider.notifier).signInAsMockAdmin(
            name: 'Alex Technician',
          );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: DashboardScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Alex Technician'), findsOneWidget);
      expect(find.text('Great to see you back.'), findsOneWidget);
      expect(find.byType(MechanicHeroVisual), findsOneWidget);
      expect(find.byType(WorkshopProgressCard), findsOneWidget);
    });
  });
}
