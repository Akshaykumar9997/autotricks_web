import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/features/vehicles/screens/vehicle_list_screen.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A09 — Vehicle List Screen Tests', () {
    testWidgets('Renders app bar, search bar, make filter pills, and vehicle cards', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const VehicleListScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Vehicles'), findsOneWidget);
      expect(find.text('Add Vehicle'), findsOneWidget);

      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('All Makes'), findsOneWidget);

      // Vehicles from MockClientVehicleRepository
      expect(find.text('Honda City'), findsOneWidget);
      expect(find.text('Toyota Fortuner'), findsOneWidget);
      expect(find.text('Hyundai Creta'), findsOneWidget);
    });

    testWidgets('Filters vehicles by search query', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const VehicleListScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Honda City'), findsOneWidget);
      expect(find.text('Toyota Fortuner'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Fortuner');
      await tester.pumpAndSettle();

      expect(find.text('Toyota Fortuner'), findsOneWidget);
      expect(find.text('Honda City'), findsNothing);
    });

    testWidgets('Filters vehicles by make chip', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const VehicleListScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Honda'), findsOneWidget);
      await tester.tap(find.text('Honda'));
      await tester.pumpAndSettle();

      expect(find.text('Honda City'), findsOneWidget);
      expect(find.text('Toyota Fortuner'), findsNothing);
    });
  });
}
