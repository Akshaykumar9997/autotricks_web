import 'package:flutter_test/flutter_test.dart';
import 'package:autotricks/core/config/env_config.dart';

void main() {
  group('EnvConfig Unit Tests', () {
    tearDown(() {
      EnvConfig.resetForTesting();
    });

    test('valid configuration succeeds and sets getters', () {
      EnvConfig.setForTesting(
        supabaseUrl: 'https://test-project.supabase.co',
        supabaseAnonKey: 'test-anon-key-xyz',
        enableDevAuth: true,
      );

      expect(EnvConfig.supabaseUrl, 'https://test-project.supabase.co');
      expect(EnvConfig.supabaseAnonKey, 'test-anon-key-xyz');
      expect(EnvConfig.isConfigured, isTrue);
      expect(EnvConfig.enableDevAuth, isTrue);
      expect(() => EnvConfig.validate(), returnsNormally);
    });

    test('validate throws ConfigurationException when SUPABASE_URL is missing', () {
      EnvConfig.setForTesting(
        supabaseUrl: '',
        supabaseAnonKey: 'valid-anon-key',
      );

      expect(
        () => EnvConfig.validate(),
        throwsA(
          isA<ConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('SUPABASE_URL'),
          ),
        ),
      );
    });

    test('validate throws ConfigurationException when SUPABASE_ANON_KEY is missing', () {
      EnvConfig.setForTesting(
        supabaseUrl: 'https://test.supabase.co',
        supabaseAnonKey: '',
      );

      expect(
        () => EnvConfig.validate(),
        throwsA(
          isA<ConfigurationException>().having(
            (e) => e.message,
            'message',
            contains('SUPABASE_ANON_KEY'),
          ),
        ),
      );
    });

    test('validate throws ConfigurationException when both keys are missing', () {
      EnvConfig.setForTesting(
        supabaseUrl: '',
        supabaseAnonKey: '',
      );

      expect(
        () => EnvConfig.validate(),
        throwsA(
          isA<ConfigurationException>().having(
            (e) => e.message,
            'message',
            allOf(contains('SUPABASE_URL'), contains('SUPABASE_ANON_KEY')),
          ),
        ),
      );
    });

    test('ConfigurationException does not expose raw secret values', () {
      final ex = ConfigurationException('Supabase environment configuration is missing: SUPABASE_URL');
      expect(ex.toString(), contains('ConfigurationException: Supabase environment configuration is missing: SUPABASE_URL'));
      expect(ex.message, isNot(contains('eyJ')));
    });

    test('isConfigured is false when uninitialized or empty', () {
      EnvConfig.resetForTesting();
      expect(EnvConfig.isConfigured, isFalse);
    });
  });
}
