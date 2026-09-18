import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_typography.dart';

/// Canonical AutoAppBar conforming to DESIGN.md and Stitch header specs.
class AutoAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final bool showBack;
  final bool showLogo;
  final VoidCallback? onBack;
  final List<Widget>? actions;
  final bool hasUnreadNotifications;
  final VoidCallback? onNotificationTap;
  final VoidCallback? onProfileTap;

  const AutoAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.showBack = false,
    this.showLogo = true,
    this.onBack,
    this.actions,
    this.hasUnreadNotifications = false,
    this.onNotificationTap,
    this.onProfileTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(64.0);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: preferredSize.height + MediaQuery.paddingOf(context).top,
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        border: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (showBack)
            IconButton(
              icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              onPressed: onBack ?? () => Navigator.of(context).maybePop(),
            )
          else
            ?leading,
          if (showLogo) ...[
            Image.asset(
              AppAssets.logoMaster,
              height: 30,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.directions_car,
                color: AppColors.primary,
                size: 26,
              ),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (subtitle != null)
                  Text(
                    subtitle!.toUpperCase(),
                    style: AppTypography.caption.copyWith(
                      letterSpacing: 0.8,
                      color: AppColors.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  title,
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (actions != null)
            ...actions!
          else ...[
            if (onNotificationTap != null)
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_none_rounded,
                        color: AppColors.textSecondary),
                    onPressed: onNotificationTap,
                  ),
                  if (hasUnreadNotifications)
                    Positioned(
                      top: 10,
                      right: 10,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface1, width: 1.5),
                        ),
                      ),
                    ),
                ],
              ),
            if (onProfileTap != null)
              GestureDetector(
                onTap: onProfileTap,
                child: Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(left: 4),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person,
                    size: 18,
                    color: Color(0xFF0B0D0F),
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
