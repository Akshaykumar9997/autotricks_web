import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/env_config.dart';
import 'design_system/theme/app_theme.dart';
import 'routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Load and validate environment configuration from .env asset
    await EnvConfig.init();

    // Initialize Supabase using public anonymous credentials
    if (EnvConfig.isConfigured) {
      try {
        await Supabase.initialize(
          url: EnvConfig.supabaseUrl,
          // ignore: deprecated_member_use
          anonKey: EnvConfig.supabaseAnonKey,
        );
      } catch (e) {
        debugPrint('Supabase initialization note: $e');
      }
    }

    runApp(
      const ProviderScope(
        child: AutoTricksApp(),
      ),
    );
  } on ConfigurationException catch (e) {
    debugPrint('FATAL CONFIGURATION ERROR: ${e.message}');
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: Scaffold(
          backgroundColor: const Color(0xFF0F172A),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 56),
                  const SizedBox(height: 16),
                  const Text(
                    'Configuration Error',
                    style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    e.message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AutoTricksApp extends ConsumerWidget {
  const AutoTricksApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'AutoTricks Admin',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
