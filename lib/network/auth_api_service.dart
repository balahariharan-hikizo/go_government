import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class AuthApiService {
  // 1. Send OTP
  static Future<Map<String, dynamic>?> sendOtp(String phone) async {
    final candidateHosts = ApiClient.candidateHosts;

    for (final host in candidateHosts) {
      final url = '$host/auth/send-otp';
      final payload = jsonEncode({'phone': phone});

      try {
        ApiClient.logRequest('POST', url, body: payload);

        final response = await http
            .post(
              Uri.parse(url),
              headers: ApiClient.defaultHeaders,
              body: payload,
            )
            .timeout(const Duration(seconds: 5));

        ApiClient.logResponse('POST', url, response.statusCode, response.body);

        if (response.statusCode == 200) {
          ApiClient.setBaseUrl(host);
          return jsonDecode(response.body);
        }
      } catch (e) {
        ApiClient.logError('POST', url, e);
      }
    }
    return null;
  }

  // 2. Verify OTP
  static Future<Map<String, dynamic>?> verifyOtp(String phone, String otp) async {
    final url = '${ApiClient.baseUrl}/auth/verify-otp';
    final payload = jsonEncode({'phone': phone, 'otp': otp});

    try {
      ApiClient.logRequest('POST', url, body: payload);

      final response = await http
          .post(
            Uri.parse(url),
            headers: ApiClient.defaultHeaders,
            body: payload,
          )
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (e) {
      ApiClient.logError('POST', url, e);
    }
    return null;
  }

  // 3. Get User Profile by User ID
  static Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final url = '${ApiClient.baseUrl}/auth/profile/$userId';
    try {
      ApiClient.logRequest('GET', url);

      final response = await http
          .get(
            Uri.parse(url),
            headers: ApiClient.defaultHeaders,
          )
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('GET', url, response.statusCode, response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          if (data['user'] is Map<String, dynamic>) {
            return data['user'] as Map<String, dynamic>;
          }
          return data;
        }
      }
    } catch (e) {
      ApiClient.logError('GET', url, e);
    }
    return null;
  }

  // 4. Update Profile
  static Future<bool> updateProfile({
    required String userId,
    required String userName,
    required String email,
    String? profileImage,
  }) async {
    final url = '${ApiClient.baseUrl}/auth/update-profile';
    final payload = jsonEncode({
      'userId': userId,
      'userName': userName,
      'email': email,
      'profileImage': profileImage,
    });

    try {
      ApiClient.logRequest('PUT', url, body: payload);

      final response = await http
          .put(
            Uri.parse(url),
            headers: ApiClient.defaultHeaders,
            body: payload,
          )
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
      return response.statusCode == 200;
    } catch (e) {
      ApiClient.logError('POST', url, e);
      return false;
    }
  }

  // 4. Upload Profile Image
  static Future<String?> uploadProfileImage(String localPath) async {
    final file = File(localPath);
    if (!file.existsSync()) {
      ApiClient.logError('UPLOAD', localPath, 'File does not exist locally');
      return localPath;
    }

    final url = '${ApiClient.baseUrl}/upload/profile';
    try {
      ApiClient.logRequest('MULTIPART POST', url, body: 'File: $localPath');

      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.files.add(await http.MultipartFile.fromPath('image', localPath));

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      ApiClient.logResponse('MULTIPART POST', url, response.statusCode, response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['imageUrl'] as String?;
      }
    } catch (e) {
      ApiClient.logError('MULTIPART POST', url, e);
    }
    return localPath;
  }

  // 5. Send Phone Update OTP
  static Future<Map<String, dynamic>?> sendPhoneUpdateOtp({
    required String userId,
    required String newPhone,
    String? currentPhone,
  }) async {
    final url = '${ApiClient.baseUrl}/auth/send-phone-update-otp';
    final payload = jsonEncode({
      'userId': userId,
      'newPhone': newPhone,
      if (currentPhone != null && currentPhone.isNotEmpty) 'currentPhone': currentPhone,
    });

    try {
      ApiClient.logRequest('POST', url, body: payload);

      final response = await http
          .post(
            Uri.parse(url),
            headers: ApiClient.defaultHeaders,
            body: payload,
          )
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data as Map<String, dynamic>;
      } else {
        return {'success': false, 'message': data['error'] ?? data['message'] ?? 'Failed to send OTP'};
      }
    } catch (e) {
      ApiClient.logError('POST', url, e);
      return {'success': false, 'message': 'Connection error. Please try again.'};
    }
  }

  // 6. Verify Phone Update OTP & Save
  static Future<Map<String, dynamic>?> verifyPhoneUpdateOtp({
    required String userId,
    required String newPhone,
    required String otp,
    String? currentPhone,
  }) async {
    final url = '${ApiClient.baseUrl}/auth/verify-phone-update-otp';
    final payload = jsonEncode({
      'userId': userId,
      'newPhone': newPhone,
      'otp': otp,
      if (currentPhone != null && currentPhone.isNotEmpty) 'currentPhone': currentPhone,
    });

    try {
      ApiClient.logRequest('POST', url, body: payload);

      final response = await http
          .post(
            Uri.parse(url),
            headers: ApiClient.defaultHeaders,
            body: payload,
          )
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200) {
        return data as Map<String, dynamic>;
      } else {
        return {'success': false, 'message': data['error'] ?? data['message'] ?? 'Failed to verify OTP'};
      }
    } catch (e) {
      ApiClient.logError('POST', url, e);
      return {'success': false, 'message': 'Connection error. Please try again.'};
    }
  }

  /// 6. Update FCM token for push notifications
  static Future<bool> updateFcmToken({
    required String fcmToken,
    String? userId,
    String? phone,
    String? storeId,
    String role = 'citizen',
  }) async {
    final url = '${ApiClient.baseUrl}/auth/update-fcm-token';
    final payload = jsonEncode({
      if (userId != null && userId.isNotEmpty) 'userId': userId,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (storeId != null && storeId.isNotEmpty) 'storeId': storeId,
      'fcmToken': fcmToken,
      'role': role,
    });

    try {
      ApiClient.logRequest('POST', url, body: payload);
      final response = await http
          .post(
            Uri.parse(url),
            headers: ApiClient.defaultHeaders,
            body: payload,
          )
          .timeout(const Duration(seconds: 6));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      ApiClient.logError('POST', url, e);
      return false;
    }
  }
}
