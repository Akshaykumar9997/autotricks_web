import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_typography.dart';

/// Reusable section header conforming to Stitch A02/A03/A04.
class AutoSectionHeader extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTrailingTap;

  const AutoSectionHeader({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.trailing,
    this.onTrailingTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 20,
                  color: iconColor ?? AppColors.primary,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  title,
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          if (onTrailingTap != null)
            GestureDetector(
              onTap: onTrailingTap,
              child: trailing!,
            )
          else
            trailing!,
        ],
      ],
    );
  }
}
