import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/category_model.dart';
import 'api_client.dart';

class CategoryApiService {
  CategoryApiService._();

  /// 1. Fetch all non-deleted categories for a store
  static Future<List<CategoryModel>> getCategoriesByStore(String storeId, {bool activeOnly = false}) async {
    final query = activeOnly ? '?activeOnly=true' : '';
    final url = '${ApiClient.baseUrl}/categories/store/$storeId$query';

    try {
      ApiClient.logRequest('GET', url);
      final response = await http
          .get(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('GET', url, response.statusCode, response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['categories'] is List) {
          return (data['categories'] as List)
              .map((c) => CategoryModel.fromJson(c as Map<dynamic, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      ApiClient.logError('GET', url, e);
      return [];
    }
  }

  /// 2. Create new category for store
  static Future<Map<String, dynamic>> createCategory({
    required String storeId,
    required String name,
    String description = '',
    String icon = '',
    String image = '',
    int displayOrder = 0,
    bool isActive = true,
  }) async {
    final url = '${ApiClient.baseUrl}/categories/create';
    final payload = jsonEncode({
      'storeId': storeId,
      'name': name.trim(),
      'description': description.trim(),
      'icon': icon,
      'image': image,
      'displayOrder': displayOrder,
      'isActive': isActive,
    });

    try {
      ApiClient.logRequest('POST', url);
      final response = await http
          .post(Uri.parse(url), headers: ApiClient.defaultHeaders, body: payload)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);

      final data = jsonDecode(response.body);
      if (response.statusCode == 201 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Category created successfully',
          'category': CategoryModel.fromJson(data['category']),
        };
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Failed to create category',
      };
    } catch (e) {
      ApiClient.logError('POST', url, e);
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 3. Update existing category
  static Future<Map<String, dynamic>> updateCategory(
    String categoryId, {
    String? name,
    String? description,
    String? icon,
    String? image,
    int? displayOrder,
    bool? isActive,
  }) async {
    final url = '${ApiClient.baseUrl}/categories/$categoryId';
    final Map<String, dynamic> body = {};
    if (name != null) body['name'] = name.trim();
    if (description != null) body['description'] = description.trim();
    if (icon != null) body['icon'] = icon;
    if (image != null) body['image'] = image;
    if (displayOrder != null) body['displayOrder'] = displayOrder;
    if (isActive != null) body['isActive'] = isActive;

    final payload = jsonEncode(body);

    try {
      ApiClient.logRequest('PUT', url);
      final response = await http
          .put(Uri.parse(url), headers: ApiClient.defaultHeaders, body: payload)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('PUT', url, response.statusCode, response.body);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Category updated successfully',
          'category': CategoryModel.fromJson(data['category']),
        };
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Failed to update category',
      };
    } catch (e) {
      ApiClient.logError('PUT', url, e);
      return {'success': false, 'error': e.toString()};
    }
  }

  /// 4. Soft delete category
  static Future<Map<String, dynamic>> deleteCategory(String categoryId) async {
    final url = '${ApiClient.baseUrl}/categories/$categoryId';

    try {
      ApiClient.logRequest('DELETE', url);
      final response = await http
          .delete(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('DELETE', url, response.statusCode, response.body);

      final data = jsonDecode(response.body);
      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'message': data['message'] ?? 'Category deleted',
        };
      }
      return {
        'success': false,
        'error': data['error'] ?? 'Failed to delete category',
      };
    } catch (e) {
      ApiClient.logError('DELETE', url, e);
      return {'success': false, 'error': e.toString()};
    }
  }
}
