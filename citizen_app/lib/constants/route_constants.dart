/// Responsibility: Centralized string identifiers for named route navigation across the application.
class RouteConstants {
  RouteConstants._();

  // Root / Initial
  static const String initial = '/';

  // Auth
  static const String login = '/login';
  static const String otp = '/otp';
  static const String permission = '/permission';

  // Home & Main
  static const String main = '/main';
  static const String home = '/home';
  static const String nearBusStop = '/near-bus-stop';
  static const String nearToilet = '/near-toilet';
  static const String feedbackSurvey = '/feedback-survey';
  static const String notification = '/notification';
  static const String directions = '/directions';

  // Stores & E-commerce
  static const String nearStores = '/near-stores';
  static const String storeDetails = '/store-details';
  static const String allProducts = '/all-products';
  static const String productDetails = '/product-details';
  static const String cart = '/cart';
  static const String coupons = '/coupons';
  static const String orderStatus = '/order-status';
  static const String orderSuccess = '/order-success';
  static const String riderChat = '/rider-chat';

  // Complaints
  static const String complaint = '/complaint';
  static const String addComplaint = '/add-complaint';
  static const String pickLocation = '/pick-location';

  // Reports
  static const String report = '/report';
  static const String complaintDetails = '/complaint-details';

  // Transactions & Payments
  static const String transaction = '/transaction';
  static const String allTransactions = '/all-transactions';
  static const String yourOrders = '/your-orders';
  static const String transactionDetails = '/transaction-details';
  static const String qrScanPay = '/qr-scan-pay';

  // Profile & Settings
  static const String profile = '/profile';
  static const String editProfile = '/edit-profile';
  static const String editPhone = '/edit-phone';
  static const String addressBook = '/address-book';
  static const String selectDeliveryLocation = '/select-delivery-location';
  static const String wishlist = '/wishlist';
  static const String selectLanguage = '/select-language';
}
