import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/design_system/components/auto_button.dart';
import 'package:autotricks/features/vehicles/screens/create_edit_vehicle_screen.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A11 — Create/Edit Vehicle Screen Tests', () {
    testWidgets('Renders all inputs in Create mode and validates required fields', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const CreateEditVehicleScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Register Vehicle'), findsNWidgets(2)); // Title & Button
      expect(find.text('VEHICLE OWNER'), findsOneWidget);
      expect(find.text('VEHICLE DETAILS'), findsOneWidget);

      expect(find.textContaining('Make', findRichText: true), findsOneWidget);
      expect(find.textContaining('Model', findRichText: true), findsOneWidget);
      expect(find.textContaining('Registration Number', findRichText: true), findsOneWidget);
      expect(find.textContaining('Chassis Number (VIN)', findRichText: true), findsOneWidget);

      final submitBtn = find.widgetWithText(AutoButton, 'Register Vehicle');
      expect(submitBtn, findsOneWidget);

      // Tap submit with empty form to trigger validation
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Please select an owner'), findsAtLeastNWidgets(1));
      expect(find.text('Make is required'), findsOneWidget);
      expect(find.text('Model is required'), findsOneWidget);
    });

    testWidgets('Renders Edit mode with pre-populated vehicle and immutable owner note', (tester) async {
      const testVehicleId = 'edd54d25-b67b-4ac7-bd72-b5dc4daf8b24'; // Honda City

      await tester.pumpWidget(
        createTestWidget(
          child: const CreateEditVehicleScreen(vehicleId: testVehicleId),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Vehicle'), findsOneWidget);
      expect(find.widgetWithText(AutoButton, 'Save Vehicle'), findsOneWidget);

      // Verify immutable owner note
      expect(find.text('Ownership is immutable once registered.'), findsOneWidget);

      // Pre-populated fields
      expect(find.text('Honda'), findsOneWidget);
      expect(find.text('City'), findsOneWidget);
      expect(find.text('2022'), findsOneWidget);
      expect(find.text('KA-01-MJ-4412'), findsOneWidget);
    });
  });
}
