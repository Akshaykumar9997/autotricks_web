import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../design_system/components/auto_bottom_nav.dart';
import '../design_system/components/auto_bottom_sheet.dart';
import '../design_system/components/auto_list_tile.dart';
import '../design_system/components/auto_toast.dart';
import '../design_system/tokens/app_colors.dart';

/// Shell hosting the canonical AutoBottomNav for Admin Foundation.
class AdminShellScreen extends StatelessWidget {
  final Widget child;
  final String location;

  const AdminShellScreen({
    super.key,
    required this.child,
    required this.location,
  });

  AdminNavTab get _currentTab {
    if (location.startsWith('/admin/requests')) {
      return AdminNavTab.requests;
    }
    if (location.startsWith('/admin/quotes')) {
      return AdminNavTab.quotes;
    }
    if (location.startsWith('/admin/more') ||
        location.startsWith('/admin/clients') ||
        location.startsWith('/admin/vehicles') ||
        location.startsWith('/admin/products')) {
      return AdminNavTab.more;
    }
    return AdminNavTab.home;
  }

  void _showMoreSheet(BuildContext context) {
    AutoBottomSheet.show(
      context: context,
      title: 'CRM & Operations',
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AutoListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surface2,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.people_outline, color: AppColors.primary, size: 22),
            ),
            title: 'Clients',
            subtitle: 'View & manage customer profiles',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
            onTap: () {
              Navigator.of(context).pop();
              context.push('/admin/clients');
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
            title: 'Vehicles',
            subtitle: 'View registered fleet & specifications',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
            onTap: () {
              Navigator.of(context).pop();
              context.push('/admin/vehicles');
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
              child: const Icon(Icons.inventory_2_outlined, color: AppColors.primary, size: 22),
            ),
            title: 'Products Catalogue',
            subtitle: 'Parts, consumables & quote pricing',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
            onTap: () {
              Navigator.of(context).pop();
              context.push('/admin/products');
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
              child: const Icon(Icons.settings_outlined, color: AppColors.textMuted, size: 22),
            ),
            title: 'Settings',
            subtitle: 'System preferences (Batch 5)',
            trailing: const Icon(Icons.chevron_right, color: AppColors.textMuted),
            onTap: () {
              Navigator.of(context).pop();
              AutoToast.showInfo(context, 'Settings scheduled for Batch 5 (A22–A26).');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: AutoBottomNav(
        currentTab: _currentTab,
        onTabSelected: (tab) {
          switch (tab) {
            case AdminNavTab.home:
              context.go('/admin');
              break;
            case AdminNavTab.requests:
              context.go('/admin/requests');
              break;
            case AdminNavTab.quotes:
              AutoToast.showInfo(
                context,
                'Quotations module scheduled for Batch 3 (A12–A16).',
              );
              break;
            case AdminNavTab.more:
              _showMoreSheet(context);
              break;
          }
        },
        onCreateRequest: () {
          context.push('/admin/requests/create');
        },
        onCreateClient: () {
          context.push('/admin/clients/create');
        },
        onCreateVehicle: () {
          context.push('/admin/vehicles/create');
        },
      ),
    );
  }
}
