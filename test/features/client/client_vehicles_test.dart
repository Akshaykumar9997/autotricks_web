import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/features/client/screens/client_vehicle_detail_screen.dart';
import 'package:autotricks/features/client/screens/client_vehicles_screen.dart';
import '../../helpers/mock_repositories.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('C03 — My Vehicles Screen Tests', () {
    testWidgets('Renders client vehicle cards with registration plate and VIN snippet', (tester) async {
      final clientRepo = MockClientPortalRepository();

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientVehiclesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('My Vehicles'), findsOneWidget);
      expect(find.text('Honda City'), findsOneWidget);
      expect(find.text('Hyundai Creta'), findsOneWidget);
      expect(find.text('KA-01-MJ-4412'), findsOneWidget);
      expect(find.text('KA-05-NB-7821'), findsOneWidget);
      expect(find.textContaining('8492'), findsOneWidget);
    });

    testWidgets('Renders empty state if client has no registered vehicles', (tester) async {
      final clientRepo = MockClientPortalRepository();
      clientRepo.vehicles = [];

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientVehiclesScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No vehicles yet'), findsOneWidget);
      expect(find.textContaining('Your vehicles will appear here'), findsOneWidget);
    });
  });

  group('C04 — Vehicle Detail Screen Tests', () {
    const testVehicleId = 'edd54d25-b67b-4ac7-bd72-b5dc4daf8b24';

    testWidgets('Renders hero specs grid, plate badge, and active requests', (tester) async {
      final clientRepo = MockClientPortalRepository();

      await tester.pumpWidget(
        createTestWidget(
          clientPortalRepo: clientRepo,
          child: const ClientVehicleDetailScreen(vehicleId: testVehicleId),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vehicle Details'), findsOneWidget);
      expect(find.textContaining('Honda City'), findsWidgets);
      expect(find.text('KA-01-MJ-4412'), findsWidgets);
      expect(find.text('MAKGM2656N1028492'), findsWidgets);

      // Specs grid items
      expect(find.text('Registration'), findsOneWidget);
      expect(find.text('Model Year'), findsOneWidget);
      expect(find.text('Chassis / VIN'), findsOneWidget);
      expect(find.text('2022'), findsWidgets);

      // Active requests section
      expect(find.text('ACTIVE SERVICE REQUESTS'), findsOneWidget);
      expect(find.text('SR-2026-00021'), findsOneWidget);

      // Service history summary
      expect(find.text('SERVICE HISTORY'), findsOneWidget);
      expect(find.textContaining('completed service', findRichText: true), findsOneWidget);
    });
  });
}
