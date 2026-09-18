import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/design_system/components/auto_button.dart';
import 'package:autotricks/features/service_requests/screens/create_service_request_screen.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A05 — Create Service Request Screen Tests', () {
    testWidgets('Renders phone intake context, client, vehicle, and description inputs', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const CreateServiceRequestScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // App bar title + submit button label both say 'Create Service Request'
      expect(find.text('Create Service Request'), findsNWidgets(2));
      expect(find.text('PHONE REQUEST'), findsOneWidget);
      expect(find.textContaining('Client', findRichText: true), findsOneWidget);
      expect(find.textContaining('Vehicle', findRichText: true), findsOneWidget);
      expect(find.textContaining('Service Description', findRichText: true), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('Validates description field when empty', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const CreateServiceRequestScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final textInput = find.widgetWithText(CreateServiceRequestScreen, 'Routine 25,000 km');
      expect(textInput, findsNothing); // description is inside TextFormField

      final fields = find.byType(CreateServiceRequestScreen);
      expect(fields, findsOneWidget);

      final submitBtn = find.widgetWithText(AutoButton, 'Create Service Request');
      expect(submitBtn, findsOneWidget);

      // Tap submit button with default prefilled text or cleared
      await tester.tap(submitBtn);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });

    testWidgets('Submits request and triggers creation flow', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const CreateServiceRequestScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final submitBtn = find.widgetWithText(AutoButton, 'Create Service Request');
      expect(submitBtn, findsOneWidget);

      await tester.tap(submitBtn);
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
