import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';

class FeedbackApiService {
  FeedbackApiService._();

  static Future<Map<String, dynamic>?> submitFeedback({
    required String userId,
    required String userName,
    required String phone,
    String type = 'survey',
    double rating = 5.0,
    String comments = '',
    List<Map<String, String>> surveyAnswers = const [],
  }) async {
    final url = '${ApiClient.baseUrl}/feedback/create';
    final body = jsonEncode({
      'userId': userId,
      'userName': userName,
      'phone': phone,
      'type': type,
      'rating': rating,
      'comments': comments,
      'surveyAnswers': surveyAnswers,
    });

    try {
      ApiClient.logRequest('POST', url, body: body);
      final response = await http
          .post(Uri.parse(url), headers: ApiClient.defaultHeaders, body: body)
          .timeout(const Duration(seconds: 10));

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
      return jsonDecode(response.body) as Map<String, dynamic>?;
    } catch (e) {
      ApiClient.logError('POST', url, e);
      return {'success': false, 'error': 'Network connection error: $e'};
    }
  }
}
