import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class StoreOrderApiService {
  // Fetch all orders for this store
  static Future<List<Map<String, dynamic>>> fetchStoreOrders(String storeId) async {
    if (storeId.isEmpty) return [];
    final url = '${ApiClient.baseUrl}/orders/store/$storeId';
    ApiClient.logRequest('GET', url);

    try {
      final response = await http
          .get(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('GET', url, response.statusCode, response.body);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        final list = decoded['data'] as List? ?? [];
        return list.map((i) => Map<String, dynamic>.from(i)).toList();
      }
      return [];
    } catch (e) {
      ApiClient.logError('GET', url, e);
      return [];
    }
  }

  // Update order status (e.g. preparing, ready_for_pickup)
  static Future<bool> updateOrderStatus({
    required String orderId,
    required String status,
    String? note,
  }) async {
    final url = '${ApiClient.baseUrl}/orders/$orderId/status';
    final body = {
      'status': status,
      'note': ?note,
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

  static Future<Map<String, dynamic>?> fetchStoreFinancialMetrics(String storeId) async {
    if (storeId.isEmpty) return null;
    final url = '${ApiClient.baseUrl}/orders/store/$storeId';
    ApiClient.logRequest('GET', url);

    try {
      final response = await http
          .get(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('GET', url, response.statusCode, response.body);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded['summary'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      ApiClient.logError('GET', url, e);
      return null;
    }
  }

  // 4. Confirm Return Received from Rider & Restock Products (POST /orders/:orderId/store-confirm-return)
  static Future<Map<String, dynamic>> confirmReturn({
    required String orderId,
    required String storeId,
    String? condition,
    String? notes,
  }) async {
    final url = '${ApiClient.baseUrl}/orders/$orderId/store-confirm-return';
    final body = {
      'storeId': storeId,
      'condition': condition ?? 'good',
      'notes': notes ?? '',
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
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'message': 'Failed to confirm return (${response.statusCode})'};
    } catch (e) {
      ApiClient.logError('POST', url, e);
      return {'success': false, 'message': e.toString()};
    }
  }

  // 5. Review Citizen Return Request (Approve or Reject) (POST /orders/:orderId/store-review-return)
  static Future<Map<String, dynamic>> reviewCitizenReturn({
    required String orderId,
    required String storeId,
    required String action, // 'approve' | 'reject'
    String? rejectionReason,
  }) async {
    final url = '${ApiClient.baseUrl}/orders/$orderId/store-review-return';
    final body = {
      'storeId': storeId,
      'action': action,
      'rejectionReason': rejectionReason ?? '',
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
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return {'success': false, 'message': 'Failed to review return (${response.statusCode})'};
    } catch (e) {
      ApiClient.logError('POST', url, e);
      return {'success': false, 'message': e.toString()};
    }
  }
}
