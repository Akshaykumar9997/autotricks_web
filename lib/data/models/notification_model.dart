import 'package:flutter/material.dart';
import '../../design_system/tokens/app_colors.dart';

/// Representation of an in-app Notification in the AutoTricks system.
class NotificationModel {
  final String id;
  final String profileId;
  final String type;
  final String title;
  final String message;
  final String? entityType;
  final String? entityId;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;

  const NotificationModel({
    required this.id,
    required this.profileId,
    required this.type,
    required this.title,
    required this.message,
    this.entityType,
    this.entityId,
    this.isRead = false,
    required this.createdAt,
    this.readAt,
  });

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    return NotificationModel(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      type: json['type'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      entityType: json['entity_type'] as String?,
      entityId: json['entity_id'] as String?,
      isRead: json['is_read'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null ? DateTime.parse(json['read_at'] as String) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'profile_id': profileId,
      'type': type,
      'title': title,
      'message': message,
      'entity_type': entityType,
      'entity_id': entityId,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'read_at': readAt?.toIso8601String(),
    };
  }

  NotificationModel copyWith({
    String? id,
    String? profileId,
    String? type,
    String? title,
    String? message,
    String? entityType,
    String? entityId,
    bool? isRead,
    DateTime? createdAt,
    DateTime? readAt,
  }) {
    return NotificationModel(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
      readAt: readAt ?? this.readAt,
    );
  }

  // Type categorizers
  bool get isQuotation => type.startsWith('QUOTATION_');
  bool get isServiceJob => type.startsWith('SERVICE_');
  bool get isAdditionalWork => type.startsWith('ADDITIONAL_WORK_');
  bool get isServiceRequest => type == 'NEW_SERVICE_REQUEST';
  bool get isVehicleCorrection => type.startsWith('VEHICLE_CORRECTION_');

  String get typeLabel {
    switch (type) {
      case 'NEW_SERVICE_REQUEST':
        return 'Service Request';
      case 'QUOTATION_SENT':
        return 'Quotation Sent';
      case 'QUOTATION_REVISED':
        return 'Quotation Revised';
      case 'QUOTATION_CHANGE_REQUESTED':
        return 'Change Request';
      case 'QUOTATION_ACCEPTED':
        return 'Quotation Accepted';
      case 'QUOTATION_SIGNED':
        return 'Quotation Signed';
      case 'ADDITIONAL_WORK_REQUESTED':
        return 'Additional Work';
      case 'ADDITIONAL_WORK_APPROVED':
        return 'Work Approved';
      case 'ADDITIONAL_WORK_REJECTED':
        return 'Work Declined';
      case 'SERVICE_STATUS_UPDATED':
        return 'Service Update';
      case 'SERVICE_JOB_COMPLETED':
        return 'Job Completed';
      case 'QUOTATION_REJECTED':
        return 'Quotation Declined';
      case 'QUOTATION_CHANGE_RESPONDED':
        return 'Change Response';
      case 'VEHICLE_CORRECTION_REQUESTED':
        return 'Vehicle Correction';
      case 'VEHICLE_CORRECTION_RESPONDED':
        return 'Correction Response';
      default:
        return 'Notification';
    }
  }

  IconData get icon {
    switch (type) {
      case 'NEW_SERVICE_REQUEST':
        return Icons.assignment_outlined;
      case 'QUOTATION_SENT':
      case 'QUOTATION_REVISED':
        return Icons.description_outlined;
      case 'QUOTATION_CHANGE_REQUESTED':
      case 'QUOTATION_CHANGE_RESPONDED':
        return Icons.edit_note_outlined;
      case 'QUOTATION_ACCEPTED':
      case 'QUOTATION_SIGNED':
        return Icons.verified_outlined;
      case 'QUOTATION_REJECTED':
        return Icons.highlight_off_outlined;
      case 'ADDITIONAL_WORK_REQUESTED':
        return Icons.add_circle_outline_rounded;
      case 'ADDITIONAL_WORK_APPROVED':
        return Icons.check_circle_outline_rounded;
      case 'ADDITIONAL_WORK_REJECTED':
        return Icons.block_outlined;
      case 'SERVICE_STATUS_UPDATED':
        return Icons.build_circle_outlined;
      case 'SERVICE_JOB_COMPLETED':
        return Icons.task_alt_outlined;
      case 'VEHICLE_CORRECTION_REQUESTED':
      case 'VEHICLE_CORRECTION_RESPONDED':
        return Icons.directions_car_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color get iconColor {
    switch (type) {
      case 'QUOTATION_ACCEPTED':
      case 'QUOTATION_SIGNED':
      case 'ADDITIONAL_WORK_APPROVED':
      case 'SERVICE_JOB_COMPLETED':
        return AppColors.success;
      case 'QUOTATION_REJECTED':
      case 'ADDITIONAL_WORK_REJECTED':
        return AppColors.danger;
      case 'ADDITIONAL_WORK_REQUESTED':
      case 'QUOTATION_CHANGE_REQUESTED':
      case 'VEHICLE_CORRECTION_REQUESTED':
        return AppColors.warning;
      case 'SERVICE_STATUS_UPDATED':
        return AppColors.info;
      case 'NEW_SERVICE_REQUEST':
      case 'QUOTATION_SENT':
      case 'QUOTATION_REVISED':
      default:
        return AppColors.primary;
    }
  }
}
