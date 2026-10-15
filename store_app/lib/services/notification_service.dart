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

      // Request notification permission and register high-priority channels for Android
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();

        // 1. High-priority store order alerts channel
        const AndroidNotificationChannel storeOrderChannel =
            AndroidNotificationChannel(
          'store_order_alerts',
          'Store Order Alerts',
          description: 'High-priority notifications for new store orders',
          importance: Importance.max,
          playSound: true,
          enableVibration: true,
          enableLights: true,
        );
        await androidPlugin.createNotificationChannel(storeOrderChannel);

        // 2. OTP notifications channel
        const AndroidNotificationChannel otpChannel =
            AndroidNotificationChannel(
          'otp_channel',
          'OTP Notifications',
          description: 'Notifications for receiving OTP verification codes',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
        );
        await androidPlugin.createNotificationChannel(otpChannel);
      }

      _isInitialized = true;
      debugPrint('[NotificationService] Initialized and channels registered successfully');
    } catch (e) {
      debugPrint('[NotificationService] Initialization error: $e');
    }
  }

  /// Show a local push notification displaying the OTP code
  static Future<void> showOtpNotification({
    required String otp,
    String title = '🔐 Your OTP Verification Code',
  }) async {
    try {
      if (!_isInitialized) {
        await initialize();
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'otp_channel',
        'OTP Notifications',
        channelDescription: 'Notifications for receiving OTP verification codes',
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

      // Unique ID so each OTP pops up cleanly
      final int id = DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: 'Your verification code is $otp. Enter this code in the GoGovernment Store App to continue.',
        notificationDetails: notificationDetails,
        payload: otp,
      );
      debugPrint('[NotificationService] Displayed OTP Notification: $otp');
    } catch (e) {
      debugPrint('[NotificationService] Error showing OTP notification: $e');
    }
  }

  static final Map<String, int> _lastOrderNotifiedMap = {};

  /// Show incoming new order notification with sound
  static Future<void> showNewOrderNotification({
    required String orderId,
    String title = '🔔 New Order Received!',
    String body = 'A new customer order has been placed. Tap to view orders.',
  }) async {
    try {
      if (orderId.isNotEmpty) {
        final now = DateTime.now().millisecondsSinceEpoch;
        final lastTime = _lastOrderNotifiedMap[orderId] ?? 0;
        if (now - lastTime < 15000) {
          debugPrint('[NotificationService] Suppressing duplicate notification for order #$orderId');
          return;
        }
        _lastOrderNotifiedMap[orderId] = now;
      }

      if (!_isInitialized) {
        await initialize();
      }

      const AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        'store_order_alerts',
        'Store Order Alerts',
        channelDescription: 'High-priority notifications for new store orders',
        importance: Importance.max,
        priority: Priority.max,
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

      final int id = orderId.isNotEmpty
          ? orderId.hashCode.abs().remainder(100000)
          : DateTime.now().millisecondsSinceEpoch.remainder(100000);

      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: orderId,
      );
    } catch (e) {
      debugPrint('[NotificationService] Error showing order notification: $e');
    }
  }
}
