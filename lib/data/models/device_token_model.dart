import 'package:flutter/foundation.dart';

/// Representation of a registered FCM device token in AutoTricks.
@immutable
class DeviceTokenModel {
  final String id;
  final String profileId;
  final String fcmToken;
  final String platform;
  final String? deviceName;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime lastSeenAt;

  const DeviceTokenModel({
    required this.id,
    required this.profileId,
    required this.fcmToken,
    required this.platform,
    this.deviceName,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    required this.lastSeenAt,
  });

  factory DeviceTokenModel.fromJson(Map<String, dynamic> json) {
    return DeviceTokenModel(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      fcmToken: json['fcm_token'] as String,
      platform: json['platform'] as String? ?? 'unknown',
      deviceName: json['device_name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      lastSeenAt: DateTime.parse(json['last_seen_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'fcm_token': fcmToken,
      'platform': platform,
      'device_name': deviceName,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_seen_at': lastSeenAt.toIso8601String(),
    };
  }

  DeviceTokenModel copyWith({
    String? id,
    String? profileId,
    String? fcmToken,
    String? platform,
    String? deviceName,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSeenAt,
  }) {
    return DeviceTokenModel(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      fcmToken: fcmToken ?? this.fcmToken,
      platform: platform ?? this.platform,
      deviceName: deviceName ?? this.deviceName,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceTokenModel &&
        other.id == id &&
        other.profileId == profileId &&
        other.fcmToken == fcmToken &&
        other.platform == platform &&
        other.deviceName == deviceName &&
        other.isActive == isActive;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      profileId,
      fcmToken,
      platform,
      deviceName,
      isActive,
    );
  }

  @override
  String toString() {
    return 'DeviceTokenModel(id: $id, profileId: $profileId, platform: $platform, isActive: $isActive)';
  }
}
