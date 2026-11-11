import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_web_plugins/flutter_web_plugins.dart';
import 'package:geolocator_web/geolocator_web.dart';
import 'services/admin_api_service.dart';
import 'screens/admin_dashboard_screen.dart';
import 'screens/admin_login_screen.dart';

final GlobalKey<NavigatorState> adminNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    try {
      GeolocatorPlugin.registerWith(webPluginRegistrar);
    } catch (_) {}
  }
  await AdminApiService.init();

  // Setup global auto-logout listener on session expiry
  AdminApiService.onUnauthorized = () {
    adminNavigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
      (route) => false,
    );
  };

  runApp(const AdminWebApp());
}

class AdminWebApp extends StatelessWidget {
  const AdminWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: adminNavigatorKey,
      title: 'GoGovernment Municipal Admin Portal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F172A),
          primary: const Color(0xFF0F172A),
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9),
        fontFamily: 'Roboto',
      ),
      home: AdminApiService.isLoggedIn
          ? const AdminDashboardScreen()
          : const AdminLoginScreen(),
    );
  }
}
