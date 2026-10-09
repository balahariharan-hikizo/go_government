import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../hive/hive_service.dart';
import 'api_client.dart';

class CartWishlistApiService {
  static String _getUserId(String? userId) {
    if (userId != null && userId.isNotEmpty) return userId;
    final cid = HiveService.citizenId;
    return cid.isNotEmpty ? cid : 'GUEST_USER';
  }

  // ==========================================
  // CART APIS
  // ==========================================

  /// 1. Fetch user's cart from backend
  static Future<Map<String, dynamic>?> fetchCart([String? userId]) async {
    final uid = _getUserId(userId);
    final url = '${ApiClient.baseUrl}/cart/$uid';

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

  /// 2. Add product to cart (or increment quantity)
  static Future<bool> addToCart({
    required String productId,
    required Map<String, dynamic> product,
    int quantity = 1,
    String? userId,
  }) async {
    final uid = _getUserId(userId);
    final url = '${ApiClient.baseUrl}/cart/add';
    final basePid = productId.contains(':')
        ? productId.split(':').first
        : (product['productId'] ?? product['id'] ?? productId).toString();
    final vid = (product['variantId'] ?? (productId.contains(':') ? productId.split(':').last : '')).toString();
    final payload = jsonEncode({
      'userId': uid,
      'productId': basePid,
      'variantId': vid,
      'quantity': quantity,
      if (product['unit'] != null) 'unit': product['unit'].toString(),
      if (product['price'] != null) 'price': product['price'],
      'product': product,
    });

    try {
      ApiClient.logRequest('POST', url, body: payload);
      final response = await http
          .post(Uri.parse(url), headers: ApiClient.defaultHeaders, body: payload)
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
      return response.statusCode == 200;
    } catch (e) {
      ApiClient.logError('POST', url, e);
    }
    return false;
  }

  /// 3. Update quantity in cart (removes if qty <= 0)
  static Future<bool> updateQuantity({
    required String productId,
    required int quantity,
    Map<String, dynamic>? product,
    String? userId,
  }) async {
    final uid = _getUserId(userId);
    final url = '${ApiClient.baseUrl}/cart/update';
    final basePid = productId.contains(':')
        ? productId.split(':').first
        : (product?['productId'] ?? product?['id'] ?? productId).toString();
    final vid = (product?['variantId'] ?? (productId.contains(':') ? productId.split(':').last : '')).toString();
    final payload = jsonEncode({
      'userId': uid,
      'productId': basePid,
      'variantId': vid,
      'quantity': quantity,
      if (product != null && product['unit'] != null) 'unit': product['unit'].toString(),
      if (product != null && product['price'] != null) 'price': product['price'],
      'product': product ?? {},
    });

    try {
      ApiClient.logRequest('PUT', url, body: payload);
      final response = await http
          .put(Uri.parse(url), headers: ApiClient.defaultHeaders, body: payload)
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('PUT', url, response.statusCode, response.body);
      return response.statusCode == 200;
    } catch (e) {
      ApiClient.logError('PUT', url, e);
    }
    return false;
  }

  /// 4. Remove item from cart
  static Future<bool> removeFromCart({
    required String productId,
    String? userId,
  }) async {
    final uid = _getUserId(userId);
    final basePid = productId.contains(':') ? productId.split(':').first : productId;
    final vid = productId.contains(':') ? productId.split(':').last : '';
    final query = vid.isNotEmpty ? '?variantId=$vid' : '';
    final url = '${ApiClient.baseUrl}/cart/$uid/item/$basePid$query';

    try {
      ApiClient.logRequest('DELETE', url);
      final response = await http
          .delete(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('DELETE', url, response.statusCode, response.body);
      return response.statusCode == 200;
    } catch (e) {
      ApiClient.logError('DELETE', url, e);
    }
    return false;
  }

  /// 5. Clear full cart
  static Future<bool> clearCart([String? userId]) async {
    final uid = _getUserId(userId);
    final url = '${ApiClient.baseUrl}/cart/$uid/clear';

    try {
      ApiClient.logRequest('DELETE', url);
      final response = await http
          .delete(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('DELETE', url, response.statusCode, response.body);
      return response.statusCode == 200;
    } catch (e) {
      ApiClient.logError('DELETE', url, e);
    }
    return false;
  }

  /// 6. Bulk sync local cart to server
  static Future<bool> syncCart({
    required Map<String, int> cartItems,
    required Map<String, Map<String, dynamic>> productDetails,
    String? userId,
  }) async {
    final uid = _getUserId(userId);
    final url = '${ApiClient.baseUrl}/cart/$uid/sync';

    final items = cartItems.entries.map((e) {
      final id = e.key;
      final qty = e.value;
      final details = productDetails[id] ?? {'id': id};
      final basePid = id.contains(':') ? id.split(':').first : (details['productId'] ?? details['id'] ?? id).toString();
      final vid = (details['variantId'] ?? (id.contains(':') ? id.split(':').last : '')).toString();
      return {
        'productId': basePid,
        'variantId': vid,
        'quantity': qty,
        if (details['unit'] != null) 'unit': details['unit'].toString(),
        if (details['price'] != null) 'price': details['price'],
        'product': details,
      };
    }).toList();

    final payload = jsonEncode({'items': items});

    try {
      ApiClient.logRequest('POST', url, body: payload);
      final response = await http
          .post(Uri.parse(url), headers: ApiClient.defaultHeaders, body: payload)
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
      return response.statusCode == 200;
    } catch (e) {
      ApiClient.logError('POST', url, e);
    }
    return false;
  }

  // ==========================================
  // WISHLIST APIS
  // ==========================================

  /// 7. Fetch user's wishlist from backend
  static Future<Map<String, dynamic>?> fetchWishlist([String? userId]) async {
    final uid = _getUserId(userId);
    final url = '${ApiClient.baseUrl}/wishlist/$uid';

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

  /// 8. Toggle item in wishlist (Add if not present, remove if present)
  static Future<bool?> toggleWishlist({
    required String productId,
    required Map<String, dynamic> product,
    String? userId,
  }) async {
    final uid = _getUserId(userId);
    final url = '${ApiClient.baseUrl}/wishlist/toggle';
    final payload = jsonEncode({
      'userId': uid,
      'productId': productId,
      'product': product,
    });

    try {
      ApiClient.logRequest('POST', url, body: payload);
      final response = await http
          .post(Uri.parse(url), headers: ApiClient.defaultHeaders, body: payload)
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        return body['data']?['isFavorite'] as bool?;
      }
    } catch (e) {
      ApiClient.logError('POST', url, e);
    }
    return null;
  }

  /// 9. Bulk sync local favorites to server
  static Future<bool> syncWishlist({
    required Set<String> favoriteIds,
    required Map<String, Map<String, dynamic>> productDetails,
    String? userId,
  }) async {
    final uid = _getUserId(userId);
    final url = '${ApiClient.baseUrl}/wishlist/$uid/sync';

    final items = favoriteIds.map((id) {
      final details = productDetails[id] ?? {'id': id};
      return {
        'productId': id,
        'product': details,
      };
    }).toList();

    final payload = jsonEncode({'items': items});

    try {
      ApiClient.logRequest('POST', url, body: payload);
      final response = await http
          .post(Uri.parse(url), headers: ApiClient.defaultHeaders, body: payload)
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
      return response.statusCode == 200;
    } catch (e) {
      ApiClient.logError('POST', url, e);
    }
    return false;
  }
}
