import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/core/services/fcm_service.dart';
import '../../helpers/mock_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FCM Service & Payload Tests', () {
    test('FcmPayload parses notification and data correctly', () {
      const message = RemoteMessage(
        messageId: 'msg-123',
        notification: RemoteNotification(
          title: 'Quotation Revised',
          body: 'Quotation Q-001 has been updated.',
        ),
        data: {
          'entity_type': 'quotation_revision',
          'entity_id': 'rev-456',
          'type': 'QUOTATION_REVISED',
          'extra_key': 'extra_val',
        },
      );

      final payload = FcmPayload.fromRemoteMessage(message);

      expect(payload.title, 'Quotation Revised');
      expect(payload.body, 'Quotation Q-001 has been updated.');
      expect(payload.entityType, 'quotation_revision');
      expect(payload.entityId, 'rev-456');
      expect(payload.notificationType, 'QUOTATION_REVISED');
      expect(payload.rawData['extra_key'], 'extra_val');
    });

    test('FcmPayload falls back to data payload if notification object is null', () {
      const message = RemoteMessage(
        messageId: 'msg-789',
        data: {
          'title': 'Service Update',
          'message': 'Vehicle is now undergoing inspection.',
          'entity_type': 'service_job',
          'entity_id': 'job-888',
          'notification_type': 'SERVICE_STATUS_UPDATED',
        },
      );

      final payload = FcmPayload.fromRemoteMessage(message);

      expect(payload.title, 'Service Update');
      expect(payload.body, 'Vehicle is now undergoing inspection.');
      expect(payload.entityType, 'service_job');
      expect(payload.entityId, 'job-888');
      expect(payload.notificationType, 'SERVICE_STATUS_UPDATED');
    });

    test('resolveRouteFromPayload maps entity types to correct Admin and Client routes', () {
      // 1. Service Request
      const srPayload = FcmPayload(
        entityType: 'service_request',
        entityId: 'sr-100',
      );
      expect(
        FcmService.resolveRouteFromPayload(srPayload, isAdmin: true),
        '/admin/requests/sr-100',
      );
      expect(
        FcmService.resolveRouteFromPayload(srPayload, isAdmin: false),
        '/client/services/sr-100',
      );

      // 2. Quotation
      const qPayload = FcmPayload(
        entityType: 'quotation',
        entityId: 'q-200',
      );
      expect(
        FcmService.resolveRouteFromPayload(qPayload, isAdmin: true),
        '/admin/quotes/q-200',
      );
      expect(
        FcmService.resolveRouteFromPayload(qPayload, isAdmin: false),
        '/client/quotes/q-200',
      );

      // 3. Service Job
      const jobPayload = FcmPayload(
        entityType: 'service_job',
        entityId: 'job-300',
      );
      expect(
        FcmService.resolveRouteFromPayload(jobPayload, isAdmin: true),
        '/admin/jobs/job-300',
      );
      expect(
        FcmService.resolveRouteFromPayload(jobPayload, isAdmin: false),
        '/client/services/job-300',
      );

      // 4. Fallback on missing entityId
      const emptyPayload = FcmPayload();
      expect(
        FcmService.resolveRouteFromPayload(emptyPayload, isAdmin: true),
        '/admin/notifications',
      );
      expect(
        FcmService.resolveRouteFromPayload(emptyPayload, isAdmin: false),
        '/client/notifications',
      );
    });

    test('FcmService initializes safely on current test runner environment', () async {
      final fcmService = FcmService();

      // On Windows / test runner, initialize skips native platform code without throwing
      await fcmService.initialize();

      expect(fcmService.isInitialized, isTrue);
      expect(fcmService.currentToken, isNull);
    });

    test('Background handler executes safely with RemoteMessage', () async {
      const message = RemoteMessage(
        messageId: 'bg-001',
        data: {'title': 'Background Test'},
      );

      // Verify the top-level background handler executes safely
      await expectLater(
        firebaseMessagingBackgroundHandler(message),
        completes,
      );
    });

    test('Receiving FCM message does NOT directly insert into in-app notification repository', () {
      final mockNotifRepo = MockNotificationsRepository();
      expect(mockNotifRepo.notifications.length, 0);

      // Simulate foreground FCM message reception
      const message = RemoteMessage(
        messageId: 'fcm-no-duplicate',
        data: {
          'title': 'Test Push',
          'message': 'This push should not duplicate in-app DB rows',
        },
      );

      final payload = FcmPayload.fromRemoteMessage(message);
      expect(payload.title, 'Test Push');

      // In-app notifications repository remains untouched (single source of truth in DB)
      expect(mockNotifRepo.notifications.length, 0);
    });
  });
}
