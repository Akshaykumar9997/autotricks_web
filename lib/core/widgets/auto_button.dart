import 'package:flutter/material.dart';
import 'package:autotricks/app/theme/app_colors.dart';

enum AutoButtonVariant { primary, secondary, danger, ghost }

/// Standard high-contrast, large-touch-target AutoTricks button.
class AutoButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final AutoButtonVariant variant;
  final IconData? icon;
  final bool isLoading;
  final double? width;
  final double height;

  const AutoButton({
    super.key,
    required this.text,
    this.onPressed,
    this.variant = AutoButtonVariant.primary,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 50.0,
  });

  const AutoButton.primary({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 50.0,
  }) : variant = AutoButtonVariant.primary;

  const AutoButton.secondary({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 50.0,
  }) : variant = AutoButtonVariant.secondary;

  const AutoButton.danger({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 50.0,
  }) : variant = AutoButtonVariant.danger;

  const AutoButton.ghost({
    super.key,
    required this.text,
    this.onPressed,
    this.icon,
    this.isLoading = false,
    this.width,
    this.height = 50.0,
  }) : variant = AutoButtonVariant.ghost;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || isLoading;

    BoxDecoration decoration;
    Color textColor;

    switch (variant) {
      case AutoButtonVariant.primary:
        decoration = BoxDecoration(
          gradient: disabled ? null : AppColors.orangeGradient,
          color: disabled ? AppColors.surfaceVariant : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: disabled
              ? null
              : [
                  BoxShadow(
                    color: AppColors.orangeGlow,
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        );
        textColor = disabled ? AppColors.textDisabled : Colors.white;
        break;

      case AutoButtonVariant.secondary:
        decoration = BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1),
        );
        textColor = disabled ? AppColors.textDisabled : AppColors.textPrimary;
        break;

      case AutoButtonVariant.danger:
        decoration = BoxDecoration(
          color: const Color(0x26E63946),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.red, width: 1),
        );
        textColor = disabled ? AppColors.textDisabled : AppColors.red;
        break;

      case AutoButtonVariant.ghost:
        decoration = BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        );
        textColor = disabled ? AppColors.textDisabled : AppColors.orange;
        break;
    }

    return Semantics(
      button: true,
      enabled: !disabled,
      label: text,
      child: Container(
        width: width,
        height: height,
        decoration: decoration,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: disabled ? null : onPressed,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, size: 18, color: textColor),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          text,
                          style: TextStyle(
                            color: textColor,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
