import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class ProductApiService {
  /// 1. Fetch all products for a specific store from backend
  static Future<List<Map<String, dynamic>>> fetchProductsByStore(
    String storeId, {
    String? storeType,
  }) async {
    if (storeId.trim().isEmpty) return [];
    final url = '${ApiClient.baseUrl}/products/store/$storeId';

    try {
      ApiClient.logRequest('GET', url);
      final response = await http
          .get(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('GET', url, response.statusCode, response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final rawProducts = (data['products'] as List? ?? []);

        return rawProducts
            .where((p) => p['isAvailable'] != false)
            .map<Map<String, dynamic>>((p) => normalizeProduct(p, defaultStoreId: storeId, storeType: storeType))
            .toList();
      }
    } catch (e) {
      ApiClient.logError('GET', url, e);
    }
    return [];
  }

  /// 2. Fetch single product details by productId
  static Future<Map<String, dynamic>?> fetchProductDetails(String productId) async {
    if (productId.trim().isEmpty) return null;
    final url = '${ApiClient.baseUrl}/products/$productId';

    try {
      ApiClient.logRequest('GET', url);
      final response = await http
          .get(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 6));

      ApiClient.logResponse('GET', url, response.statusCode, response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['product'] != null) {
          return normalizeProduct(data['product']);
        }
      }
    } catch (e) {
      ApiClient.logError('GET', url, e);
    }
    return null;
  }

  /// Normalizes product data from MongoDB into a uniform Map for the citizen app UI
  static Map<String, dynamic> normalizeProduct(
    dynamic raw, {
    String? defaultStoreId,
    String? storeType,
  }) {
    final p = Map<String, dynamic>.from(raw as Map);
    final double price = (p['price'] as num?)?.toDouble() ?? 0.0;
    final double origPrice = (p['originalPrice'] as num?)?.toDouble() ?? price;
    final int stock = (p['stock'] as num?)?.toInt() ?? 0;

    int discount = 0;
    if (p['discountPercentage'] is num) {
      discount = (p['discountPercentage'] as num).toInt();
    } else if (p['discountPercentage'] is String) {
      final match = RegExp(r'\d+').firstMatch(p['discountPercentage']);
      if (match != null) {
        discount = int.tryParse(match.group(0) ?? '') ?? 0;
      }
    }
    if (discount == 0 && origPrice > price && origPrice > 0) {
      discount = (((origPrice - price) / origPrice) * 100).round();
    }

    String stockBadge = '';
    if (stock <= 0) {
      stockBadge = 'Out of Stock';
    } else if (stock <= 3) {
      stockBadge = 'Only $stock left';
    }

    // Process multiple images
    List<String> images = [];
    if (p['images'] is List) {
      images = (p['images'] as List)
          .map((e) => e?.toString() ?? '')
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final primaryImg = (p['image'] != null && p['image'].toString().trim().isNotEmpty)
        ? p['image'].toString().trim()
        : '';
    if (images.isEmpty && primaryImg.isNotEmpty) {
      images = [primaryImg];
    }

    // Process variants
    List<Map<String, dynamic>> variants = [];
    if (p['variants'] is List) {
      variants = (p['variants'] as List)
          .map((v) => v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{})
          .where((v) => v.isNotEmpty)
          .toList();
    }

    return {
      'id': p['productId'] ?? p['_id'] ?? '',
      'productId': p['productId'] ?? p['_id'] ?? '',
      'title': p['title'] ?? 'Product',
      'price': price,
      'originalPrice': origPrice,
      'discountPercentage': discount,
      'stock': stock,
      'unit': p['unit'] ?? (variants.isNotEmpty ? (variants[0]['unit'] ?? '1 Units') : '1 Units'),
      'image': primaryImg.isNotEmpty ? primaryImg : (images.isNotEmpty ? images[0] : ''),
      'images': images,
      'hasVariants': p['hasVariants'] == true || variants.isNotEmpty,
      'variants': variants,
      'category': p['category'] ?? '',
      'stockBadge': stockBadge.isNotEmpty ? stockBadge : null,
      'brand': p['brand'] ?? 'Unbranded',
      'packOf': p['packOf'] ?? '1',
      'type': p['type'] ?? (storeType == 'medical' ? 'Medicine' : 'Grocery'),
      'shelfLife': p['shelfLife'] ?? '7 Days',
      'formFactor': p['formFactor'] ?? 'Standard',
      'origin': p['origin'] ?? 'India',
      'description': p['description'] ?? '',
      'isSubsidized': p['isSubsidized'] == true,
      'subsidyLimit': p['subsidyLimit'],
      'storeId': p['storeId'] ?? defaultStoreId ?? '',
    };
  }
}
