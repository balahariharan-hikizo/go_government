import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'bloc/auth/auth_bloc.dart';
import 'bloc/product/product_bloc.dart';
import 'bloc/store/store_bloc.dart';
import 'constants/route_constants.dart';
import 'hive/hive_service.dart';
import 'routes/app_router.dart';
import 'services/notification_service.dart';
import 'utils/app_theme.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  } catch (_) {}

  debugPrint('📩 [FCM Background Store] Message: ${message.messageId} | data: ${message.data}');

  // If message has notification payload, Android automatically displays it.
  // Only trigger local notification for data-only push to prevent duplicates.
  if (message.notification == null && message.data['type'] == 'new_order') {
    final orderId = message.data['orderId']?.toString() ?? '';
    final title = message.data['title']?.toString() ?? '🔔 New Order Received!';
    final body = message.data['body']?.toString() ?? 'Order #$orderId has been placed. Tap to prepare items.';
    await NotificationService.showNewOrderNotification(
      orderId: orderId,
      title: title,
      body: body,
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase
  try {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    debugPrint('🔥 [Store App] Firebase initialized successfully');
  } catch (e) {
    debugPrint('❌ [Store App] Firebase init error: $e');
  }

  // 2. Initialize Local Storage (Hive)
  await HiveService.init();

  // 3. Initialize Push Notifications for SMS OTPs & Order alerts
  await NotificationService.initialize();

  // 3. System UI Overlay & Orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );

  runApp(const StoreApp());
}

class StoreApp extends StatelessWidget {
  const StoreApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>(create: (_) => AuthBloc()),
        BlocProvider<StoreBloc>(create: (_) => StoreBloc()),
        BlocProvider<ProductBloc>(create: (_) => ProductBloc()),
      ],
      child: MaterialApp(
        title: 'GoGovernment Store Partner',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        initialRoute: RouteConstants.initial,
        onGenerateRoute: AppRouter.generateRoute,
      ),
    );
  }
}
