import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../features/auth/providers/auth_provider.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/catalogue/screens/create_edit_product_screen.dart';
import '../features/catalogue/screens/products_list_screen.dart';
import '../features/client/screens/client_accept_quote_screen.dart';
import '../features/client/screens/client_home_screen.dart';
import '../features/client/screens/client_login_screen.dart';
import '../features/client/screens/client_profile_placeholder_screen.dart';
import '../features/client/screens/client_quote_detail_screen.dart';
import '../features/client/screens/client_quote_rejected_screen.dart';
import '../features/client/screens/client_quotes_screen.dart';
import '../features/client/screens/client_request_changes_screen.dart';
import '../features/client/screens/client_service_request_detail_screen.dart';
import '../features/client/screens/client_service_requests_screen.dart';
import '../features/client/screens/client_shell_screen.dart';
import '../features/client/screens/client_vehicle_detail_screen.dart';
import '../features/client/screens/client_vehicles_screen.dart';
import '../features/clients/screens/client_detail_screen.dart';
import '../features/clients/screens/client_list_screen.dart';
import '../features/clients/screens/create_edit_client_screen.dart';
import '../features/home/screens/admin_home_screen.dart';
import '../features/quotes/screens/create_quote_screen.dart';
import '../features/quotes/screens/edit_quote_revision_screen.dart';
import '../features/quotes/screens/quote_change_requests_screen.dart';
import '../features/quotes/screens/quote_detail_screen.dart';
import '../features/quotes/screens/quote_list_screen.dart';
import '../features/service_jobs/screens/service_job_detail_screen.dart';
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
    initialLocation: authState.isAuthenticated
        ? (authState.isAdmin ? '/admin' : '/client')
        : '/login',
    routes: [
      // Approved C01 Client Login
      GoRoute(
        path: '/login',
        builder: (context, state) => const ClientLoginScreen(),
      ),
      // Approved A01 Admin Login
      GoRoute(
        path: '/admin/login',
        builder: (context, state) => const LoginScreen(),
      ),

      // Client Portal Bottom Navigation Shell (C02, C03, C05, Profile)
      ShellRoute(
        builder: (context, state, child) {
          return ClientShellScreen(
            location: state.uri.path,
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/client',
            builder: (context, state) => const ClientHomeScreen(),
          ),
          GoRoute(
            path: '/client/vehicles',
            builder: (context, state) => const ClientVehiclesScreen(),
          ),
          GoRoute(
            path: '/client/services',
            builder: (context, state) => const ClientServiceRequestsScreen(),
          ),
          GoRoute(
            path: '/client/profile',
            builder: (context, state) => const ClientProfilePlaceholderScreen(),
          ),
        ],
      ),

      // Client Detail Subroutes (Pushed outside Shell to preserve back navigation stack)
      GoRoute(
        path: '/client/vehicles/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ClientVehicleDetailScreen(vehicleId: id);
        },
      ),
      GoRoute(
        path: '/client/services/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ClientServiceRequestDetailScreen(requestId: id);
        },
      ),
      GoRoute(
        path: '/client/quotes',
        builder: (context, state) => const ClientQuotesScreen(),
      ),
      GoRoute(
        path: '/client/quotes/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ClientQuoteDetailScreen(quotationId: id);
        },
      ),
      GoRoute(
        path: '/client/quotes/:id/changes',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ClientRequestChangesScreen(quotationId: id);
        },
      ),
      GoRoute(
        path: '/client/quotes/:id/accept',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ClientAcceptQuoteScreen(quotationId: id);
        },
      ),
      GoRoute(
        path: '/client/quotes/:id/rejected',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ClientQuoteRejectedScreen(quotationId: id);
        },
      ),

      // Admin Portal Bottom Navigation Shell
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
      // Admin Service Requests
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
      // Admin Clients CRM (A06–A08)
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
      // Admin Vehicles CRM (A09–A11)
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
      // Admin Catalogue (A22–A23)
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
      // Admin Quotations (A12–A16)
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
      // Admin Service Jobs (Day 12)
      GoRoute(
        path: '/admin/jobs/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return ServiceJobDetailScreen(jobId: id);
        },
      ),
    ],
    redirect: (context, state) {
      final isAuth = authState.isAuthenticated;
      final isAdmin = authState.isAdmin;
      final isClient = authState.isClient;
      final path = state.uri.path;

      final isClientLogin = path == '/login';
      final isAdminLogin = path == '/admin/login';

      // 1. Unauthenticated users
      if (!isAuth) {
        if (isClientLogin || isAdminLogin) {
          return null;
        }
        // Redirect admin attempts to admin login, client attempts to client login
        if (path.startsWith('/admin')) {
          return '/admin/login';
        }
        return '/login';
      }

      // 2. Authenticated user visiting login pages
      if (isClientLogin || isAdminLogin) {
        return isAdmin ? '/admin' : '/client';
      }

      // 3. Authenticated Admin attempting to visit Client portal
      if (isAdmin && path.startsWith('/client')) {
        return '/admin';
      }

      // 4. Authenticated Client attempting to visit Admin portal
      if (isClient && path.startsWith('/admin')) {
        return '/client';
      }

      // 5. Root path
      if (path == '/') {
        return isAdmin ? '/admin' : '/client';
      }

      return null;
    },
  );
});
