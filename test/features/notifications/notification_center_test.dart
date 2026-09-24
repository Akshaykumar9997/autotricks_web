import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autotricks/data/models/notification_model.dart';
import 'package:autotricks/data/repositories/notifications_repository.dart';
import 'package:autotricks/design_system/theme/app_theme.dart';
import 'package:autotricks/features/client/screens/client_home_screen.dart';
import 'package:autotricks/features/home/screens/admin_home_screen.dart';
import 'package:autotricks/features/notifications/screens/notification_center_screen.dart';
import '../../helpers/mock_repositories.dart';
import '../../helpers/test_wrapper.dart';

void main() {
  group('Notification Center Tests', () {
    late MockNotificationsRepository notifRepo;

    final sampleNotifications = [
      NotificationModel(
        id: 'n-1',
        profileId: 'usr-admin-1',
        type: 'QUOTATION_ACCEPTED',
        title: 'Quotation Q-001 accepted',
        message: 'Client accepted quotation revision 1.',
        entityType: 'quotation',
        entityId: 'q-101',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      NotificationModel(
        id: 'n-2',
        profileId: 'usr-admin-1',
        type: 'NEW_SERVICE_REQUEST',
        title: 'New service request SR-002',
        message: 'Submitted from the website.',
        entityType: 'service_request',
        entityId: 'sr-202',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
        readAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      NotificationModel(
        id: 'n-3',
        profileId: 'usr-admin-1',
        type: 'ADDITIONAL_WORK_REQUESTED',
        title: 'Additional work pending',
        message: 'Requires client authorization.',
        entityType: 'service_job',
        entityId: 'job-303',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 2)),
      ),
    ];

    setUp(() {
      notifRepo = MockNotificationsRepository(
        initialNotifications: sampleNotifications,
      );
    });

    testWidgets('renders notification list with unread indicators and badges', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          notificationsRepo: notifRepo,
          child: const NotificationCenterScreen(isAdmin: true),
        ),
      );
      await tester.pumpAndSettle();

      // Check titles
      expect(find.text('Notifications'), findsOneWidget);
      expect(find.text('Quotation Q-001 accepted'), findsOneWidget);
      expect(find.text('New service request SR-002'), findsOneWidget);
      expect(find.text('Additional work pending'), findsOneWidget);

      // Check unread dots exist for n-1 and n-3, but NOT n-2
      expect(find.byKey(const Key('unread_dot_n-1')), findsOneWidget);
      expect(find.byKey(const Key('unread_dot_n-3')), findsOneWidget);
      expect(find.byKey(const Key('unread_dot_n-2')), findsNothing);

      // Check mark read buttons exist for unread items only
      expect(find.byKey(const Key('mark_read_btn_n-1')), findsOneWidget);
      expect(find.byKey(const Key('mark_read_btn_n-3')), findsOneWidget);
      expect(find.byKey(const Key('mark_read_btn_n-2')), findsNothing);

      // Check "Mark all read" button exists because unread count > 0
      expect(find.byKey(const Key('mark_all_read_button')), findsOneWidget);
    });

    testWidgets('renders empty state when there are no notifications', (tester) async {
      final emptyRepo = MockNotificationsRepository(initialNotifications: []);

      await tester.pumpWidget(
        createTestWidget(
          notificationsRepo: emptyRepo,
          child: const NotificationCenterScreen(isAdmin: false),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No notifications yet'), findsOneWidget);
      expect(find.byKey(const Key('mark_all_read_button')), findsNothing);
    });

    testWidgets('mark single notification as read updates state and hides unread dot', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          notificationsRepo: notifRepo,
          child: const NotificationCenterScreen(isAdmin: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('unread_dot_n-1')), findsOneWidget);

      // Tap individual mark read button
      await tester.tap(find.byKey(const Key('mark_read_btn_n-1')));
      await tester.pumpAndSettle();

      // Unread dot and button should disappear for n-1
      expect(find.byKey(const Key('unread_dot_n-1')), findsNothing);
      expect(find.byKey(const Key('mark_read_btn_n-1')), findsNothing);

      // n-3 should still have its unread dot
      expect(find.byKey(const Key('unread_dot_n-3')), findsOneWidget);
    });

    testWidgets('mark all as read updates all notifications and removes Mark All button', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          notificationsRepo: notifRepo,
          child: const NotificationCenterScreen(isAdmin: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('mark_all_read_button')), findsOneWidget);

      // Tap Mark all read
      await tester.tap(find.byKey(const Key('mark_all_read_button')));
      await tester.pumpAndSettle();

      // All unread dots should disappear
      expect(find.byKey(const Key('unread_dot_n-1')), findsNothing);
      expect(find.byKey(const Key('unread_dot_n-3')), findsNothing);
      expect(find.byKey(const Key('mark_all_read_button')), findsNothing);
    });

    testWidgets('AdminHomeScreen shows actual unread notification count badge', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          notificationsRepo: notifRepo,
          child: const AdminHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Unread count is 2 (n-1 and n-3)
      final badgeFinder = find.byKey(const Key('auto_app_bar_unread_badge'));
      expect(badgeFinder, findsOneWidget);
      expect(find.descendant(of: badgeFinder, matching: find.text('2')), findsOneWidget);
    });

    testWidgets('ClientHomeScreen shows actual unread notification count badge and bell', (tester) async {
      await tester.pumpWidget(
        createTestWidget(
          notificationsRepo: notifRepo,
          child: const ClientHomeScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('client_notification_bell_button')), findsOneWidget);
      final clientBadgeFinder = find.byKey(const Key('client_unread_notification_badge'));
      expect(clientBadgeFinder, findsOneWidget);
      expect(find.descendant(of: clientBadgeFinder, matching: find.text('2')), findsOneWidget);
    });

    testWidgets('Tapping notification marks it as read and triggers deep linking', (tester) async {
      String? navigatedRoute;

      final router = GoRouter(
        initialLocation: '/admin/notifications',
        routes: [
          GoRoute(
            path: '/admin/notifications',
            builder: (context, state) => const NotificationCenterScreen(isAdmin: true),
          ),
          GoRoute(
            path: '/admin/quotes/:id',
            builder: (context, state) {
              navigatedRoute = state.uri.toString();
              return const Scaffold(body: Text('Quote Detail Screen'));
            },
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            notificationsRepositoryProvider.overrideWithValue(notifRepo),
          ],
          child: MaterialApp.router(
            theme: AppTheme.darkTheme,
            routerConfig: router,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap on the first notification (Quotation Q-001 accepted)
      await tester.tap(find.text('Quotation Q-001 accepted'));
      await tester.pumpAndSettle();

      // Deep link to /admin/quotes/q-101 should be opened
      expect(navigatedRoute, '/admin/quotes/q-101');
      expect(find.text('Quote Detail Screen'), findsOneWidget);

      // And n-1 was marked as read
      expect(notifRepo.notifications.firstWhere((n) => n.id == 'n-1').isRead, isTrue);
    });
  });
}
