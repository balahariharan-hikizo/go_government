import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../hive/hive_service.dart';
import '../model/address_model.dart';
import 'api_client.dart';

class AddressApiService {
  // 1. Fetch addresses for a user
  static Future<List<AddressModel>> fetchAddresses([String? userId]) async {
    final uid = (userId != null && userId.isNotEmpty) ? userId : HiveService.citizenId;
    if (uid.isEmpty) return [];

    final url = '${ApiClient.baseUrl}/addresses/$uid';
    try {
      ApiClient.logRequest('GET', url);

      final response = await http
          .get(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('GET', url, response.statusCode, response.body);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final list = (body['data'] as List<dynamic>?) ?? [];
        return list.map((item) => AddressModel.fromMap(item as Map<String, dynamic>)).toList();
      }
    } catch (e) {
      ApiClient.logError('GET', url, e);
    }
    return [];
  }

  // 2. Add a new address
  static Future<AddressModel?> addAddress(AddressModel address, {String? userId}) async {
    final uid = (userId != null && userId.isNotEmpty) ? userId : HiveService.citizenId;
    final url = '${ApiClient.baseUrl}/addresses/create';

    final payloadMap = address.toMap();
    payloadMap['userId'] = uid;
    final payload = jsonEncode(payloadMap);

    try {
      ApiClient.logRequest('POST', url, body: payload);

      final response = await http
          .post(Uri.parse(url), headers: ApiClient.defaultHeaders, body: payload)
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        final body = jsonDecode(response.body);
        if (body['data'] != null) {
          return AddressModel.fromMap(body['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      ApiClient.logError('POST', url, e);
    }
    return null;
  }

  // 3. Update an existing address
  static Future<AddressModel?> updateAddress(String addressId, AddressModel address) async {
    final url = '${ApiClient.baseUrl}/addresses/update/$addressId';
    final payload = jsonEncode(address.toMap());

    try {
      ApiClient.logRequest('PUT', url, body: payload);

      final response = await http
          .put(Uri.parse(url), headers: ApiClient.defaultHeaders, body: payload)
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('PUT', url, response.statusCode, response.body);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['data'] != null) {
          return AddressModel.fromMap(body['data'] as Map<String, dynamic>);
        }
      }
    } catch (e) {
      ApiClient.logError('PUT', url, e);
    }
    return null;
  }

  // 4. Delete an address
  static Future<bool> deleteAddress(String addressId) async {
    final url = '${ApiClient.baseUrl}/addresses/delete/$addressId';

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
}
