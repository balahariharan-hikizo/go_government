export 'api_client.dart';
export 'auth_api_service.dart';
export 'complaint_api_service.dart';
export 'address_api_service.dart';
export 'feedback_api_service.dart';
export 'store_api_service.dart';
export 'product_api_service.dart';
export 'order_api_service.dart';
export 'cart_wishlist_api_service.dart';
export 'wallet_api_service.dart';

import '../model/address_model.dart';
import 'api_client.dart';
import 'auth_api_service.dart';
import 'complaint_api_service.dart';
import 'address_api_service.dart';
import 'store_api_service.dart';
import 'product_api_service.dart';

/// Facade for backward compatibility.
/// You can also use [AuthApiService] and [ComplaintApiService] directly.
class ApiService {
  static String get baseUrl => ApiClient.baseUrl;
  static String get defaultBaseUrl => ApiClient.defaultBaseUrl;
  static void setBaseUrl(String url) => ApiClient.setBaseUrl(url);

  // Auth & Profile
  static Future<Map<String, dynamic>?> sendOtp(String phone) =>
      AuthApiService.sendOtp(phone);

  static Future<Map<String, dynamic>?> verifyOtp(String phone, String otp) =>
      AuthApiService.verifyOtp(phone, otp);

  static Future<Map<String, dynamic>?> sendPhoneUpdateOtp({
    required String userId,
    required String newPhone,
    String? currentPhone,
  }) =>
      AuthApiService.sendPhoneUpdateOtp(
        userId: userId,
        newPhone: newPhone,
        currentPhone: currentPhone,
      );

  static Future<Map<String, dynamic>?> verifyPhoneUpdateOtp({
    required String userId,
    required String newPhone,
    required String otp,
    String? currentPhone,
  }) =>
      AuthApiService.verifyPhoneUpdateOtp(
        userId: userId,
        newPhone: newPhone,
        otp: otp,
        currentPhone: currentPhone,
      );

  static Future<bool> updateProfile({
    required String userId,
    required String userName,
    required String email,
    String? profileImage,
  }) =>
      AuthApiService.updateProfile(
        userId: userId,
        userName: userName,
        email: email,
        profileImage: profileImage,
      );

  static Future<String?> uploadProfileImage(String localPath) =>
      AuthApiService.uploadProfileImage(localPath);

  // Complaints
  static Future<String?> uploadComplaintImage(String localPath, String complaintId) =>
      ComplaintApiService.uploadComplaintImage(localPath, complaintId);

  static Future<void> submitComplaint(Map<String, dynamic> complaint) =>
      ComplaintApiService.submitComplaint(complaint);

  static Future<List<Map<String, dynamic>>> fetchComplaints() =>
      ComplaintApiService.fetchComplaints();

  static Future<List<Map<String, dynamic>>> fetchMyComplaints([String? userId]) =>
      ComplaintApiService.fetchMyComplaints(userId);

  static Stream<List<Map<String, dynamic>>> streamAllComplaints() =>
      ComplaintApiService.streamAllComplaints();

  static Future<void> toggleLike(String complaintId, bool isCurrentlyLiked) =>
      ComplaintApiService.toggleLike(complaintId, isCurrentlyLiked);

  static Future<void> addComment(String complaintId, String comment, String userName) =>
      ComplaintApiService.addComment(complaintId, comment, userName);

  // Addresses
  static Future<List<AddressModel>> fetchAddresses([String? userId]) =>
      AddressApiService.fetchAddresses(userId);

  static Future<AddressModel?> addAddress(AddressModel address, {String? userId}) =>
      AddressApiService.addAddress(address, userId: userId);

  static Future<AddressModel?> updateAddress(String addressId, AddressModel address) =>
      AddressApiService.updateAddress(addressId, address);

  static Future<bool> deleteAddress(String addressId) =>
      AddressApiService.deleteAddress(addressId);

  // Stores
  static Future<List<Map<String, dynamic>>> fetchApprovedStores({String? category, bool includeOffline = false}) =>
      StoreApiService.fetchApprovedStores(category: category, includeOffline: includeOffline);

  static Future<Map<String, dynamic>?> fetchStoreDetails(String storeId) =>
      StoreApiService.fetchStoreDetails(storeId);

  // Products
  static Future<List<Map<String, dynamic>>> fetchProductsByStore(String storeId, {String? storeType}) =>
      ProductApiService.fetchProductsByStore(storeId, storeType: storeType);

  static Future<Map<String, dynamic>?> fetchProductDetails(String productId) =>
      ProductApiService.fetchProductDetails(productId);
}
