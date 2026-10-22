import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'bloc/auth/rider_auth_bloc.dart';
import 'bloc/delivery/delivery_bloc.dart';
import 'bloc/customer_chat/customer_chat_bloc.dart';
import 'constants/route_constants.dart';
import 'hive/hive_service.dart';
import 'network/rider_api_service.dart';
import 'routes/app_routes.dart';
import 'services/notification_service.dart';
import 'utils/app_theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}

  debugPrint('📩 [FCM Background Rider] Message received: ${message.messageId} | data: ${message.data}');

  if (message.data['type'] == 'order_dispatch') {
    final orderId = message.data['orderId']?.toString() ?? '';
    final storeName = message.data['storeName']?.toString() ?? 'Store';
    final dropAddress = message.data['dropAddress']?.toString() ?? 'Customer Location';
    final fee = message.data['fee']?.toString() ?? '0';

    // 1. Programmatically wake up the device screen and launch app immediately
    try {
      FlutterForegroundTask.wakeUpScreen();
      FlutterForegroundTask.launchApp();
    } catch (e) {
      debugPrint("Failed to auto-launch app from FCM: $e");
    }

    // 2. Only trigger local notification for data-only push to prevent duplicate alerts
    if (message.notification == null) {
      await NotificationService.showOrderAlert(
        orderId: orderId,
        storeName: storeName,
        dropAddress: dropAddress,
        fee: fee,
      );
    }
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    debugPrint('🔥 [Rider App] Firebase initialized successfully');
  } catch (e) {
    debugPrint('❌ [Rider App] Firebase init error: $e');
  }

  // Initialize foreground task communication port
  FlutterForegroundTask.initCommunicationPort();

  // Set status bar colors
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Hive
  await HiveService.init();

  // Initialize Local Notifications
  await NotificationService.initialize();

  // Auto-resolve backend Wi-Fi IP
  RiderApiService.resolveBaseUrl();

  runApp(const GoGovernmentRiderApp());
}

class GoGovernmentRiderApp extends StatelessWidget {
  const GoGovernmentRiderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<RiderAuthBloc>(
          create: (_) => RiderAuthBloc.instance,
        ),
        BlocProvider<DeliveryBloc>(
          create: (_) => DeliveryBloc.instance,
        ),
        BlocProvider<CustomerChatBloc>(
          create: (_) => CustomerChatBloc(),
        ),
      ],
      child: MaterialApp(
        title: 'GoGovernment Delivery Partner',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: RouteConstants.splash,
        onGenerateRoute: AppRoutes.onGenerateRoute,
      ),
    );
  }
}
