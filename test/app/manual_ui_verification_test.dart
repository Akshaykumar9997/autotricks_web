import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autotricks/app/app.dart';
import 'package:autotricks/app/theme/app_theme.dart';
import 'package:autotricks/core/widgets/auto_bottom_sheet.dart';
import 'package:autotricks/core/widgets/auto_dialog.dart';
import 'package:autotricks/core/widgets/auto_toast.dart';
import 'package:autotricks/features/auth/providers/auth_provider.dart';
import 'package:autotricks/features/dashboard/providers/dashboard_provider.dart';
import 'package:autotricks/features/dashboard/repositories/dashboard_repository.dart';
import 'package:autotricks/features/dashboard/screens/dashboard_screen.dart';
import 'package:autotricks/features/dashboard/widgets/mechanic_hero_visual.dart';
import 'package:autotricks/features/dashboard/widgets/workshop_progress_card.dart';
import 'package:autotricks/features/more/screens/more_screen.dart';
import 'package:autotricks/features/splash/screens/splash_screen.dart';

void main() {
  const targetViewports = [
    Size(360, 740), // 360px width
    Size(375, 812), // 375px width
    Size(390, 844), // 390px width
    Size(430, 932), // 430px width
  ];

  group('Manual UI & Breakpoint Inspection Suite', () {
    for (final size in targetViewports) {
      testWidgets('Verify Splash / loading at ${size.width}px', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              home: SplashScreen(),
            ),
          ),
        );

        // Inspect initial frame
        expect(find.byType(SplashScreen), findsOneWidget);
        expect(find.text('Getting things ready...'), findsOneWidget);
        expect(find.text('CARS • SERVICE • PEOPLE • ALWAYS FORWARD'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Verify Dashboard & Mechanic Hero & Progress Card at ${size.width}px',
          (tester) async {
        tester.view.physicalSize = size;
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

        // 1. Contextual Greeting
        expect(find.text('Great to see you back.'), findsOneWidget);

        // 2. Mechanic Hero Visual
        expect(find.byType(MechanicHeroVisual), findsOneWidget);
        expect(find.text('SERVICE TODAY'), findsOneWidget);
        expect(find.text('A BETTER TOMORROW'), findsOneWidget);
        expect(find.text('LIVE BAY 01'), findsOneWidget);

        // 3. Workshop Progress Card
        expect(find.byType(WorkshopProgressCard), findsOneWidget);
        expect(find.text("Today's Workshop Progress"), findsOneWidget);
        expect(find.text('72%'), findsOneWidget);
        expect(find.text('12'), findsOneWidget);
        expect(find.text('9'), findsOneWidget);
        expect(find.text('4'), findsOneWidget);

        expect(tester.takeException(), isNull);
      });

      testWidgets('Verify More screen at ${size.width}px', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final container = ProviderContainer();
        addTearDown(container.dispose);
        container.read(authProvider.notifier).signInAsMockAdmin();

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: Builder(
              builder: (context) => MaterialApp(
                theme: AppTheme.darkTheme(context),
                home: const MoreScreen(),
              ),
            ),
          ),
        );

        expect(find.text('Clients'), findsOneWidget);
        expect(find.text('Vehicles'), findsOneWidget);
        expect(find.text('Service Jobs'), findsOneWidget);
        expect(find.text('Services & Pricing'), findsOneWidget);

        // Scroll to reveal lower items in ListView
        await tester.scrollUntilVisible(
          find.text('Notifications'),
          100,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('Notifications'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Help & Support'),
          100,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('Help & Support'), findsOneWidget);

        await tester.scrollUntilVisible(
          find.text('Log Out'),
          100,
          scrollable: find.byType(Scrollable),
        );
        expect(find.text('Log Out'), findsOneWidget);

        expect(tester.takeException(), isNull);
      });

      testWidgets('Verify Dialog, BottomSheet, and Toast at ${size.width}px',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => Column(
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        AutoToast.show(
                          context,
                          message: 'Quotation saved successfully',
                          type: AutoToastType.success,
                        );
                      },
                      child: const Text('Trigger Toast'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        AutoDialog.destructive(
                          context,
                          title: 'Confirm Delete',
                          description: 'Delete this workshop item?',
                          deleteText: 'Delete',
                        );
                      },
                      child: const Text('Trigger Dialog'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        AutoBottomSheet.show(
                          context: context,
                          title: 'Quick Actions',
                          child: const Text('Sheet Content'),
                        );
                      },
                      child: const Text('Trigger Sheet'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // 1. Test Toast
        await tester.tap(find.text('Trigger Toast'));
        await tester.pump();
        expect(find.text('Quotation saved successfully'), findsOneWidget);

        // 2. Test Dialog
        await tester.tap(find.text('Trigger Dialog'));
        await tester.pumpAndSettle();
        expect(find.text('Confirm Delete'), findsOneWidget);
        expect(find.text('Delete this workshop item?'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        // 3. Test Bottom Sheet
        await tester.tap(find.text('Trigger Sheet'));
        await tester.pumpAndSettle();
        expect(find.text('Quick Actions'), findsOneWidget);
        expect(find.text('Sheet Content'), findsOneWidget);

        expect(tester.takeException(), isNull);
      });

      testWidgets('Verify Bottom Navigation Shell switching at ${size.width}px',
          (tester) async {
        tester.view.physicalSize = size;
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
            child: const AutoTricksApp(),
          ),
        );

        // Fast forward past splash
        await tester.pump(const Duration(milliseconds: 2500));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Bottom nav tabs should be visible
        expect(find.byIcon(Icons.home), findsOneWidget);
        expect(find.byIcon(Icons.assignment_outlined), findsOneWidget);
        expect(find.byIcon(Icons.add_rounded), findsOneWidget);
        expect(find.byIcon(Icons.receipt_long_outlined), findsOneWidget);
        expect(find.byIcon(Icons.grid_view_outlined), findsOneWidget);

        // Tap Requests tab
        await tester.tap(find.byIcon(Icons.assignment_outlined), warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Service Requests'), findsOneWidget);

        // Tap Quotes tab
        await tester.tap(find.byIcon(Icons.receipt_long_outlined), warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('Quotations'), findsOneWidget);

        // Tap More tab
        await tester.tap(find.byIcon(Icons.grid_view_outlined), warnIfMissed: false);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(find.text('WORKSHOP MANAGEMENT'), findsOneWidget);

        expect(tester.takeException(), isNull);
      });
    }
  });
}
