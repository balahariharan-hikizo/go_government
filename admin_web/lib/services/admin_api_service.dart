import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AdminApiService {
  static const List<String> candidateBases = [
    'http://localhost:5000/api',
    'http://127.0.0.1:5000/api',
    'http://192.168.1.12:5000/api',
    'http://192.168.1.11:5000/api',
  ];

  static String _baseUrl = 'http://localhost:5000/api';


  static String get baseUrl => _baseUrl;

  static Future<void> init() async {
    for (final host in candidateBases) {
      try {
        final res = await http.get(Uri.parse('$host/health')).timeout(const Duration(milliseconds: 1200));
        if (res.statusCode == 200) {
          _baseUrl = host;
          debugPrint('🏛️ [AdminApiService] Connected to: $_baseUrl');
          return;
        }
      } catch (_) {}
    }
  }

  // 1. Fetch All Stores with Stats
  static Future<Map<String, dynamic>> getAllStores({String? status}) async {
    try {
      final query = status != null && status.isNotEmpty ? '?status=$status' : '';
      final res = await http.get(Uri.parse('$_baseUrl/stores$query'));
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
      final res = await http.get(Uri.parse('$_baseUrl/stores/pending'));
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
    String verifiedBy = 'Chief Municipal Officer',
  }) async {
    try {
      final res = await http.patch(
        Uri.parse('$_baseUrl/stores/$storeId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status': status,
          'rejectionReason': rejectionReason ?? '',
          'verifiedBy': verifiedBy,
        }),
      );

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
      final res = await http.get(Uri.parse('$_baseUrl/complaints/all$query'));
      if (res.statusCode == 200) {
        final list = jsonDecode(res.body);
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
      final res = await http.get(Uri.parse('$_baseUrl/complaints/meta/stats'));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        return {'success': true, 'stats': Map<String, dynamic>.from(body['stats'] ?? {})};
      }
      return {'success': false, 'error': 'Failed to fetch complaint stats'};
    } catch (e) {
      return {'success': false, 'error': 'Connection error: $e'};
    }
  }

  // 6. Update Complaint Status (Under Review, In Progress, Resolved, Rejected)
  static Future<Map<String, dynamic>> updateComplaintStatus({
    required String complaintId,
    required String status,
    String? adminNotes,
    String updatedBy = 'Chief Municipal Officer',
  }) async {
    try {
      final res = await http.patch(
        Uri.parse('$_baseUrl/complaints/$complaintId/status'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'status': status,
          'adminNotes': adminNotes ?? '',
          'updatedBy': updatedBy,
        }),
      );

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

      final res = await http.get(Uri.parse('$_baseUrl/feedback/all$query'));
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
      final res = await http.get(Uri.parse('$_baseUrl/feedback/stats'));
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
      final res = await http.get(Uri.parse('$_baseUrl/orders/riders/live-locations'));
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
      final res = await http.get(Uri.parse('$_baseUrl/orders/all'));
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

