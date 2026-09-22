import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:autotricks/data/repositories/auth_repository.dart';
import 'package:autotricks/design_system/components/auto_app_bar.dart';
import 'package:autotricks/design_system/components/auto_button.dart';
import 'package:autotricks/design_system/components/auto_select.dart';
import 'package:autotricks/design_system/theme/app_theme.dart';
import 'package:autotricks/features/auth/providers/auth_provider.dart';
import 'package:autotricks/features/home/providers/home_provider.dart';
import 'package:autotricks/features/quotes/providers/quotes_provider.dart';
import 'package:autotricks/features/service_requests/providers/service_requests_provider.dart';
import 'package:autotricks/routing/app_router.dart';
import '../helpers/mock_repositories.dart';

Widget createNavigationTestApp({
  MockClientVehicleRepository? clientVehicleRepo,
  MockServiceRequestsRepository? srRepo,
  MockQuotationsRepository? quotesRepo,
}) {
  final authRepo = MockAuthRepository()
    ..currentUser = const UserProfile(
      id: 'usr-admin-1',
      email: 'admin@autotricks.in',
      fullName: 'Vikram Mehta',
      role: 'ADMIN',
    );

  return ProviderScope(
    overrides: [
      authRepositoryProvider.overrideWithValue(authRepo),
      homeRepositoryProvider.overrideWithValue(MockHomeRepository()),
      serviceRequestsRepositoryProvider.overrideWithValue(srRepo ?? MockServiceRequestsRepository()),
      clientVehicleRepositoryProvider.overrideWithValue(clientVehicleRepo ?? MockClientVehicleRepository()),
      quotationsRepositoryProvider.overrideWithValue(quotesRepo ?? MockQuotationsRepository()),
    ],
    child: Consumer(
      builder: (context, ref, _) {
        final router = ref.watch(routerProvider);
        return MaterialApp.router(
          theme: AppTheme.darkTheme,
          routerConfig: router,
        );
      },
    ),
  );
}

GoRouter getRouter(WidgetTester tester) {
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp))).read(routerProvider);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const rahulClientId = '2bd5d7fb-3b55-48b1-931f-69896d3f0838';
  const hondaVehicleId = 'edd54d25-b67b-4ac7-bd72-b5dc4daf8b24';

  group('Navigation & Back-Button Flow Tests (A04–A11)', () {
    testWidgets('1. A06 -> A08 -> Back returns to A06 Client List', (tester) async {
      await tester.pumpWidget(createNavigationTestApp());
      await tester.pumpAndSettle();

      getRouter(tester).go('/admin/clients');
      await tester.pumpAndSettle();

      expect(find.text('Clients'), findsOneWidget);

      // Tap New Client FAB
      await tester.tap(find.widgetWithText(FloatingActionButton, 'New Client'));
      await tester.pumpAndSettle();

      expect(find.text('Create Client'), findsAtLeastNWidgets(1));

      // Tap top-left Back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Should be back on Clients
      expect(find.text('Clients'), findsOneWidget);
    });

    testWidgets('2. A07 -> A08 Edit -> Back returns to A07 Client Detail', (tester) async {
      await tester.pumpWidget(createNavigationTestApp());
      await tester.pumpAndSettle();

      getRouter(tester).go('/admin/clients/$rahulClientId');
      await tester.pumpAndSettle();

      expect(find.text('Client Profile'), findsOneWidget);
      expect(find.text('Rahul Kumar'), findsAtLeastNWidgets(1));

      // Tap Edit Client icon in AppBar
      await tester.tap(find.byTooltip('Edit Client').first);
      await tester.pumpAndSettle();

      expect(find.text('Edit Client'), findsOneWidget);

      // Tap top-left Back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Should return to Client Profile
      expect(find.text('Client Profile'), findsOneWidget);
      expect(find.text('Rahul Kumar'), findsAtLeastNWidgets(1));
    });

    testWidgets('3. A09 -> A11 -> Back returns to A09 Vehicle List', (tester) async {
      await tester.pumpWidget(createNavigationTestApp());
      await tester.pumpAndSettle();

      getRouter(tester).go('/admin/vehicles');
      await tester.pumpAndSettle();

      expect(find.text('Vehicles'), findsOneWidget);

      // Tap Add Vehicle FAB
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Vehicle'));
      await tester.pumpAndSettle();

      expect(find.text('Register Vehicle'), findsAtLeastNWidgets(1));

      // Tap top-left Back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Should be back on Vehicles
      expect(find.text('Vehicles'), findsOneWidget);
    });

    testWidgets('4. A10 -> A11 Edit -> Back returns to A10 Vehicle Detail', (tester) async {
      await tester.pumpWidget(createNavigationTestApp());
      await tester.pumpAndSettle();

      getRouter(tester).go('/admin/vehicles/$hondaVehicleId');
      await tester.pumpAndSettle();

      expect(find.text('Vehicle Details'), findsOneWidget);
      expect(find.text('Honda City'), findsOneWidget);

      // Tap Edit icon in AppBar
      await tester.tap(find.byTooltip('Edit Vehicle').first);
      await tester.pumpAndSettle();

      expect(find.text('Edit Vehicle'), findsOneWidget);

      // Tap top-left Back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Should return to Vehicle Details
      expect(find.text('Vehicle Details'), findsOneWidget);
      expect(find.text('Honda City'), findsOneWidget);
    });

    testWidgets('5. A07 -> A11 Add Vehicle -> Back returns to A07 Client Detail', (tester) async {
      await tester.pumpWidget(createNavigationTestApp());
      await tester.pumpAndSettle();

      getRouter(tester).go('/admin/clients/$rahulClientId');
      await tester.pumpAndSettle();

      expect(find.text('Client Profile'), findsOneWidget);

      // Scroll to Registered Vehicles section and tap "+ Add Vehicle"
      final addVehicleBtn = find.widgetWithText(TextButton, 'Add Vehicle');
      await tester.scrollUntilVisible(addVehicleBtn, 200);
      await tester.tap(addVehicleBtn);
      await tester.pumpAndSettle();

      expect(find.text('Register Vehicle'), findsAtLeastNWidgets(1));

      // Tap top-left Back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Should return to Client Profile
      expect(find.text('Client Profile'), findsOneWidget);
      expect(find.text('Rahul Kumar'), findsAtLeastNWidgets(1));
    });

    testWidgets('6. A10 -> A05 New Request -> Back returns to A10 Vehicle Detail', (tester) async {
      await tester.pumpWidget(createNavigationTestApp());
      await tester.pumpAndSettle();

      getRouter(tester).go('/admin/vehicles/$hondaVehicleId');
      await tester.pumpAndSettle();

      expect(find.text('Vehicle Details'), findsOneWidget);

      // Tap "New Service Request" in sticky bottom bar
      final newSrBtn = find.widgetWithText(AutoButton, 'New Service Request');
      expect(newSrBtn, findsOneWidget);
      await tester.tap(newSrBtn);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(AutoAppBar, 'Create Service Request'), findsOneWidget);

      // Tap top-left Back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Should return to Vehicle Details
      expect(find.text('Vehicle Details'), findsOneWidget);
      expect(find.text('Honda City'), findsOneWidget);
    });

    testWidgets('7. Create Client -> successful save -> Back returns to A06 Client List', (tester) async {
      await tester.pumpWidget(createNavigationTestApp());
      await tester.pumpAndSettle();

      getRouter(tester).go('/admin/clients');
      await tester.pumpAndSettle();

      // Tap New Client FAB
      await tester.tap(find.widgetWithText(FloatingActionButton, 'New Client'));
      await tester.pumpAndSettle();

      expect(find.text('Create Client'), findsAtLeastNWidgets(1));

      // Fill in required fields: Full Name & Phone
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Rohit Sharma');
      await tester.enterText(textFields.at(1), '9876543210');
      await tester.pumpAndSettle();

      // Tap Create Client submit button
      final submitBtn = find.widgetWithText(AutoButton, 'Create Client');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Should have navigated to Client Profile
      expect(find.text('Client Profile'), findsOneWidget);

      // Tap top-left Back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // MUST return to Clients List
      expect(find.text('Clients'), findsOneWidget);
    });

    testWidgets('8. Create Vehicle -> successful save -> Back returns to A09 Vehicle List', (tester) async {
      await tester.pumpWidget(createNavigationTestApp());
      await tester.pumpAndSettle();

      getRouter(tester).go('/admin/vehicles');
      await tester.pumpAndSettle();

      // Tap Add Vehicle FAB
      await tester.tap(find.widgetWithText(FloatingActionButton, 'Add Vehicle'));
      await tester.pumpAndSettle();

      expect(find.text('Register Vehicle'), findsAtLeastNWidgets(1));

      // Select Owner
      final selectFinder = find.byType(AutoSelect<String>);
      await tester.tap(selectFinder);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Rahul Kumar').last);
      await tester.pumpAndSettle();

      // Fill Make, Model, Year, Reg, VIN
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'Hyundai'); // Make
      await tester.enterText(textFields.at(1), 'Verna'); // Model
      await tester.enterText(textFields.at(2), '2023'); // Year
      await tester.enterText(textFields.at(3), 'KA-03-NA-1122'); // Reg
      await tester.enterText(textFields.at(4), 'MALBA51CLHM109283'); // VIN
      await tester.pumpAndSettle();

      // Tap Register Vehicle submit button
      final submitBtn = find.widgetWithText(AutoButton, 'Register Vehicle');
      await tester.ensureVisible(submitBtn);
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      // Should have navigated to Vehicle Details
      expect(find.text('Vehicle Details'), findsOneWidget);

      // Tap top-left Back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // MUST return to Vehicles List
      expect(find.text('Vehicles'), findsOneWidget);
    });

    testWidgets('9. A12 -> A13 Quote Detail -> Back returns to A12 Quote List', (tester) async {
      await tester.pumpWidget(createNavigationTestApp());
      await tester.pumpAndSettle();

      getRouter(tester).go('/admin/quotes');
      await tester.pumpAndSettle();

      expect(find.text('Quotations'), findsWidgets);

      // Tap on first quote card (QT-2026-00012)
      await tester.tap(find.text('QT-2026-00012'));
      await tester.pumpAndSettle();

      // Expect to be on Quote Detail Screen
      expect(find.text('QUOTATION FILE'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // MUST return to Quote List
      expect(find.text('Quotations'), findsWidgets);
    });

    testWidgets('10. A04 Service Request Detail -> A14 Create Quote -> Back returns to A04', (tester) async {
      final srRepo = MockServiceRequestsRepository();
      // Ensure sr-1 has UNDER_REVIEW and isLinked so Create Quote is available
      final reviewSr = srRepo.items.first.copyWith(
        status: 'UNDER_REVIEW',
        clientId: 'c-1',
        vehicleId: 'v-1',
      );
      srRepo.items[0] = reviewSr;

      await tester.pumpWidget(createNavigationTestApp(srRepo: srRepo));
      await tester.pumpAndSettle();

      getRouter(tester).go('/admin/requests/sr-1');
      await tester.pumpAndSettle();

      expect(find.text('Service Request'), findsOneWidget);

      // Tap Create Quote button
      final createQuoteBtn = find.widgetWithText(AutoButton, 'Create Quote');
      expect(createQuoteBtn, findsOneWidget);
      await tester.tap(createQuoteBtn);
      await tester.pumpAndSettle();

      // Verify on Create Quote Screen
      expect(find.text('Create Quote'), findsOneWidget);

      // Tap back button
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // MUST return to Service Request
      expect(find.text('Service Request'), findsOneWidget);
    });
  });
}
