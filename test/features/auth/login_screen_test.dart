import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/features/auth/screens/login_screen.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('A01 — Admin Login Screen Tests', () {
    testWidgets('Renders Admin Portal branding, email and password fields', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const LoginScreen(),
        ),
      );

      expect(find.text('Admin Portal'), findsOneWidget);
      expect(find.text('Sign in to your account'), findsOneWidget);
      expect(find.text('Email', findRichText: true), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
      expect(find.text('Forgot password?'), findsOneWidget);
    });

    testWidgets('Toggles password visibility when eye icon tapped', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const LoginScreen(),
        ),
      );

      final eyeButton = find.byIcon(Icons.visibility_outlined);
      expect(eyeButton, findsOneWidget);

      await tester.tap(eyeButton);
      await tester.pump();

      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });

    testWidgets('Shows validation errors on empty submission', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: const LoginScreen(),
        ),
      );

      // Clear the pre-filled text
      final textFields = find.byType(TextFormField);
      await tester.enterText(textFields.at(0), '');
      await tester.enterText(textFields.at(1), '');

      // Tap Sign In
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Please enter your password'), findsOneWidget);
    });
  });
}
