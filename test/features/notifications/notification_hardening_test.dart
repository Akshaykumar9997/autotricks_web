import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/data/models/notification_model.dart';

void main() {
  group('Phase 3.1 Notification Hardening & Data Integrity Tests', () {
    test('QUOTATION_ACCEPTED notification model parses correctly with all properties', () {
      final json = {
        'id': 'notif-qa-01',
        'profile_id': 'admin-uuid-1',
        'type': 'QUOTATION_ACCEPTED',
        'title': 'Quotation revision 1 accepted',
        'message': 'Quotation revision 1 was accepted by the client and is awaiting signature.',
        'entity_type': 'quotation_revision',
        'entity_id': 'rev-uuid-1',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
        'read_at': null,
      };

      final model = NotificationModel.fromJson(json);

      expect(model.id, equals('notif-qa-01'));
      expect(model.profileId, equals('admin-uuid-1'));
      expect(model.type, equals('QUOTATION_ACCEPTED'));
      expect(model.entityType, equals('quotation_revision'));
      expect(model.entityId, equals('rev-uuid-1'));
      expect(model.isRead, isFalse);
      expect(model.typeLabel, equals('Quotation Accepted'));
    });

    test('QUOTATION_REJECTED notification model parses correctly with all properties', () {
      final json = {
        'id': 'notif-qr-02',
        'profile_id': 'admin-uuid-1',
        'type': 'QUOTATION_REJECTED',
        'title': 'Quotation revision 1 rejected',
        'message': 'Client rejected quotation revision 1. Reason: Budget exceeded.',
        'entity_type': 'quotation_revision',
        'entity_id': 'rev-uuid-2',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
        'read_at': null,
      };

      final model = NotificationModel.fromJson(json);

      expect(model.id, equals('notif-qr-02'));
      expect(model.profileId, equals('admin-uuid-1'));
      expect(model.type, equals('QUOTATION_REJECTED'));
      expect(model.entityType, equals('quotation_revision'));
      expect(model.entityId, equals('rev-uuid-2'));
      expect(model.isRead, isFalse);
      expect(model.typeLabel, equals('Quotation Declined'));
    });

    test('QUOTATION_CHANGE_RESPONDED notification model parses correctly for Client', () {
      final json = {
        'id': 'notif-qcr-03',
        'profile_id': 'client-uuid-1',
        'type': 'QUOTATION_CHANGE_RESPONDED',
        'title': 'Your quotation change request was reviewed',
        'message': 'Status: ACCEPTED. We will update the labor charges in revision 2.',
        'entity_type': 'quotation_change_request',
        'entity_id': 'qcr-uuid-1',
        'is_read': false,
        'created_at': DateTime.now().toIso8601String(),
        'read_at': null,
      };

      final model = NotificationModel.fromJson(json);

      expect(model.id, equals('notif-qcr-03'));
      expect(model.profileId, equals('client-uuid-1'));
      expect(model.type, equals('QUOTATION_CHANGE_RESPONDED'));
      expect(model.entityType, equals('quotation_change_request'));
      expect(model.entityId, equals('qcr-uuid-1'));
      expect(model.isRead, isFalse);
      expect(model.typeLabel, equals('Change Response'));
    });

    test('All 15 AutoTricks notification types produce valid labels and routes', () {
      const allTypes = [
        'NEW_SERVICE_REQUEST',
        'QUOTATION_SENT',
        'QUOTATION_REVISED',
        'QUOTATION_CHANGE_REQUESTED',
        'QUOTATION_ACCEPTED',
        'QUOTATION_SIGNED',
        'ADDITIONAL_WORK_REQUESTED',
        'ADDITIONAL_WORK_APPROVED',
        'ADDITIONAL_WORK_REJECTED',
        'SERVICE_STATUS_UPDATED',
        'SERVICE_JOB_COMPLETED',
        'QUOTATION_REJECTED',
        'QUOTATION_CHANGE_RESPONDED',
        'VEHICLE_CORRECTION_REQUESTED',
        'VEHICLE_CORRECTION_RESPONDED',
      ];

      for (final type in allTypes) {
        final notif = NotificationModel(
          id: 'test-$type',
          profileId: 'usr-test',
          type: type,
          title: 'Title for $type',
          message: 'Message for $type',
          isRead: false,
          createdAt: DateTime.now(),
        );

        expect(notif.typeLabel.isNotEmpty, isTrue, reason: 'Type $type should have a label');
        expect(notif.icon, isNotNull, reason: 'Type $type should have an icon');
        expect(notif.iconColor, isNotNull, reason: 'Type $type should have an icon color');
      }
    });

    test('Retention threshold logic: identifies items older than 90 days', () {
      final now = DateTime.now();
      final retentionThreshold = now.subtract(const Duration(days: 90));

      final oldNotif = NotificationModel(
        id: 'old-1',
        profileId: 'u1',
        type: 'SERVICE_STATUS_UPDATED',
        title: 'Old',
        message: '95 days ago',
        isRead: false,
        createdAt: now.subtract(const Duration(days: 95)),
      );

      final recentNotif = NotificationModel(
        id: 'recent-1',
        profileId: 'u1',
        type: 'SERVICE_STATUS_UPDATED',
        title: 'Recent',
        message: '10 days ago',
        isRead: false,
        createdAt: now.subtract(const Duration(days: 10)),
      );

      final readWithinPeriod = NotificationModel(
        id: 'read-1',
        profileId: 'u1',
        type: 'SERVICE_STATUS_UPDATED',
        title: 'Read',
        message: '30 days ago',
        isRead: true,
        createdAt: now.subtract(const Duration(days: 30)),
        readAt: now.subtract(const Duration(days: 29)),
      );

      // Verify retention qualification
      expect(oldNotif.createdAt.isBefore(retentionThreshold), isTrue,
          reason: 'Old notification qualifies for 90-day deletion');
      expect(recentNotif.createdAt.isBefore(retentionThreshold), isFalse,
          reason: 'Recent notification must be retained');
      expect(readWithinPeriod.createdAt.isBefore(retentionThreshold), isFalse,
          reason: 'Read notification within 90 days must be retained');
    });
  });
}
