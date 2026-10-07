import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/store_model.dart';
import 'api_client.dart';

class StoreApiService {
  StoreApiService._();

  static Future<Map<String, dynamic>?> registerStore(StoreModel store) async {
    final url = '${ApiClient.baseUrl}/stores/register';
    final body = jsonEncode(store.toJson());

    try {
      ApiClient.logRequest('POST', url, body: body);
      final response = await http
          .post(Uri.parse(url), headers: ApiClient.defaultHeaders, body: body)
          .timeout(const Duration(seconds: 15));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      ApiClient.logError('POST', url, e);
      return {'success': false, 'error': 'Network connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>?> getMyStore(String identifier) async {
    final url = '${ApiClient.baseUrl}/stores/my-store/$identifier';

    try {
      ApiClient.logRequest('GET', url);
      final response = await http
          .get(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('GET', url, response.statusCode, response.body);
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      if (response.statusCode == 404) {
        decoded['notFound'] = true;
      }
      return decoded;
    } catch (e) {
      ApiClient.logError('GET', url, e);
      return {'success': false, 'error': 'Network connection error: $e'};
    }
  }

  static Future<Map<String, dynamic>?> updateOnlineStatus(String storeId, bool isOnline) async {
    final url = '${ApiClient.baseUrl}/stores/$storeId/online';
    final body = jsonEncode({'isOnline': isOnline});

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

  static Future<String?> uploadStoreImage(String localPath) async {
    final url = '${ApiClient.baseUrl}/upload/store';
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
    return null;
  }

  static Future<List<String>> uploadMultipleProductImages(List<String> localPaths) async {
    if (localPaths.isEmpty) return [];
    final url = '${ApiClient.baseUrl}/upload/product';
    try {
      ApiClient.logRequest('MULTIPART POST', url, body: 'Files count: ${localPaths.length}');

      final request = http.MultipartRequest('POST', Uri.parse(url));
      for (final path in localPaths) {
        request.files.add(await http.MultipartFile.fromPath('images', path));
      }

      final streamed = await request.send();
      final response = await http.Response.fromStream(streamed);

      ApiClient.logResponse('MULTIPART POST', url, response.statusCode, response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final list = data['imageUrls'] as List? ?? [];
        return list.map((e) => e.toString()).toList();
      }
    } catch (e) {
      ApiClient.logError('MULTIPART POST', url, e);
    }
    return [];
  }

  static Future<Map<String, dynamic>?> updateStoreProfile(String storeId, Map<String, dynamic> updates) async {
    final url = '${ApiClient.baseUrl}/stores/$storeId/update-profile';
    final body = jsonEncode(updates);

    try {
      ApiClient.logRequest('PUT', url, body: body);
      final response = await http
          .put(Uri.parse(url), headers: ApiClient.defaultHeaders, body: body)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('PUT', url, response.statusCode, response.body);
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      ApiClient.logError('PUT', url, e);
      return {'success': false, 'error': 'Network error: $e'};
    }
  }
}
