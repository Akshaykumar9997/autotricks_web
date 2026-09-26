import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'core/config/env_config.dart';
import 'core/constants/app_assets.dart';
import 'core/services/fcm_service.dart';
import 'core/services/local_notifications_service.dart';
import 'data/models/notification_model.dart';
import 'data/repositories/notifications_repository.dart';
import 'design_system/components/auto_tricks_startup_loader.dart';
import 'design_system/theme/app_theme.dart';
import 'features/auth/providers/auth_provider.dart';
import 'firebase_options.dart';
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

    // Initialize Firebase using configured platform options
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Firebase initialization note: $e');
    }

    // Initialize Local Notifications (creates Android notification channel)
    final localNotifications = LocalNotificationsService();
    try {
      await localNotifications.initialize();
    } catch (e) {
      debugPrint('Local notifications initialization note: $e');
    }

    // Initialize FCM client if supported on current platform
    if (FcmService.isPlatformSupported) {
      try {
        final fcmService = FcmService();
        fcmService.attachLocalNotificationsService(localNotifications);
        await fcmService.initialize();
      } catch (e) {
        debugPrint('FCM initialization note: $e');
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

class AutoTricksApp extends ConsumerStatefulWidget {
  const AutoTricksApp({super.key});

  @override
  ConsumerState<AutoTricksApp> createState() => _AutoTricksAppState();
}

class _AutoTricksAppState extends ConsumerState<AutoTricksApp> {
  FcmPayload? _pendingPayload;
  bool _isStartupReady = false;

  @override
  void initState() {
    super.initState();
    _initStartup();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupNotificationNavigation();
    });
  }

  Future<void> _initStartup() async {
    try {
      // 1. Precache symbol-only branding asset for sharp, immediate rendering
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          precacheImage(
            const AssetImage(AppAssets.logoSymbol),
            context,
          ).catchError((_) {});
        }
      });

      // 2. Await genuine session hydration / auth restoration without artificial delays
      await ref.read(authProvider.notifier).waitForInitialization();
    } catch (e) {
      debugPrint('[StartupLoader] Startup initialization note: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isStartupReady = true;
        });
      }
    }
  }

  void _setupNotificationNavigation() {
    final fcmService = ref.read(fcmServiceProvider);
    final localNotifications = ref.read(localNotificationsServiceProvider);

    void handleTap(FcmPayload payload) {
      debugPrint('[NotificationTap] callback fired');
      debugPrint('[NotificationTap] payload received: $payload');
      _navigateToPayload(payload);
    }

    fcmService.setOnNotificationTap(handleTap);
    localNotifications.setTapHandler(handleTap);
  }

  Future<void> _navigateToPayload(FcmPayload payload) async {
    final authState = ref.read(authProvider);

    if (!authState.isAuthenticated) {
      debugPrint(
        '[NotificationTap] auth not authenticated, holding pending payload for post-auth navigation',
      );
      _pendingPayload = payload;
      return;
    }

    String? route;
    try {
      final notifsRepo = ref.read(notificationsRepositoryProvider);
      final model = NotificationModel(
        id: payload.rawData['notification_id'] as String? ?? '',
        profileId: '',
        type: payload.notificationType ?? '',
        title: payload.title ?? '',
        message: payload.body ?? '',
        entityType: payload.entityType,
        entityId: payload.entityId,
        createdAt: DateTime.now(),
      );
      route = await notifsRepo.resolveTargetRoute(
        model,
        isAdmin: authState.isAdmin,
      );
    } catch (e) {
      debugPrint('[NotificationTap] Note resolving route via repository: $e');
    }

    route ??= FcmService.resolveRouteFromPayload(
      payload,
      isAdmin: authState.isAdmin,
    );

    if (route != null && mounted) {
      debugPrint('[NotificationTap] route resolved: $route');
      debugPrint('[NotificationTap] router ready: true');
      debugPrint('[NotificationTap] navigating: $route');
      final router = ref.read(routerProvider);
      final currentLoc = router.routeInformationProvider.value.uri.toString();
      if (currentLoc != route) {
        router.push(route);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Listen for auth state transitions to process any pending notification payload
    ref.listen<AuthState>(authProvider, (previous, next) {
      if (next.isAuthenticated && _pendingPayload != null) {
        final payload = _pendingPayload!;
        _pendingPayload = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          debugPrint(
            '[NotificationTap] auth restored, processing queued payload: $payload',
          );
          _navigateToPayload(payload);
        });
      }
    });

    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'AutoTricks',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
      builder: (context, child) {
        return Stack(
          children: [
            child ?? const SizedBox.shrink(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 280),
              switchOutCurve: Curves.easeOutCubic,
              child: _isStartupReady
                  ? const SizedBox.shrink()
                  : const AutoTricksStartupLoader(
                      key: ValueKey('startup_loader'),
                    ),
            ),
          ],
        );
      },
    );
  }
}
