import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../design_system/components/auto_client_bottom_nav.dart';
import '../../../design_system/tokens/app_colors.dart';

/// Shell screen providing the approved bottom navigation container for Client Portal.
class ClientShellScreen extends StatelessWidget {
  final Widget child;
  final String location;

  const ClientShellScreen({
    super.key,
    required this.child,
    required this.location,
  });

  ClientNavTab _calculateSelectedTab() {
    if (location == '/client') {
      return ClientNavTab.home;
    } else if (location.startsWith('/client/vehicles')) {
      return ClientNavTab.vehicles;
    } else if (location.startsWith('/client/services')) {
      return ClientNavTab.services;
    } else if (location.startsWith('/client/profile')) {
      return ClientNavTab.profile;
    }
    return ClientNavTab.home;
  }

  void _onTabSelected(BuildContext context, ClientNavTab tab) {
    switch (tab) {
      case ClientNavTab.home:
        context.go('/client');
        break;
      case ClientNavTab.vehicles:
        context.go('/client/vehicles');
        break;
      case ClientNavTab.services:
        context.go('/client/services');
        break;
      case ClientNavTab.profile:
        context.go('/client/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: child,
      bottomNavigationBar: AutoClientBottomNav(
        currentTab: _calculateSelectedTab(),
        onTabSelected: (tab) => _onTabSelected(context, tab),
      ),
    );
  }
}
