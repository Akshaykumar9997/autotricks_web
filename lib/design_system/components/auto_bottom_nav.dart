import 'package:flutter/material.dart';
import '../tokens/app_colors.dart';
import '../tokens/app_typography.dart';
import 'auto_bottom_sheet.dart';
import 'auto_list_tile.dart';

enum AdminNavTab {
  home,
  requests,
  quotes,
  more,
}

/// Canonical bottom navigation bar conforming to DESIGN.md Section 12 & 18 and Stitch.
class AutoBottomNav extends StatelessWidget {
  final AdminNavTab currentTab;
  final ValueChanged<AdminNavTab> onTabSelected;
  final VoidCallback? onCreateRequest;
  final VoidCallback? onCreateClient;
  final VoidCallback? onCreateVehicle;

  const AutoBottomNav({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
    this.onCreateRequest,
    this.onCreateClient,
    this.onCreateVehicle,
  });

  void _showCreationSheet(BuildContext context) {
    AutoBottomSheet.show(
      context: context,
      title: 'Quick Create',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AutoListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.add_circle_outline, color: AppColors.primary, size: 22),
            ),
            title: 'Create Service Request',
            subtitle: 'Phone intake',
            onTap: () {
              Navigator.of(context).pop();
              onCreateRequest?.call();
            },
          ),
          AutoListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.person_add_outlined, color: AppColors.primary, size: 22),
            ),
            title: 'Create Client',
            subtitle: 'Register new customer profile',
            onTap: () {
              Navigator.of(context).pop();
              onCreateClient?.call();
            },
          ),
          AutoListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.directions_car_outlined, color: AppColors.primary, size: 22),
            ),
            title: 'Create Vehicle',
            subtitle: 'Add vehicle to existing client',
            onTap: () {
              Navigator.of(context).pop();
              onCreateVehicle?.call();
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface1,
        border: Border(
          top: BorderSide(color: AppColors.border, width: 1),
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
                  context,
                  tab: AdminNavTab.home,
                  icon: Icons.speed_rounded,
                  label: 'HOME',
                ),
              ),
              // REQUESTS
              Expanded(
                child: _buildNavItem(
                  context,
                  tab: AdminNavTab.requests,
                  icon: Icons.assignment_outlined,
                  activeIcon: Icons.assignment_rounded,
                  label: 'REQUESTS',
                ),
              ),
              // CENTER +
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: () => _showCreationSheet(context),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x4DFF6B00),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
              // QUOTES
              Expanded(
                child: _buildNavItem(
                  context,
                  tab: AdminNavTab.quotes,
                  icon: Icons.request_quote_outlined,
                  label: 'QUOTES',
                ),
              ),
              // MORE
              Expanded(
                child: _buildNavItem(
                  context,
                  tab: AdminNavTab.more,
                  icon: Icons.tune_rounded,
                  label: 'MORE',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required AdminNavTab tab,
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
            size: 22,
          ),
          const SizedBox(height: 3),
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
