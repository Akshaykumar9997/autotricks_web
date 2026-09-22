import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/features/client/screens/client_login_screen.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('C01 — Client Login Screen Tests', () {
    testWidgets('Renders Client Garage Portal branding, email, password, and sign in button', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const ClientLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('CLIENT GARAGE PORTAL'), findsOneWidget);
      expect(find.text('Welcome Back'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('CRITICAL: Does NOT contain a "Keep me signed in" checkbox', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const ClientLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Keep me signed in', findRichText: true), findsNothing);
      expect(find.textContaining('Remember me', findRichText: true), findsNothing);
      expect(find.byType(Checkbox), findsNothing);
    });

    testWidgets('Toggles password visibility when eye icon tapped', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const ClientLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final eyeButton = find.byIcon(Icons.visibility_outlined);
      expect(eyeButton, findsOneWidget);

      await tester.tap(eyeButton);
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('Shows validation errors on empty submission', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const ClientLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Clear default values
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '');
      await tester.enterText(textFields.at(1), '');

      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('Shows validation error for invalid email format', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const ClientLoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), 'invalid-email');
      await tester.enterText(textFields.at(1), 'password123');

      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(find.text('Please enter a valid email address'), findsOneWidget);
    });
  });
}
