import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/design_system/components/auto_button.dart';
import 'package:autotricks/features/clients/screens/client_detail_screen.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A07 — Client Detail Screen Tests', () {
    const testClientId = '2bd5d7fb-3b55-48b1-931f-69896d3f0838'; // Rahul Kumar

    testWidgets('Renders client overview, contact info, admin notes, and vehicles', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const ClientDetailScreen(clientId: testClientId),
        ),
      );
      await tester.pumpAndSettle();

      // App bar
      expect(find.text('Client Profile'), findsOneWidget);

      // Client info
      expect(find.text('Rahul Kumar'), findsOneWidget);
      expect(find.text('ACTIVE'), findsOneWidget);

      // Contact & location
      expect(find.text('CONTACT & LOCATION'), findsOneWidget);
      expect(find.text('+91 98450 12890'), findsOneWidget);
      expect(find.text('rahul.kumar@gmail.com'), findsOneWidget);

      // Admin notes
      expect(find.text('CONFIDENTIAL ADMIN NOTES'), findsOneWidget);
      expect(find.textContaining('Prefers phone call updates'), findsOneWidget);

      // Registered Vehicles
      expect(find.text('REGISTERED VEHICLES'), findsOneWidget);
      expect(find.text('Add Vehicle'), findsOneWidget);

      // Service History
      expect(find.text('SERVICE HISTORY'), findsOneWidget);

      // Sticky Bottom Bar
      expect(find.widgetWithText(AutoButton, 'New Service Request'), findsOneWidget);
    });
  });
}
