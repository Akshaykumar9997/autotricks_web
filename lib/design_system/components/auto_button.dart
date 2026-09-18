import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_typography.dart';

enum AutoButtonVariant {
  primary,
  secondary,
  ghost,
  destructive,
}

/// Canonical button component conforming to DESIGN.md Section 10.
class AutoButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final AutoButtonVariant variant;
  final bool isLoading;
  final bool isExpanded;
  final Widget? icon;
  final double height;

  const AutoButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = AutoButtonVariant.primary,
    this.isLoading = false,
    this.isExpanded = true,
    this.icon,
    this.height = 48.0,
  });

  const AutoButton.primary({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isExpanded = true,
    this.icon,
    this.height = 48.0,
  }) : variant = AutoButtonVariant.primary;

  const AutoButton.secondary({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isExpanded = true,
    this.icon,
    this.height = 48.0,
  }) : variant = AutoButtonVariant.secondary;

  const AutoButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isExpanded = true,
    this.icon,
    this.height = 48.0,
  }) : variant = AutoButtonVariant.ghost;

  const AutoButton.destructive({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.isExpanded = true,
    this.icon,
    this.height = 48.0,
  }) : variant = AutoButtonVariant.destructive;

  @override
  Widget build(BuildContext context) {
    final bool isDisabled = onPressed == null || isLoading;

    Widget content = Row(
      mainAxisSize: isExpanded ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isLoading) ...[
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2.2,
              valueColor: AlwaysStoppedAnimation<Color>(_getTextColor(isDisabled)),
            ),
          ),
          const SizedBox(width: 10),
        ] else if (icon != null) ...[
          icon!,
          const SizedBox(width: 8),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.button.copyWith(
              color: _getTextColor(isDisabled),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );

    final decoration = _getDecoration(isDisabled);

    return SizedBox(
      height: height,
      width: isExpanded ? double.infinity : null,
      child: Material(
        color: Colors.transparent,
        borderRadius: AppRadius.radiusMd,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: isDisabled ? null : onPressed,
          borderRadius: AppRadius.radiusMd,
          splashColor: _getSplashColor(),
          highlightColor: _getHighlightColor(),
          child: Ink(
            decoration: decoration,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: content,
          ),
        ),
      ),
    );
  }

  BoxDecoration _getDecoration(bool isDisabled) {
    switch (variant) {
      case AutoButtonVariant.primary:
        if (isDisabled) {
          return BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.4),
            borderRadius: AppRadius.radiusMd,
          );
        }
        return BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.primary, AppColors.primaryStrong],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: AppRadius.radiusMd,
          boxShadow: const [
            BoxShadow(
              color: Color(0x33FF6B00),
              blurRadius: 10,
              offset: Offset(0, 4),
            ),
          ],
        );
      case AutoButtonVariant.secondary:
        return BoxDecoration(
          color: isDisabled
              ? AppColors.surface2.withValues(alpha: 0.5)
              : AppColors.surface2,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(
            color: isDisabled
                ? AppColors.border.withValues(alpha: 0.5)
                : AppColors.border,
            width: 1,
          ),
        );
      case AutoButtonVariant.ghost:
        return BoxDecoration(
          color: Colors.transparent,
          borderRadius: AppRadius.radiusMd,
        );
      case AutoButtonVariant.destructive:
        return BoxDecoration(
          color: isDisabled
              ? AppColors.dangerSoft.withValues(alpha: 0.5)
              : AppColors.dangerSoft,
          borderRadius: AppRadius.radiusMd,
          border: Border.all(
            color: AppColors.danger.withValues(alpha: 0.3),
            width: 1,
          ),
        );
    }
  }

  Color _getTextColor(bool isDisabled) {
    if (isDisabled) {
      return AppColors.textMuted;
    }
    switch (variant) {
      case AutoButtonVariant.primary:
        return Colors.white;
      case AutoButtonVariant.secondary:
        return AppColors.textPrimary;
      case AutoButtonVariant.ghost:
        return AppColors.textSecondary;
      case AutoButtonVariant.destructive:
        return AppColors.danger;
    }
  }

  Color _getSplashColor() {
    switch (variant) {
      case AutoButtonVariant.primary:
        return Colors.white.withValues(alpha: 0.2);
      case AutoButtonVariant.secondary:
      case AutoButtonVariant.ghost:
        return AppColors.border.withValues(alpha: 0.3);
      case AutoButtonVariant.destructive:
        return AppColors.danger.withValues(alpha: 0.2);
    }
  }

  Color _getHighlightColor() {
    switch (variant) {
      case AutoButtonVariant.primary:
        return AppColors.primaryStrong;
      case AutoButtonVariant.secondary:
        return AppColors.surface1;
      case AutoButtonVariant.ghost:
        return AppColors.surface2.withValues(alpha: 0.5);
      case AutoButtonVariant.destructive:
        return AppColors.dangerSoft;
    }
  }
}
