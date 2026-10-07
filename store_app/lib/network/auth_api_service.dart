import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class AuthApiService {
  AuthApiService._();

  static Future<Map<String, dynamic>?> sendOtp(String phone) async {
    final url = '${ApiClient.baseUrl}/stores/auth/send-otp';
    final body = jsonEncode({'phone': phone});

    try {
      ApiClient.logRequest('POST', url, body: body);
      final response = await http
          .post(Uri.parse(url), headers: ApiClient.defaultHeaders, body: body)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      ApiClient.logError('POST', url, e);
      return {'success': false, 'message': 'Network connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>?> verifyOtp(String phone, String otp) async {
    final url = '${ApiClient.baseUrl}/stores/auth/verify-otp';
    final body = jsonEncode({
      'phone': phone,
      'otp': otp,
    });

    try {
      ApiClient.logRequest('POST', url, body: body);
      final response = await http
          .post(Uri.parse(url), headers: ApiClient.defaultHeaders, body: body)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      ApiClient.logError('POST', url, e);
      return {'success': false, 'message': 'Network connection error: $e'};
    }
  }

  static Future<bool> updateFcmToken({
    required String phone,
    required String fcmToken,
    String? userId,
    String? storeId,
  }) async {
    if (fcmToken.isEmpty) return false;
    final url = '${ApiClient.baseUrl}/stores/update-fcm-token';
    final body = jsonEncode({
      'phone': phone,
      'storeId': storeId ?? userId ?? '',
      'fcmToken': fcmToken,
      'role': 'store_owner',
    });

    try {
      ApiClient.logRequest('POST', url, body: body);
      final response = await http
          .post(Uri.parse(url), headers: ApiClient.defaultHeaders, body: body)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
      return response.statusCode == 200;
    } catch (e) {
      ApiClient.logError('POST', url, e);
      return false;
    }
  }

  static Future<bool> logout({
    required String userId,
    required String phone,
  }) async {
    final url = '${ApiClient.baseUrl}/auth/logout';
    final body = jsonEncode({
      'userId': userId,
      'phone': phone,
    });

    try {
      ApiClient.logRequest('POST', url, body: body);
      final response = await http
          .post(Uri.parse(url), headers: ApiClient.defaultHeaders, body: body)
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
      return response.statusCode == 200;
    } catch (e) {
      ApiClient.logError('POST', url, e);
      return false;
    }
  }
}
