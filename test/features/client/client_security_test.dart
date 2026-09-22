import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autotricks/data/repositories/auth_repository.dart';
import 'package:autotricks/features/auth/providers/auth_provider.dart';
import 'package:autotricks/routing/app_router.dart';
import '../../helpers/mock_repositories.dart';

void main() {
  group('Client Security & Isolation Tests', () {
    test('UserProfile correctly distinguishes CLIENT and ADMIN roles', () {
      const clientUser = UserProfile(
        id: 'usr-client-1',
        email: 'rahul.kumar@gmail.com',
        fullName: 'Rahul Kumar',
        role: 'CLIENT',
        clientId: 'c-1',
      );

      const adminUser = UserProfile(
        id: 'usr-admin-1',
        email: 'admin@autotricks.com',
        fullName: 'Vikram Mehta',
        role: 'ADMIN',
      );

      expect(clientUser.isClient, isTrue);
      expect(clientUser.isAdmin, isFalse);
      expect(clientUser.clientId, equals('c-1'));

      expect(adminUser.isAdmin, isTrue);
      expect(adminUser.isClient, isFalse);
    });

    test('Client repository throws exception when vehicle is not found or unauthorized', () async {
      final repo = MockClientPortalRepository();

      expect(
        () => repo.getVehicleById('unauthorized-vehicle-id'),
        throwsA(isA<Exception>()),
      );
    });

    test('Client repository throws exception when service request is not found or unauthorized', () async {
      final repo = MockClientPortalRepository();

      expect(
        () => repo.getServiceRequestById('unauthorized-request-id'),
        throwsA(isA<Exception>()),
      );
    });

    test('Router redirect rules enforce bidirectional role isolation', () {
      // 1. Unauthenticated user initial location is /login
      final unauthContainer = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(MockAuthRepository()),
        ],
      );
      final unauthRouter = unauthContainer.read(routerProvider);
      expect(unauthRouter.routeInformationProvider.value.uri.path, equals('/login'));

      // 2. Client role user
      final clientMockAuth = MockAuthRepository();
      clientMockAuth.currentUser = const UserProfile(
        id: 'c-user-1',
        email: 'rahul@gmail.com',
        fullName: 'Rahul Kumar',
        role: 'CLIENT',
        clientId: 'c-1',
      );

      final clientContainer = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(clientMockAuth),
        ],
      );

      final clientRouter = clientContainer.read(routerProvider);
      // Client initial location is /client
      expect(clientRouter.routeInformationProvider.value.uri.path, equals('/client'));

      // 3. Admin role user
      final adminMockAuth = MockAuthRepository();
      adminMockAuth.currentUser = const UserProfile(
        id: 'a-user-1',
        email: 'admin@autotricks.com',
        fullName: 'Vikram Mehta',
        role: 'ADMIN',
      );

      final adminContainer = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(adminMockAuth),
        ],
      );

      final adminRouter = adminContainer.read(routerProvider);
      // Admin initial location is /admin
      expect(adminRouter.routeInformationProvider.value.uri.path, equals('/admin'));
    });
  });
}
