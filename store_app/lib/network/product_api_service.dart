import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/product_model.dart';
import 'api_client.dart';

class ProductApiService {
  ProductApiService._();

  static Future<List<ProductModel>> getProductsByStore(String storeId) async {
    final url = '${ApiClient.baseUrl}/products/store/$storeId';

    try {
      ApiClient.logRequest('GET', url);
      final response = await http
          .get(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('GET', url, response.statusCode, response.body);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final list = data['products'] as List<dynamic>? ?? [];
        return list.map((e) => ProductModel.fromJson(e as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      ApiClient.logError('GET', url, e);
    }
    return [];
  }

  static Future<Map<String, dynamic>?> addProduct(ProductModel product) async {
    final url = '${ApiClient.baseUrl}/products/create';
    final body = jsonEncode(product.toJson());

    try {
      ApiClient.logRequest('POST', url, body: body);
      final response = await http
          .post(Uri.parse(url), headers: ApiClient.defaultHeaders, body: body)
          .timeout(const Duration(seconds: 15));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      ApiClient.logError('POST', url, e);
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<Map<String, dynamic>?> updateProduct(ProductModel product) async {
    final url = '${ApiClient.baseUrl}/products/${product.productId}';
    final body = jsonEncode(product.toJson());

    try {
      ApiClient.logRequest('PATCH', url, body: body);
      final response = await http
          .patch(Uri.parse(url), headers: ApiClient.defaultHeaders, body: body)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('PATCH', url, response.statusCode, response.body);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      ApiClient.logError('PATCH', url, e);
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  static Future<bool> toggleAvailability(String productId, bool isAvailable) async {
    final url = '${ApiClient.baseUrl}/products/$productId';
    final body = jsonEncode({'isAvailable': isAvailable});

    try {
      ApiClient.logRequest('PATCH', url, body: body);
      final response = await http
          .patch(Uri.parse(url), headers: ApiClient.defaultHeaders, body: body)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('PATCH', url, response.statusCode, response.body);
      return response.statusCode == 200;
    } catch (e) {
      ApiClient.logError('PATCH', url, e);
      return false;
    }
  }

  static Future<bool> deleteProduct(String productId) async {
    final url = '${ApiClient.baseUrl}/products/$productId';

    try {
      ApiClient.logRequest('DELETE', url);
      final response = await http
          .delete(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('DELETE', url, response.statusCode, response.body);
      return response.statusCode == 200;
    } catch (e) {
      ApiClient.logError('DELETE', url, e);
      return false;
    }
  }

  static Future<bool> updateProductStock(String productId, int newStock) async {
    final url = '${ApiClient.baseUrl}/products/$productId';
    final body = jsonEncode({
      'stock': newStock,
      'isAvailable': newStock > 0,
    });

    try {
      ApiClient.logRequest('PATCH', url, body: body);
      final response = await http
          .patch(Uri.parse(url), headers: ApiClient.defaultHeaders, body: body)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('PATCH', url, response.statusCode, response.body);
      return response.statusCode == 200;
    } catch (e) {
      ApiClient.logError('PATCH', url, e);
      return false;
    }
  }
}
