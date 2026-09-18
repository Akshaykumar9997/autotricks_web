import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_typography.dart';
import 'auto_button.dart';

/// Reusable generic empty state conforming to DESIGN.md Section 30.
class AutoEmptyState extends StatelessWidget {
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData? icon;
  final bool useIllustration;

  const AutoEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.icon,
    this.useIllustration = true,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (useIllustration)
              Image.asset(
                AppAssets.genericEmptyState,
                width: 140,
                height: 140,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => _buildIconFallback(),
              )
            else
              _buildIconFallback(),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTypography.headlineSmall.copyWith(
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              AutoButton.secondary(
                label: actionLabel!,
                isExpanded: false,
                onPressed: onAction,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildIconFallback() {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        color: AppColors.surface2,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon ?? Icons.inbox_outlined,
        color: AppColors.textMuted,
        size: 32,
      ),
    );
  }
}
