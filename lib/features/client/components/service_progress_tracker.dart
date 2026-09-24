import 'package:flutter/material.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';

/// Visual Service Progress Tracker conforming to Day 12 Section 8 specifications:
/// ✓ Scheduled
/// ✓ Vehicle Received
/// ✓ Inspection
/// ● Work In Progress
/// ○ Quality Check
/// ○ Ready for Delivery
/// ○ Completed
class ServiceProgressTracker extends StatelessWidget {
  final String currentStatus;
  final bool isCompact;

  const ServiceProgressTracker({
    super.key,
    required this.currentStatus,
    this.isCompact = false,
  });

  static const List<String> steps = [
    'SCHEDULED',
    'VEHICLE_RECEIVED',
    'INSPECTION',
    'WORK_IN_PROGRESS',
    'QUALITY_CHECK',
    'READY_FOR_DELIVERY',
    'COMPLETED',
  ];

  static const Map<String, String> stepLabels = {
    'SCHEDULED': 'Scheduled',
    'VEHICLE_RECEIVED': 'Vehicle Received',
    'INSPECTION': 'Inspection',
    'WORK_IN_PROGRESS': 'Work In Progress',
    'QUALITY_CHECK': 'Quality Check',
    'READY_FOR_DELIVERY': 'Ready for Delivery',
    'COMPLETED': 'Completed',
    'CANCELLED': 'Cancelled',
  };

  static Color getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'SCHEDULED':
        return AppColors.info;
      case 'VEHICLE_RECEIVED':
        return AppColors.primary;
      case 'INSPECTION':
        return const Color(0xFF6366F1);
      case 'WORK_IN_PROGRESS':
        return const Color(0xFF8B5CF6);
      case 'QUALITY_CHECK':
        return AppColors.warning;
      case 'READY_FOR_DELIVERY':
        return const Color(0xFF10B981);
      case 'COMPLETED':
        return AppColors.success;
      case 'CANCELLED':
        return AppColors.danger;
      default:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final normStatus = currentStatus.toUpperCase();

    if (normStatus == 'CANCELLED') {
      return Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.1),
          borderRadius: AppRadius.radiusMd,
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cancel_rounded, color: AppColors.danger, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Service Job Cancelled',
              style: AppTypography.bodyMdEmphasis.copyWith(color: AppColors.danger),
            ),
          ],
        ),
      );
    }

    final currentIndex = steps.indexOf(normStatus);

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: steps.length,
      itemBuilder: (context, index) {
        final step = steps[index];
        final label = stepLabels[step] ?? step;
        final isPast = currentIndex > index;
        final isCurrent = currentIndex == index;
        final isLast = index == steps.length - 1;

        Widget iconWidget;
        Color labelColor;
        FontWeight labelWeight;

        if (isPast) {
          labelColor = AppColors.textPrimary;
          labelWeight = FontWeight.w600;
          iconWidget = const CircleAvatar(
            radius: 10,
            backgroundColor: AppColors.success,
            child: Icon(Icons.check, size: 12, color: Colors.white),
          );
        } else if (isCurrent) {
          labelColor = getStatusColor(step);
          labelWeight = FontWeight.bold;
          iconWidget = Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: labelColor,
              boxShadow: [
                BoxShadow(
                  color: labelColor.withValues(alpha: 0.4),
                  blurRadius: 6,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Center(
              child: CircleAvatar(
                radius: 4,
                backgroundColor: Colors.white,
              ),
            ),
          );
        } else {
          labelColor = AppColors.textMuted;
          labelWeight = FontWeight.w400;
          iconWidget = Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border, width: 1.5),
              color: AppColors.surface2,
            ),
          );
        }

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  iconWidget,
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        color: isPast ? AppColors.success : AppColors.border,
                        margin: const EdgeInsets.symmetric(vertical: 3),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isCompact ? 10 : 14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          label,
                          style: AppTypography.bodyMd.copyWith(
                            color: labelColor,
                            fontWeight: labelWeight,
                            fontSize: isCurrent ? 14 : 13,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isCurrent) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: labelColor.withValues(alpha: 0.15),
                            borderRadius: AppRadius.radiusPill,
                          ),
                          child: Text(
                            'Active',
                            style: AppTypography.caption.copyWith(
                              color: labelColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
