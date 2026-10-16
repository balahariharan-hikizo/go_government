import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();

  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _isInitialized = false;

  /// Initialize local notification plugin for Android, iOS & Windows/Web
  static Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings iosSettings =
          DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
        iOS: iosSettings,
      );

      await _notificationsPlugin.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint('[NotificationService] Notification clicked: ${response.payload}');
        },
      );

      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        try {
          await androidPlugin.requestNotificationsPermission();
        } catch (e) {
          debugPrint('[NotificationService] Skipping runtime permission dialog in background isolate: $e');
        }
      }

      _isInitialized = true;
      debugPrint('[NotificationService] Initialized successfully');
    } catch (e) {
      debugPrint('[NotificationService] Initialization error: $e');
    }
  }

  /// Show a local push notification displaying the OTP code
  static Future<void> showOtpNotification({
    required String otp,
    String title = '🔐 Rider OTP Verification Code',
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'rider_otp_channel',
        'Rider OTP Notifications',
        channelDescription: 'Notifications for receiving Rider OTP verification codes',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );

      final int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: 'Your verification code is $otp. Enter this code to sign in to GoGovernment Rider App.',
        notificationDetails: notificationDetails,
        payload: otp,
      );
    } catch (e) {
      debugPrint('[NotificationService] Error showing OTP notification: $e');
    }
  }

  /// Show high-priority Order Alert notification with sound and heads-up display
  static Future<void> showOrderAlert({
    required String orderId,
    required String storeName,
    required String dropAddress,
    required String fee,
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'rider_order_alerts_v2',
        'Order Alerts',
        channelDescription: 'Heads-up alerts for incoming delivery orders',
        importance: Importance.max,
        priority: Priority.max,
        fullScreenIntent: true,
        category: AndroidNotificationCategory.call,
        audioAttributesUsage: AudioAttributesUsage.notification,
        sound: RawResourceAndroidNotificationSound('alert'),
        playSound: true,
        enableVibration: true,
        enableLights: true,
      );

      const NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'alert.wav',
        ),
      );

      final int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await _notificationsPlugin.show(
        id: id,
        title: '🚨 New Delivery Order Available (₹$fee)',
        body: 'Pick up from $storeName → Deliver to $dropAddress',
        notificationDetails: notificationDetails,
        payload: orderId,
      );
    } catch (e) {
      debugPrint('[NotificationService] Error showing order alert: $e');
    }
  }
}
