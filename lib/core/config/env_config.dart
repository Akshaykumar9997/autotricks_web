/// Environment configuration for AutoTricks application.
///
/// Uses compile-time environment variables (`--dart-define`) with public fallbacks
/// for local development and testing.
///
/// IMPORTANT: Under NO circumstance should service role keys, database passwords,
/// or admin secrets be placed here. Only the public Supabase anon key is used.
class EnvConfig {
  EnvConfig._();

  /// The Supabase Project URL for AutoTricks
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://extsmeyxnzhhvcmwyvbi.supabase.co',
  );

  /// The public Supabase anonymous API key
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImV4dHNtZXl4bnpoaHZjbXd5dmJpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODkwMTc5MDcsImV4cCI6MjEwNDU5MzkwN30.mZ7b02kRLI-UN1v5u0FZfllAji79ZYJn_0CkVuZagPg',
  );

  /// Whether the app is configured to use live Supabase data
  static bool get isConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
