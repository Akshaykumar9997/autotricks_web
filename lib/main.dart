import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/config/env_config.dart';
import 'design_system/theme/app_theme.dart';
import 'routing/app_router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
