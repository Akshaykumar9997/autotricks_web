import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_typography.dart';

/// Canonical status badge / pill component conforming to DESIGN.md Section 10 & 16.
class AutoBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color? textColor;
  final Color? backgroundColor;
  final bool showDot;
  final Widget? leadingIcon;

  const AutoBadge({
    super.key,
    required this.label,
    required this.color,
    this.textColor,
    this.backgroundColor,
    this.showDot = true,
    this.leadingIcon,
  });

  factory AutoBadge.newRequest() => const AutoBadge(
        label: 'NEW',
        color: AppColors.info,
        showDot: true,
      );

  factory AutoBadge.underReview() => const AutoBadge(
        label: 'UNDER REVIEW',
        color: AppColors.warning,
        showDot: true,
      );

  factory AutoBadge.quotationCreated() => const AutoBadge(
        label: 'QUOTATION CREATED',
        color: AppColors.info,
        showDot: true,
      );

  factory AutoBadge.quotationSent() => const AutoBadge(
        label: 'QUOTATION SENT',
        color: AppColors.info,
        showDot: false,
        leadingIcon: Icon(Icons.outgoing_mail, size: 13, color: AppColors.info),
      );

  factory AutoBadge.approved() => const AutoBadge(
        label: 'APPROVED',
        color: AppColors.success,
        showDot: true,
      );

  factory AutoBadge.convertedToJob() => const AutoBadge(
        label: 'CONVERTED TO JOB',
        color: AppColors.success,
        showDot: false,
        leadingIcon: Icon(Icons.task_alt, size: 13, color: AppColors.success),
      );

  factory AutoBadge.cancelled() => const AutoBadge(
        label: 'CANCELLED',
        color: AppColors.danger,
        showDot: true,
      );

  factory AutoBadge.fromStatus(String status) {
    switch (status.toUpperCase()) {
      case 'NEW':
        return AutoBadge.newRequest();
      case 'UNDER_REVIEW':
        return AutoBadge.underReview();
      case 'QUOTATION_CREATED':
        return AutoBadge.quotationCreated();
      case 'QUOTATION_SENT':
        return AutoBadge.quotationSent();
      case 'APPROVED':
        return AutoBadge.approved();
      case 'CONVERTED_TO_JOB':
        return AutoBadge.convertedToJob();
      case 'CANCELLED':
        return AutoBadge.cancelled();
      default:
        return AutoBadge(
          label: status.replaceAll('_', ' '),
          color: AppColors.textSecondary,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveTextColor = textColor ?? color;
    final effectiveBgColor = backgroundColor ?? color.withValues(alpha: 0.15);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: effectiveBgColor,
        borderRadius: AppRadius.radiusPill,
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leadingIcon != null) ...[
            leadingIcon!,
            const SizedBox(width: 4),
          ] else if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: effectiveTextColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
