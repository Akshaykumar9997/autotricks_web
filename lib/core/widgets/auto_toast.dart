import 'package:flutter/material.dart';
import 'package:autotricks/app/theme/app_colors.dart';

enum AutoToastType { info, success, warning, error }

/// Lightweight automotive toast feedback component.
class AutoToast {
  AutoToast._();

  static void show(
    BuildContext context, {
    required String message,
    AutoToastType type = AutoToastType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    Color accentColor;
    IconData icon;

    switch (type) {
      case AutoToastType.success:
        accentColor = AppColors.statusCompleted;
        icon = Icons.check_circle_rounded;
        break;
      case AutoToastType.warning:
        accentColor = AppColors.statusPending;
        icon = Icons.warning_amber_rounded;
        break;
      case AutoToastType.error:
        accentColor = AppColors.red;
        icon = Icons.error_outline_rounded;
        break;
      case AutoToastType.info:
        accentColor = AppColors.orange;
        icon = Icons.info_outline_rounded;
        break;
    }

    messenger.showSnackBar(
      SnackBar(
        duration: duration,
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(160),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: accentColor.withAlpha(38),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
