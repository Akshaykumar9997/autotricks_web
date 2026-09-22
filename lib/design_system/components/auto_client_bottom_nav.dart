import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_typography.dart';

enum ClientNavTab {
  home,
  vehicles,
  services,
  profile,
}

/// Approved Client Bottom Navigation Bar conforming to Stitch C02–C05 and DESIGN.md Section 13.
/// Structure: HOME | VEHICLES | SERVICES | PROFILE
class AutoClientBottomNav extends StatelessWidget {
  final ClientNavTab currentTab;
  final ValueChanged<ClientNavTab> onTabSelected;

  const AutoClientBottomNav({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        border: Border(
          top: BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x66000000),
            blurRadius: 16,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              // HOME
              Expanded(
                child: _buildNavItem(
                  tab: ClientNavTab.home,
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'HOME',
                ),
              ),
              // VEHICLES
              Expanded(
                child: _buildNavItem(
                  tab: ClientNavTab.vehicles,
                  icon: Icons.directions_car_outlined,
                  activeIcon: Icons.directions_car_rounded,
                  label: 'VEHICLES',
                ),
              ),
              // SERVICES
              Expanded(
                child: _buildNavItem(
                  tab: ClientNavTab.services,
                  icon: Icons.car_repair_outlined,
                  activeIcon: Icons.car_repair_rounded,
                  label: 'SERVICES',
                ),
              ),
              // PROFILE
              Expanded(
                child: _buildNavItem(
                  tab: ClientNavTab.profile,
                  icon: Icons.account_circle_outlined,
                  activeIcon: Icons.account_circle_rounded,
                  label: 'PROFILE',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required ClientNavTab tab,
    required IconData icon,
    IconData? activeIcon,
    required String label,
  }) {
    final isSelected = currentTab == tab;
    final color = isSelected ? AppColors.primary : AppColors.textMuted;

    return InkWell(
      onTap: () => onTabSelected(tab),
      splashColor: AppColors.primarySoft,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isSelected ? (activeIcon ?? icon) : icon,
            color: color,
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTypography.caption.copyWith(
              color: color,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.5,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
