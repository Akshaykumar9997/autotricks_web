import 'package:flutter/material.dart';
import 'package:autotricks/app/theme/app_colors.dart';

/// Reusable status badge component for AutoTricks lifecycle states.
class AutoBadge extends StatelessWidget {
  final String label;
  final Color color;
  final Color backgroundColor;
  final IconData? icon;

  const AutoBadge({
    super.key,
    required this.label,
    required this.color,
    required this.backgroundColor,
    this.icon,
  });

  factory AutoBadge.open({String label = 'Open'}) => AutoBadge(
        label: label,
        color: AppColors.statusOpen,
        backgroundColor: AppColors.statusOpenBg,
      );

  factory AutoBadge.inService({String label = 'In Service'}) => AutoBadge(
        label: label,
        color: AppColors.statusInService,
        backgroundColor: AppColors.statusInServiceBg,
      );

  factory AutoBadge.pending({String label = 'Pending'}) => AutoBadge(
        label: label,
        color: AppColors.statusPending,
        backgroundColor: AppColors.statusPendingBg,
      );

  factory AutoBadge.completed({String label = 'Completed'}) => AutoBadge(
        label: label,
        color: AppColors.statusCompleted,
        backgroundColor: AppColors.statusCompletedBg,
      );

  factory AutoBadge.ready({String label = 'Ready'}) => AutoBadge(
        label: label,
        color: AppColors.statusCompleted,
        backgroundColor: AppColors.statusCompletedBg,
      );

  factory AutoBadge.draft({String label = 'Draft'}) => AutoBadge(
        label: label,
        color: AppColors.statusDraft,
        backgroundColor: AppColors.statusDraftBg,
      );

  factory AutoBadge.danger({required String label}) => AutoBadge(
        label: label,
        color: AppColors.red,
        backgroundColor: const Color(0x26E63946),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(80), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
