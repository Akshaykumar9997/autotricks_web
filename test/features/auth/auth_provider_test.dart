import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autotricks/features/auth/models/user_profile.dart';
import 'package:autotricks/features/auth/providers/auth_provider.dart';

void main() {
  group('AuthNotifier & Role-Based Access Tests', () {
    test('initial auth state initializes cleanly', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final authState = container.read(authProvider);
      expect(authState.isAuthenticated, isFalse);
    });

    test('mock admin sign-in correctly assigns ADMIN role', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);
      notifier.signInAsMockAdmin(
        email: 'alex@autotricks.com',
        name: 'Alex Technician',
      );

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticatedAdmin);
      expect(state.isAdmin, isTrue);
      expect(state.isClient, isFalse);
      expect(state.profile?.role, UserRole.admin);
      expect(state.profile?.fullName, 'Alex Technician');
      expect(state.email, 'alex@autotricks.com');
    });

    test('mock client sign-in correctly assigns CLIENT role and isolates from admin', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);
      notifier.signInAsMockClient(
        email: 'rohit@example.com',
        name: 'Rohit Sharma',
      );

      final state = container.read(authProvider);
      expect(state.status, AuthStatus.authenticatedClient);
      expect(state.isAdmin, isFalse);
      expect(state.isClient, isTrue);
      expect(state.profile?.role, UserRole.client);
      expect(state.profile?.fullName, 'Rohit Sharma');
      expect(state.email, 'rohit@example.com');
    });

    test('signOut resets state to unauthenticated', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);
      notifier.signInAsMockAdmin();
      expect(container.read(authProvider).isAuthenticated, isTrue);

      await notifier.signOut();
      final state = container.read(authProvider);
      expect(state.status, AuthStatus.unauthenticated);
      expect(state.isAuthenticated, isFalse);
      expect(state.profile, isNull);
    });
  });
}
