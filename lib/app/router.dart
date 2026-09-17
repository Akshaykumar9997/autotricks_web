import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:autotricks/features/auth/providers/auth_provider.dart';
import 'package:autotricks/features/auth/screens/login_screen.dart';
import 'package:autotricks/features/client_portal/screens/client_portal_shell.dart';
import 'package:autotricks/features/clients/screens/clients_screen.dart';
import 'package:autotricks/features/dashboard/screens/dashboard_screen.dart';
import 'package:autotricks/features/more/screens/more_screen.dart';
import 'package:autotricks/features/notifications/screens/notifications_screen.dart';
import 'package:autotricks/features/quotations/screens/quotations_screen.dart';
import 'package:autotricks/features/service_jobs/screens/service_jobs_screen.dart';
import 'package:autotricks/features/service_requests/screens/service_requests_screen.dart';
import 'package:autotricks/features/settings/screens/settings_screen.dart';
import 'package:autotricks/features/shared_nav/widgets/app_nav_shell.dart';
import 'package:autotricks/features/splash/screens/splash_screen.dart';
import 'package:autotricks/features/vehicles/screens/vehicles_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      final location = state.uri.path;

      // Allow splash to run uninterrupted
      if (location == '/splash') return null;

      final isGoingToLogin = location == '/login';

      // 1. Unauthenticated users
      if (!authState.isAuthenticated) {
        return isGoingToLogin ? null : '/login';
      }

      // 2. Authenticated CLIENT users
      if (authState.isClient) {
        // Clients are not allowed into the admin dashboard or admin operational routes
        final adminRoutes = [
          '/dashboard',
          '/requests',
          '/quotations',
          '/more',
          '/clients',
          '/vehicles',
          '/jobs',
          '/settings',
        ];

        if (adminRoutes.contains(location) || isGoingToLogin) {
          return '/client-portal';
        }
        return null;
      }

      // 3. Authenticated ADMIN users
      if (authState.isAdmin) {
        // Admins going to login or client-portal get redirected to dashboard
        if (isGoingToLogin || location == '/client-portal') {
          return '/dashboard';
        }
        return null;
      }

      return null;
    },
    routes: [
      // 1. Splash Screen
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) => const SplashScreen(),
      ),

      // 2. Login Screen
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),

      // 3. Client Portal Shell (Future-proof CLIENT isolation)
      GoRoute(
        path: '/client-portal',
        name: 'client-portal',
        builder: (context, state) => const ClientPortalShell(),
      ),

      // 4. Admin Navigation Shell (Home, Requests, Quotes, More)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppNavShell(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Dashboard (Home)
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                name: 'dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),

          // Branch 1: Service Requests
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/requests',
                name: 'requests',
                builder: (context, state) => const ServiceRequestsScreen(),
              ),
            ],
          ),

          // Branch 2: Quotations
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/quotations',
                name: 'quotations',
                builder: (context, state) => const QuotationsScreen(),
              ),
            ],
          ),

          // Branch 3: More
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/more',
                name: 'more',
                builder: (context, state) => const MoreScreen(),
              ),
            ],
          ),
        ],
      ),

      // 5. Admin Sub-routes
      GoRoute(
        path: '/clients',
        name: 'clients',
        builder: (context, state) => const ClientsScreen(),
      ),
      GoRoute(
        path: '/vehicles',
        name: 'vehicles',
        builder: (context, state) => const VehiclesScreen(),
      ),
      GoRoute(
        path: '/jobs',
        name: 'jobs',
        builder: (context, state) => const ServiceJobsScreen(),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (context, state) => const SettingsScreen(),
      ),
      GoRoute(
        path: '/notifications',
        name: 'notifications',
        builder: (context, state) => const NotificationsScreen(),
      ),
    ],
  );
});
