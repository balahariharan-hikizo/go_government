import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:rider_app/network/api_client.dart';
import '../../bloc/delivery/delivery_bloc.dart';
import '../../bloc/delivery/delivery_event.dart';
import '../../bloc/delivery/delivery_state.dart';
import '../../constants/route_constants.dart';
import '../../hive/hive_service.dart';
import '../../model/delivery_order_model.dart';
import '../../network/rider_api_service.dart';
import '../../service/socket_service.dart';
import '../../service/background_task_handler.dart';
import '../../utils/app_colors.dart';
import '../../utils/navigation_launcher.dart';
import '../../utils/responsive_helper.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../widget/available_order_card.dart';
import '../../widget/common_background.dart';
import '../../widget/custom_text.dart';
import '../../widget/rider_bottom_nav_bar.dart';

class RiderDashboardScreen extends StatefulWidget {
  const RiderDashboardScreen({super.key});

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen>
    with WidgetsBindingObserver {
  StreamSubscription? _availableSub;
  StreamSubscription? _statusSub;
  StreamSubscription? _assignedSub;
  StreamSubscription? _dispatchSub;
  StreamSubscription? _dispatchCancelledSub;
  StreamSubscription<ServiceStatus>? _gpsStatusSub;
  Timer? _gpsPingTimer;
  final Set<String> _acceptingOrderIds = {};
  final AudioPlayer _audioPlayer = AudioPlayer();
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  bool _isPlayingSound = false;
  String? _activeDispatchModalOrderId;
  double _cachedLat = 0;
  double _cachedLng = 0;
  String? _lastNotifiedOrderId;
  int _lastNotifiedTime = 0;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Rider returned to app — verify GPS is still enabled before resuming/syncing
      _checkAndEnforceGpsRequirement().then((hasGps) {
        if (hasGps && HiveService.isOnline) {
          if (mounted) {
            context.read<DeliveryBloc>().add(LoadDeliveriesEvent());
          }
          RiderSocketService().init();
          _sendGpsPing();
        }
      });
    } else if (state == AppLifecycleState.detached) {
      // Rider app closed / killed by user -> Turn OFFLINE immediately
      HiveService.setIsOnline(false);
      RiderSocketService().sendGpsPing(0, 0, false);
      RiderSocketService().dispose();
      FlutterForegroundTask.stopService();
    }
  }

  Future<void> _playAlertSound() async {
    if (_isPlayingSound) return;
    _isPlayingSound = true;
    try {
      await _audioPlayer.setAudioContext(
        AudioContext(
          android: AudioContextAndroid(
            isSpeakerphoneOn: true,
            stayAwake: true,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.notification,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play(AssetSource('sound/alert.wav'));
    } catch (_) {
      try {
        await _audioPlayer.play(AssetSource('assets/sound/alert.wav'));
      } catch (_) {}
    }
  }

  Future<void> _stopAlertSound() async {
    if (!_isPlayingSound) return;
    _isPlayingSound = false;
    try {
      await _audioPlayer.stop();
    } catch (_) {}
  }

  Future<void> _syncRealRiderProfile() async {
    final userId = HiveService.userId;
    if (userId.isEmpty) return;
    final profile = await RiderApiService.fetchRiderProfile(userId);
    if (profile != null && mounted) {
      final name = profile['userName']?.toString();
      final phone = profile['phone']?.toString();
      final vType = profile['vehicleType']?.toString();
      final vNum = profile['vehicleNumber']?.toString();
      if (name != null && name.isNotEmpty) await HiveService.setUserName(name);
      if (phone != null && phone.isNotEmpty) await HiveService.setUserPhone(phone);
      if (vType != null && vType.isNotEmpty) await HiveService.setVehicleType(vType);
      if (vNum != null && vNum.isNotEmpty) await HiveService.setVehicleNumber(vNum);
      setState(() {});
    }
  }

  void _startGpsPings() {
    _gpsPingTimer?.cancel();
    _sendGpsPing();
    _gpsPingTimer = Timer.periodic(const Duration(seconds: 20), (_) => _sendGpsPing());
  }

  Future<void> _sendGpsPing() async {
    if (!HiveService.isOnline) return;

    // Guard: Verify system GPS is still enabled before pinging
    final isGpsOn = await Geolocator.isLocationServiceEnabled();
    if (!isGpsOn) {
      await _forceGoOffline(
        reason: 'GPS Location was turned OFF. You are now OFFLINE.',
        showBanner: true,
      );
      return;
    }

    try {
      // 1. Try instant last-known cached position from OS first
      Position? pos = await Geolocator.getLastKnownPosition();

      // 2. If null, request fresh position with 10s timeout
      pos ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );

      if (pos.latitude != 0 && pos.longitude != 0) {
        _cachedLat = pos.latitude;
        _cachedLng = pos.longitude;
      }
    } catch (e) {
      debugPrint('⚠️ [RiderDashboard] GPS fix fetch error: $e');
    }

    // 3. Emit position (use cached real coordinates, never wipe to 0.0 if already known)
    if (_cachedLat != 0 && _cachedLng != 0) {
      RiderSocketService().sendGpsPing(_cachedLat, _cachedLng, true);
      FlutterForegroundTask.saveData(key: 'lastLat', value: _cachedLat);
      FlutterForegroundTask.saveData(key: 'lastLng', value: _cachedLng);
    } else {
      // If OS has never returned a location fix yet, only ping if online
      if (HiveService.isOnline) {
        RiderSocketService().sendGpsPing(0, 0, true);
      }
    }
  }

  Future<void> _forceGoOffline({required String reason, bool showBanner = true}) async {
    debugPrint('🛑 [RiderDashboard] Forcing OFFLINE: $reason');
    await HiveService.setIsOnline(false);
    if (mounted) {
      context.read<DeliveryBloc>().add(const ToggleDutyEvent(false));
    }
    _gpsPingTimer?.cancel();
    RiderSocketService().sendGpsPing(0, 0, false);
    await _stopForegroundService();

    if (showBanner && mounted) {
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              const Icon(Icons.location_off_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  reason,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'TURN ON',
            textColor: Colors.white,
            onPressed: () {
              Geolocator.openLocationSettings();
            },
          ),
        ),
      );
    }
  }

  Future<bool> _checkAndEnforceGpsRequirement({bool showNotification = true}) async {
    try {
      final isGpsOn = await Geolocator.isLocationServiceEnabled();
      if (!isGpsOn) {
        if (HiveService.isOnline) {
          await _forceGoOffline(
            reason: 'GPS Location is turned OFF. You are OFFLINE.',
            showBanner: showNotification,
          );
        }
        return false;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (HiveService.isOnline) {
          await _forceGoOffline(
            reason: 'Location permission missing. You are OFFLINE.',
            showBanner: showNotification,
          );
        }
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('⚠️ [RiderDashboard] GPS requirement check error: $e');
      return false;
    }
  }

  Future<void> _handleToggleOnline(bool targetOnline) async {
    if (targetOnline) {
      // 1. Check if location services are enabled
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        _showLocationDialog(
          title: 'GPS Location Disabled',
          content: 'GPS / Location services are required to go online and receive delivery order alerts nearby. Please turn on GPS on your device.',
          isAppSettings: false,
        );
        return;
      }

      // 2. Check location permission
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        _showLocationDialog(
          title: 'Location Permission Required',
          content: 'Location permission is mandatory to go online and take delivery orders. Please grant location access in App Settings.',
          isAppSettings: true,
        );
        return;
      }

      // 3. Acquire location fix (try fast cached fix first, then fresh fix)
      try {
        Position? pos = await Geolocator.getLastKnownPosition();
        pos ??= await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
            timeLimit: Duration(seconds: 10),
          ),
        );

        if (pos.latitude != 0 && pos.longitude != 0) {
          _cachedLat = pos.latitude;
          _cachedLng = pos.longitude;
        }

        await HiveService.setIsOnline(true);
        if (!mounted) return;
        context.read<DeliveryBloc>().add(const ToggleDutyEvent(true));
        RiderSocketService().sendGpsPing(_cachedLat, _cachedLng, true);
        _startGpsPings();
        // Start foreground service with real coordinates so background socket stays alive
        await _startForegroundService(lat: _cachedLat, lng: _cachedLng);
      } catch (e) {
        if (_cachedLat != 0 && _cachedLng != 0) {
          await HiveService.setIsOnline(true);
          if (!mounted) return;
          context.read<DeliveryBloc>().add(const ToggleDutyEvent(true));
          RiderSocketService().sendGpsPing(_cachedLat, _cachedLng, true);
          _startGpsPings();
          await _startForegroundService(lat: _cachedLat, lng: _cachedLng);
          return;
        }
        if (!mounted) return;
        _showLocationDialog(
          title: 'Unable to Get GPS Signal',
          content: 'Could not fetch your location signal. Please ensure you have clear GPS signal to go online.',
        );
      }
    } else {
      // Turn OFFLINE
      await _forceGoOffline(reason: 'You are now OFFLINE', showBanner: false);
    }
  }

  void _showLocationDialog({
    required String title,
    required String content,
    bool isAppSettings = false,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.location_off_rounded, color: AppColors.error),
            const SizedBox(width: 10),
            Expanded(child: CustomText.title(title, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: CustomText.body(content, fontSize: 13),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: AppColors.grayFont)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              if (isAppSettings) {
                Geolocator.openAppSettings();
              } else {
                Geolocator.openLocationSettings();
              }
            },
            child: Text(
              isAppSettings ? 'Open Settings' : 'Turn On GPS',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAcceptOrder(DeliveryOrder order) async {
    if (_acceptingOrderIds.contains(order.orderId)) return;

    setState(() {
      _acceptingOrderIds.add(order.orderId);
    });

    final riderId = HiveService.userId;
    final riderName = HiveService.userName.isNotEmpty ? HiveService.userName : 'Express Rider';
    final riderPhone = HiveService.userPhone;
    final vehicleNumber = HiveService.vehicleNumber.isNotEmpty ? HiveService.vehicleNumber : 'KA-01-EE-4521';

    try {
      final res = await RiderApiService.acceptOrder(
        orderId: order.orderId,
        riderId: riderId,
        riderName: riderName,
        riderPhone: riderPhone,
        vehicleNumber: vehicleNumber,
      );

      if (!mounted) return;

      if (res['success'] == true) {
        _stopAlertSound();
        _localNotifications.cancel(id: 2001);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Accepted Order #${order.orderId}! Navigate to store for pickup.'),
            backgroundColor: AppColors.success,
          ),
        );
        context.read<DeliveryBloc>().add(LoadDeliveriesEvent());
      } else if (res['alreadyAccepted'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? '⚠️ Order was already claimed by another delivery partner.'),
            backgroundColor: AppColors.warning,
            duration: const Duration(seconds: 4),
          ),
        );
        // Refresh deliveries to remove the claimed order from this rider's screen
        context.read<DeliveryBloc>().add(LoadDeliveriesEvent());
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(res['message'] ?? 'Failed to accept order. Please try again.'),
            backgroundColor: AppColors.error,
          ),
        );
        context.read<DeliveryBloc>().add(LoadDeliveriesEvent());
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error accepting delivery: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _acceptingOrderIds.remove(order.orderId);
        });
      }
    }
  }

  // ─── Foreground Task Setup ──────────────────────────────────────────────

  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'rider_duty_channel',
        channelName: 'Rider Duty Status',
        channelDescription: 'Shows when rider is on duty and listening for orders',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(15000), // ping every 15s
        autoRunOnBoot: false,
        allowWakeLock: true,
      ),
    );
  }

  Future<void> _startForegroundService({double? lat, double? lng}) async {
    await FlutterForegroundTask.requestNotificationPermission();

    // 1. Request Ignore Battery Optimization so Android never puts socket to sleep (prompt once)
    try {
      final isIgnoring = await FlutterForegroundTask.isIgnoringBatteryOptimizations;
      final alreadyRequested = HiveService.hasRequestedBatteryOptimization;
      if (!isIgnoring && !alreadyRequested) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
        await HiveService.setRequestedBatteryOptimization(true);
      }
    } catch (_) {}

    // 2. Check and prompt for "Display over other apps" (SYSTEM_ALERT_WINDOW) for auto-opening
    try {
      final canDraw = await FlutterForegroundTask.canDrawOverlays;
      if (!canDraw && mounted) {
        _showAutoOpenPermissionDialog();
      }
    } catch (_) {}

    // 3. Save real rider ID so background isolate can read it
    final riderId = HiveService.userId.isNotEmpty
        ? HiveService.userId
        : HiveService.userPhone;
    await FlutterForegroundTask.saveData(key: 'riderId', value: riderId);

    // 4. Save dynamic server URL (without /api)
    String cleanUrl = ApiClient.baseUrl.replaceAll('/api', '');
    if (cleanUrl.endsWith('/')) cleanUrl = cleanUrl.substring(0, cleanUrl.length - 1);
    await FlutterForegroundTask.saveData(key: 'serverUrl', value: cleanUrl);

    // 5. Save coordinates
    if (lat != null && lng != null) {
      await FlutterForegroundTask.saveData(key: 'lastLat', value: lat);
      await FlutterForegroundTask.saveData(key: 'lastLng', value: lng);
    }

    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.restartService();
      return;
    }
    await FlutterForegroundTask.startService(
      serviceId: 1001,
      notificationTitle: '🟢 GoGovernment — On Duty',
      notificationText: 'Listening for nearby delivery orders...',
      callback: startCallback,
    );
  }

  void _showAutoOpenPermissionDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.open_in_new_rounded, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Auto-Open New Orders',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'Allow "Display over other apps" so GoGovernment can automatically pop up order alerts on your screen while navigating in Google Maps or using other apps.\n\n(On Vivo/Xiaomi: Also enable "Display pop-up window while running in background")',
          style: TextStyle(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later', style: TextStyle(color: AppColors.grayFont)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              try {
                const MethodChannel('com.hikizo.goGovernment_riderapp/app_launcher')
                    .invokeMethod('openOverlaySettings');
              } catch (_) {
                FlutterForegroundTask.openSystemAlertWindowSettings();
              }
            },
            child: const Text(
              'Enable',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _stopForegroundService() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
  }

  // ─── Local Notifications Init ───────────────────────────────────────────

  Future<void> _initLocalNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (details) {
        try {
          const MethodChannel('com.hikizo.goGovernment_riderapp/app_launcher')
              .invokeMethod('bringAppToFront');
        } catch (_) {}
      },
    );
    // Create the high-priority order alert channel
    const channel = AndroidNotificationChannel(
      'rider_order_alerts_v2',
      'Order Alerts',
      description: 'Heads-up alerts for incoming delivery orders',
      importance: Importance.max,
      sound: RawResourceAndroidNotificationSound('alert'),
      playSound: true,
      enableVibration: true,
      enableLights: true,
      audioAttributesUsage: AudioAttributesUsage.notification,
    );
    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(channel);
    await androidPlugin?.requestNotificationsPermission();
  }

  // ─── Firebase Cloud Messaging (FCM) Init ─────────────────────────────────

  Future<void> _initFCM() async {
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('🔔 [FCM Rider] Permission status: ${settings.authorizationStatus}');

      final token = await messaging.getToken();
      debugPrint('📱 [FCM Rider] Device token: $token');
      if (token != null && token.isNotEmpty) {
        await RiderApiService.updateFcmToken(
          userId: HiveService.userId,
          phone: HiveService.userPhone,
          fcmToken: token,
        );
      }

      messaging.onTokenRefresh.listen((newToken) async {
        debugPrint('🔄 [FCM Rider] Token refreshed: $newToken');
        await RiderApiService.updateFcmToken(
          userId: HiveService.userId,
          phone: HiveService.userPhone,
          fcmToken: newToken,
        );
      });

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('📩 [FCM Foreground Rider]: ${message.data}');
        if (message.data['type'] == 'order_dispatch' && mounted) {
          _handleIncomingDispatchOrder(Map<String, dynamic>.from(message.data));
        }
      });
    } catch (e) {
      debugPrint('❌ [FCM Rider] Init error: $e');
    }
  }

  @override
  void initState() {
    super.initState();
    context.read<DeliveryBloc>().add(LoadDeliveriesEvent());

    // Listen for events from native System Alert Window Overlay
    const MethodChannel('com.hikizo.goGovernment_riderapp/app_launcher')
        .setMethodCallHandler((call) async {
      if (call.method == 'onOrderAccepted') {
        final orderId = call.arguments?['orderId']?.toString() ?? '';
        if (orderId.isNotEmpty) {
          _stopAlertSound();
          _activeDispatchModalOrderId = null;
          final state = context.read<DeliveryBloc>().state;
          if (state is DeliveryLoaded) {
            final match = state.availableOrders.where((o) => o.orderId == orderId);
            if (match.isNotEmpty) {
              await _handleAcceptOrder(match.first);
            }
          }
        }
      } else if (call.method == 'onOrderDeclined' || call.method == 'onOrderTimedOut') {
        _stopAlertSound();
        _activeDispatchModalOrderId = null;
      }
    });

    // Init foreground task config & local notification channel
    _initForegroundTask();
    _initLocalNotifications();
    _initFCM();

    // Connect to real-time WebSocket events & sync backend rider profile
    RiderSocketService().init();
    _syncRealRiderProfile();

    // Listen for real-time changes to the device location service (GPS toggle)
    _gpsStatusSub = Geolocator.getServiceStatusStream().listen((ServiceStatus status) {
      if (status == ServiceStatus.disabled) {
        _forceGoOffline(
          reason: 'Device GPS was turned OFF. You are now OFFLINE.',
          showBanner: true,
        );
      }
    });

    // Verify system GPS is enabled before allowing/resuming any online status
    _checkAndEnforceGpsRequirement(showNotification: false).then((hasGps) {
      if (hasGps && HiveService.isOnline) {
        _startGpsPings();
        _startForegroundService();
      } else {
        _forceGoOffline(
          reason: 'Device GPS is OFF. You are OFFLINE.',
          showBanner: false,
        );
      }
    });

    _availableSub = RiderSocketService().onOrderAvailable.listen((_) {
      if (mounted) {
        context.read<DeliveryBloc>().add(LoadDeliveriesEvent());
      }
    });
    _statusSub = RiderSocketService().onOrderStatusUpdate.listen((_) {
      if (mounted) {
        context.read<DeliveryBloc>().add(LoadDeliveriesEvent());
      }
    });
    _assignedSub = RiderSocketService().onOrderAssigned.listen((_) {
      if (mounted) {
        context.read<DeliveryBloc>().add(LoadDeliveriesEvent());
      }
    });

    // Targeted 30-second dispatch alert
    _dispatchSub = RiderSocketService().onOrderDispatch.listen((data) {
      if (mounted) {
        context.read<DeliveryBloc>().add(LoadDeliveriesEvent());
        _handleIncomingDispatchOrder(data);
      }
    });

    // Refresh when dispatch is cancelled / claimed by another rider
    _dispatchCancelledSub = RiderSocketService().onOrderDispatchCancelled.listen((data) {
      if (mounted) {
        context.read<DeliveryBloc>().add(LoadDeliveriesEvent());
        final cancelledId = data['orderId']?.toString();
        if (_activeDispatchModalOrderId != null && _activeDispatchModalOrderId == cancelledId) {
          _dismissDispatchModal();
        }
      }
    });

    // Register Background Task communication port listener
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    // Register App Lifecycle Observer
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    _dismissDispatchModal();
    _stopAlertSound();
    _availableSub?.cancel();
    _statusSub?.cancel();
    _assignedSub?.cancel();
    _dispatchSub?.cancel();
    _dispatchCancelledSub?.cancel();
    _gpsPingTimer?.cancel();
    _gpsStatusSub?.cancel();
    super.dispose();
  }

  void _onReceiveTaskData(Object data) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      if (mounted) {
        if (!HiveService.isLoggedIn || !HiveService.isOnline) return;
        context.read<DeliveryBloc>().add(LoadDeliveriesEvent());
        // If it's only a feed refresh notification, don't trigger modal or extra sound
        if (map['type'] == 'available_feed_refresh') {
          return;
        }
        _handleIncomingDispatchOrder(map);
      }
    }
  }

  void _handleIncomingDispatchOrder(Map<String, dynamic> data) {
    if (!HiveService.isLoggedIn || !HiveService.isOnline) return;

    // Suppress dispatch alerts if rider is already busy delivering an order
    try {
      final deliveryState = context.read<DeliveryBloc>().state;
      if (deliveryState is DeliveryLoaded && deliveryState.activeOrders.isNotEmpty) {
        debugPrint('🛑 [Dispatch Alert] Suppressed: Rider is currently busy with active delivery.');
        return;
      }
    } catch (_) {}

    try {
      final order = DeliveryOrder.fromJson(data);
      if (order.orderId.isEmpty) return;

      // Ignore orders that are already completed, delivered, or cancelled
      final status = order.status.toLowerCase();
      if (status == 'delivered' || status == 'cancelled' || status == 'completed') {
        if (_activeDispatchModalOrderId == order.orderId) {
          _dismissDispatchModal();
        }
        return;
      }

      if (_activeDispatchModalOrderId == order.orderId) return; // already displayed

      // 1. Wake up the device screen and launch app via Foreground Task immediately
      try {
        FlutterForegroundTask.wakeUpScreen();
        FlutterForegroundTask.launchApp();
      } catch (e) {
        debugPrint("Failed to open app: $e");
      }

      // 2. Bring app to foreground via native Android Intent & WindowManager
      try {
        const MethodChannel('com.hikizo.goGovernment_riderapp/app_launcher')
            .invokeMethod('bringAppToFront');
      } catch (_) {}

      // 3. Native dark overlay disabled — only the clean interactive 30s countdown bottom sheet is displayed!
      /*
      try {
        final storeName = order.storeName.isNotEmpty ? order.storeName : (data['storeName']?.toString() ?? 'Store');
        final dropAddress = order.dropAddress.isNotEmpty ? order.dropAddress : (data['dropAddress']?.toString() ?? 'Customer Location');
        final fee = order.deliveryCharge > 0
            ? order.deliveryCharge.toStringAsFixed(0)
            : (data['deliveryFee'] != null ? data['deliveryFee'].toString() : '0');
        const MethodChannel('com.hikizo.goGovernment_riderapp/app_launcher').invokeMethod('showOrderOverlay', {
          'orderId': order.orderId,
          'storeName': storeName,
          'dropAddress': dropAddress,
          'fee': fee,
          'countdownSecs': (data['countdownSecs'] as num?)?.toInt() ?? 30,
        });
      } catch (_) {}
      */

      // 4. Post high-priority heads-up notification with sound & fullScreenIntent
      _showIncomingOrderNotification(order, data);

      // 5. Show interactive 30s countdown modal
      _showDispatchOrderModal(order, (data['countdownSecs'] as num?)?.toInt() ?? 30);
    } catch (_) {}
  }

  Future<void> _showIncomingOrderNotification(DeliveryOrder order, Map<String, dynamic> data) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      if (order.orderId.isNotEmpty &&
          _lastNotifiedOrderId == order.orderId &&
          (now - _lastNotifiedTime < 25000)) {
        return; // Prevent duplicate notifications within 25 seconds
      }
      _lastNotifiedOrderId = order.orderId;
      _lastNotifiedTime = now;

      final storeName = order.storeName.isNotEmpty ? order.storeName : (data['storeName']?.toString() ?? 'Store');
      final dropAddress = order.dropAddress.isNotEmpty ? order.dropAddress : (data['dropAddress']?.toString() ?? 'Customer Location');
      final charge = order.deliveryCharge > 0
          ? ' • ₹${order.deliveryCharge.toStringAsFixed(0)}'
          : (data['deliveryFee'] != null ? ' • ₹${data['deliveryFee']}' : '');

      final androidDetails = AndroidNotificationDetails(
        'rider_order_alerts_v2',
        'Order Alerts',
        channelDescription: 'Heads-up alerts for incoming delivery orders',
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
          '📍 Pickup: $storeName\n🏠 Drop: $dropAddress$charge\n\nTap to open and accept the order.',
        ),
      );

      await _localNotifications.show(
        id: 2001,
        title: '🚨 New Delivery Order!',
        body: 'Pickup: $storeName → $dropAddress$charge',
        notificationDetails: NotificationDetails(android: androidDetails),
      );
    } catch (e) {
      debugPrint('⚠️ [RiderDashboard] Error showing order notification: $e');
    }
  }

  void _dismissDispatchModal() {
    if (_activeDispatchModalOrderId != null && Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    _activeDispatchModalOrderId = null;
    _stopAlertSound();
    _localNotifications.cancel(id: 2001);
  }

  void _showDispatchOrderModal(DeliveryOrder order, int initialSeconds) {
    _activeDispatchModalOrderId = order.orderId;
    _playAlertSound();

    int remainingSeconds = initialSeconds > 0 ? initialSeconds : 30;

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            Timer? timer;
            timer ??= Timer.periodic(const Duration(seconds: 1), (t) {
              if (!ctx.mounted || _activeDispatchModalOrderId != order.orderId) {
                t.cancel();
                return;
              }
              if (remainingSeconds > 1) {
                setModalState(() {
                  remainingSeconds--;
                });
              } else {
                t.cancel();
                if (ctx.mounted && Navigator.canPop(ctx)) {
                  Navigator.pop(ctx);
                }
                _activeDispatchModalOrderId = null;
                _stopAlertSound();
              }
            });

            return Container(
              padding: EdgeInsets.symmetric(horizontal: Responsive.w(20), vertical: Responsive.h(20)),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 20, spreadRadius: 4),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header badge & timer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: Responsive.w(12), vertical: Responsive.h(6)),
                        decoration: BoxDecoration(
                          color: AppColors.error.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.flash_on_rounded, color: AppColors.error, size: 18),
                            SizedBox(width: Responsive.w(4)),
                            CustomText.caption(
                              'NEW ORDER ALERT',
                              color: AppColors.error,
                              fontWeight: FontWeight.bold,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: Responsive.w(12), vertical: Responsive.h(6)),
                        decoration: BoxDecoration(
                          color: remainingSeconds <= 10
                              ? AppColors.error.withOpacity(0.15)
                              : AppColors.primary.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer_outlined,
                              size: 16,
                              color: remainingSeconds <= 10 ? AppColors.error : AppColors.primary,
                            ),
                            SizedBox(width: Responsive.w(4)),
                            CustomText.caption(
                              '${remainingSeconds}s',
                              fontWeight: FontWeight.bold,
                              color: remainingSeconds <= 10 ? AppColors.error : AppColors.primary,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Responsive.h(16)),

                  // Order & Earnings summary
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CustomText.title('Order #${order.orderId}', fontSize: Responsive.sp(18)),
                          SizedBox(height: Responsive.h(2)),
                          CustomText.caption(
                            '${order.items.length} Items · ${order.paymentMethod.toUpperCase()}',
                            color: AppColors.grayFont,
                          ),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: Responsive.w(12), vertical: Responsive.h(8)),
                        decoration: BoxDecoration(
                          color: AppColors.success.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            CustomText.caption('EARNINGS', fontSize: Responsive.sp(10), color: AppColors.success, fontWeight: FontWeight.bold),
                            CustomText.title(
                              '₹${order.estimatedPayout.toInt()}',
                              fontSize: Responsive.sp(16),
                              color: AppColors.success,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Responsive.h(16)),
                  const Divider(height: 1),
                  SizedBox(height: Responsive.h(14)),

                  // Store Pickup Info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.store_mall_directory_rounded, color: AppColors.primary, size: 20),
                      ),
                      SizedBox(width: Responsive.w(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomText.body('PICKUP STORE', fontSize: Responsive.sp(11), color: AppColors.grayFont, fontWeight: FontWeight.bold),
                            SizedBox(height: Responsive.h(2)),
                            CustomText.title(order.storeName.isNotEmpty ? order.storeName : 'Partner Store', fontSize: Responsive.sp(14)),
                            SizedBox(height: Responsive.h(2)),
                            CustomText.caption(order.storeAddress, color: AppColors.grayFont, maxLines: 2),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Responsive.h(14)),

                  // Customer Dropoff Info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.info.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on_rounded, color: AppColors.info, size: 20),
                      ),
                      SizedBox(width: Responsive.w(12)),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CustomText.body('DELIVERY DROP', fontSize: Responsive.sp(11), color: AppColors.grayFont, fontWeight: FontWeight.bold),
                            SizedBox(height: Responsive.h(2)),
                            CustomText.title(order.receiverName.isNotEmpty ? order.receiverName : 'Customer', fontSize: Responsive.sp(14)),
                            SizedBox(height: Responsive.h(2)),
                            CustomText.caption(order.dropAddress, color: AppColors.grayFont, maxLines: 2),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Responsive.h(20)),

                  // Buttons: Decline & Accept
                  Row(
                    children: [
                      Expanded(
                        flex: 1,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            padding: EdgeInsets.symmetric(vertical: Responsive.h(14)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: const BorderSide(color: AppColors.border),
                          ),
                          onPressed: () {
                            if (Navigator.canPop(modalCtx)) {
                              Navigator.pop(modalCtx);
                            }
                            _activeDispatchModalOrderId = null;
                            _stopAlertSound();
                          },
                          child: const Text('Decline', style: TextStyle(color: AppColors.grayFont, fontWeight: FontWeight.bold)),
                        ),
                      ),
                      SizedBox(width: Responsive.w(12)),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            padding: EdgeInsets.symmetric(vertical: Responsive.h(14)),
                            elevation: 4,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            if (Navigator.canPop(modalCtx)) {
                              Navigator.pop(modalCtx);
                            }
                            _activeDispatchModalOrderId = null;
                            _stopAlertSound();
                            await _handleAcceptOrder(order);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                              SizedBox(width: Responsive.w(6)),
                              const Text(
                                'ACCEPT ORDER',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: Responsive.h(10)),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      _activeDispatchModalOrderId = null;
      _stopAlertSound();
      try {
        const MethodChannel('com.hikizo.goGovernment_riderapp/app_launcher')
            .invokeMethod('dismissOrderOverlay');
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);

    return Scaffold(
      body: CommonBackground(
        child: SafeArea(
          child: BlocBuilder<DeliveryBloc, DeliveryState>(
            builder: (context, state) {
              final isOnline = state is DeliveryLoaded ? state.isOnline : HiveService.isOnline;
              final available = state is DeliveryLoaded ? state.availableOrders : <DeliveryOrder>[];
              final active = state is DeliveryLoaded ? state.activeOrders : <DeliveryOrder>[];
              final earnings = state is DeliveryLoaded ? state.totalEarnings : HiveService.totalEarnings;
              final completed = state is DeliveryLoaded ? state.completedOrders.length : HiveService.completedCount;

              if (active.isEmpty && available.isNotEmpty && isOnline) {
                _playAlertSound();
              } else {
                _stopAlertSound();
              }

              return RefreshIndicator(
                onRefresh: () async {
                  context.read<DeliveryBloc>().add(LoadDeliveriesEvent());
                },
                color: AppColors.primary,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.symmetric(horizontal: Responsive.w(18), vertical: Responsive.h(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      _buildHeader(context, isOnline),
                      SizedBox(height: Responsive.h(16)),

                      // Metrics Cards Row
                      _buildMetricsRow(earnings, completed, active.length),
                      SizedBox(height: Responsive.h(20)),

                      // Active Tasks section
                      if (active.isNotEmpty) ...[
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: AppColors.warning, shape: BoxShape.circle),
                            ),
                            SizedBox(width: Responsive.w(8)),
                            CustomText.title('Active Delivery In Progress', fontSize: Responsive.sp(16)),
                          ],
                        ),
                        SizedBox(height: Responsive.h(10)),
                        ...active.map((order) => _buildActiveOrderCard(context, order)),
                        SizedBox(height: Responsive.h(20)),
                      ],

                      // Available Deliveries Feed (Only shown when rider has NO active order)
                      if (active.isEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isOnline ? AppColors.success : AppColors.grayFont,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: Responsive.w(8)),
                                CustomText.title('Available Deliveries', fontSize: Responsive.sp(16)),
                              ],
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(horizontal: Responsive.w(10), vertical: Responsive.h(4)),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(Responsive.w(12)),
                              ),
                              child: CustomText.caption(
                                '${available.length} Nearby',
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: Responsive.h(12)),

                        if (!isOnline)
                          _buildOfflineNotice()
                        else if (available.isEmpty)
                          _buildNoOrdersState()
                        else
                          ...available.map(
                            (order) => AvailableOrderCard(
                              key: ValueKey(order.orderId),
                              order: order,
                              isAccepting: _acceptingOrderIds.contains(order.orderId),
                              onAccept: () => _handleAcceptOrder(order),
                              onExpired: () {
                                if (mounted) {
                                  context.read<DeliveryBloc>().add(LoadDeliveriesEvent());
                                }
                              },
                            ),
                          ),
                      ],

                      SizedBox(height: Responsive.h(30)),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      bottomNavigationBar: const RiderBottomNavBar(currentIndex: 0),
    );
  }

  // ----------------------------------------------------
  // Header Widget
  // ----------------------------------------------------
  Widget _buildHeader(BuildContext context, bool isOnline) {
    final riderName = HiveService.userName.isNotEmpty ? HiveService.userName : 'Rider Partner';

    return Container(
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(16)),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: Responsive.w(22),
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: const Icon(Icons.two_wheeler_rounded, color: AppColors.primary),
          ),
          SizedBox(width: Responsive.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CustomText.title(riderName, fontSize: Responsive.sp(16), fontWeight: FontWeight.bold),
                CustomText.caption(
                  '${HiveService.vehicleType} · ${HiveService.vehicleNumber}',
                  color: AppColors.grayFont,
                ),
              ],
            ),
          ),
          // Duty Toggle Button (Mandatory GPS check required to go online)
          GestureDetector(
            onTap: () => _handleToggleOnline(!isOnline),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: Responsive.w(12), vertical: Responsive.h(6)),
              decoration: BoxDecoration(
                color: isOnline ? AppColors.success.withOpacity(0.12) : AppColors.lightGray,
                borderRadius: BorderRadius.circular(Responsive.w(20)),
                border: Border.all(
                  color: isOnline ? AppColors.success : AppColors.grayFont,
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.power_settings_new_rounded,
                    size: 16,
                    color: isOnline ? AppColors.success : AppColors.grayFont,
                  ),
                  SizedBox(width: Responsive.w(6)),
                  Text(
                    isOnline ? 'ONLINE' : 'OFFLINE',
                    style: TextStyle(
                      fontSize: Responsive.sp(12),
                      fontWeight: FontWeight.bold,
                      color: isOnline ? AppColors.success : AppColors.grayFont,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // Metrics Row
  // ----------------------------------------------------
  Widget _buildMetricsRow(double earnings, int completed, int activeCount) {
    return Row(
      children: [
        Expanded(
          child: _metricCard('Today\'s Payout', '₹${earnings.toStringAsFixed(0)}', Icons.account_balance_wallet_outlined, AppColors.success),
        ),
        SizedBox(width: Responsive.w(10)),
        Expanded(
          child: _metricCard('Completed', '$completed', Icons.check_circle_outline, AppColors.primary),
        ),
        SizedBox(width: Responsive.w(10)),
        Expanded(
          child: _metricCard('Active', '$activeCount', Icons.pedal_bike_outlined, AppColors.warning),
        ),
      ],
    );
  }

  Widget _metricCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(10), vertical: Responsive.h(12)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(14)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          SizedBox(height: Responsive.h(6)),
          CustomText.caption(label, fontSize: Responsive.sp(11), color: AppColors.grayFont),
          SizedBox(height: Responsive.h(2)),
          CustomText.title(value, fontSize: Responsive.sp(16), fontWeight: FontWeight.bold, color: AppColors.black),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // Active Order Card
  // ----------------------------------------------------
  Widget _buildActiveOrderCard(BuildContext context, DeliveryOrder order) {
    final isOutForDelivery = order.status == 'out_for_delivery';

    return Container(
      margin: EdgeInsets.only(bottom: Responsive.h(12)),
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF9E6), // Warm highlight card
        borderRadius: BorderRadius.circular(Responsive.w(16)),
        border: Border.all(color: AppColors.warning.withOpacity(0.6), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: Responsive.w(8), vertical: Responsive.h(3)),
                decoration: BoxDecoration(
                  color: isOutForDelivery ? AppColors.info : AppColors.warning,
                  borderRadius: BorderRadius.circular(Responsive.w(6)),
                ),
                child: CustomText.caption(
                  isOutForDelivery ? 'OUT FOR DELIVERY' : 'PICKUP READY',
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              CustomText.caption(
                'Order #${order.orderId}',
                fontWeight: FontWeight.bold,
                color: AppColors.black,
              ),
            ],
          ),
          SizedBox(height: Responsive.h(12)),

          // Store & Customer summary
          Row(
            children: [
              const Icon(Icons.storefront_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: Responsive.w(8)),
              Expanded(
                child: CustomText.title(
                  order.storeName,
                  fontSize: Responsive.sp(14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(6)),
          Row(
            children: [
              const Icon(Icons.location_on_outlined, size: 18, color: AppColors.success),
              SizedBox(width: Responsive.w(8)),
              Expanded(
                child: CustomText.body(
                  order.dropAddress,
                  fontSize: Responsive.sp(12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(14)),

          // Navigation and Details buttons
          Row(
            children: [
              // Google Maps Direction Launcher
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    if (isOutForDelivery) {
                      NavigationLauncher.openGoogleMapsDirections(order.dropLat, order.dropLng, label: 'Customer Location');
                    } else {
                      NavigationLauncher.openGoogleMapsDirections(order.storeLat, order.storeLng, label: 'Store Location');
                    }
                  },
                  icon: const Icon(Icons.navigation_outlined, size: 18, color: AppColors.primary),
                  label: Text(
                    isOutForDelivery ? 'To Customer' : 'To Store',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(10))),
                  ),
                ),
              ),
              SizedBox(width: Responsive.w(10)),

              // Open Details Screen
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, RouteConstants.activeDelivery, arguments: order);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(10))),
                  ),
                  child: const Text('Manage', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // States
  // ----------------------------------------------------
  Widget _buildOfflineNotice() {
    return Container(
      padding: EdgeInsets.all(Responsive.w(24)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(16)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.power_off_rounded, size: 48, color: AppColors.grayFont),
          SizedBox(height: Responsive.h(12)),
          CustomText.title('You are currently Offline', fontSize: Responsive.sp(16), fontWeight: FontWeight.bold),
          SizedBox(height: Responsive.h(6)),
          CustomText.body(
            'Turn on Duty switch at top right to start receiving available orders and payouts.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoOrdersState() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(Responsive.w(24)),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(Responsive.w(16)),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Icon(Icons.two_wheeler_outlined, size: 48, color: AppColors.outliner),
          SizedBox(height: Responsive.h(12)),
          CustomText.title('Searching for nearby orders...', fontSize: Responsive.sp(15), fontWeight: FontWeight.bold),
          SizedBox(height: Responsive.h(6)),
          CustomText.body(
            'Keep app open. When citizens place orders at government stores, they will appear here.',
            textAlign: TextAlign.center,
            fontSize: Responsive.sp(12.5),
          ),
        ],
      ),
    );
  }

}
