import 'package:flutter/material.dart';
import '../../../data/models/service_request_model.dart';
import '../../../design_system/tokens/app_colors.dart';

/// Information regarding the customer-facing status of a service request.
class ClientStatusInfo {
  final String label;
  final Color color;
  final String explanation;
  final String? nextActionHint;

  const ClientStatusInfo({
    required this.label,
    required this.color,
    required this.explanation,
    this.nextActionHint,
  });
}

/// Helper to translate backend request status + optional job status into
/// customer-facing presentation labels, colors, and humanized explanations.
///
/// Strictly UI-only. Never stores these display labels back into the database.
class ClientStatusHelper {
  ClientStatusHelper._();

  static String getStatusLabel(ServiceRequestModel request) {
    return getStatusInfo(
      requestStatus: request.status,
      jobStatus: request.jobStatus,
    ).label;
  }

  static Color getStatusColor(ServiceRequestModel request) {
    return getStatusInfo(
      requestStatus: request.status,
      jobStatus: request.jobStatus,
    ).color;
  }

  static String getStatusExplanation(ServiceRequestModel request) {
    return getStatusInfo(
      requestStatus: request.status,
      jobStatus: request.jobStatus,
    ).explanation;
  }

  static IconData getStatusIcon(ServiceRequestModel request) {
    final normReq = request.status.toUpperCase();
    final normJob = request.jobStatus?.toUpperCase();
    if (normReq == 'CANCELLED' || normJob == 'CANCELLED') {
      return Icons.cancel_outlined;
    }
    if (normJob == 'COMPLETED') {
      return Icons.check_circle_rounded;
    }
    if (normReq == 'QUOTATION_SENT') {
      return Icons.request_quote_rounded;
    }
    if (normReq == 'CONVERTED_TO_JOB') {
      return Icons.handyman_rounded;
    }
    return Icons.hourglass_top_rounded;
  }

  static ClientStatusInfo getStatusInfo({
    required String requestStatus,
    String? jobStatus,
  }) {
    final normReq = requestStatus.toUpperCase();
    final normJob = jobStatus?.toUpperCase();

    if (normReq == 'CANCELLED' || normJob == 'CANCELLED') {
      return const ClientStatusInfo(
        label: 'Cancelled',
        color: AppColors.danger,
        explanation: 'This service request has been cancelled.',
        nextActionHint: 'No further action required.',
      );
    }

    if (normJob == 'COMPLETED') {
      return const ClientStatusInfo(
        label: 'Service Completed',
        color: AppColors.success,
        explanation: 'Service has been completed successfully.',
        nextActionHint: 'Your vehicle service is complete.',
      );
    }

    switch (normReq) {
      case 'NEW':
        return const ClientStatusInfo(
          label: 'Request Received',
          color: AppColors.info,
          explanation:
              'We have received your service request and will review it shortly.',
          nextActionHint: 'Our team will review your requirements.',
        );

      case 'UNDER_REVIEW':
        return const ClientStatusInfo(
          label: 'Under Review',
          color: AppColors.info,
          explanation:
              'Our team is reviewing your vehicle service request and preparing the next step.',
          nextActionHint: 'Quotation will be prepared shortly.',
        );

      case 'QUOTATION_CREATED':
        return const ClientStatusInfo(
          label: 'Quotation Being Prepared',
          color: AppColors.warning,
          explanation:
              'Our team is calculating the service estimate for your vehicle.',
          nextActionHint: 'Quotation will be ready for review soon.',
        );

      case 'QUOTATION_SENT':
        return const ClientStatusInfo(
          label: 'Quotation Ready',
          color: AppColors.primary,
          explanation:
              'Your quotation is ready for your digital review and approval.',
          nextActionHint: 'Review and approve quote items directly.',
        );

      case 'APPROVED':
        return const ClientStatusInfo(
          label: 'Service Approved',
          color: AppColors.success,
          explanation:
              'You have approved the quotation. We are preparing for vehicle intake.',
          nextActionHint: 'Workshop intake is being scheduled.',
        );

      case 'CONVERTED_TO_JOB':
        // Dynamically inspect underlying job status
        if (normJob == 'SCHEDULED') {
          return const ClientStatusInfo(
            label: 'Service Scheduled',
            color: AppColors.info,
            explanation:
                'Your service has been scheduled with the workshop team.',
            nextActionHint: 'Awaiting vehicle arrival at the workshop.',
          );
        } else if (normJob == 'VEHICLE_RECEIVED') {
          return const ClientStatusInfo(
            label: 'Vehicle Received',
            color: AppColors.info,
            explanation: 'Your vehicle has been received at the workshop.',
            nextActionHint: 'Initial intake checklist in progress.',
          );
        } else if (normJob == 'INSPECTION') {
          return const ClientStatusInfo(
            label: 'Under Inspection',
            color: AppColors.info,
            explanation: 'Technicians are currently inspecting your vehicle.',
            nextActionHint: 'Inspection findings being compiled.',
          );
        } else if (normJob == 'WORK_IN_PROGRESS') {
          return const ClientStatusInfo(
            label: 'Service Started',
            color: AppColors.primary,
            explanation: 'Service work is actively in progress.',
            nextActionHint: 'Technicians are carrying out approved work.',
          );
        } else if (normJob == 'QUALITY_CHECK') {
          return const ClientStatusInfo(
            label: 'Quality Check',
            color: AppColors.warning,
            explanation: 'Final inspection and quality checks are in progress.',
            nextActionHint: 'Vehicle undergoing quality assurance.',
          );
        } else if (normJob == 'READY_FOR_DELIVERY') {
          return const ClientStatusInfo(
            label: 'Ready for Delivery',
            color: AppColors.success,
            explanation: 'Your vehicle is ready for delivery/pickup.',
            nextActionHint: 'You may collect your vehicle from the workshop.',
          );
        } else {
          return const ClientStatusInfo(
            label: 'Service Confirmed',
            color: AppColors.info,
            explanation:
                'Service confirmed. Workshop intake is being scheduled.',
            nextActionHint: 'Our team will contact you for intake.',
          );
        }

      default:
        return ClientStatusInfo(
          label: normReq.replaceAll('_', ' '),
          color: AppColors.textSecondary,
          explanation: 'Your service request is being processed.',
        );
    }
  }

  /// Determines whether a service request is considered "Active".
  static bool isActive({
    required String requestStatus,
    String? jobStatus,
  }) {
    final normReq = requestStatus.toUpperCase();
    final normJob = jobStatus?.toUpperCase();

    if (normReq == 'CANCELLED' || normJob == 'CANCELLED') return false;
    if (normJob == 'COMPLETED') return false;

    if (normReq == 'NEW' ||
        normReq == 'UNDER_REVIEW' ||
        normReq == 'QUOTATION_CREATED' ||
        normReq == 'QUOTATION_SENT' ||
        normReq == 'APPROVED') {
      return true;
    }

    if (normReq == 'CONVERTED_TO_JOB') {
      return normJob != 'COMPLETED' && normJob != 'CANCELLED';
    }

    return false;
  }

  /// Determines whether a service request is considered "Completed".
  static bool isCompleted({
    required String requestStatus,
    String? jobStatus,
  }) {
    return jobStatus?.toUpperCase() == 'COMPLETED';
  }

  /// Determines whether a service request is considered "Cancelled".
  static bool isCancelled({
    required String requestStatus,
    String? jobStatus,
  }) {
    return requestStatus.toUpperCase() == 'CANCELLED' ||
        jobStatus?.toUpperCase() == 'CANCELLED';
  }
}
