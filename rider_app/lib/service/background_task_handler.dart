import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart'
    hide NotificationVisibility; // avoid clash with flutter_foreground_task
import 'package:socket_io_client/socket_io_client.dart' as io;

/// Top-level callback — required by flutter_foreground_task.
/// Must be annotated with @pragma('vm:entry-point').
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(RiderBackgroundTaskHandler());
}

/// Runs inside the Android Foreground Service isolate.
/// Maintains a dedicated socket connection independent of the UI isolate.
/// Sends periodic isOnline=true GPS pings to keep rider ONLINE on server.
class RiderBackgroundTaskHandler extends TaskHandler {
  io.Socket? _socket;
  String _riderId = 'rider_bg';
  String _serverUrl = 'http://192.168.1.11:5000';
  double _lastLat = 0;
  double _lastLng = 0;
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'rider_order_alerts_v2';
  static const String _channelName = 'Order Alerts';
  static int _notificationId = 1000;

  // ─── Lifecycle ────────────────────────────────────────────────────────────

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Read dynamic rider ID and server URL saved by main isolate
    final savedId = await FlutterForegroundTask.getData<String>(key: 'riderId');
    if (savedId != null && savedId.isNotEmpty) {
      _riderId = savedId;
    }
    final savedUrl = await FlutterForegroundTask.getData<String>(key: 'serverUrl');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _serverUrl = savedUrl;
    }
    final savedLat = await FlutterForegroundTask.getData<double>(key: 'lastLat');
    if (savedLat != null && savedLat != 0) _lastLat = savedLat;
    final savedLng = await FlutterForegroundTask.getData<double>(key: 'lastLng');
    if (savedLng != null && savedLng != 0) _lastLng = savedLng;

    await _initNotifications();
    _connectBackgroundSocket();
  }

  /// Called every 15 seconds by the Foreground Service.
  /// Keeps rider marked ONLINE on server with last-known coordinates while app is in background.
  @override
  void onRepeatEvent(DateTime timestamp) {
    FlutterForegroundTask.getData<double>(key: 'lastLat').then((lat) {
      if (lat != null && lat != 0) _lastLat = lat;
    });
    FlutterForegroundTask.getData<double>(key: 'lastLng').then((lng) {
      if (lng != null && lng != 0) _lastLng = lng;
    });
    FlutterForegroundTask.getData<String>(key: 'riderId').then((id) {
      if (id != null && id.isNotEmpty && id != _riderId) {
        _riderId = id;
        _socket?.emit('join:rider', _riderId);
      }
    });
    FlutterForegroundTask.getData<String>(key: 'serverUrl').then((url) {
      if (url != null && url.isNotEmpty) _serverUrl = url;
    });

    if (_socket != null && _socket!.connected) {
      // Send keepalive ping with real/last coordinates so nearest-rider calculations succeed
      _socket?.emit('rider:location_ping', {
        'riderId': _riderId,
        'lat': _lastLat,
        'lng': _lastLng,
        'isOnline': true,
        'bgPing': true,
      });
    } else {
      // Socket dropped — reconnect
      _connectBackgroundSocket();
    }
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Send final offline ping before service stops
    if (_socket != null && _socket!.connected) {
      _socket?.emit('rider:location_ping', {
        'riderId': _riderId,
        'lat': 0,
        'lng': 0,
        'isOnline': false,
      });
    }
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
  }

  // ─── Local Notifications Init ─────────────────────────────────────────────

  Future<void> _initNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notificationsPlugin.initialize(settings: initSettings);

    // Create high-importance notification channel with custom alert.wav sound
    const androidChannel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: 'Alerts for new delivery order assignments',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('alert'),
      playSound: true,
      enableVibration: true,
      enableLights: true,
      audioAttributesUsage: AudioAttributesUsage.notification,
    );
    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  String? _lastNotifiedOrderId;
  int _lastNotifiedTime = 0;

  // ─── Background Socket ────────────────────────────────────────────────────

  void _connectBackgroundSocket() {
    try {
      _socket = io.io(
        _serverUrl,
        io.OptionBuilder()
            .setTransports(['websocket', 'polling'])
            .enableAutoConnect()
            .enableReconnection()
            .setReconnectionDelay(2000)
            .setReconnectionAttempts(99)
            .build(),
      );

      _socket?.onConnect((_) {
        // Join riders room with the REAL rider ID
        _socket?.emit('join:rider', _riderId);

        // Immediately send an online ping on reconnect
        _socket?.emit('rider:location_ping', {
          'riderId': _riderId,
          'lat': _lastLat,
          'lng': _lastLng,
          'isOnline': true,
          'bgPing': true,
        });
      });

      // Listen for targeted dispatch events (Alarm + Auto-launch)
      _socket?.on('order:dispatch', (data) {
        if (data is Map) {
          _showOrderNotification(Map<String, dynamic>.from(data));
        }
      });

      // Listen for general available order events (Only refresh feed, NO duplicate alarm)
      _socket?.on('order:available', (data) {
        if (data is Map) {
          try {
            FlutterForegroundTask.sendDataToMain({
              'type': 'available_feed_refresh',
              ...Map<String, dynamic>.from(data),
            });
          } catch (_) {}
        }
      });

      _socket?.connect();
    } catch (_) {
      // Background isolate — silently swallow exceptions
    }
  }

  // ─── Show Heads-Up Notification & Auto-Launch App ─────────────────────────

  Future<void> _showOrderNotification(Map<String, dynamic> data) async {
    // Ignore completed, delivered, or cancelled orders
    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status == 'delivered' || status == 'cancelled' || status == 'completed') {
      return;
    }

    final orderId = data['orderId']?.toString() ?? '';
    final now = DateTime.now().millisecondsSinceEpoch;
    // Deduplication check: ignore if the exact same order was notified within the last 25 seconds
    if (orderId.isNotEmpty && _lastNotifiedOrderId == orderId && (now - _lastNotifiedTime < 25000)) {
      return;
    }
    _lastNotifiedOrderId = orderId;
    _lastNotifiedTime = now;

    // 1. Programmatically wake screen and bring the Rider App to foreground immediately
    try {
      FlutterForegroundTask.wakeUpScreen();
      FlutterForegroundTask.launchApp();
    } catch (e) {
      debugPrint("Failed to open app: $e");
    }
    // 2. Also forward payload to main isolate in case app UI is active
    try {
      FlutterForegroundTask.sendDataToMain(data);
    } catch (_) {}

    // 3. Show high-priority heads-up notification with sound and full screen intent
    final storeName = data['storeName']?.toString() ?? 'Store';
    final dropAddress = data['dropAddress']?.toString() ?? 'Customer Location';
    final deliveryFee = data['deliveryFee']?.toString() ?? '';
    final feeText = deliveryFee.isNotEmpty ? ' • ₹$deliveryFee' : '';

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: 'Alerts for new delivery order assignments',
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      audioAttributesUsage: AudioAttributesUsage.notification,
      sound: const RawResourceAndroidNotificationSound('alert'),
      playSound: true,
      enableVibration: true,
      fullScreenIntent: true,
      ticker: 'New delivery order available!',
      styleInformation: BigTextStyleInformation(
        '📍 Pickup: $storeName\n🏠 Drop: $dropAddress$feeText'
        '\n\nTap to open and accept the order.',
      ),
    );

    await _notificationsPlugin.show(
      id: _notificationId++,
      title: '🚨 New Delivery Order!',
      body: 'Pickup: $storeName → $dropAddress$feeText',
      notificationDetails: NotificationDetails(android: androidDetails),
    );
  }
}
