import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:store_app/model/product_model.dart';
import '../constants/route_constants.dart';
import '../hive/hive_service.dart';
import '../model/store_model.dart';
import '../screen/auth/login_screen.dart';
import '../screen/auth/otp_screen.dart';
import '../screen/store/register_store_screen.dart';
import '../screen/store/application_status_screen.dart';
import '../screen/store/store_dashboard_screen.dart';
import '../screen/store/store_details_screen.dart';
import '../screen/store/manage_products_screen.dart';
import '../screen/store/add_product_screen.dart';
import '../screen/store/store_orders_queue_screen.dart';
import '../screen/location/pick_store_location_screen.dart';

class AppRouter {
  AppRouter._();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case RouteConstants.initial:
        if (HiveService.isLoggedIn) {
          final cachedData = HiveService.cachedStoreData;
          final savedStatus = HiveService.storeStatus;
          if (cachedData != null) {
            final store = StoreModel.fromJson(cachedData);
            if (store.status == 'approved' || savedStatus == 'approved') {
              return MaterialPageRoute(builder: (_) => StoreDashboardScreen(store: store));
            } else {
              return MaterialPageRoute(builder: (_) => ApplicationStatusScreen(store: store, isColdStart: true));
            }
          }
        }
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case RouteConstants.login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());

      case RouteConstants.otp:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final phone = args['phone']?.toString() ?? '';
        final testOtp = args['testOtp']?.toString();
        return MaterialPageRoute(
          builder: (_) => OtpScreen(phone: phone, testOtp: testOtp),
        );

      case RouteConstants.registerStore:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final phone = args['initialPhone']?.toString() ?? HiveService.userPhone;
        return MaterialPageRoute(
          builder: (_) => RegisterStoreScreen(initialPhone: phone),
        );

      case RouteConstants.applicationStatus:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final store = args['store'] as StoreModel? ?? StoreModel();
        final justSubmitted = args['justSubmitted'] == true;
        final isColdStart = args['isColdStart'] == true;
        return MaterialPageRoute(
          builder: (_) => ApplicationStatusScreen(
            store: store,
            justSubmitted: justSubmitted,
            isColdStart: isColdStart,
          ),
        );

      case RouteConstants.storeDashboard:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final store = args['store'] as StoreModel? ?? StoreModel();
        return MaterialPageRoute(
          builder: (_) => StoreDashboardScreen(store: store),
        );

      case RouteConstants.pickLocation:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final initialLocation = args['initialLocation'] as LatLng?;
        final initialAddress = args['initialAddress']?.toString();
        return MaterialPageRoute(
          builder: (_) => PickStoreLocationScreen(
            initialLocation: initialLocation,
            initialAddress: initialAddress,
          ),
        );

      case RouteConstants.storeDetails:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final store = args['store'] as StoreModel? ?? StoreModel();
        return MaterialPageRoute(
          builder: (_) => StoreDetailsScreen(store: store),
        );

      case RouteConstants.manageProducts:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final store = args['store'] as StoreModel? ?? StoreModel();
        return MaterialPageRoute(
          builder: (_) => ManageProductsScreen(store: store),
        );

      case RouteConstants.addProduct:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final storeId = args['storeId']?.toString() ?? '';
        final storeCategory = args['storeCategory']?.toString() ?? 'general';
        final initialProduct = args['initialProduct'] as ProductModel?;
        return MaterialPageRoute(
          builder: (_) => AddProductScreen(
            storeId: storeId,
            storeCategory: storeCategory,
            initialProduct: initialProduct,
          ),
        );

      case RouteConstants.orderQueue:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final store = args['store'] as StoreModel? ?? StoreModel();
        return MaterialPageRoute(
          builder: (_) => StoreOrdersQueueScreen(store: store),
        );

      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
