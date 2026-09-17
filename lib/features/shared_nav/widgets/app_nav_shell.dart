import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:autotricks/app/theme/app_colors.dart';
import 'package:autotricks/core/widgets/auto_bottom_sheet.dart';
import 'package:autotricks/core/widgets/auto_toast.dart';

/// Primary mobile navigation shell providing the bottom navigation bar
/// with Home, Requests, Quick Action (+), Quotes, and More.
class AppNavShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const AppNavShell({
    super.key,
    required this.navigationShell,
  });

  void _onTabSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  void _showQuickActionsSheet(BuildContext context) {
    AutoBottomSheet.show(
      context: context,
      title: 'Quick Workshop Action',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildQuickActionTile(
            context,
            icon: Icons.assignment_add,
            title: 'New Service Request',
            subtitle: 'Log a new phone or walk-in request',
            onTap: () {
              Navigator.of(context).pop();
              AutoToast.show(
                context,
                message: 'New request form opens in Day 5 scope',
                type: AutoToastType.info,
              );
            },
          ),
          const SizedBox(height: 8),
          _buildQuickActionTile(
            context,
            icon: Icons.receipt_long,
            title: 'Draft Quotation',
            subtitle: 'Create a new multi-item quotation',
            onTap: () {
              Navigator.of(context).pop();
              AutoToast.show(
                context,
                message: 'Quotation builder opens in Day 7 scope',
                type: AutoToastType.info,
              );
            },
          ),
          const SizedBox(height: 8),
          _buildQuickActionTile(
            context,
            icon: Icons.directions_car,
            title: 'Add Vehicle',
            subtitle: 'Register vehicle to existing client',
            onTap: () {
              Navigator.of(context).pop();
              AutoToast.show(
                context,
                message: 'Vehicle registration opens in Day 6 scope',
                type: AutoToastType.info,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.orange.withAlpha(38),
            borderRadius: BorderRadius.circular(10),
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
        trailing: const Icon(
          Icons.chevron_right,
          color: AppColors.textMuted,
          size: 20,
        ),
        onTap: onTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeIndex = navigationShell.currentIndex;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: navigationShell,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          border: Border(
            top: BorderSide(color: AppColors.border, width: 1),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Container(
            height: 64,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // 1. Home
                _buildNavItem(
                  index: 0,
                  activeIcon: Icons.home,
                  inactiveIcon: Icons.home_outlined,
                  label: 'Home',
                  isSelected: activeIndex == 0,
                ),

                // 2. Requests
                _buildNavItem(
                  index: 1,
                  activeIcon: Icons.assignment,
                  inactiveIcon: Icons.assignment_outlined,
                  label: 'Requests',
                  isSelected: activeIndex == 1,
                ),

                // 3. Center Quick Action (+) Button
                GestureDetector(
                  onTap: () => _showQuickActionsSheet(context),
                  child: Container(
                    width: 46,
                    height: 46,
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    decoration: BoxDecoration(
                      gradient: AppColors.orangeGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.orangeGlow,
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),

                // 4. Quotes
                _buildNavItem(
                  index: 2,
                  activeIcon: Icons.receipt_long,
                  inactiveIcon: Icons.receipt_long_outlined,
                  label: 'Quotes',
                  isSelected: activeIndex == 2,
                ),

                // 5. More
                _buildNavItem(
                  index: 3,
                  activeIcon: Icons.grid_view_rounded,
                  inactiveIcon: Icons.grid_view_outlined,
                  label: 'More',
                  isSelected: activeIndex == 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData activeIcon,
    required IconData inactiveIcon,
    required String label,
    required bool isSelected,
  }) {
    final color = isSelected ? AppColors.orange : AppColors.textSecondary;

    return InkWell(
      onTap: () => _onTabSelected(index),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? activeIcon : inactiveIcon,
              color: color,
              size: 22,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
