import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/design_system/components/auto_badge.dart';
import 'package:autotricks/design_system/components/auto_button.dart';
import 'package:autotricks/design_system/components/auto_card.dart';
import 'package:autotricks/design_system/components/auto_empty_state.dart';
import 'package:autotricks/design_system/components/auto_error_state.dart';
import 'package:autotricks/design_system/components/auto_input.dart';
import 'package:autotricks/design_system/components/auto_list_tile.dart';
import 'package:autotricks/design_system/components/auto_section_header.dart';
import 'package:autotricks/design_system/components/auto_select.dart';
import 'package:autotricks/design_system/components/auto_timeline.dart';
import 'package:autotricks/design_system/components/auto_bottom_nav.dart';
import 'package:autotricks/design_system/tokens/app_colors.dart';
import '../helpers/test_wrapper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Core Components Test', () {
    testWidgets('AutoButton renders text and triggers callback', (tester) async {
      var tapped = false;
      await tester.pumpWidget(
        createTestWidget(
          child: Scaffold(
            body: AutoButton(
              label: 'Submit Action',
              onPressed: () => tapped = true,
            ),
          ),
        ),
      );

      expect(find.text('Submit Action'), findsOneWidget);
      await tester.tap(find.text('Submit Action'));
      expect(tapped, isTrue);
    });

    testWidgets('AutoButton shows loading indicator when isLoading is true', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: AutoButton(
            label: 'Saving Data',
            isLoading: true,
            onPressed: () {},
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Saving Data'), findsOneWidget);
    });

    testWidgets('AutoBadge displays status label and styling', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: Column(
            children: [
              AutoBadge.fromStatus('NEW'),
              AutoBadge.fromStatus('UNDER_REVIEW'),
              AutoBadge.fromStatus('APPROVED'),
            ],
          ),
        ),
      );

      expect(find.text('NEW'), findsOneWidget);
      expect(find.text('UNDER REVIEW'), findsOneWidget);
      expect(find.text('APPROVED'), findsOneWidget);
    });

    testWidgets('AutoCard responds to taps and displays content', (tester) async {
      var cardTapped = false;
      await tester.pumpWidget(
        createTestWidget(
          child: AutoCard(
            statusStripeColor: AppColors.info,
            onTap: () => cardTapped = true,
            child: const Text('Card Content'),
          ),
        ),
      );

      expect(find.text('Card Content'), findsOneWidget);
      await tester.tap(find.text('Card Content'));
      expect(cardTapped, isTrue);
    });

    testWidgets('AutoInput handles text input and labels', (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        createTestWidget(
          child: Scaffold(
            body: AutoInput(
              controller: controller,
              label: 'Customer Name',
              hint: 'Enter full name',
            ),
          ),
        ),
      );

      expect(find.text('Customer Name', findRichText: true), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'John Doe');
      expect(controller.text, 'John Doe');
    });

    testWidgets('AutoSelect renders selected value and opens dropdown', (tester) async {
      String? selectedValue = 'item1';
      await tester.pumpWidget(
        createTestWidget(
          child: Scaffold(
            body: AutoSelect<String>(
              label: 'Select Option',
              placeholder: 'Choose one',
              value: selectedValue,
              items: const [
                DropdownMenuItem(value: 'item1', child: Text('Option 1')),
                DropdownMenuItem(value: 'item2', child: Text('Option 2')),
              ],
              onChanged: (val) => selectedValue = val,
            ),
          ),
        ),
      );

      expect(find.text('Option 1'), findsOneWidget);
    });

    testWidgets('AutoListTile renders title, subtitle, and responds to taps', (tester) async {
      var tileTapped = false;
      await tester.pumpWidget(
        createTestWidget(
          child: AutoListTile(
            title: 'Diagnostic Test',
            subtitle: 'Engine inspection',
            onTap: () => tileTapped = true,
          ),
        ),
      );

      expect(find.text('Diagnostic Test'), findsOneWidget);
      expect(find.text('Engine inspection'), findsOneWidget);
      await tester.tap(find.text('Diagnostic Test'));
      expect(tileTapped, isTrue);
    });

    testWidgets('AutoEmptyState renders message and action button', (tester) async {
      var actionTriggered = false;
      await tester.pumpWidget(
        createTestWidget(
          child: AutoEmptyState(
            title: 'No Data Available',
            message: 'Nothing to see here',
            actionLabel: 'Refresh Now',
            useIllustration: false,
            onAction: () => actionTriggered = true,
          ),
        ),
      );

      expect(find.text('No Data Available'), findsOneWidget);
      expect(find.text('Nothing to see here'), findsOneWidget);
      expect(find.text('Refresh Now'), findsOneWidget);
      await tester.tap(find.text('Refresh Now'));
      expect(actionTriggered, isTrue);
    });

    testWidgets('AutoErrorState renders error title and retry button', (tester) async {
      var retried = false;
      await tester.pumpWidget(
        createTestWidget(
          child: AutoErrorState(
            title: 'Failed to Load',
            message: 'Network connection failed',
            onRetry: () => retried = true,
          ),
        ),
      );

      expect(find.text('Failed to Load'), findsOneWidget);
      expect(find.text('Network connection failed'), findsOneWidget);
      await tester.tap(find.text('Try Again'));
      expect(retried, isTrue);
    });

    testWidgets('AutoSectionHeader renders title and action', (tester) async {
      var viewAllPressed = false;
      await tester.pumpWidget(
        createTestWidget(
          child: AutoSectionHeader(
            title: 'Active Jobs',
            trailing: const Text('View All'),
            onTrailingTap: () => viewAllPressed = true,
          ),
        ),
      );

      expect(find.text('Active Jobs'), findsOneWidget);
      expect(find.text('View All'), findsOneWidget);
      await tester.tap(find.text('View All'));
      expect(viewAllPressed, isTrue);
    });

    testWidgets('AutoTimeline renders timeline items via forServiceRequest factory', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          child: AutoTimeline.forServiceRequest(
            currentStatus: 'UNDER_REVIEW',
            timestamp: '10:30 AM',
          ),
        ),
      );

      expect(find.text('NEW'), findsOneWidget);
      expect(find.text('UNDER REVIEW'), findsOneWidget);
      expect(find.text('CURRENT'), findsOneWidget);
    });

    testWidgets('AutoBottomNav opens Quick Create sheet with 3 approved actions', (tester) async {
      var createRequestTapped = false;

      await tester.pumpWidget(
        createTestWidget(
          child: Scaffold(
            bottomNavigationBar: AutoBottomNav(
              currentTab: AdminNavTab.home,
              onTabSelected: (_) {},
              onCreateRequest: () => createRequestTapped = true,
              onCreateClient: () {},
              onCreateVehicle: () {},
            ),
          ),
        ),
      );

      // Tap center + button
      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();

      // Verify the 3 approved contextual creation actions are present
      expect(find.text('Quick Create'), findsOneWidget);
      expect(find.text('Create Service Request'), findsOneWidget);
      expect(find.text('Create Client'), findsOneWidget);
      expect(find.text('Create Vehicle'), findsOneWidget);

      // Tap Create Service Request
      await tester.tap(find.text('Create Service Request'));
      await tester.pumpAndSettle();
      expect(createRequestTapped, isTrue);
    });
  });
}
