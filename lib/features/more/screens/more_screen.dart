import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:autotricks/app/theme/app_colors.dart';
import 'package:autotricks/core/widgets/auto_dialog.dart';
import 'package:autotricks/core/widgets/auto_toast.dart';
import 'package:autotricks/features/auth/providers/auth_provider.dart';

/// The More screen containing secondary modules and account management.
class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final profile = authState.profile;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('More'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            // Account Profile Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.orange.withAlpha(38),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.orange.withAlpha(120)),
                    ),
                    child: Center(
                      child: Text(
                        (profile?.fullName.isNotEmpty ?? false)
                            ? profile!.fullName[0].toUpperCase()
                            : 'A',
                        style: const TextStyle(
                          color: AppColors.orange,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.fullName ?? 'Admin User',
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          authState.email ?? 'admin@autotricks.com',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.orange.withAlpha(26),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      profile?.role.dbValue ?? 'ADMIN',
                      style: const TextStyle(
                        color: AppColors.orange,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Workshop Modules
            const Text(
              'WORKSHOP MANAGEMENT',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            _buildMenuItem(
              context,
              icon: Icons.people_alt_outlined,
              title: 'Clients',
              subtitle: 'Manage customer accounts & history',
              onTap: () => context.push('/clients'),
            ),
            _buildMenuItem(
              context,
              icon: Icons.directions_car_outlined,
              title: 'Vehicles',
              subtitle: 'Manage client garage vehicles',
              onTap: () => context.push('/vehicles'),
            ),
            _buildMenuItem(
              context,
              icon: Icons.build_circle_outlined,
              title: 'Service Jobs',
              subtitle: 'Active workshop floor jobs & stages',
              onTap: () => context.push('/jobs'),
            ),
            _buildMenuItem(
              context,
              icon: Icons.room_service_outlined,
              title: 'Services & Pricing',
              subtitle: 'Pre-configured service items catalogue',
              onTap: () => AutoToast.show(
                context,
                message: 'Services & Pricing module arrives in Day 6',
              ),
            ),
            _buildMenuItem(
              context,
              icon: Icons.inventory_2_outlined,
              title: 'Products Catalogue',
              subtitle: 'Protected parts & consumables inventory',
              onTap: () => AutoToast.show(
                context,
                message: 'Products catalogue arrives in Day 6',
              ),
            ),

            const SizedBox(height: 20),
            const Text(
              'APPLICATION & PREFERENCES',
              style: TextStyle(
                color: AppColors.textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            _buildMenuItem(
              context,
              icon: Icons.notifications_outlined,
              title: 'Notifications',
              subtitle: 'View real-time workshop alerts',
              badgeText: '2 New',
              onTap: () => context.push('/notifications'),
            ),
            _buildMenuItem(
              context,
              icon: Icons.settings_outlined,
              title: 'Settings',
              subtitle: 'App preferences & workshop details',
              onTap: () => context.push('/settings'),
            ),
            _buildMenuItem(
              context,
              icon: Icons.help_outline_rounded,
              title: 'Help & Support',
              subtitle: 'Documentation, guides & staff support',
              onTap: () => AutoToast.show(
                context,
                message: 'AutoTricks staff helpdesk: support@autotricks.com',
              ),
            ),

            const SizedBox(height: 20),

            // Logout Action
            Container(
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: const Color(0x1AE63946),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.red.withAlpha(80)),
              ),
              child: Material(
                color: Colors.transparent,
                child: ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.red),
                  title: const Text(
                    'Log Out',
                    style: TextStyle(
                      color: AppColors.red,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: AppColors.red,
                    size: 20,
                  ),
                  onTap: () async {
                    final confirmed = await AutoDialog.destructive(
                      context,
                      title: 'Log out of AutoTricks?',
                      description:
                          'You will need to sign back in with your administrator credentials to access workshop features.',
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
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    String? badgeText,
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
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Icon(icon, color: AppColors.orange, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeText != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.red,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
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
