import 'package:hive_flutter/hive_flutter.dart';
import 'hive_boxes.dart';

class HiveService {
  static late Box _authBox;
  static late Box _storeBox;

  static Future<void> init() async {
    await Hive.initFlutter();
    _authBox = await Hive.openBox(HiveBoxes.auth);
    _storeBox = await Hive.openBox(HiveBoxes.store);
  }

  // ----------------------------------------------------
  // Auth & Merchant Profile
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

  static String get userId =>
      _authBox.get(HiveKeys.userId, defaultValue: '') as String;

  static Future<void> setUserId(String id) async {
    await _authBox.put(HiveKeys.userId, id);
  }

  static String get userRole =>
      _authBox.get(HiveKeys.userRole, defaultValue: 'store_owner') as String;

  static Future<void> setUserRole(String role) async {
    await _authBox.put(HiveKeys.userRole, role);
  }

  static String get userName =>
      _authBox.get(HiveKeys.userName, defaultValue: '') as String;

  static Future<void> setUserName(String name) async {
    await _authBox.put(HiveKeys.userName, name);
  }

  // ----------------------------------------------------
  // Store Data & Status
  // ----------------------------------------------------
  static String get storeId =>
      _storeBox.get(HiveKeys.storeId, defaultValue: '') as String;

  static Future<void> setStoreId(String id) async {
    await _storeBox.put(HiveKeys.storeId, id);
  }

  static String get storeStatus =>
      _storeBox.get(HiveKeys.storeStatus, defaultValue: '') as String;

  static Future<void> setStoreStatus(String status) async {
    await _storeBox.put(HiveKeys.storeStatus, status);
  }

  static Map<String, dynamic>? get cachedStoreData {
    final raw = _storeBox.get(HiveKeys.storeData);
    if (raw != null && raw is Map) {
      return Map<String, dynamic>.from(raw);
    }
    return null;
  }

  static Future<void> setCachedStoreData(Map<String, dynamic> data) async {
    await _storeBox.put(HiveKeys.storeData, data);
  }

  // ----------------------------------------------------
  // Clear Session
  // ----------------------------------------------------
  static Future<void> clearAuth() async {
    await _authBox.put(HiveKeys.isLoggedIn, false);
    await _authBox.put(HiveKeys.userPhone, '');
    await _authBox.put(HiveKeys.userId, '');
    await _authBox.put(HiveKeys.userName, '');
    await _storeBox.put(HiveKeys.storeStatus, '');
    await _storeBox.put(HiveKeys.storeId, '');
    await _storeBox.delete(HiveKeys.storeData);
    await _authBox.clear();
    await _storeBox.clear();
  }
}
