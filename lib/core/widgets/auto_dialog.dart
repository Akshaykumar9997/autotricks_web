import 'package:flutter/material.dart';
import 'package:autotricks/app/theme/app_colors.dart';
import 'package:autotricks/core/widgets/auto_button.dart';

/// Standard AutoTricks dialogs.
class AutoDialog extends StatelessWidget {
  final String title;
  final String description;
  final String primaryButtonText;
  final VoidCallback onPrimaryPressed;
  final String secondaryButtonText;
  final VoidCallback? onSecondaryPressed;
  final bool isDestructive;
  final IconData? icon;

  const AutoDialog({
    super.key,
    required this.title,
    required this.description,
    required this.primaryButtonText,
    required this.onPrimaryPressed,
    this.secondaryButtonText = 'Cancel',
    this.onSecondaryPressed,
    this.isDestructive = false,
    this.icon,
  });

  /// Shows a standard confirmation dialog
  static Future<bool?> confirm(
    BuildContext context, {
    required String title,
    required String description,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withAlpha(204),
      builder: (ctx) => AutoDialog(
        title: title,
        description: description,
        primaryButtonText: confirmText,
        secondaryButtonText: cancelText,
        icon: icon ?? Icons.help_outline_rounded,
        onPrimaryPressed: () => Navigator.of(ctx).pop(true),
        onSecondaryPressed: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  /// Shows a permission request dialog
  static Future<bool?> permission(
    BuildContext context, {
    required String title,
    required String description,
    String allowText = 'Allow',
    String notNowText = 'Not now',
    IconData? icon,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withAlpha(204),
      builder: (ctx) => AutoDialog(
        title: title,
        description: description,
        primaryButtonText: allowText,
        secondaryButtonText: notNowText,
        icon: icon ?? Icons.security_rounded,
        onPrimaryPressed: () => Navigator.of(ctx).pop(true),
        onSecondaryPressed: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  /// Shows a destructive action confirmation dialog (red accent)
  static Future<bool?> destructive(
    BuildContext context, {
    required String title,
    required String description,
    String deleteText = 'Delete',
    String cancelText = 'Cancel',
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withAlpha(204),
      builder: (ctx) => AutoDialog(
        title: title,
        description: description,
        primaryButtonText: deleteText,
        secondaryButtonText: cancelText,
        isDestructive: true,
        icon: Icons.warning_amber_rounded,
        onPrimaryPressed: () => Navigator.of(ctx).pop(true),
        onSecondaryPressed: () => Navigator.of(ctx).pop(false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDestructive
                ? AppColors.red.withAlpha(100)
                : AppColors.border,
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(150),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (icon != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDestructive
                        ? const Color(0x26E63946)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDestructive
                          ? AppColors.red.withAlpha(100)
                          : AppColors.border,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: isDestructive ? AppColors.red : AppColors.orange,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
            Text(
              title,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: AutoButton.secondary(
                    text: secondaryButtonText,
                    height: 44,
                    onPressed: () {
                      if (onSecondaryPressed != null) {
                        onSecondaryPressed!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: isDestructive
                      ? AutoButton.danger(
                          text: primaryButtonText,
                          height: 44,
                          onPressed: onPrimaryPressed,
                        )
                      : AutoButton.primary(
                          text: primaryButtonText,
                          height: 44,
                          onPressed: onPrimaryPressed,
                        ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
