import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:autotricks/core/services/fcm_service.dart';
import 'package:autotricks/data/repositories/auth_repository.dart';
import 'package:autotricks/data/repositories/device_tokens_repository.dart';
import 'package:autotricks/features/auth/providers/auth_provider.dart';
import '../../helpers/mock_repositories.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Device Tokens Repository & Lifecycle Tests', () {
    late MockDeviceTokensRepository tokensRepo;
    late MockAuthRepository authRepo;

    setUp(() {
      tokensRepo = MockDeviceTokensRepository();
      authRepo = MockAuthRepository();
      FcmService.resetInstance();
    });

    test('upsertToken adds new token when not existing', () async {
      await tokensRepo.upsertToken(
        fcmToken: 'token-abc',
        platform: 'android',
        deviceName: 'Samsung S24',
      );

      final active = await tokensRepo.getMyActiveTokens();
      expect(active.length, 1);
      expect(active.first.fcmToken, 'token-abc');
      expect(active.first.platform, 'android');
      expect(active.first.deviceName, 'Samsung S24');
      expect(active.first.isActive, isTrue);
    });

    test('upsertToken reactivates and updates existing token on conflict', () async {
      await tokensRepo.upsertToken(
        fcmToken: 'token-conflict',
        platform: 'android',
        deviceName: 'Initial Phone',
      );

      // Deactivate first
      await tokensRepo.deactivateToken('token-conflict');
      var active = await tokensRepo.getMyActiveTokens();
      expect(active.isEmpty, isTrue);

      // Re-upsert (same token re-registered)
      await tokensRepo.upsertToken(
        fcmToken: 'token-conflict',
        platform: 'android',
        deviceName: 'Updated Phone',
      );

      active = await tokensRepo.getMyActiveTokens();
      expect(active.length, 1);
      expect(active.first.fcmToken, 'token-conflict');
      expect(active.first.deviceName, 'Updated Phone');
      expect(active.first.isActive, isTrue);
    });

    test('deactivateToken marks token inactive', () async {
      await tokensRepo.upsertToken(
        fcmToken: 'token-to-deactivate',
        platform: 'ios',
        deviceName: 'iPhone 14',
      );

      expect((await tokensRepo.getMyActiveTokens()).length, 1);

      await tokensRepo.deactivateToken('token-to-deactivate');

      final active = await tokensRepo.getMyActiveTokens();
      expect(active.isEmpty, isTrue);
      expect(tokensRepo.tokens.first.isActive, isFalse);
    });

    test('FcmService syncTokenWithBackend persists token to repository', () async {
      final fcmService = FcmService();
      fcmService.setTokenForTesting('fcm-test-token-123');

      await fcmService.syncTokenWithBackend(
        repository: tokensRepo,
        deviceName: 'Test Device',
      );

      final active = await tokensRepo.getMyActiveTokens();
      expect(active.length, 1);
      expect(active.first.fcmToken, 'fcm-test-token-123');
      expect(active.first.deviceName, 'Test Device');
    });

    test('FcmService deactivateCurrentToken marks active token inactive', () async {
      final fcmService = FcmService();
      fcmService.setTokenForTesting('fcm-deactivate-me');

      await fcmService.syncTokenWithBackend(
        repository: tokensRepo,
      );
      expect((await tokensRepo.getMyActiveTokens()).length, 1);

      await fcmService.deactivateCurrentToken(
        repository: tokensRepo,
      );

      final active = await tokensRepo.getMyActiveTokens();
      expect(active.isEmpty, isTrue);
    });

    test('FcmService sync failure does NOT throw or interrupt execution', () async {
      final fcmService = FcmService();
      fcmService.setTokenForTesting('fcm-fail-safe');

      tokensRepo.throwOnUpsert = true;

      // syncTokenWithBackend catches any error and never throws
      await expectLater(
        fcmService.syncTokenWithBackend(repository: tokensRepo),
        completes,
      );
    });

    test('AuthNotifier signIn triggers token sync in background', () async {
      final fcmService = FcmService();
      fcmService.setTokenForTesting('fcm-auth-login-token');

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          deviceTokensRepositoryProvider.overrideWithValue(tokensRepo),
          fcmServiceProvider.overrideWithValue(fcmService),
        ],
      );
      addTearDown(container.dispose);

      // Verify sign in
      final notifier = container.read(authProvider.notifier);
      final success = await notifier.signIn(
        email: 'admin@autotricks.in',
        password: 'password123',
      );

      expect(success, isTrue);
      expect(container.read(authProvider).isAuthenticated, isTrue);

      // Verify token was synced
      final active = await tokensRepo.getMyActiveTokens();
      expect(active.length, 1);
      expect(active.first.fcmToken, 'fcm-auth-login-token');
    });

    test('AuthNotifier signOut deactivates active token', () async {
      final fcmService = FcmService();
      fcmService.setTokenForTesting('fcm-auth-logout-token');

      // Pre-seed token in repository
      await tokensRepo.upsertToken(
        fcmToken: 'fcm-auth-logout-token',
        platform: 'android',
      );
      expect((await tokensRepo.getMyActiveTokens()).length, 1);

      authRepo.currentUser = const UserProfile(
        id: 'usr-1',
        email: 'user@autotricks.in',
        fullName: 'Client User',
        role: 'CLIENT',
      );

      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          deviceTokensRepositoryProvider.overrideWithValue(tokensRepo),
          fcmServiceProvider.overrideWithValue(fcmService),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(authProvider.notifier);
      await Future.delayed(Duration.zero);
      await notifier.signOut();

      expect(container.read(authProvider).isAuthenticated, isFalse);

      final active = await tokensRepo.getMyActiveTokens();
      expect(active.isEmpty, isTrue);
    });
  });
}

