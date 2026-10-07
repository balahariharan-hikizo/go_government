import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../hive/hive_service.dart';
import 'api_client.dart';

class OrderApiService {
  static String _getUserId(String? userId) {
    if (userId != null && userId.isNotEmpty) return userId;
    final cid = HiveService.citizenId;
    return cid.isNotEmpty ? cid : 'GUEST_USER';
  }

  /// 1. Create a new order in backend
  static Future<Map<String, dynamic>?> createOrder({
    required String storeId,
    required List<Map<String, dynamic>> items,
    required double itemTotal,
    double deliveryCharge = 0,
    double handlingCharge = 2,
    double couponDiscount = 0,
    double coinsDiscount = 0,
    required double grandTotal,
    String paymentMethod = 'Cash on Delivery',
    required Map<String, dynamic> deliveryAddress,
    Map<String, dynamic>? storeDetails,
    String? userId,
  }) async {
    final uid = _getUserId(userId);
    final url = '${ApiClient.baseUrl}/orders/create';

    final payload = jsonEncode({
      'userId': uid,
      'storeId': storeId,
      'items': items,
      'itemTotal': itemTotal,
      'deliveryCharge': deliveryCharge,
      'handlingCharge': handlingCharge,
      'couponDiscount': couponDiscount,
      'coinsDiscount': coinsDiscount,
      'grandTotal': grandTotal,
      'paymentMethod': paymentMethod,
      'deliveryAddress': deliveryAddress,
      'storeDetails': storeDetails ?? {},
    });

    try {
      ApiClient.logRequest('POST', url, body: payload);
      final response = await http
          .post(Uri.parse(url), headers: ApiClient.defaultHeaders, body: payload)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        return body['data'] as Map<String, dynamic>?;
      }
    } catch (e) {
      ApiClient.logError('POST', url, e);
    }
    return null;
  }

  /// 2. Fetch all orders for current user
  static Future<List<Map<String, dynamic>>> fetchUserOrders([String? userId]) async {
    final uid = _getUserId(userId);
    final url = '${ApiClient.baseUrl}/orders/user/$uid';

    try {
      ApiClient.logRequest('GET', url);
      final response = await http
          .get(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('GET', url, response.statusCode, response.body);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = (body['data'] as List<dynamic>?) ?? [];
        return list.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      }
    } catch (e) {
      ApiClient.logError('GET', url, e);
    }
    return [];
  }

  /// 3. Fetch single order details
  static Future<Map<String, dynamic>?> fetchOrderDetails(String orderId) async {
    final url = '${ApiClient.baseUrl}/orders/$orderId';

    try {
      ApiClient.logRequest('GET', url);
      final response = await http
          .get(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('GET', url, response.statusCode, response.body);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data'] as Map<String, dynamic>?;
      }
    } catch (e) {
      ApiClient.logError('GET', url, e);
    }
    return null;
  }
  /// 4. Update order status (e.g. cancel order)
  static Future<bool> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    final url = '${ApiClient.baseUrl}/orders/$orderId/status';
    final payload = jsonEncode({'status': status});

    try {
      ApiClient.logRequest('PATCH', url, body: payload);
      final response = await http
          .patch(Uri.parse(url), headers: ApiClient.defaultHeaders, body: payload)
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('PATCH', url, response.statusCode, response.body);
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (e) {
      ApiClient.logError('PATCH', url, e);
      return false;
    }
  }
}
