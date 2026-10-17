import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class StoreWalletApiService {
  StoreWalletApiService._();

  /// Fetch store live wallet balance, transaction ledger, and sales summary metrics
  static Future<Map<String, dynamic>?> fetchStoreWallet(String storeId) async {
    if (storeId.isEmpty) return null;
    final url = '${ApiClient.baseUrl}/wallet/$storeId?role=store';
    ApiClient.logRequest('GET', url);

    try {
      final response = await http
          .get(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('GET', url, response.statusCode, response.body);
      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          return decoded as Map<String, dynamic>;
        }
      }
      return null;
    } catch (e) {
      ApiClient.logError('GET', url, e);
      return null;
    }
  }
}
