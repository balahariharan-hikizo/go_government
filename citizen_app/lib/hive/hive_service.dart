import 'package:hive_flutter/hive_flutter.dart';
import 'hive_boxes.dart';

class HiveService {
  static late Box _authBox;
  static late Box _cartBox;
  static late Box _addressBox;
  static late Box _settingsBox;
  static late Box _complaintBox;
  static late Box _transactionBox;

  static Future<void> init() async {
    await Hive.initFlutter();

    _authBox = await Hive.openBox(HiveBoxes.auth);
    _cartBox = await Hive.openBox(HiveBoxes.cart);
    _addressBox = await Hive.openBox(HiveBoxes.address);
    _settingsBox = await Hive.openBox(HiveBoxes.settings);
    _complaintBox = await Hive.openBox(HiveBoxes.complaint);
    _transactionBox = await Hive.openBox(HiveBoxes.transaction);
  }

  // ----------------------------------------------------
  // Auth & Profile
  // ----------------------------------------------------
  static bool get isLoggedIn =>
      _authBox.get(HiveKeys.isLoggedIn, defaultValue: false) as bool;

  static Future<void> setLoggedIn(bool value) async {
    await _authBox.put(HiveKeys.isLoggedIn, value);
  }

  static String get userPhone =>
      _authBox.get(HiveKeys.userPhone, defaultValue: '') as String;

  static Future<void> setUserPhone(String phone) async {
    await _authBox.put(HiveKeys.userPhone, phone);
  }

  static String get userName =>
      _authBox.get(HiveKeys.userName, defaultValue: '') as String;

  static Future<void> setUserName(String name) async {
    await _authBox.put(HiveKeys.userName, name);
  }

  static String get userEmail =>
      _authBox.get(HiveKeys.userEmail, defaultValue: '') as String;

  static Future<void> setUserEmail(String email) async {
    await _authBox.put(HiveKeys.userEmail, email);
  }

  static String get userProfileImage =>
      _authBox.get(HiveKeys.userProfileImage, defaultValue: '') as String;

  static Future<void> setUserProfileImage(String path) async {
    await _authBox.put(HiveKeys.userProfileImage, path);
  }

  static String get citizenId {
    return _authBox.get('citizenId', defaultValue: '') as String;
  }

  static Future<void> setCitizenId(String id) async {
    await _authBox.put('citizenId', id);
  }

  static String get userId => citizenId;
  static Future<void> setUserId(String id) => setCitizenId(id);

  static Future<void> saveProfile({
    required String name,
    required String email,
    String? phone,
    String? imagePath,
  }) async {
    await _authBox.put(HiveKeys.userName, name);
    await _authBox.put(HiveKeys.userEmail, email);
    if (phone != null && phone.isNotEmpty) {
      await _authBox.put(HiveKeys.userPhone, phone);
    }
    if (imagePath != null) {
      await _authBox.put(HiveKeys.userProfileImage, imagePath);
    }
  }

  static Future<void> clearAuth() async {
    await clearAllHiveData();
  }

  /// Clears ALL Hive boxes across the app on logout
  static Future<void> clearAllHiveData({bool preserveLanguage = true}) async {
    final lang = preserveLanguage ? getLanguage() : null;
    final langCode = preserveLanguage ? getLanguageCode() : null;

    await _authBox.clear();
    await _cartBox.clear();
    await _addressBox.clear();
    await _complaintBox.clear();
    await _transactionBox.clear();
    await _settingsBox.clear();

    // Preserve the user's selected language preference across logouts
    if (preserveLanguage && lang != null && langCode != null) {
      await setLanguage(lang);
      await setLanguageCode(langCode);
    }
  }

  static Future<void> clearAddresses() async {
    await _addressBox.delete(HiveKeys.savedAddresses);
    await _addressBox.delete(HiveKeys.selectedAddressIndex);
  }

  // ----------------------------------------------------
  // Cart & Wishlist
  // ----------------------------------------------------
  static Map<String, int> getCartItems() {
    final raw = _cartBox.get(HiveKeys.cartItems);
    if (raw == null) return {};
    try {
      final map = Map<dynamic, dynamic>.from(raw as Map);
      return map.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveCartItems(Map<String, int> items) async {
    await _cartBox.put(HiveKeys.cartItems, items);
  }

  static Map<String, Map<String, dynamic>> getProductDetails() {
    final raw = _cartBox.get(HiveKeys.productDetails);
    if (raw == null) return {};
    try {
      final map = Map<dynamic, dynamic>.from(raw as Map);
      return map.map((k, v) {
        final innerMap = Map<dynamic, dynamic>.from(v as Map);
        return MapEntry(
          k.toString(),
          innerMap.map((ik, iv) => MapEntry(ik.toString(), iv)),
        );
      });
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveProductDetails(
      Map<String, Map<String, dynamic>> details) async {
    await _cartBox.put(HiveKeys.productDetails, details);
  }

  static Set<String> getFavoriteIds() {
    final raw = _cartBox.get(HiveKeys.favoriteIds);
    if (raw == null) return {};
    try {
      final list = List<dynamic>.from(raw as List);
      return list.map((e) => e.toString()).toSet();
    } catch (_) {
      return {};
    }
  }

  static Future<void> saveFavoriteIds(Set<String> ids) async {
    await _cartBox.put(HiveKeys.favoriteIds, ids.toList());
  }

  static Future<void> clearCart() async {
    await _cartBox.delete(HiveKeys.cartItems);
    await _cartBox.delete(HiveKeys.productDetails);
  }

  // ----------------------------------------------------
  // Address
  // ----------------------------------------------------
  static List<Map<String, dynamic>> getSavedAddresses() {
    final raw = _addressBox.get(HiveKeys.savedAddresses);
    if (raw == null) return [];
    try {
      final list = List<dynamic>.from(raw as List);
      return list.map((item) {
        final map = Map<dynamic, dynamic>.from(item as Map);
        return map.map((k, v) => MapEntry(k.toString(), v));
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveAddresses(List<Map<String, dynamic>> addresses) async {
    await _addressBox.put(HiveKeys.savedAddresses, addresses);
  }

  static int getSelectedAddressIndex() {
    return _addressBox.get(HiveKeys.selectedAddressIndex, defaultValue: 0) as int;
  }

  static Future<void> setSelectedAddressIndex(int index) async {
    await _addressBox.put(HiveKeys.selectedAddressIndex, index);
  }

  static Map<String, dynamic>? getManualLocation() {
    try {
      final raw = _addressBox.get(HiveKeys.manualLocation);
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  static Future<void> setManualLocation({
    required double latitude,
    required double longitude,
    required String address,
  }) async {
    await _addressBox.put(HiveKeys.manualLocation, {
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    });
  }

  static Future<void> clearManualLocation() async {
    await _addressBox.delete(HiveKeys.manualLocation);
  }

  // ----------------------------------------------------
  // Complaints & Reports
  // ----------------------------------------------------
  static List<Map<String, dynamic>> getMyComplaints() {
    final raw = _complaintBox.get(HiveKeys.myComplaints);
    if (raw == null) return [];
    try {
      final list = List<dynamic>.from(raw as List);
      return list.map((item) {
        final map = Map<dynamic, dynamic>.from(item as Map);
        return map.map((k, v) => MapEntry(k.toString(), v));
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveComplaint(Map<String, dynamic> complaint) async {
    final list = getMyComplaints();
    list.insert(0, complaint);
    await _complaintBox.put(HiveKeys.myComplaints, list);
  }

  static Future<void> saveAllComplaints(List<Map<String, dynamic>> complaints) async {
    await _complaintBox.put(HiveKeys.myComplaints, complaints);
  }

  static Future<void> clearComplaints() async {
    await _complaintBox.delete(HiveKeys.myComplaints);
  }

  // ----------------------------------------------------
  // Transactions & Orders
  // ----------------------------------------------------
  static List<Map<String, dynamic>> getMyTransactions() {
    final raw = _transactionBox.get(HiveKeys.myTransactions);
    if (raw == null) return [];
    try {
      final list = List<dynamic>.from(raw as List);
      return list.map((item) {
        final map = Map<dynamic, dynamic>.from(item as Map);
        return map.map((k, v) {
          if (v is List) {
            return MapEntry(
              k.toString(),
              v.map((inner) {
                if (inner is Map) {
                  return Map<dynamic, dynamic>.from(inner).map((ik, iv) => MapEntry(ik.toString(), iv));
                }
                return inner;
              }).toList(),
            );
          }
          return MapEntry(k.toString(), v);
        });
      }).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveTransaction(Map<String, dynamic> transaction) async {
    final list = getMyTransactions();
    list.insert(0, transaction);
    await _transactionBox.put(HiveKeys.myTransactions, list);
  }

  static Future<void> saveAllTransactions(List<Map<String, dynamic>> transactions) async {
    await _transactionBox.put(HiveKeys.myTransactions, transactions);
  }

  static double getWalletBalance() {
    final val = _transactionBox.get(HiveKeys.walletBalance, defaultValue: 0.0);
    if (val is num) return val.toDouble();
    return 0.0;
  }

  static Future<void> setWalletBalance(double amount) async {
    await _transactionBox.put(HiveKeys.walletBalance, amount);
  }

  static int getCoinsBalance() {
    final val = _transactionBox.get(HiveKeys.coinsBalance, defaultValue: 0);
    if (val is num) return val.toInt();
    return 0;
  }

  static Future<void> setCoinsBalance(int coins) async {
    await _transactionBox.put(HiveKeys.coinsBalance, coins);
  }

  static bool isReferralClaimed() {
    return _transactionBox.get(HiveKeys.referralClaimed, defaultValue: false) as bool;
  }

  static Future<void> setReferralClaimed(bool claimed) async {
    await _transactionBox.put(HiveKeys.referralClaimed, claimed);
  }

  // ----------------------------------------------------
  // Settings
  // ----------------------------------------------------
  static String getLanguage() {
    return _settingsBox.get(HiveKeys.selectedLanguage, defaultValue: 'English')
        as String;
  }

  static Future<void> setLanguage(String lang) async {
    await _settingsBox.put(HiveKeys.selectedLanguage, lang);
  }

  static String getLanguageCode() {
    try {
      final code = _settingsBox.get(HiveKeys.selectedLanguageCode);
      if (code != null && (code as String).isNotEmpty) return code;
      final lang = getLanguage();
      const map = {
        'English': 'en',
        'Kannada': 'kn',
        'Hindi': 'hi',
        'Telugu': 'te',
        'Tamil': 'ta',
        'Malayalam': 'ml',
        'Marathi': 'mr',
        'Bengali': 'bn',
      };
      return map[lang] ?? 'en';
    } catch (_) {
      return 'en';
    }
  }

  static Future<void> setLanguageCode(String code) async {
    await _settingsBox.put(HiveKeys.selectedLanguageCode, code);
  }

  static bool get hasSeenPermissionScreen =>
      _settingsBox.get(HiveKeys.hasSeenPermissionScreen, defaultValue: false) as bool;

  static Future<void> setHasSeenPermissionScreen(bool value) async {
    await _settingsBox.put(HiveKeys.hasSeenPermissionScreen, value);
  }

  // Chat Unread Count Tracking per Order
  static int getLastReadChatCount(String orderId) {
    if (orderId.isEmpty) return 0;
    final val = _authBox.get('chat_last_read_$orderId', defaultValue: 0);
    return (val is num) ? val.toInt() : 0;
  }

  static Future<void> setLastReadChatCount(String orderId, int count) async {
    if (orderId.isEmpty) return;
    await _authBox.put('chat_last_read_$orderId', count);
  }
}

