import 'package:flutter/material.dart';
import '../../../data/models/quotation_model.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../core/utils/date_formatter.dart';

class ClientQuotationStatusInfo {
  final String label;
  final Color color;
  final IconData icon;
  final String explanation;

  const ClientQuotationStatusInfo({
    required this.label,
    required this.color,
    required this.icon,
    required this.explanation,
  });
}

class ClientQuotationStatusHelper {
  ClientQuotationStatusHelper._();

  static ClientQuotationStatusInfo getStatusInfo(String rawStatus) {
    final status = rawStatus.toUpperCase().trim();
    switch (status) {
      case 'SENT':
        return const ClientQuotationStatusInfo(
          label: 'Awaiting Review',
          color: AppColors.primary,
          icon: Icons.mark_email_unread_outlined,
          explanation: 'This quotation is ready and awaiting your review.',
        );
      case 'VIEWED':
        return const ClientQuotationStatusInfo(
          label: 'Under Review',
          color: AppColors.info,
          icon: Icons.visibility_outlined,
          explanation: 'You have viewed this quotation.',
        );
      case 'CHANGE_REQUESTED':
        return const ClientQuotationStatusInfo(
          label: 'Changes Requested',
          color: AppColors.warning,
          icon: Icons.edit_note_rounded,
          explanation:
              'You have requested changes on this revision. Our service advisor is preparing an update.',
        );
      case 'ACCEPTED':
        return const ClientQuotationStatusInfo(
          label: 'Accepted',
          color: AppColors.success,
          icon: Icons.check_circle_outline_rounded,
          explanation:
              'Quotation accepted. Digital signature authorization is required in the next step before service execution can begin.',
        );
      case 'REJECTED':
        return const ClientQuotationStatusInfo(
          label: 'Declined',
          color: AppColors.danger,
          icon: Icons.cancel_outlined,
          explanation: 'This quotation revision was declined.',
        );
      case 'SUPERSEDED':
        return const ClientQuotationStatusInfo(
          label: 'Superseded',
          color: AppColors.textMuted,
          icon: Icons.history_rounded,
          explanation: 'This revision was superseded by a newer revision.',
        );
      case 'CANCELLED':
        return const ClientQuotationStatusInfo(
          label: 'Cancelled',
          color: AppColors.danger,
          icon: Icons.block_rounded,
          explanation: 'This quotation was cancelled.',
        );
      case 'EXPIRED':
        return const ClientQuotationStatusInfo(
          label: 'Expired',
          color: AppColors.textMuted,
          icon: Icons.timer_off_outlined,
          explanation: 'This quotation has expired.',
        );
      default:
        return ClientQuotationStatusInfo(
          label: status.replaceAll('_', ' '),
          color: AppColors.textSecondary,
          icon: Icons.description_outlined,
          explanation: 'Quotation status: $status.',
        );
    }
  }

  static String getFormattedRevisionDate(QuotationRevisionModel rev) {
    final status = rev.status.toUpperCase();
    if (status == 'ACCEPTED' && rev.acceptedAt != null) {
      return 'Accepted ${DateFormatter.formatDate(rev.acceptedAt!)}';
    }
    if (status == 'REJECTED' && rev.rejectedAt != null) {
      return 'Declined ${DateFormatter.formatDate(rev.rejectedAt!)}';
    }
    if (status == 'SENT' && rev.sentAt != null) {
      return 'Received ${DateFormatter.formatDate(rev.sentAt!)}';
    }
    if (status == 'VIEWED') {
      return rev.sentAt != null
          ? 'Received ${DateFormatter.formatDate(rev.sentAt!)}'
          : 'Date ${DateFormatter.formatDate(rev.createdAt)}';
    }
    if (status == 'CHANGE_REQUESTED') {
      return 'Requested ${DateFormatter.formatDate(rev.createdAt)}';
    }
    return 'Date ${DateFormatter.formatDate(rev.createdAt)}';
  }
}
