import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'fcm_service.dart';

/// Service managing client-side local notification presentation and channels.
class LocalNotificationsService {
  static const String channelId = 'autotricks_high_importance';
  static const String channelName = 'High Importance Notifications';
  static const String channelDescription =
      'Used for critical service updates, quotation status, and job alerts.';

  static LocalNotificationsService? _instance;

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;
  void Function(FcmPayload payload)? _onTapHandler;
  FcmPayload? _pendingTapPayload;

  factory LocalNotificationsService([FlutterLocalNotificationsPlugin? plugin]) {
    if (plugin != null) {
      return LocalNotificationsService._internal(plugin);
    }
    _instance ??= LocalNotificationsService._internal(FlutterLocalNotificationsPlugin());
    return _instance!;
  }

  LocalNotificationsService._internal(this._plugin);

  @visibleForTesting
  static void resetInstance() {
    _instance = null;
  }

  bool get isInitialized => _initialized;

  /// Initializes local notification plugin, creates Android notification channel,
  /// and listens for user tap responses.
  Future<void> initialize({
    void Function(FcmPayload payload)? onNotificationTap,
  }) async {
    _onTapHandler = onNotificationTap;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    try {
      await _plugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint(
            '[NotificationTap] local notification tap response received: actionId=${response.actionId}',
          );
          final payloadStr = response.payload;
          if (payloadStr != null && payloadStr.isNotEmpty) {
            _handlePayloadString(payloadStr);
          }
        },
      );

      // Create Android Notification Channel for Android 8.0+ (API 26+)
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (androidPlugin != null) {
          const channel = AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDescription,
            importance: Importance.max,
            playSound: true,
            enableVibration: true,
          );
          await androidPlugin.createNotificationChannel(channel);
          debugPrint('[LocalNotifications] Created Android channel: $channelId');
        }
      }

      // Check if launched by notification tap from terminated state
      final launchDetails = await _plugin.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp ?? false) {
        debugPrint(
          '[NotificationTap] initial message detected via local notification launch details',
        );
        final payloadStr = launchDetails?.notificationResponse?.payload;
        if (payloadStr != null && payloadStr.isNotEmpty) {
          _handlePayloadString(payloadStr);
        }
      }

      _initialized = true;
      debugPrint('[LocalNotifications] Local notification service initialized');
    } catch (e) {
      debugPrint('[LocalNotifications] Initialization error: $e');
      _initialized = true;
    }
  }

  void _handlePayloadString(String payloadStr) {
    try {
      debugPrint('[NotificationTap] payload received (local): $payloadStr');
      final Map<String, dynamic> data =
          jsonDecode(payloadStr) as Map<String, dynamic>;
      final payload = FcmPayload(
        title: data['title'] as String?,
        body: data['message'] as String? ?? data['body'] as String?,
        entityType: data['entity_type'] as String?,
        entityId: data['entity_id'] as String?,
        notificationType:
            data['type'] as String? ?? data['notification_type'] as String?,
        rawData: data,
      );

      if (_onTapHandler != null) {
        debugPrint(
          '[NotificationTap] invoking onTapHandler with payload: $payload',
        );
        _onTapHandler!(payload);
      } else {
        debugPrint(
          '[NotificationTap] queuing local notification payload (no handler yet)',
        );
        _pendingTapPayload = payload;
      }
    } catch (e) {
      debugPrint('[NotificationTap] Error parsing tap payload: $e');
    }
  }

  /// Sets or updates the tap handler callback. Flushes any pending payload.
  void setTapHandler(void Function(FcmPayload payload)? handler) {
    _onTapHandler = handler;
    if (handler != null && _pendingTapPayload != null) {
      final p = _pendingTapPayload!;
      _pendingTapPayload = null;
      debugPrint('[NotificationTap] flushing pending tap payload: $p');
      handler(p);
    }
  }

  /// Displays a heads-up local notification on device using FCM payload details.
  Future<void> showNotificationFromPayload(FcmPayload payload) async {
    if (kIsWeb) return;

    final id = DateTime.now().millisecondsSinceEpoch.remainder(100000);
    final title = payload.title ?? 'AutoTricks Notification';
    final body = payload.body ?? '';

    // Encode payload data for deep linking when tapped
    final payloadMap = {
      'title': title,
      'body': body,
      'type': payload.notificationType,
      'entity_type': payload.entityType,
      'entity_id': payload.entityId,
      ...payload.rawData,
    };
    final payloadJson = jsonEncode(payloadMap);

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      playSound: true,
      enableVibration: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );

    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payloadJson,
      );
      debugPrint(
        '[LocalNotifications] Displayed heads-up notification: id=$id, title=$title',
      );
    } catch (e) {
      debugPrint('[LocalNotifications] Error displaying notification: $e');
    }
  }
}

/// Provider for LocalNotificationsService singleton.
final localNotificationsServiceProvider =
    Provider<LocalNotificationsService>((ref) {
  return LocalNotificationsService();
});
