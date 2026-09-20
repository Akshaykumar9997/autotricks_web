import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/design_system/components/auto_button.dart';
import 'package:autotricks/features/clients/screens/create_edit_client_screen.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A08 — Create/Edit Client Screen Tests', () {
    testWidgets('Renders all inputs in Create mode and validates required fields', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const CreateEditClientScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Create Client'), findsNWidgets(2)); // Title & Button
      expect(find.textContaining('Full Name', findRichText: true), findsOneWidget);
      expect(find.textContaining('Phone Number', findRichText: true), findsOneWidget);
      expect(find.text('CONFIDENTIAL ADMIN NOTES'), findsOneWidget);
      expect(find.text('Client Account Status'), findsOneWidget);

      final submitBtn = find.widgetWithText(AutoButton, 'Create Client');
      expect(submitBtn, findsOneWidget);

      // Tap submit with empty form to trigger validation
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(find.text('Full name is required'), findsOneWidget);
      expect(find.text('Phone number is required'), findsOneWidget);
    });

    testWidgets('Renders Edit mode with pre-populated client data', (tester) async {
      const testClientId = '2bd5d7fb-3b55-48b1-931f-69896d3f0838'; // Rahul Kumar

      await tester.pumpWidget(
        createTestWidget(
          child: const CreateEditClientScreen(clientId: testClientId),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Edit Client'), findsOneWidget);
      expect(find.widgetWithText(AutoButton, 'Save Changes'), findsOneWidget);

      expect(find.text('Rahul Kumar'), findsOneWidget);
      expect(find.text('+91 98450 12890'), findsOneWidget);
      expect(find.text('rahul.kumar@gmail.com'), findsOneWidget);
    });
  });
}
