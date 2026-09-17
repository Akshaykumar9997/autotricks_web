import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autotricks/core/widgets/auto_button.dart';
import 'package:autotricks/features/auth/screens/login_screen.dart';

void main() {
  group('LoginScreen UI & Developer Auth Isolation Tests', () {
    testWidgets('renders login form elements and validation messages',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // Verify branding and form headers
      expect(find.text('WORKSHOP PORTAL ACCESS'), findsOneWidget);
      expect(find.text('Sign In'), findsAtLeastNWidgets(1));

      // Verify email and password text fields exist
      expect(find.byType(TextFormField), findsNWidgets(2));

      // Attempt to submit empty password
      await tester.tap(find.byType(AutoButton).first);
      await tester.pump();

      expect(find.text('Please enter your password'), findsOneWidget);
    });

    testWidgets('developer quick-login helper is present in debug mode',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: LoginScreen(),
          ),
        ),
      );

      // In debug mode with enableDevAuth, the dev auth container is displayed
      expect(find.text('DEVELOPER / TESTING QUICK AUTH'), findsOneWidget);
      expect(find.text('Admin Mode'), findsOneWidget);
      expect(find.text('Client Mode'), findsOneWidget);
    });
  });
}
