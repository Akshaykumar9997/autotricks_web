import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/core/widgets/auto_button.dart';
import 'package:autotricks/core/widgets/auto_badge.dart';
import 'package:autotricks/core/widgets/auto_card.dart';
import 'package:autotricks/core/widgets/auto_dialog.dart';
import 'package:autotricks/core/widgets/auto_feedback_states.dart';

void main() {
  group('AutoTricks Reusable Micro-Interactions System Tests', () {
    testWidgets('AutoButton renders primary, secondary, danger, and responds to taps',
        (tester) async {
      bool tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                AutoButton.primary(
                  text: 'Primary Action',
                  onPressed: () => tapped = true,
                ),
                const AutoButton.secondary(
                  text: 'Secondary Action',
                ),
                const AutoButton.danger(
                  text: 'Danger Action',
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Primary Action'), findsOneWidget);
      expect(find.text('Secondary Action'), findsOneWidget);
      expect(find.text('Danger Action'), findsOneWidget);

      await tester.tap(find.text('Primary Action'));
      expect(tapped, isTrue);
    });

    testWidgets('AutoBadge displays correct status labels and styles',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Row(
              children: [
                AutoBadge.open(),
                AutoBadge.inService(),
                AutoBadge.pending(),
                AutoBadge.ready(),
                AutoBadge.draft(),
              ],
            ),
          ),
        ),
      );

      expect(find.text('Open'), findsOneWidget);
      expect(find.text('In Service'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Ready'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
    });

    testWidgets('AutoCard wraps children with rounded dark surface',
        (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AutoCard(
              child: Text('Card Content'),
            ),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      expect(find.byType(AutoCard), findsOneWidget);
    });

    testWidgets('AutoDialog confirm and destructive dialogs function properly',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  AutoDialog.destructive(
                    context,
                    title: 'Delete Request?',
                    description: 'This action cannot be undone.',
                    deleteText: 'Delete Now',
                  );
                },
                child: const Text('Show Dialog'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Show Dialog'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Request?'), findsOneWidget);
      expect(find.text('This action cannot be undone.'), findsOneWidget);
      expect(find.text('Delete Now'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.text('Delete Request?'), findsNothing);
    });

    testWidgets('AutoEmptyState and AutoErrorState render properly with retry',
        (tester) async {
      bool retried = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                const AutoEmptyState(
                  title: 'No Service Requests',
                  description: 'No new requests logged today.',
                ),
                AutoErrorState(
                  message: 'Connection failed',
                  onRetry: () => retried = true,
                ),
              ],
            ),
          ),
        ),
      );

      expect(find.text('No Service Requests'), findsOneWidget);
      expect(find.text('Connection failed'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      await tester.tap(find.text('Try Again'));
      expect(retried, isTrue);
    });
  });
}
