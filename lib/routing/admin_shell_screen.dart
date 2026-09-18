import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../design_system/components/auto_bottom_nav.dart';
import '../design_system/components/auto_toast.dart';

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
    if (location.startsWith('/admin/more')) {
      return AdminNavTab.more;
    }
    return AdminNavTab.home;
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
              AutoToast.showInfo(
                context,
                'More & settings scheduled for Batch 5 (A22–A26).',
              );
              break;
          }
        },
        onCreateRequest: () {
          context.push('/admin/requests/create');
        },
        onCreateClient: () {
          AutoToast.showInfo(
            context,
            'Client creation scheduled for Batch 2 CRM (A06–A11).',
          );
        },
        onCreateVehicle: () {
          AutoToast.showInfo(
            context,
            'Vehicle registration scheduled for Batch 2 CRM (A06–A11).',
          );
        },
      ),
    );
  }
}
