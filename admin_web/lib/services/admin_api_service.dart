import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AdminApiService {
  static String _baseUrl = 'http://192.168.1.11:5000';
  static String? _token;
  static Map<String, dynamic>? _currentAdmin;

  static String get baseUrl => _baseUrl;
  static String? get token => _token;
  static Map<String, dynamic>? get currentAdmin => _currentAdmin;
  static bool get isLoggedIn => _token != null && _token!.trim().isNotEmpty;
  static bool get isSuperAdmin =>
      _currentAdmin?['role'] == 'SUPER_ADMIN' || _currentAdmin?['adminId'] == 'ADM_00001';

  static const String _tokenPrefKey = 'gogov_admin_jwt_token';
  static const String _adminPrefKey = 'gogov_admin_profile_data';

  // Global callback for automatic logout when 401 occurs
  static VoidCallback? onUnauthorized;

  static Future<void> init() async {
    try {
      if (kIsWeb && Uri.base.host.isNotEmpty) {
        _baseUrl = '${Uri.base.scheme}://${Uri.base.host}:5000';
      }
      debugPrint('🏛️ [AdminApiService] Base URL initialized to: $_baseUrl');

      final prefs = await SharedPreferences.getInstance();
      _token = prefs.getString(_tokenPrefKey);
      final adminJson = prefs.getString(_adminPrefKey);
      if (adminJson != null && adminJson.isNotEmpty) {
        _currentAdmin = jsonDecode(adminJson) as Map<String, dynamic>;
      }
      debugPrint('🔐 [AdminApiService] Session loaded: LoggedIn=$isLoggedIn, Admin=${_currentAdmin?['adminId']}');
    } catch (e) {
      debugPrint('⚠️ [AdminApiService] Init error: $e');
    }
  }

  // Common Headers with JWT Bearer Token
  static Map<String, String> get headers {
    final map = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (_token != null && _token!.isNotEmpty) {
      map['Authorization'] = 'Bearer $_token';
    }
    return map;
  }

  // Intercept 401 Unauthorized for Auto-Logout
  static void _checkUnauthorized(int statusCode) {
    if (statusCode == 401) {
      debugPrint('⚠️ [AdminApiService] 401 Unauthorized received. Triggering auto-logout.');
      logout();
      onUnauthorized?.call();
    }
  }

  // ==========================================
  // AUTHENTICATION APIs
  // ==========================================

  // 1. Admin Login
  static Future<Map<String, dynamic>> login(String username, String password) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/admin/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username.trim(),
          'password': password.trim(),
        }),
      );

      final body = jsonDecode(res.body);

      if (res.statusCode == 200 && body['success'] == true) {
        _token = body['token'];
        _currentAdmin = Map<String, dynamic>.from(body['admin'] ?? {});

        final prefs = await SharedPreferences.getInstance();
        if (_token != null) await prefs.setString(_tokenPrefKey, _token!);
        if (_currentAdmin != null) await prefs.setString(_adminPrefKey, jsonEncode(_currentAdmin));

        return {'success': true, 'admin': _currentAdmin};
      }

      return {
        'success': false,
        'error': body['message'] ?? body['error'] ?? 'Login failed. Please check credentials.',
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // 2. Create New Admin (Protected)
  static Future<Map<String, dynamic>> createAdmin({
    required String username,
    required String password,
    String? name,
    String role = 'OFFICER',
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/admin/auth/create-admin'),
        headers: headers,
        body: jsonEncode({
          'username': username.trim(),
          'password': password.trim(),
          'name': name?.trim(),
          'role': role,
        }),
      );

      _checkUnauthorized(res.statusCode);
      final body = jsonDecode(res.body);

      if (res.statusCode == 201 && body['success'] == true) {
        return {'success': true, 'admin': body['admin']};
      }

      return {
        'success': false,
        'error': body['message'] ?? body['error'] ?? 'Failed to create admin.',
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // 3. List All Admins / Officers (Protected)
  static Future<Map<String, dynamic>> listAdmins() async {
    try {
      final res = await http.get(
        Uri.parse('$_baseUrl/admin/auth/list'),
        headers: headers,
      );

      _checkUnauthorized(res.statusCode);
      final body = jsonDecode(res.body);

      if (res.statusCode == 200 && body['success'] == true) {
        return {
          'success': true,
          'admins': List<Map<String, dynamic>>.from(body['admins'] ?? []),
        };
      }

      return {
        'success': false,
        'error': body['message'] ?? 'Failed to fetch officers list',
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // 4. Master Admin Resets Officer Password (ADM_00001 only)
  static Future<Map<String, dynamic>> resetOfficerPassword({
    required String targetAdminId,
    required String newPassword,
  }) async {
    try {
      final res = await http.patch(
        Uri.parse('$_baseUrl/admin/auth/reset-officer-password'),
        headers: headers,
        body: jsonEncode({
          'targetAdminId': targetAdminId.trim(),
          'newPassword': newPassword.trim(),
        }),
      );

      _checkUnauthorized(res.statusCode);
      final body = jsonDecode(res.body);

      if (res.statusCode == 200 && body['success'] == true) {
        return {'success': true, 'message': body['message']};
      }

      return {
        'success': false,
        'error': body['message'] ?? body['error'] ?? 'Failed to reset officer password',
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // 5. Any Officer Changes Their Own Password (Requires current password)
  static Future<Map<String, dynamic>> changeMyPassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final res = await http.patch(
        Uri.parse('$_baseUrl/admin/auth/change-my-password'),
        headers: headers,
        body: jsonEncode({
          'currentPassword': currentPassword.trim(),
          'newPassword': newPassword.trim(),
        }),
      );

      _checkUnauthorized(res.statusCode);
      final body = jsonDecode(res.body);

      if (res.statusCode == 200 && body['success'] == true) {
        return {'success': true, 'message': body['message']};
      }

      return {
        'success': false,
        'error': body['message'] ?? body['error'] ?? 'Failed to change password',
      };
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // 6. Logout
  static Future<void> logout() async {
    _token = null;
    _currentAdmin = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenPrefKey);
      await prefs.remove(_adminPrefKey);
    } catch (_) {}
    debugPrint('🚪 [AdminApiService] Admin logged out successfully.');
  }

  // ==========================================
  // MUNICIPAL MANAGEMENT APIs
  // ==========================================

  // 1. Fetch All Stores with Stats
  static Future<Map<String, dynamic>> getAllStores({String? status}) async {
    try {
      final query = status != null && status.isNotEmpty ? '?status=$status' : '';
      final res = await http.get(Uri.parse('$_baseUrl/stores/all$query'), headers: headers);
      _checkUnauthorized(res.statusCode);
      if (res.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(res.body)};
      }
      return {'success': false, 'error': 'Server error: ${res.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // 2. Fetch Pending Stores
  static Future<List<Map<String, dynamic>>> getPendingStores() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/stores/pending'), headers: headers);
      _checkUnauthorized(res.statusCode);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return List<Map<String, dynamic>>.from(body['stores'] ?? []);
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching pending stores: $e');
      return [];
    }
  }

  // 3. Approve / Reject Store
  static Future<Map<String, dynamic>> updateStoreStatus({
    required String storeId,
    required String status,
    String? rejectionReason,
    String? verifiedBy,
  }) async {
    try {
      final officerName = verifiedBy ??
          (_currentAdmin?['name'] != null
              ? '${_currentAdmin!['name']} (${_currentAdmin!['adminId']})'
              : 'Chief Municipal Officer');

      final res = await http.patch(
        Uri.parse('$_baseUrl/stores/$storeId/status'),
        headers: headers,
        body: jsonEncode({
          'status': status,
          'rejectionReason': rejectionReason ?? '',
          'verifiedBy': officerName,
        }),
      );

      _checkUnauthorized(res.statusCode);
      final body = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return {'success': true, 'store': body['store']};
      }
      return {'success': false, 'error': body['error'] ?? 'Action failed'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // 4. Fetch All Complaints with optional status filter
  static Future<Map<String, dynamic>> getAllComplaints({String? status}) async {
    try {
      final query = status != null && status.isNotEmpty && status != 'all'
          ? '?status=${Uri.encodeComponent(status)}'
          : '';
      final res = await http.get(Uri.parse('$_baseUrl/complaints/all$query'), headers: headers);
      _checkUnauthorized(res.statusCode);
      if (res.statusCode == 200) {
        final dynamic decoded = jsonDecode(res.body);
        final List<dynamic> list = decoded is List
            ? decoded
            : (decoded is Map ? (decoded['complaints'] as List<dynamic>? ?? []) : []);
        return {'success': true, 'complaints': List<Map<String, dynamic>>.from(list)};
      }
      return {'success': false, 'error': 'Server error: ${res.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // 5. Fetch Complaint Statistics (Totals by Status)
  static Future<Map<String, dynamic>> getComplaintStats() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/complaints/meta/stats'), headers: headers);
      _checkUnauthorized(res.statusCode);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return {'success': true, 'stats': Map<String, dynamic>.from(body['stats'] ?? {})};
      }
      return {'success': false, 'error': 'Failed to fetch complaint stats'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // 6. Update Complaint Status
  static Future<Map<String, dynamic>> updateComplaintStatus({
    required String complaintId,
    required String status,
    String? adminNotes,
    String? updatedBy,
  }) async {
    try {
      final officerName = updatedBy ??
          (_currentAdmin?['name'] != null
              ? '${_currentAdmin!['name']} (${_currentAdmin!['adminId']})'
              : 'Chief Municipal Officer');

      final res = await http.patch(
        Uri.parse('$_baseUrl/complaints/$complaintId/status'),
        headers: headers,
        body: jsonEncode({
          'status': status,
          'adminNotes': adminNotes ?? '',
          'updatedBy': officerName,
        }),
      );

      _checkUnauthorized(res.statusCode);
      final body = jsonDecode(res.body);
      if (res.statusCode == 200) {
        return {'success': true, 'complaint': body['complaint']};
      }
      return {'success': false, 'error': body['error'] ?? 'Failed to update status'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // 7. Fetch All Citizen Feedback
  static Future<Map<String, dynamic>> getAllFeedback({String? type, String? rating, String? search}) async {
    try {
      final params = <String>[];
      if (type != null && type.isNotEmpty && type != 'all') params.add('type=$type');
      if (rating != null && rating.isNotEmpty && rating != 'all') params.add('rating=$rating');
      if (search != null && search.isNotEmpty) params.add('search=${Uri.encodeComponent(search)}');
      final query = params.isNotEmpty ? '?${params.join('&')}' : '';

      final res = await http.get(Uri.parse('$_baseUrl/feedback/all$query'), headers: headers);
      _checkUnauthorized(res.statusCode);
      if (res.statusCode == 200) {
        return {'success': true, 'data': jsonDecode(res.body)};
      }
      return {'success': false, 'error': 'Server error: ${res.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // 8. Fetch Feedback KPI Stats
  static Future<Map<String, dynamic>> getFeedbackStats() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/feedback/stats'), headers: headers);
      _checkUnauthorized(res.statusCode);
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return {'success': true, 'stats': body['stats']};
      }
      return {'success': false, 'error': 'Server error: ${res.statusCode}'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // Helper to normalize image URLs for web browser display
  static String normalizeImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    final trimmed = url.trim();

    if (trimmed.startsWith('/uploads/') || trimmed.startsWith('uploads/')) {
      final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
      final serverOrigin = _baseUrl.replaceAll('/api', '');
      return '$serverOrigin$cleanPath';
    }

    if (trimmed.contains('/uploads/')) {
      final serverOrigin = _baseUrl.replaceAll('/api', '');
      final uploadsIndex = trimmed.indexOf('/uploads/');
      return '$serverOrigin${trimmed.substring(uploadsIndex)}';
    }

    return trimmed;
  }

  // 9. Fetch Live Rider Locations
  static Future<Map<String, dynamic>> getLiveRiders() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/orders/riders/live-locations'), headers: headers);
      _checkUnauthorized(res.statusCode);
      debugPrint('📡 [AdminApiService] GET /orders/riders/live-locations status: ${res.statusCode}');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = body['riders'] as List? ?? body['data'] as List? ?? [];
        return {
          'success': true,
          'riders': List<Map<String, dynamic>>.from(list),
          'data': body,
        };
      }
      return {'success': false, 'riders': [], 'error': 'Server error: ${res.statusCode}'};
    } catch (e) {
      debugPrint('⚠️ [AdminApiService] getLiveRiders error: $e');
      return {'success': false, 'riders': [], 'error': 'Connection error: $e'};
    }
  }

  // 10. Fetch All Orders for Live Monitoring
  static Future<Map<String, dynamic>> getAllOrders() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/orders/all'), headers: headers);
      _checkUnauthorized(res.statusCode);
      debugPrint('📦 [AdminApiService] GET /orders status: ${res.statusCode}');
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        final list = body['data'] as List? ?? body['orders'] as List? ?? [];
        return {
          'success': true,
          'orders': List<Map<String, dynamic>>.from(list),
        };
      }
      return {'success': false, 'orders': [], 'error': 'Server error: ${res.statusCode}'};
    } catch (e) {
      debugPrint('⚠️ [AdminApiService] getAllOrders error: $e');
      return {'success': false, 'orders': [], 'error': 'Connection error: $e'};
    }
  }
}
