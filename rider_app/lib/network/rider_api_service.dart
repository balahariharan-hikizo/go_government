import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/delivery_order_model.dart';
import 'api_client.dart';

class RiderApiService {
  // --------------------------------------------------------------------------
  // Dynamic Host Prober (Checks office Wi-Fi, home Wi-Fi, desktop localhost)
  // --------------------------------------------------------------------------
  static Future<String> resolveBaseUrl() async {
    for (final host in ApiClient.candidateHosts) {
      try {
        final uri = Uri.parse('$host/health');
        final response = await http.get(uri).timeout(const Duration(milliseconds: 1500));
        if (response.statusCode == 200) {
          ApiClient.setBaseUrl(host);
          return host;
        }
      } catch (_) {}
    }
    return ApiClient.defaultBaseUrl;
  }

  // --------------------------------------------------------------------------
  // 1. Send OTP
  // --------------------------------------------------------------------------
  static Future<Map<String, dynamic>> sendOtp(String phone) async {
    final url = '${ApiClient.baseUrl}/riders/auth/send-otp';
    ApiClient.logRequest('POST', url, body: {'phone': phone});

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: ApiClient.defaultHeaders,
            body: jsonEncode({'phone': phone}),
          )
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'error': 'Failed to send OTP (${response.statusCode})'};
    } catch (e) {
      ApiClient.logError('POST', url, e);
      return {'success': false, 'error': e.toString()};
    }
  }

  // --------------------------------------------------------------------------
  // 2. Verify OTP
  // --------------------------------------------------------------------------
  static Future<Map<String, dynamic>> verifyOtp(String phone, String otp) async {
    final url = '${ApiClient.baseUrl}/riders/auth/verify-otp';
    final body = {'phone': phone, 'otp': otp};
    ApiClient.logRequest('POST', url, body: body);

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: ApiClient.defaultHeaders,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'error': 'Invalid OTP or server error'};
    } catch (e) {
      ApiClient.logError('POST', url, e);
      return {'success': false, 'error': e.toString()};
    }
  }

  // --------------------------------------------------------------------------
  // 3. Update Rider Profile
  // --------------------------------------------------------------------------
  static Future<bool> updateProfile({
    required String userId,
    required String userName,
    String? email,
    String? vehicleType,
    String? vehicleNumber,
  }) async {
    final url = '${ApiClient.baseUrl}/riders/update-profile';
    final body = {
      'riderId': userId,
      'name': userName,
      if (email != null) 'email': email,
      if (vehicleType != null) 'vehicleType': vehicleType,
      if (vehicleNumber != null) 'vehicleNumber': vehicleNumber,
    };
    ApiClient.logRequest('PUT', url, body: body);

    try {
      final response = await http
          .put(
            Uri.parse(url),
            headers: ApiClient.defaultHeaders,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      ApiClient.logError('POST', url, e);
      return false;
    }
  }

  // --------------------------------------------------------------------------
  // 4. Fetch Available Orders (Unassigned orders ready or preparing)
  // --------------------------------------------------------------------------
  static Future<List<DeliveryOrder>> fetchAvailableOrders() async {
    final url = '${ApiClient.baseUrl}/orders/available';
    ApiClient.logRequest('GET', url);

    try {
      final response = await http
          .get(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('GET', url, response.statusCode, response.body);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final list = decoded['data'] as List? ?? [];
        return list.map((item) => DeliveryOrder.fromJson(Map<String, dynamic>.from(item))).toList();
      }
      return [];
    } catch (e) {
      ApiClient.logError('GET', url, e);
      return [];
    }
  }

  // --------------------------------------------------------------------------
  // 5. Fetch Rider's Orders (Assigned / Active / Completed)
  // --------------------------------------------------------------------------
  static Future<List<DeliveryOrder>> fetchRiderOrders(String riderId) async {
    if (riderId.isEmpty) return [];
    final url = '${ApiClient.baseUrl}/orders/rider/$riderId';
    ApiClient.logRequest('GET', url);

    try {
      final response = await http
          .get(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('GET', url, response.statusCode, response.body);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final list = decoded['data'] as List? ?? [];
        return list.map((item) => DeliveryOrder.fromJson(Map<String, dynamic>.from(item))).toList();
      }
      return [];
    } catch (e) {
      ApiClient.logError('GET', url, e);
      return [];
    }
  }

  // --------------------------------------------------------------------------
  // 6. Rider Accepts Delivery Order
  // --------------------------------------------------------------------------
  static Future<Map<String, dynamic>> acceptOrder({
    required String orderId,
    required String riderId,
    required String riderName,
    required String riderPhone,
    required String vehicleNumber,
  }) async {
    final url = '${ApiClient.baseUrl}/orders/$orderId/accept-rider';
    final body = {
      'riderId': riderId,
      'name': riderName,
      'phone': riderPhone,
      'vehicleNumber': vehicleNumber,
      'rating': 4.9,
    };
    ApiClient.logRequest('POST', url, body: body);

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: ApiClient.defaultHeaders,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
      final json = jsonDecode(response.body);
      final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
      final isAlreadyAccepted = response.statusCode == 409 || json['code'] == 'ALREADY_ACCEPTED';

      return {
        'success': isSuccess,
        'alreadyAccepted': isAlreadyAccepted,
        'message': json['message'] ?? (isSuccess ? 'Delivery accepted successfully' : 'Failed to accept delivery'),
      };
    } catch (e) {
      ApiClient.logError('POST', url, e);
      return {
        'success': false,
        'alreadyAccepted': false,
        'message': 'Connection error: Unable to accept delivery.',
      };
    }
  }

  // --------------------------------------------------------------------------
  // 7. Update Order Status (e.g. out_for_delivery, delivered)
  // --------------------------------------------------------------------------
  static Future<bool> updateOrderStatus({
    required String orderId,
    required String status,
    String? note,
  }) async {
    final url = '${ApiClient.baseUrl}/orders/$orderId/status';
    final body = {
      'status': status,
      if (note != null) 'note': note,
    };
    ApiClient.logRequest('PATCH', url, body: body);

    try {
      final response = await http
          .patch(
            Uri.parse(url),
            headers: ApiClient.defaultHeaders,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('PATCH', url, response.statusCode, response.body);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      ApiClient.logError('PATCH', url, e);
      return false;
    }
  }

  // --------------------------------------------------------------------------
  // 8. Fetch Single Order Details
  // --------------------------------------------------------------------------
  static Future<DeliveryOrder?> fetchOrderDetails(String orderId) async {
    final url = '${ApiClient.baseUrl}/orders/$orderId';
    ApiClient.logRequest('GET', url);

    try {
      final response = await http
          .get(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('GET', url, response.statusCode, response.body);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final data = decoded['data'];
        if (data != null) {
          return DeliveryOrder.fromJson(Map<String, dynamic>.from(data));
        }
      }
      return null;
    } catch (e) {
      ApiClient.logError('GET', url, e);
      return null;
    }
  }

  // --------------------------------------------------------------------------
  // 9. Fetch Real Rider Profile Details from Backend
  // --------------------------------------------------------------------------
  static Future<Map<String, dynamic>?> fetchRiderProfile(String userId) async {
    if (userId.isEmpty) return null;
    final url = '${ApiClient.baseUrl}/riders/profile/$userId';
    ApiClient.logRequest('GET', url);

    try {
      final response = await http
          .get(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('GET', url, response.statusCode, response.body);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          return Map<String, dynamic>.from(decoded);
        }
      }
      return null;
    } catch (e) {
      ApiClient.logError('GET', url, e);
      return null;
    }
  }

  // --------------------------------------------------------------------------
  // 10. Fetch Rider Wallet & Earnings History
  // --------------------------------------------------------------------------
  static Future<Map<String, dynamic>?> fetchRiderWallet(String userId) async {
    if (userId.isEmpty) return null;
    final url = '${ApiClient.baseUrl}/wallet/$userId';
    ApiClient.logRequest('GET', url);

    try {
      final response = await http
          .get(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('GET', url, response.statusCode, response.body);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map && decoded['success'] == true) {
          return Map<String, dynamic>.from(decoded);
        }
      }
      return null;
    } catch (e) {
      ApiClient.logError('GET', url, e);
      return null;
    }
  }

  // --------------------------------------------------------------------------
  // 11. Update Rider FCM Device Token
  // --------------------------------------------------------------------------
  static Future<bool> updateFcmToken({
    required String userId,
    required String phone,
    required String fcmToken,
  }) async {
    if (fcmToken.isEmpty) return false;
    final url = '${ApiClient.baseUrl}/riders/update-fcm-token';
    final body = {
      'riderId': userId,
      'phone': phone,
      'fcmToken': fcmToken,
    };
    ApiClient.logRequest('POST', url, body: body);

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: ApiClient.defaultHeaders,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
      return response.statusCode == 200;
    } catch (e) {
      ApiClient.logError('POST', url, e);
      return false;
    }
  }

  // --------------------------------------------------------------------------
  // 12. Rider Logout (Clears FCM Token & Registry on Server)
  // --------------------------------------------------------------------------
  static Future<bool> logout({
    required String userId,
    required String phone,
  }) async {
    final url = '${ApiClient.baseUrl}/riders/logout';
    final body = {
      'riderId': userId,
      'phone': phone,
    };
    ApiClient.logRequest('POST', url, body: body);

    try {
      final response = await http
          .post(
            Uri.parse(url),
            headers: ApiClient.defaultHeaders,
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
      return response.statusCode == 200;
    } catch (e) {
      ApiClient.logError('POST', url, e);
      return false;
    }
  }
}
