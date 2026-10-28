import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class CategoryApiService {
  CategoryApiService._();

  /// 1. Fetch active categories for a store (Includes productCount per category)
  static Future<List<Map<String, dynamic>>> fetchCategoriesByStore(
    String storeId, {
    bool activeOnly = true,
  }) async {
    if (storeId.trim().isEmpty) return [];

    final query = activeOnly ? '?activeOnly=true' : '';
    final url = '${ApiClient.baseUrl}/categories/store/$storeId$query';

    try {
      ApiClient.logRequest('GET', url);
      final response = await http
          .get(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('GET', url, response.statusCode, response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['categories'] is List) {
          final list = (data['categories'] as List)
              .map((c) => Map<String, dynamic>.from(c as Map))
              .toList();
          return list;
        }
      }
    } catch (e) {
      ApiClient.logError('GET', url, e);
    }
    return [];
  }
}
