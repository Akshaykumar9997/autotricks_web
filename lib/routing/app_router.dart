import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/home/screens/admin_home_screen.dart';
import '../features/service_requests/screens/create_service_request_screen.dart';
import '../features/service_requests/screens/service_request_detail_screen.dart';
import '../features/service_requests/screens/service_requests_list_screen.dart';
import 'admin_shell_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: authState.isAuthenticated ? '/admin' : '/login',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AdminShellScreen(
            location: state.uri.path,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/admin',
            builder: (context, state) => const AdminHomeScreen(),
          ),
          GoRoute(
            path: '/admin/requests',
            builder: (context, state) {
              final filter = state.uri.queryParameters['filter'];
              return ServiceRequestsListScreen(initialFilter: filter);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/admin/requests/create',
        builder: (context, state) => const CreateServiceRequestScreen(),
      ),
      GoRoute(
        path: '/admin/requests/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ServiceRequestDetailScreen(requestId: id);
        },
      ),
    ],
    redirect: (context, state) {
      final isAuth = authState.isAuthenticated;
      final isLoggingIn = state.uri.path == '/login';

      if (!isAuth && !isLoggingIn) {
        return '/login';
      }

      if (isAuth && isLoggingIn) {
        return '/admin';
      }

      return null;
    },
  );
});
