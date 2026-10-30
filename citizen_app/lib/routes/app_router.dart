import 'package:flutter/material.dart';
import '../constants/route_constants.dart';

// Auth Screens
import '../screen/auth/login_screen.dart';
import '../screen/auth/otp_screen.dart';
import '../screen/auth/permission_screen.dart';

// Home & Main Screens
import '../screen/home/main_screen.dart';
import '../screen/home/bus_stop/near_bus_stop_screen.dart';
import '../screen/home/toilet/near_toilet_screen.dart';
import '../screen/home/feedback/feedback_survey_screen.dart';
import '../screen/home/notification/notification_screen.dart';
import '../screen/home/directions_screen.dart';

// Stores & E-commerce Screens
import '../screen/home/stores/near_stores_screen.dart';
import '../screen/home/stores/store_details_screen.dart';
import '../screen/home/stores/all_products_screen.dart';
import '../screen/home/stores/product_details_screen.dart';
import '../screen/home/stores/cart_screen.dart';
import '../screen/home/stores/coupons_screen.dart';
import '../screen/home/stores/order_status_screen.dart';
import '../screen/home/stores/rider_chat_screen.dart';
import '../widget/common_success_screen.dart';

// Complaint Screens
import '../screen/complaint/complaint_screen.dart';
import '../screen/complaint/add_complaint_screen.dart';
import '../screen/complaint/pick_location_screen.dart';
import 'package:latlong2/latlong.dart';

// Report Screens
import '../screen/report/report_screen.dart';
import '../screen/report/complaint_details_screen.dart';

// Transaction Screens
import '../screen/transaction/transaction_screen.dart';
import '../screen/transaction/all_transactions_screen.dart';
import '../screen/transaction/transaction_details_screen.dart';
import '../screen/transaction/qr_scan_pay_screen.dart';

// Profile Screens
import '../screen/profile/profile_screen.dart';
import '../screen/profile/edit_profile_screen.dart';
import '../screen/profile/edit_phone_screen.dart';
import '../screen/profile/address_book_screen.dart';
import '../screen/profile/select_delivery_location_screen.dart';
import '../screen/profile/wishlist_screen.dart';
import '../screen/profile/language_screen.dart';
import '../screen/profile/your_orders_screen.dart';

import '../hive/hive_service.dart';

/// Responsibility: Generates and maps named routes to corresponding screen widgets with smooth page transitions.
class AppRouter {
  AppRouter._();

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      // Root / Auth
      case RouteConstants.initial:
        if (HiveService.isLoggedIn && HiveService.userName.trim().isNotEmpty) {
          if (!HiveService.hasSeenPermissionScreen) {
            return _buildSmoothRoute(const PermissionScreen(), settings);
          }
          return _buildSmoothRoute(const MainScreen(), settings);
        }
        return _buildSmoothRoute(const LoginScreen(), settings);

      case RouteConstants.login:
        return _buildSmoothRoute(const LoginScreen(), settings);

      case RouteConstants.otp:
        final phoneNumber = settings.arguments is String ? settings.arguments as String : '';
        return _buildSmoothRoute(OtpScreen(phoneNumber: phoneNumber), settings);

      case RouteConstants.permission:
        return _buildSmoothRoute(const PermissionScreen(), settings);

      // Home / Main Shell
      case RouteConstants.main:
      case RouteConstants.home:
        return _buildSmoothRoute(const MainScreen(), settings);

      case RouteConstants.nearBusStop:
        return _buildSmoothRoute(const NearBusStopScreen(), settings);

      case RouteConstants.nearToilet:
        return _buildSmoothRoute(const NearToiletScreen(), settings);

      case RouteConstants.feedbackSurvey:
        return _buildSmoothRoute(const FeedbackSurveyScreen(), settings);

      case RouteConstants.notification:
        return _buildSmoothRoute(const NotificationScreen(), settings);

      case RouteConstants.directions:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return _buildSmoothRoute(
          DirectionsScreen(
            title: args['title'] as String? ?? 'Directions',
            address: args['address'] as String? ?? '',
            destinationCoords: args['destinationCoords'] as LatLng?,
            originCoords: args['originCoords'] as LatLng?, // manual/picked location
            initialWalkMode: args['isWalkMode'] as bool? ?? false,
          ),
          settings,
        );

      // Stores & E-Commerce
      case RouteConstants.nearStores:
        return _buildSmoothRoute(const NearStoresScreen(), settings);

      case RouteConstants.storeDetails:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return _buildSmoothRoute(
          StoreDetailsScreen(
            storeId: args['storeId'] as String? ?? '',
            storeName: args['storeName'] as String? ?? '',
            storeAddress: args['storeAddress'] as String? ?? '',
            storeImage: args['storeImage'] as String? ?? '',
            storeType: args['storeType'] as String? ?? 'medical',
            storePhone: args['storePhone'] as String? ?? args['phone'] as String? ?? '',
            ownerName: args['ownerName'] as String? ?? '',
          ),
          settings,
        );

      case RouteConstants.allProducts:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return _buildSmoothRoute(
          AllProductsScreen(
            title: args['title'] as String? ?? 'Products',
            products: (args['products'] as List<dynamic>?)?.cast<Map<String, dynamic>>() ?? [],
            storeType: args['storeType'] as String? ?? 'medical',
            categories: (args['categories'] as List<dynamic>?)?.cast<Map<String, dynamic>>(),
            storeCategories: (args['storeCategories'] as List<dynamic>?)?.cast<Map<String, dynamic>>(),
            initialMainCategoryId: args['initialMainCategoryId'] as String?,
            initialSubCategoryId: args['initialSubCategoryId'] as String?,
            initialChildCategoryId: args['initialChildCategoryId'] as String?,
            initialSubChildCategoryId: args['initialSubChildCategoryId'] as String?,
          ),
          settings,
        );

      case RouteConstants.productDetails:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return _buildSmoothRoute(
          ProductDetailsScreen(
            product: args['product'] as Map<String, dynamic>? ?? {},
            storeType: args['storeType'] as String? ?? 'medical',
          ),
          settings,
        );

      case RouteConstants.cart:
        final storeType = settings.arguments is String ? settings.arguments as String : 'medical';
        return _buildSmoothRoute(CartScreen(storeType: storeType), settings);

      case RouteConstants.coupons:
        final currentCouponCode = settings.arguments as String?;
        return _buildSmoothRoute(CouponsScreen(currentCouponCode: currentCouponCode), settings);

      case RouteConstants.orderStatus:
        String storeType = 'medical';
        Map<String, dynamic>? transaction;
        String? orderId;

        if (settings.arguments is String) {
          storeType = settings.arguments as String;
        } else if (settings.arguments is Map) {
          final rawArgs = settings.arguments as Map;
          final args = Map<String, dynamic>.from(rawArgs);
          storeType = args['storeType']?.toString() ?? 'medical';
          transaction = args['transaction'] is Map
              ? Map<String, dynamic>.from(args['transaction'] as Map)
              : null;
          orderId = args['orderId']?.toString() ??
              transaction?['orderId']?.toString() ??
              transaction?['id']?.toString();
        }

        return _buildSmoothRoute(
          OrderStatusScreen(
            storeType: storeType,
            transaction: transaction,
            orderId: orderId,
          ),
          settings,
        );

      case RouteConstants.orderSuccess:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return _buildSmoothRoute(
          CommonSuccessScreen(
            amount: (args['amount'] as num?)?.toDouble() ?? 0.0,
            title: args['title'] as String? ?? '',
            subtitle: args['subtitle'] as String? ?? 'Paid to',
            dateString: args['dateString'] as String? ?? '',
            buttonText: args['buttonText'] as String? ?? 'Done',
            onDone: args['onDone'] as VoidCallback?,
            nextRoute: args['nextRoute'] as String?,
            nextRouteArgs: args['nextRouteArgs'],
          ),
          settings,
        );

      case RouteConstants.riderChat:
        String orderId = '';
        String riderName = 'Delivery Partner';
        String riderPhone = '';
        if (settings.arguments is Map) {
          final args = settings.arguments as Map<String, dynamic>;
          orderId = args['orderId']?.toString() ?? '';
          riderName = args['riderName']?.toString() ?? 'Delivery Partner';
          riderPhone = args['riderPhone']?.toString() ?? '';
        } else if (settings.arguments is String) {
          riderName = settings.arguments as String;
        }
        return _buildSmoothRoute(
          RiderChatScreen(
            orderId: orderId,
            riderName: riderName,
            riderPhone: riderPhone,
          ),
          settings,
        );

      // Complaints
      case RouteConstants.complaint:
        return _buildSmoothRoute(const ComplaintScreen(), settings);

      case RouteConstants.addComplaint:
        final category = settings.arguments as String?;
        return _buildSmoothRoute(AddComplaintScreen(category: category), settings);

      case RouteConstants.pickLocation:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return _buildSmoothRoute(
          PickLocationScreen(
            initialLatLng: args['initialLatLng'] as LatLng?,
            initialAddress: args['initialAddress'] as String?,
            isLiveGps: args['isLiveGps'] as bool?,
          ),
          settings,
        );

      // Reports
      case RouteConstants.report:
        return _buildSmoothRoute(const ReportScreen(), settings);

      case RouteConstants.complaintDetails:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return _buildSmoothRoute(
          ComplaintDetailsScreen(
            report: args['report'] as Map<String, dynamic>?,
            userName: args['userName'] as String? ?? 'User',
            status: args['status'] as String? ?? 'Pending',
            statusColor: args['statusColor'] as Color? ?? Colors.orange,
            category: args['category'] as String? ?? 'Road Damage',
            description: args['description'] as String? ?? '',
            id: args['id'] as String? ?? '',
            imagePath: args['imagePath'] as String?,
            userAddress: args['userAddress'] as String?,
            date: args['date'] as String?,
          ),
          settings,
        );

      // Transactions
      case RouteConstants.transaction:
        return _buildSmoothRoute(const TransactionScreen(), settings);

      case RouteConstants.allTransactions:
        return _buildSmoothRoute(const AllTransactionsScreen(), settings);

      case RouteConstants.yourOrders:
        return _buildSmoothRoute(const YourOrdersScreen(), settings);

      case RouteConstants.transactionDetails:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return _buildSmoothRoute(
          TransactionDetailsScreen(
            title: args['title'] as String? ?? 'Transaction Details',
            transaction: args['transaction'] as Map<String, dynamic>?,
          ),
          settings,
        );

      case RouteConstants.qrScanPay:
        return _buildSmoothRoute(const QrScanPayScreen(), settings);

      // Profile
      case RouteConstants.profile:
        return _buildSmoothRoute(const ProfileScreen(), settings);

      case RouteConstants.editProfile:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return _buildSmoothRoute(
          EditProfileScreen(
            initialName: args['initialName'] as String? ?? '',
            initialEmail: args['initialEmail'] as String? ?? '',
            initialImagePath: args['initialImagePath'] as String? ?? '',
            isRegistration: args['isRegistration'] as bool? ?? false,
          ),
          settings,
        );

      case RouteConstants.editPhone:
        final initialPhone = settings.arguments is String ? settings.arguments as String : '';
        return _buildSmoothRoute(EditPhoneScreen(initialPhone: initialPhone), settings);

      case RouteConstants.addressBook:
        final isSelectionMode = settings.arguments as bool? ?? false;
        return _buildSmoothRoute(AddressBookScreen(isSelectionMode: isSelectionMode), settings);

      case RouteConstants.selectDeliveryLocation:
        final editAddress = settings.arguments as AddressModel?;
        return _buildSmoothRoute(SelectDeliveryLocationScreen(editAddress: editAddress), settings);

      case RouteConstants.wishlist:
        return _buildSmoothRoute(const WishlistScreen(), settings);

      case RouteConstants.selectLanguage:
        return _buildSmoothRoute(const LanguageScreen(), settings);

      default:
        return _buildSmoothRoute(
          Scaffold(
            appBar: AppBar(title: const Text('Route Not Found')),
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
          settings,
        );
    }
  }

  /// Helper to generate smooth, flicker-free slide page transitions.
  static Route<dynamic> _buildSmoothRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final tween = Tween<Offset>(
          begin: const Offset(1.0, 0.0),
          end: Offset.zero,
        ).chain(CurveTween(curve: Curves.easeOutCubic));

        return SlideTransition(
          position: animation.drive(tween),
          child: Container(
            color: const Color(0xFFFAFAFC),
            child: child,
          ),
        );
      },
    );
  }
}
