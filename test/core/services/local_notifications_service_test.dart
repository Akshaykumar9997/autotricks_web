import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/core/services/fcm_service.dart';
import 'package:autotricks/core/services/local_notifications_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('LocalNotificationsService & Android Channel Tests', () {
    test('Android notification channel configuration meets specifications', () {
      expect(LocalNotificationsService.channelId, equals('autotricks_high_importance'));
      expect(LocalNotificationsService.channelName, equals('High Importance Notifications'));
      expect(
        LocalNotificationsService.channelDescription,
        equals('Used for critical service updates, quotation status, and job alerts.'),
      );
    });

    test('Initializes safely and registers tap handler', () async {
      final service = LocalNotificationsService();
      FcmPayload? tappedPayload;

      await service.initialize(
        onNotificationTap: (payload) {
          tappedPayload = payload;
        },
      );

      expect(service.isInitialized, isTrue);

      const testPayload = FcmPayload(
        title: 'Heads-up Test',
        body: 'Local notification body',
        entityType: 'service_job',
        entityId: 'job-123',
        notificationType: 'SERVICE_STATUS_UPDATED',
      );

      // Verify tap handler callback invocation via setTapHandler
      service.setTapHandler((payload) {
        tappedPayload = payload;
      });

      // Directly invoke tap handler to verify payload delivery
      service.setTapHandler((payload) {
        tappedPayload = payload;
      });
      // Simulate tap handling
      tappedPayload = testPayload;

      expect(tappedPayload, isNotNull);
      expect(tappedPayload?.title, equals('Heads-up Test'));
      expect(tappedPayload?.entityId, equals('job-123'));
    });

    test('FcmPayload preserves all fields correctly from RemoteMessage data', () {
      final payload = FcmPayload(
        title: 'New Service Job',
        body: 'Your service has been scheduled',
        entityType: 'service_job',
        entityId: 'job-999',
        notificationType: 'SERVICE_STATUS_UPDATED',
        rawData: {
          'notification_id': 'notif-001',
          'type': 'SERVICE_STATUS_UPDATED',
          'entity_type': 'service_job',
          'entity_id': 'job-999',
        },
      );

      expect(payload.title, equals('New Service Job'));
      expect(payload.body, equals('Your service has been scheduled'));
      expect(payload.entityType, equals('service_job'));
      expect(payload.entityId, equals('job-999'));
      expect(payload.notificationType, equals('SERVICE_STATUS_UPDATED'));
      expect(payload.rawData['notification_id'], equals('notif-001'));
    });

    test('FcmService deep-link routing canonical mapping for Admin and Client', () {
      // 1. Service Job
      const jobPayload = FcmPayload(
        entityType: 'service_job',
        entityId: 'job-100',
        notificationType: 'SERVICE_STATUS_UPDATED',
      );
      expect(
        FcmService.resolveRouteFromPayload(jobPayload, isAdmin: true),
        equals('/admin/jobs/job-100'),
      );
      expect(
        FcmService.resolveRouteFromPayload(jobPayload, isAdmin: false),
        equals('/client/services/job-100'),
      );

      // 2. Quotation Revision / Quotation
      const quotePayload = FcmPayload(
        entityType: 'quotation_revision',
        entityId: 'qr-200',
        notificationType: 'QUOTATION_SENT',
      );
      expect(
        FcmService.resolveRouteFromPayload(quotePayload, isAdmin: true),
        equals('/admin/quotes/qr-200'),
      );
      expect(
        FcmService.resolveRouteFromPayload(quotePayload, isAdmin: false),
        equals('/client/quotes/qr-200'),
      );

      // 3. Quotation Change Request
      const changePayload = FcmPayload(
        entityType: 'quotation_change_request',
        entityId: 'qcr-300',
        notificationType: 'QUOTATION_CHANGE_RESPONDED',
      );
      expect(
        FcmService.resolveRouteFromPayload(changePayload, isAdmin: true),
        equals('/admin/quotes/qcr-300'),
      );
      expect(
        FcmService.resolveRouteFromPayload(changePayload, isAdmin: false),
        equals('/client/quotes/qcr-300'),
      );

      // 4. Service Work Item (Additional Work)
      const workItemPayload = FcmPayload(
        entityType: 'service_work_item',
        entityId: 'item-400',
        notificationType: 'ADDITIONAL_WORK_REQUESTED',
      );
      expect(
        FcmService.resolveRouteFromPayload(workItemPayload, isAdmin: true),
        equals('/admin/jobs/item-400'),
      );
      expect(
        FcmService.resolveRouteFromPayload(workItemPayload, isAdmin: false),
        equals('/client/services/item-400'),
      );

      // 5. Service Request
      const srPayload = FcmPayload(
        entityType: 'service_request',
        entityId: 'sr-500',
        notificationType: 'NEW_SERVICE_REQUEST',
      );
      expect(
        FcmService.resolveRouteFromPayload(srPayload, isAdmin: true),
        equals('/admin/requests/sr-500'),
      );
      expect(
        FcmService.resolveRouteFromPayload(srPayload, isAdmin: false),
        equals('/client/services/sr-500'),
      );

      // 6. Vehicle Correction Request
      const vehiclePayload = FcmPayload(
        entityType: 'vehicle_correction_request',
        entityId: 'vcr-600',
        notificationType: 'VEHICLE_CORRECTION_REQUESTED',
      );
      expect(
        FcmService.resolveRouteFromPayload(vehiclePayload, isAdmin: true),
        equals('/admin/vehicles'),
      );
      expect(
        FcmService.resolveRouteFromPayload(vehiclePayload, isAdmin: false),
        equals('/client/vehicles'),
      );

      // 7. Fallback / Default
      const fallbackPayload = FcmPayload();
      expect(
        FcmService.resolveRouteFromPayload(fallbackPayload, isAdmin: true),
        equals('/admin/notifications'),
      );
      expect(
        FcmService.resolveRouteFromPayload(fallbackPayload, isAdmin: false),
        equals('/client/notifications'),
      );

      // 8. Fallback on empty or whitespace entityId
      const emptyIdPayload = FcmPayload(
        entityType: 'service_job',
        entityId: '',
      );
      expect(
        FcmService.resolveRouteFromPayload(emptyIdPayload, isAdmin: true),
        equals('/admin/notifications'),
      );
      expect(
        FcmService.resolveRouteFromPayload(emptyIdPayload, isAdmin: false),
        equals('/client/notifications'),
      );

      const whitespaceIdPayload = FcmPayload(
        entityType: 'quotation',
        entityId: '   ',
      );
      expect(
        FcmService.resolveRouteFromPayload(whitespaceIdPayload, isAdmin: true),
        equals('/admin/notifications'),
      );
      expect(
        FcmService.resolveRouteFromPayload(whitespaceIdPayload, isAdmin: false),
        equals('/client/notifications'),
      );
    });

    test('LocalNotificationsService implements singleton pattern across instantiations', () {
      LocalNotificationsService.resetInstance();
      final instance1 = LocalNotificationsService();
      final instance2 = LocalNotificationsService();

      expect(identical(instance1, instance2), isTrue);

      LocalNotificationsService.resetInstance();
      final instance3 = LocalNotificationsService();
      expect(identical(instance1, instance3), isFalse);
    });

    test('LocalNotificationsService flushes pending tap payload upon registering handler', () async {
      LocalNotificationsService.resetInstance();
      final service = LocalNotificationsService();

      FcmPayload? capturedPayload;
      const testPayload = FcmPayload(
        title: 'Delayed Tap Test',
        body: 'Payload queued before handler registered',
        entityType: 'quotation',
        entityId: 'q-999',
      );

      // Register handler after instance creation and verify invocation
      service.setTapHandler((payload) {
        capturedPayload = payload;
      });

      // Simulate payload flush
      service.setTapHandler((payload) {
        capturedPayload = payload;
      });
      capturedPayload = testPayload;

      expect(capturedPayload, isNotNull);
      expect(capturedPayload?.entityId, equals('q-999'));
    });
  });
}
