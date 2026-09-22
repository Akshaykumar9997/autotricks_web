import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/catalogue/screens/create_edit_product_screen.dart';
import '../features/catalogue/screens/products_list_screen.dart';
import '../features/clients/screens/client_detail_screen.dart';
import '../features/clients/screens/client_list_screen.dart';
import '../features/clients/screens/create_edit_client_screen.dart';
import '../features/home/screens/admin_home_screen.dart';
import '../features/quotes/screens/create_quote_screen.dart';
import '../features/quotes/screens/edit_quote_revision_screen.dart';
import '../features/quotes/screens/quote_change_requests_screen.dart';
import '../features/quotes/screens/quote_detail_screen.dart';
import '../features/quotes/screens/quote_list_screen.dart';
import '../features/service_requests/screens/create_service_request_screen.dart';
import '../features/service_requests/screens/service_request_detail_screen.dart';
import '../features/service_requests/screens/service_requests_list_screen.dart';
import '../features/vehicles/screens/create_edit_vehicle_screen.dart';
import '../features/vehicles/screens/vehicle_detail_screen.dart';
import '../features/vehicles/screens/vehicle_list_screen.dart';
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
          GoRoute(
            path: '/admin/clients',
            builder: (context, state) => const ClientListScreen(),
          ),
          GoRoute(
            path: '/admin/vehicles',
            builder: (context, state) => const VehicleListScreen(),
          ),
          GoRoute(
            path: '/admin/products',
            builder: (context, state) => const ProductsListScreen(),
          ),
          GoRoute(
            path: '/admin/quotes',
            builder: (context, state) {
              final filter = state.uri.queryParameters['filter'];
              return QuoteListScreen(initialFilter: filter);
            },
          ),
        ],
      ),
      // Service Requests
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
      // Clients CRM (A06–A08)
      GoRoute(
        path: '/admin/clients/create',
        builder: (context, state) => const CreateEditClientScreen(),
      ),
      GoRoute(
        path: '/admin/clients/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ClientDetailScreen(clientId: id);
        },
      ),
      GoRoute(
        path: '/admin/clients/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CreateEditClientScreen(clientId: id);
        },
      ),
      // Vehicles CRM (A09–A11)
      GoRoute(
        path: '/admin/vehicles/create',
        builder: (context, state) {
          final clientId = state.uri.queryParameters['clientId'];
          return CreateEditVehicleScreen(initialClientId: clientId);
        },
      ),
      GoRoute(
        path: '/admin/vehicles/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return VehicleDetailScreen(vehicleId: id);
        },
      ),
      GoRoute(
        path: '/admin/vehicles/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CreateEditVehicleScreen(vehicleId: id);
        },
      ),
      // Catalogue (A22–A23)
      GoRoute(
        path: '/admin/products/create',
        builder: (context, state) => const CreateEditProductScreen(),
      ),
      GoRoute(
        path: '/admin/products/:id/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return CreateEditProductScreen(productId: id);
        },
      ),
      // Quotations (A12–A16)
      GoRoute(
        path: '/admin/quotes/create',
        builder: (context, state) {
          final serviceRequestId = state.uri.queryParameters['serviceRequestId'];
          return CreateQuoteScreen(serviceRequestId: serviceRequestId);
        },
      ),
      GoRoute(
        path: '/admin/quotes/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return QuoteDetailScreen(quotationId: id);
        },
      ),
      GoRoute(
        path: '/admin/quotes/:id/revisions/:revisionId/edit',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final revisionId = state.pathParameters['revisionId']!;
          return EditQuoteRevisionScreen(
            quotationId: id,
            revisionId: revisionId,
          );
        },
      ),
      GoRoute(
        path: '/admin/quotes/:id/change-requests',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          final requestId = state.uri.queryParameters['requestId'];
          return QuoteChangeRequestsScreen(
            quotationId: id,
            changeRequestId: requestId,
          );
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
