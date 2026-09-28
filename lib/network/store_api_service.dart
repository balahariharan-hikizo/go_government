import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class StoreApiService {
  /// 1. Fetch approved & online stores (optionally filtered by category)
  static Future<List<Map<String, dynamic>>> fetchApprovedStores({
    String? category,
    bool includeOffline = false,
  }) async {
    final queryParams = <String, String>{};
    if (category != null && category.isNotEmpty && category != 'all') {
      queryParams['category'] = category;
    }
    if (includeOffline) {
      queryParams['includeOffline'] = 'true';
    }

    final uri = Uri.parse('${ApiClient.baseUrl}/stores/approved').replace(
      queryParameters: queryParams.isNotEmpty ? queryParams : null,
    );
    final urlStr = uri.toString();

    try {
      ApiClient.logRequest('GET', urlStr);
      final response = await http
          .get(uri, headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('GET', urlStr, response.statusCode, response.body);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = body['stores'] as List? ?? [];
        return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      ApiClient.logError('GET', urlStr, e);
    }
    return [];
  }

  /// 2. Fetch single store details by storeId or MongoDB ID
  static Future<Map<String, dynamic>?> fetchStoreDetails(String storeId) async {
    if (storeId.trim().isEmpty) return null;
    final url = '${ApiClient.baseUrl}/stores/$storeId';

    try {
      ApiClient.logRequest('GET', url);
      final response = await http
          .get(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 6));

      ApiClient.logResponse('GET', url, response.statusCode, response.body);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['store'] != null) {
          return Map<String, dynamic>.from(body['store'] as Map);
        }
      }
    } catch (e) {
      ApiClient.logError('GET', url, e);
    }
    return null;
  }
}
