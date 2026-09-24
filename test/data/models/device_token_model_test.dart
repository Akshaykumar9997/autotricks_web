import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/data/models/device_token_model.dart';

void main() {
  group('DeviceTokenModel Tests', () {
    final now = DateTime.now().toUtc();

    test('fromJson deserializes all fields correctly', () {
      final json = {
        'id': 'token-001',
        'profile_id': 'usr-123',
        'fcm_token': 'fcm-abc-123',
        'platform': 'android',
        'device_name': 'Pixel 8 Pro',
        'is_active': true,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
        'last_seen_at': now.toIso8601String(),
      };

      final model = DeviceTokenModel.fromJson(json);

      expect(model.id, 'token-001');
      expect(model.profileId, 'usr-123');
      expect(model.fcmToken, 'fcm-abc-123');
      expect(model.platform, 'android');
      expect(model.deviceName, 'Pixel 8 Pro');
      expect(model.isActive, isTrue);
      expect(model.createdAt.toIso8601String(), now.toIso8601String());
      expect(model.updatedAt.toIso8601String(), now.toIso8601String());
      expect(model.lastSeenAt.toIso8601String(), now.toIso8601String());
    });

    test('toJson serializes model accurately', () {
      final model = DeviceTokenModel(
        id: 'token-002',
        profileId: 'usr-456',
        fcmToken: 'fcm-xyz-789',
        platform: 'ios',
        deviceName: 'iPhone 15 Pro',
        isActive: false,
        createdAt: now,
        updatedAt: now,
        lastSeenAt: now,
      );

      final json = model.toJson();

      expect(json['id'], 'token-002');
      expect(json['profile_id'], 'usr-456');
      expect(json['fcm_token'], 'fcm-xyz-789');
      expect(json['platform'], 'ios');
      expect(json['device_name'], 'iPhone 15 Pro');
      expect(json['is_active'], isFalse);
      expect(json['created_at'], now.toIso8601String());
      expect(json['updated_at'], now.toIso8601String());
      expect(json['last_seen_at'], now.toIso8601String());
    });

    test('copyWith updates specified fields only', () {
      final model = DeviceTokenModel(
        id: 'token-003',
        profileId: 'usr-789',
        fcmToken: 'token-initial',
        platform: 'web',
        isActive: true,
        createdAt: now,
        updatedAt: now,
        lastSeenAt: now,
      );

      final updated = model.copyWith(
        isActive: false,
        deviceName: 'Chrome on Windows',
      );

      expect(updated.id, model.id);
      expect(updated.profileId, model.profileId);
      expect(updated.fcmToken, model.fcmToken);
      expect(updated.isActive, isFalse);
      expect(updated.deviceName, 'Chrome on Windows');
    });

    test('equality and hashCode verify value semantics', () {
      final model1 = DeviceTokenModel(
        id: 'token-1',
        profileId: 'usr-1',
        fcmToken: 'token-1',
        platform: 'android',
        isActive: true,
        createdAt: now,
        updatedAt: now,
        lastSeenAt: now,
      );

      final model2 = DeviceTokenModel(
        id: 'token-1',
        profileId: 'usr-1',
        fcmToken: 'token-1',
        platform: 'android',
        isActive: true,
        createdAt: now,
        updatedAt: now,
        lastSeenAt: now,
      );

      expect(model1, equals(model2));
      expect(model1.hashCode, equals(model2.hashCode));
    });
  });
}
