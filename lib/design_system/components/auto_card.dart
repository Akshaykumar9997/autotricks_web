import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_radius.dart';
import '../tokens/app_spacing.dart';

/// Canonical card component conforming to DESIGN.md Section 10 and Stitch cards.
class AutoCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final Color backgroundColor;
  final Color borderColor;
  final Color? statusStripeColor;
  final double borderRadius;

  const AutoCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = AppSpacing.cardPadding,
    this.margin,
    this.backgroundColor = AppColors.surface1,
    this.borderColor = AppColors.border,
    this.statusStripeColor,
    this.borderRadius = AppRadius.lg,
  });

  const AutoCard.elevated({
    super.key,
    required this.child,
    this.onTap,
    this.padding = AppSpacing.cardPadding,
    this.margin,
    this.backgroundColor = AppColors.surface2,
    this.borderColor = AppColors.border,
    this.statusStripeColor,
    this.borderRadius = AppRadius.lg,
  });

  @override
  Widget build(BuildContext context) {
    Widget content = Padding(
      padding: padding,
      child: child,
    );

    if (statusStripeColor != null) {
      content = Stack(
        children: [
          Positioned(
            left: 0,
            top: 0,
            bottom: 0,
            width: 4,
            child: Container(
              color: statusStripeColor,
            ),
          ),
          content,
        ],
      );
    }

    final radius = BorderRadius.circular(borderRadius);

    Widget cardBody = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: content,
    );

    if (onTap != null) {
      return Container(
        margin: margin,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: radius,
          border: Border.all(color: borderColor, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            splashColor: AppColors.primary.withValues(alpha: 0.1),
            highlightColor: AppColors.surface2,
            child: Padding(
              padding: EdgeInsets.zero,
              child: Stack(
                children: [
                  if (statusStripeColor != null)
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: 4,
                      child: Container(color: statusStripeColor),
                    ),
                  Padding(padding: padding, child: child),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return cardBody;
  }
}
