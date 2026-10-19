import 'dart:convert';
import 'package:http/http.dart' as http;
import '../model/notification_model.dart';
import 'api_client.dart';

class NotificationApiService {
  NotificationApiService._();

  /// Fetch all notifications for a user
  static Future<List<NotificationModel>> getNotifications(String userId) async {
    final url = '${ApiClient.baseUrl}/notifications/user/$userId';

    try {
      ApiClient.logRequest('GET', url);
      final response = await http
          .get(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('GET', url, response.statusCode, response.body);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        if (decoded['success'] == true && decoded['notifications'] is List) {
          final list = decoded['notifications'] as List;
          return list
              .map((item) => NotificationModel.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
      return [];
    } catch (e) {
      ApiClient.logError('GET', url, e);
      return [];
    }
  }

  /// Mark single notification as read
  static Future<bool> markAsRead(String notificationId) async {
    final url = '${ApiClient.baseUrl}/notifications/$notificationId/read';

    try {
      ApiClient.logRequest('PATCH', url);
      final response = await http
          .patch(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('PATCH', url, response.statusCode, response.body);
      return response.statusCode == 200;
    } catch (e) {
      ApiClient.logError('PATCH', url, e);
      return false;
    }
  }

  /// Mark all notifications as read for a user
  static Future<bool> markAllAsRead(String userId) async {
    final url = '${ApiClient.baseUrl}/notifications/user/$userId/read-all';

    try {
      ApiClient.logRequest('PATCH', url);
      final response = await http
          .patch(Uri.parse(url), headers: ApiClient.defaultHeaders)
          .timeout(const Duration(seconds: 8));

      ApiClient.logResponse('PATCH', url, response.statusCode, response.body);
      return response.statusCode == 200;
    } catch (e) {
      ApiClient.logError('PATCH', url, e);
      return false;
    }
  }
}
