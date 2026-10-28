class HiveBoxes {
  static const String auth = 'auth_box';
  static const String cart = 'cart_box';
  static const String address = 'address_box';
  static const String settings = 'settings_box';
  static const String complaint = 'complaint_box';
  static const String transaction = 'transaction_box';
}

class HiveKeys {
  // Auth & Profile
  static const String isLoggedIn = 'is_logged_in';
  static const String userPhone = 'user_phone';
  static const String userName = 'user_name';
  static const String userEmail = 'user_email';
  static const String userProfileImage = 'user_profile_image';

  // Cart & Wishlist
  static const String cartItems = 'cart_items';
  static const String productDetails = 'product_details';
  static const String favoriteIds = 'favorite_ids';

  // Address
  static const String savedAddresses = 'saved_addresses';
  static const String selectedAddressIndex = 'selected_address_index';
  static const String manualLocation = 'manual_location';

  // Complaints & Reports
  static const String myComplaints = 'my_complaints';

  // Transactions, Wallet & Coins
  static const String myTransactions = 'my_transactions';
  static const String walletBalance = 'wallet_balance';
  static const String coinsBalance = 'coins_balance';
  static const String referralClaimed = 'referral_claimed';

  // Settings
  static const String selectedLanguage = 'selected_language';
  static const String selectedLanguageCode = 'selected_language_code';
  static const String isDarkMode = 'is_dark_mode';
  static const String hasSeenPermissionScreen = 'has_seen_permission_screen';
}

