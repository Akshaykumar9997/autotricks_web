import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/device_tokens_repository.dart';
import '../../firebase_options.dart';

/// Top-level background message handler for Firebase Cloud Messaging.
/// Must be a top-level function annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint('[FCM Background] Firebase init warning: $e');
  }

  debugPrint(
    '[FCM Background] Received message id: ${message.messageId}, data: ${message.data}',
  );
}

/// Parsed push notification payload from FCM RemoteMessage.
class FcmPayload {
  final String? title;
  final String? body;
  final String? entityType;
  final String? entityId;
  final String? notificationType;
  final Map<String, dynamic> rawData;

  const FcmPayload({
    this.title,
    this.body,
    this.entityType,
    this.entityId,
    this.notificationType,
    this.rawData = const {},
  });

  factory FcmPayload.fromRemoteMessage(RemoteMessage message) {
    final data = message.data;
    return FcmPayload(
      title: message.notification?.title ?? data['title'] as String?,
      body: message.notification?.body ??
          data['message'] as String? ??
          data['body'] as String?,
      entityType: data['entity_type'] as String?,
      entityId: data['entity_id'] as String?,
      notificationType:
          data['type'] as String? ?? data['notification_type'] as String?,
      rawData: data,
    );
  }

  @override
  String toString() {
    return 'FcmPayload(title: $title, entityType: $entityType, entityId: $entityId, type: $notificationType)';
  }
}

/// Service managing Firebase Cloud Messaging client lifecycle, permissions, and handlers.
class FcmService {
  static FcmService? _instance;

  final FirebaseMessaging? _customMessaging;
  String? _currentToken;
  final _tokenController = StreamController<String>.broadcast();
  bool _initialized = false;
  DeviceTokensRepository? _tokensRepository;

  factory FcmService([FirebaseMessaging? customMessaging]) {
    if (customMessaging != null) {
      return FcmService._internal(customMessaging);
    }
    _instance ??= FcmService._internal(null);
    return _instance!;
  }

  FcmService._internal(this._customMessaging);

  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }

  @visibleForTesting
  void setTokenForTesting(String? token) {
    _currentToken = token;
    if (token != null) {
      _tokenController.add(token);
    }
  }

  /// True if current platform is supported by Firebase Cloud Messaging.
  static bool get isPlatformSupported {
    if (kIsWeb) return true;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  /// Returns normalized platform string for device_tokens table.
  static String get currentPlatformName {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.windows:
        return 'windows';
      default:
        return 'android';
    }
  }

  FirebaseMessaging get _messaging =>
      _customMessaging ?? FirebaseMessaging.instance;

  String? get currentToken => _currentToken;

  Stream<String> get tokenStream => _tokenController.stream;

  bool get isInitialized => _initialized;

  /// Attaches a DeviceTokensRepository to handle automatic token persistence.
  void attachTokensRepository(DeviceTokensRepository repository) {
    _tokensRepository = repository;
  }

  /// Syncs current FCM token to Supabase device_tokens table for the logged-in user.
  Future<void> syncTokenWithBackend({
    DeviceTokensRepository? repository,
    String? deviceName,
  }) async {
    try {
      final repo = repository ?? _tokensRepository;
      if (repo == null) {
        debugPrint('[FCM] No tokens repository attached to sync token');
        return;
      }

      // If current token is not yet fetched, try fetching it now
      if (_currentToken == null && isPlatformSupported && Firebase.apps.isNotEmpty) {
        try {
          _currentToken = await _messaging.getToken();
        } catch (e) {
          debugPrint('[FCM] Error fetching token during sync: $e');
        }
      }

      if (_currentToken == null || _currentToken!.isEmpty) {
        debugPrint('[FCM] No token available to sync with backend');
        return;
      }

      await repo.upsertToken(
        fcmToken: _currentToken!,
        platform: currentPlatformName,
        deviceName: deviceName,
      );
      debugPrint('[FCM] Successfully synced token with backend');
    } catch (e) {
      debugPrint('[FCM] Token sync with backend failed (non-blocking): $e');
    }
  }

  /// Deactivates current token in Supabase device_tokens table (e.g. on logout).
  Future<void> deactivateCurrentToken({
    DeviceTokensRepository? repository,
  }) async {
    try {
      final repo = repository ?? _tokensRepository;
      if (repo == null) return;
      if (_currentToken == null || _currentToken!.isEmpty) return;

      await repo.deactivateToken(_currentToken!);
      debugPrint('[FCM] Successfully deactivated token on backend');
    } catch (e) {
      debugPrint('[FCM] Token deactivation failed (non-blocking): $e');
    }
  }

  /// Initializes FCM client, registers background handler, requests permission, and fetches token.
  Future<void> initialize({
    void Function(FcmPayload payload)? onNotificationTap,
    void Function(FcmPayload payload)? onForegroundMessage,
  }) async {
    if (!isPlatformSupported) {
      debugPrint(
        '[FCM] Skipping initialization on unsupported platform: $defaultTargetPlatform',
      );
      _initialized = true;
      return;
    }

    if (Firebase.apps.isEmpty) {
      debugPrint('[FCM] Firebase not initialized. Skipping FCM client setup.');
      _initialized = true;
      return;
    }

    try {
      // 1. Request notification permissions (required for iOS and Android 13+)
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('[FCM] Notification authorization status: ${settings.authorizationStatus}');

      // 2. Register top-level background handler
      FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

      // 3. Obtain initial FCM token
      try {
        _currentToken = await _messaging.getToken();
        if (_currentToken != null) {
          debugPrint('[FCM] Device Token: $_currentToken');
          _tokenController.add(_currentToken!);
          if (_tokensRepository != null) {
            unawaited(syncTokenWithBackend());
          }
        }
      } catch (e) {
        debugPrint('[FCM] Error obtaining initial token: $e');
      }

      // 4. Listen for token refresh events
      _messaging.onTokenRefresh.listen((newToken) {
        _currentToken = newToken;
        debugPrint('[FCM] Device Token refreshed: $newToken');
        _tokenController.add(newToken);
        if (_tokensRepository != null) {
          unawaited(syncTokenWithBackend());
        }
      });

      // 5. Handle foreground notifications
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('[FCM Foreground] Received: ${message.messageId}, data: ${message.data}');
        final payload = FcmPayload.fromRemoteMessage(message);
        onForegroundMessage?.call(payload);
      });

      // 6. Handle notification click when app is opened from terminated state
      final initialMessage = await _messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM InitialMessage] Opened app from terminated: ${initialMessage.messageId}');
        final payload = FcmPayload.fromRemoteMessage(initialMessage);
        onNotificationTap?.call(payload);
      }

      // 7. Handle notification click when app is in background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('[FCM onMessageOpenedApp] Opened app from background: ${message.messageId}');
        final payload = FcmPayload.fromRemoteMessage(message);
        onNotificationTap?.call(payload);
      });

      _initialized = true;
    } catch (e) {
      debugPrint('[FCM] Initialization error: $e');
      _initialized = true;
    }
  }

  /// Maps an FcmPayload to an existing application route for deep linking.
  static String? resolveRouteFromPayload(
    FcmPayload payload, {
    required bool isAdmin,
  }) {
    final entityType = payload.entityType;
    final entityId = payload.entityId;

    if (entityType == null || entityId == null) {
      return isAdmin ? '/admin/notifications' : '/client/notifications';
    }

    switch (entityType) {
      case 'service_request':
        return isAdmin
            ? '/admin/requests/$entityId'
            : '/client/services/$entityId';
      case 'quotation_revision':
      case 'quotation':
        return isAdmin
            ? '/admin/quotes/$entityId'
            : '/client/quotes/$entityId';
      case 'quotation_change_request':
        return isAdmin
            ? '/admin/quotes/$entityId'
            : '/client/quotes/$entityId';
      case 'service_job':
        return isAdmin
            ? '/admin/jobs/$entityId'
            : '/client/services/$entityId';
      case 'service_work_item':
        return isAdmin
            ? '/admin/jobs/$entityId'
            : '/client/services/$entityId';
      case 'vehicle_correction_request':
        return isAdmin ? '/admin/vehicles' : '/client/vehicles';
      default:
        return isAdmin ? '/admin/notifications' : '/client/notifications';
    }
  }

  void dispose() {
    _tokenController.close();
  }
}

/// Provider for FcmService singleton.
final fcmServiceProvider = Provider<FcmService>((ref) {
  final service = FcmService();
  final repo = ref.watch(deviceTokensRepositoryProvider);
  service.attachTokensRepository(repo);
  ref.onDispose(() => service.dispose());
  return service;
});
