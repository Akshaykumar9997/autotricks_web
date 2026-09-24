import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/data/models/notification_model.dart';
import 'package:autotricks/design_system/tokens/app_colors.dart';

void main() {
  group('NotificationModel Tests', () {
    final testDate = DateTime.parse('2026-09-24T10:30:00.000Z');
    final readDate = DateTime.parse('2026-09-24T11:00:00.000Z');

    test('creates model fromJson and serializes toJson cleanly', () {
      final json = {
        'id': 'notif-1',
        'profile_id': 'prof-1',
        'type': 'QUOTATION_SENT',
        'title': 'Quotation Q-001 is ready',
        'message': 'Please review the quotation in your client portal.',
        'entity_type': 'quotation_revision',
        'entity_id': 'rev-1',
        'is_read': true,
        'created_at': testDate.toIso8601String(),
        'read_at': readDate.toIso8601String(),
      };

      final model = NotificationModel.fromJson(json);

      expect(model.id, 'notif-1');
      expect(model.profileId, 'prof-1');
      expect(model.type, 'QUOTATION_SENT');
      expect(model.title, 'Quotation Q-001 is ready');
      expect(model.message, 'Please review the quotation in your client portal.');
      expect(model.entityType, 'quotation_revision');
      expect(model.entityId, 'rev-1');
      expect(model.isRead, isTrue);
      expect(model.createdAt, testDate);
      expect(model.readAt, readDate);

      final serialized = model.toJson();
      expect(serialized['id'], 'notif-1');
      expect(serialized['is_read'], isTrue);
      expect(serialized['type'], 'QUOTATION_SENT');
    });

    test('copyWith updates specified fields only', () {
      final model = NotificationModel(
        id: 'notif-2',
        profileId: 'prof-2',
        type: 'SERVICE_STATUS_UPDATED',
        title: 'Vehicle in progress',
        message: 'Mechanics have started work.',
        createdAt: testDate,
        isRead: false,
      );

      final updated = model.copyWith(
        isRead: true,
        readAt: readDate,
      );

      expect(updated.id, 'notif-2');
      expect(updated.title, 'Vehicle in progress');
      expect(updated.isRead, isTrue);
      expect(updated.readAt, readDate);
      expect(model.isRead, isFalse);
    });

    test('type helpers and categorizers evaluate correctly', () {
      final quoteNotif = NotificationModel(
        id: '1',
        profileId: 'p',
        type: 'QUOTATION_SENT',
        title: 'Q',
        message: 'M',
        createdAt: testDate,
      );
      expect(quoteNotif.isQuotation, isTrue);
      expect(quoteNotif.isServiceJob, isFalse);

      final jobNotif = NotificationModel(
        id: '2',
        profileId: 'p',
        type: 'SERVICE_STATUS_UPDATED',
        title: 'S',
        message: 'M',
        createdAt: testDate,
      );
      expect(jobNotif.isServiceJob, isTrue);
      expect(jobNotif.isQuotation, isFalse);

      final workNotif = NotificationModel(
        id: '3',
        profileId: 'p',
        type: 'ADDITIONAL_WORK_REQUESTED',
        title: 'A',
        message: 'M',
        createdAt: testDate,
      );
      expect(workNotif.isAdditionalWork, isTrue);

      final srNotif = NotificationModel(
        id: '4',
        profileId: 'p',
        type: 'NEW_SERVICE_REQUEST',
        title: 'N',
        message: 'M',
        createdAt: testDate,
      );
      expect(srNotif.isServiceRequest, isTrue);

      final vNotif = NotificationModel(
        id: '5',
        profileId: 'p',
        type: 'VEHICLE_CORRECTION_REQUESTED',
        title: 'V',
        message: 'M',
        createdAt: testDate,
      );
      expect(vNotif.isVehicleCorrection, isTrue);
    });

    test('typeLabel, icon, and iconColor mapping', () {
      final approved = NotificationModel(
        id: '1',
        profileId: 'p',
        type: 'QUOTATION_ACCEPTED',
        title: 'T',
        message: 'M',
        createdAt: testDate,
      );
      expect(approved.typeLabel, 'Quotation Accepted');
      expect(approved.icon, Icons.verified_outlined);
      expect(approved.iconColor, AppColors.success);

      final rejected = NotificationModel(
        id: '2',
        profileId: 'p',
        type: 'QUOTATION_REJECTED',
        title: 'T',
        message: 'M',
        createdAt: testDate,
      );
      expect(rejected.typeLabel, 'Quotation Declined');
      expect(rejected.iconColor, AppColors.danger);

      final addWork = NotificationModel(
        id: '3',
        profileId: 'p',
        type: 'ADDITIONAL_WORK_REQUESTED',
        title: 'T',
        message: 'M',
        createdAt: testDate,
      );
      expect(addWork.typeLabel, 'Additional Work');
      expect(addWork.iconColor, AppColors.warning);
    });
  });
}
