import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:autotricks/app/theme/app_colors.dart';
import 'package:autotricks/core/widgets/auto_button.dart';
import 'package:autotricks/core/widgets/auto_dialog.dart';
import 'package:autotricks/core/widgets/auto_toast.dart';
import 'package:autotricks/features/auth/providers/auth_provider.dart';

/// Screen shell for Settings & Profile (Screen 10 in UI Reference Board).
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final profile = authState.profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          children: [
            // Centered Profile Card
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 84,
                        height: 84,
                        decoration: BoxDecoration(
                          color: AppColors.orange.withAlpha(38),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.orange,
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            (profile?.fullName.isNotEmpty ?? false)
                                ? profile!.fullName[0].toUpperCase()
                                : 'A',
                            style: const TextStyle(
                              color: AppColors.orange,
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(
                          color: AppColors.orange,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile?.fullName ?? 'AutoTricks Admin',
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    authState.email ?? 'admin@autotricks.com',
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Text(
                      'ROLE: ${profile?.role.dbValue ?? "ADMIN"}',
                      style: const TextStyle(
                        color: AppColors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Settings Options
            _buildSettingsTile(
              icon: Icons.person_outline_rounded,
              title: 'Edit Profile',
              onTap: () => AutoToast.show(
                context,
                message: 'Profile editing opens in Day 11 scope',
              ),
            ),
            _buildSettingsTile(
              icon: Icons.tune_rounded,
              title: 'App Settings',
              onTap: () => AutoToast.show(
                context,
                message: 'Workshop configuration settings',
              ),
            ),
            _buildSettingsTile(
              icon: Icons.notifications_none_rounded,
              title: 'Notifications',
              onTap: () => context.push('/notifications'),
            ),
            _buildSettingsTile(
              icon: Icons.language_rounded,
              title: 'Language',
              trailingText: 'English',
              onTap: () => AutoToast.show(
                context,
                message: 'Multi-language support configured',
              ),
            ),
            _buildSettingsTile(
              icon: Icons.shield_outlined,
              title: 'Privacy & Security',
              onTap: () => AutoToast.show(
                context,
                message: 'Supabase RLS & Role-Based Access active',
              ),
            ),

            const SizedBox(height: 28),

            // Logout Button (Red Destructive)
            AutoButton.danger(
              text: 'Logout',
              icon: Icons.logout_rounded,
              onPressed: () async {
                final confirmed = await AutoDialog.destructive(
                  context,
                  title: 'Log out of AutoTricks?',
                  description:
                      'Are you sure you want to log out? Any unsaved changes will be lost.',
                  deleteText: 'Log Out',
                );

                if (confirmed == true && context.mounted) {
                  await ref.read(authProvider.notifier).signOut();
                  if (context.mounted) {
                    context.go('/login');
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    String? trailingText,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.textPrimary, size: 20),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (trailingText != null) ...[
                Text(
                  trailingText,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              const Icon(
                Icons.chevron_right,
                color: AppColors.textMuted,
                size: 20,
              ),
            ],
          ),
          onTap: onTap,
        ),
      ),
    );
  }
}
