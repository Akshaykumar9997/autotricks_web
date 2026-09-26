import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_assets.dart';
import '../../../design_system/components/auto_dialog.dart';
import '../../../design_system/tokens/app_colors.dart';
import '../../../design_system/tokens/app_radius.dart';
import '../../../design_system/tokens/app_spacing.dart';
import '../../../design_system/tokens/app_typography.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/client_portal_provider.dart';

/// Minimal shell continuity for the Client Profile bottom navigation tab.
///
/// Note: C17 Full Profile screen is out of scope for Day 9.
/// This screen provides read-only client identity continuity and session sign-out
/// for testing and account switching.
class ClientProfilePlaceholderScreen extends ConsumerWidget {
  const ClientProfilePlaceholderScreen({super.key});

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AutoDialog(
        title: 'Sign Out',
        message: 'Are you sure you want to sign out of your AutoTricks account?',
        confirmLabel: 'Sign Out',
        cancelLabel: 'Cancel',
        isDestructive: true,
        onConfirm: () async {
          Navigator.of(ctx).pop();
          await ref.read(authProvider.notifier).signOut();
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientProfileAsync = ref.watch(clientProfileProvider);
    final authState = ref.watch(authProvider);

    final client = clientProfileAsync.asData?.value;
    final clientName = client?.fullName ??
        authState.profile?.fullName ??
        'Valued Client';
    final clientEmail = client?.email ??
        authState.profile?.email ??
        'client@autotricks.com';
    final clientPhone = client?.phone ?? '+91 98450 12890';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface1,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleSpacing: AppSpacing.margin,
        title: Row(
          children: [
            Image.asset(
              AppAssets.logoSymbol,
              height: 28,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: AppSpacing.sm),
            Text(
              'Profile',
              style: AppTypography.headlineSm.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.margin,
          vertical: AppSpacing.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Client Identity Summary Card
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface1,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: AppColors.primary,
                    child: Text(
                      clientName.isNotEmpty ? clientName[0].toUpperCase() : 'C',
                      style: AppTypography.headlineLg.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    clientName,
                    style: AppTypography.headlineSm.copyWith(
                      color: AppColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    clientEmail,
                    style: AppTypography.bodyMd.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (clientPhone.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      clientPhone,
                      style: AppTypography.bodyMd.copyWith(
                        color: AppColors.textMuted,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: AppSpacing.md),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.full),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.verified_user_rounded,
                          size: 14,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Active Client Account',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Informational Shell Continuity Note
            Container(
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.borderSubtle),
              ),
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 20,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Portal Update Coming Soon',
                          style: AppTypography.labelSm.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Profile editing, vehicle document vault, and communication preferences will be available in an upcoming update.',
                          style: AppTypography.caption.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Sign Out Button (for testing & session switching)
            OutlinedButton.icon(
              onPressed: () => _confirmSignOut(context, ref),
              icon: const Icon(Icons.logout_rounded, size: 18, color: AppColors.danger),
              label: Text(
                'Sign Out',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.danger,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.danger),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
