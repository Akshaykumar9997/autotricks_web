import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/design_system/components/auto_button.dart';
import 'package:autotricks/features/vehicles/screens/vehicle_detail_screen.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A10 — Vehicle Detail Screen Tests', () {
    const testVehicleId = 'edd54d25-b67b-4ac7-bd72-b5dc4daf8b24'; // Honda City

    testWidgets('Renders vehicle specs, owner card, history, and contains NO telemetry', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const VehicleDetailScreen(vehicleId: testVehicleId),
        ),
      );
      await tester.pumpAndSettle();

      // App bar
      expect(find.text('Vehicle Details'), findsOneWidget);

      // Identity & Plate
      expect(find.text('Honda City'), findsOneWidget);
      expect(find.text('KA-01-MJ-4412'), findsOneWidget);

      // Specifications (NO Telemetry)
      expect(find.text('VEHICLE SPECIFICATIONS'), findsOneWidget);
      expect(find.text('Telemetry'), findsNothing);
      expect(find.textContaining(RegExp(r'telemetry', caseSensitive: false)), findsNothing);
      expect(find.text('MAKGM6650NN102938'), findsOneWidget); // VIN

      // Registered Owner
      expect(find.text('REGISTERED OWNER'), findsOneWidget);
      expect(find.text('Rahul Kumar'), findsOneWidget);
      expect(find.text('View Profile'), findsOneWidget);

      // Service History
      expect(find.text('SERVICE HISTORY'), findsOneWidget);

      // Sticky Bottom Bar
      expect(find.widgetWithText(AutoButton, 'New Service Request'), findsOneWidget);
    });
  });
}
