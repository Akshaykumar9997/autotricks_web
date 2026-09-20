import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Centralized environment configuration for the AutoTricks application.
///
/// Loads connection settings from the root `.env` asset file at application launch.
/// Supports compile-time overrides (`--dart-define`) if provided.
///
/// IMPORTANT: Under NO circumstance should service role keys, database passwords,
/// private signing secrets, or admin credentials be stored here or in `.env`.
class EnvConfig {
  EnvConfig._();

  static bool _initialized = false;
  static String _supabaseUrl = '';
  static String _supabaseAnonKey = '';
  static bool _enableDevAuth = false;

  /// Loads environment configuration from the `.env` asset file.
  /// Validates that all required Supabase variables are present and non-empty.
  ///
  /// Throws a [ConfigurationException] if required variables are missing.
  static Future<void> init({String fileName = '.env'}) async {
    try {
      await dotenv.load(fileName: fileName);
    } catch (e) {
      debugPrint('EnvConfig note: Error loading $fileName: $e');
    }

    // 1. Read from dotenv, fallback to compile-time --dart-define
    const dartDefineUrl = String.fromEnvironment('SUPABASE_URL');
    const dartDefineAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    final envUrl = dotenv.maybeGet('SUPABASE_URL') ??
        (dartDefineUrl.isNotEmpty ? dartDefineUrl : '');
    final envAnonKey = dotenv.maybeGet('SUPABASE_ANON_KEY') ??
        (dartDefineAnonKey.isNotEmpty ? dartDefineAnonKey : '');

    _supabaseUrl = envUrl.trim();
    _supabaseAnonKey = envAnonKey.trim();

    final devAuthStr = dotenv.maybeGet('ENABLE_DEV_AUTH') ??
        const String.fromEnvironment('ENABLE_DEV_AUTH');
    _enableDevAuth = !kReleaseMode &&
        (devAuthStr.toLowerCase() == 'true' || devAuthStr == '1');

    _initialized = true;

    // 2. Validate configuration
    validate();
  }

  /// Validates that required environment settings are present.
  /// Throws a [ConfigurationException] with a clean, user-friendly message.
  /// Never logs or exposes raw secrets.
  static void validate() {
    final List<String> missing = [];
    if (_supabaseUrl.isEmpty) {
      missing.add('SUPABASE_URL');
    }
    if (_supabaseAnonKey.isEmpty) {
      missing.add('SUPABASE_ANON_KEY');
    }

    if (missing.isNotEmpty) {
      throw ConfigurationException(
        'Supabase environment configuration is missing: ${missing.join(', ')}. '
        'Ensure that a valid .env asset file exists with these variables defined, '
        'or pass them via --dart-define.',
      );
    }
  }

  /// The Supabase Project URL for AutoTricks
  static String get supabaseUrl {
    _ensureInitialized();
    return _supabaseUrl;
  }

  /// The public Supabase anonymous API key
  static String get supabaseAnonKey {
    _ensureInitialized();
    return _supabaseAnonKey;
  }

  /// Whether the app is configured with non-empty Supabase credentials
  static bool get isConfigured {
    _ensureInitialized();
    return _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty;
  }

  /// Whether developer quick-auth shortcuts are permitted.
  /// Strictly false in release builds (`!kReleaseMode`).
  static bool get enableDevAuth {
    _ensureInitialized();
    return _enableDevAuth;
  }

  static void _ensureInitialized() {
    if (!_initialized) {
      // Check if dart-define was provided without explicit init()
      const dartDefineUrl = String.fromEnvironment('SUPABASE_URL');
      const dartDefineAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
      if (dartDefineUrl.isNotEmpty || dartDefineAnonKey.isNotEmpty) {
        _supabaseUrl = dartDefineUrl.trim();
        _supabaseAnonKey = dartDefineAnonKey.trim();
        const devAuthStr = String.fromEnvironment('ENABLE_DEV_AUTH');
        _enableDevAuth = !kReleaseMode &&
            (devAuthStr.toLowerCase() == 'true' || devAuthStr == '1');
        _initialized = true;
      }
    }
  }

  /// Helper for unit and integration testing
  @visibleForTesting
  static void setForTesting({
    String? supabaseUrl,
    String? supabaseAnonKey,
    bool? enableDevAuth,
    bool initialized = true,
  }) {
    _supabaseUrl = supabaseUrl ?? '';
    _supabaseAnonKey = supabaseAnonKey ?? '';
    _enableDevAuth = enableDevAuth ?? false;
    _initialized = initialized;
  }

  /// Reset testing overrides
  @visibleForTesting
  static void resetForTesting() {
    _supabaseUrl = '';
    _supabaseAnonKey = '';
    _enableDevAuth = false;
    _initialized = false;
  }
}

/// Thrown when application configuration or environment variables are missing/invalid.
class ConfigurationException implements Exception {
  final String message;
  const ConfigurationException(this.message);

  @override
  String toString() => 'ConfigurationException: $message';
}
