import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../hive/hive_service.dart';
import '../service/socket_service.dart';
import 'api_client.dart';

class ComplaintApiService {
  // 1. Upload Complaint Image (Multipart)
  static Future<String?> uploadComplaintImage(String localPath, String complaintId) async {
    final file = File(localPath);
    if (!file.existsSync()) {
      ApiClient.logError('UPLOAD', localPath, 'Local image file does not exist');
      return localPath;
    }

    final url = '${ApiClient.baseUrl}/upload/complaint';
    try {
      ApiClient.logRequest('MULTIPART POST', url, body: 'File: $localPath, ComplaintId: $complaintId');

      final request = http.MultipartRequest('POST', Uri.parse(url));
      request.files.add(await http.MultipartFile.fromPath('image', localPath));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      ApiClient.logResponse('MULTIPART POST', url, response.statusCode, response.body);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['imageUrl'] as String?;
      }
    } catch (e) {
      ApiClient.logError('MULTIPART POST', url, e);
    }
    return localPath;
  }

  // 2. Submit Complaint to MongoDB
  static Future<void> submitComplaint(Map<String, dynamic> complaint) async {
    final dataToSend = Map<String, dynamic>.from(complaint);
    dataToSend['userId'] = HiveService.citizenId;
    dataToSend['complaintId'] = complaint['complaintId'] ??
        complaint['id'] ??
        ('CMP${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}');
    dataToSend.remove('id');
    dataToSend.remove('citizenId');

    final url = '${ApiClient.baseUrl}/complaints/create';
    final payload = jsonEncode(dataToSend);

    try {
      ApiClient.logRequest('POST', url, body: payload);

      final response = await http.post(
        Uri.parse(url),
        headers: ApiClient.defaultHeaders,
        body: payload,
      );

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
    } catch (e) {
      ApiClient.logError('POST', url, e);
    }
  }

  // 3. Fetch All Complaints
  static Future<List<Map<String, dynamic>>> fetchComplaints() async {
    final url = '${ApiClient.baseUrl}/complaints/all';
    try {
      ApiClient.logRequest('GET', url);

      final response = await http.get(Uri.parse(url));
      ApiClient.logResponse('GET', url, response.statusCode, response.body);

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      ApiClient.logError('GET', url, e);
    }
    return [];
  }

  // 4. Fetch User-Specific Complaints ("My Activity")
  static Future<List<Map<String, dynamic>>> fetchMyComplaints([String? userId]) async {
    final uid = userId ?? HiveService.citizenId;
    final url = '${ApiClient.baseUrl}/complaints/user/$uid';

    try {
      ApiClient.logRequest('GET', url);

      final response = await http.get(Uri.parse(url));
      ApiClient.logResponse('GET', url, response.statusCode, response.body);

      if (response.statusCode == 200) {
        final List<dynamic> list = jsonDecode(response.body);
        return list.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      ApiClient.logError('GET', url, e);
    }
    return [];
  }

  // 5. Stream Complaints (Real-Time WebSocket Push via Socket.io - ZERO POLLING)
  static Stream<List<Map<String, dynamic>>> streamAllComplaints() async* {
    // 1. Initialize WebSocket connection
    final socketService = SocketService();
    socketService.init();

    // 2. Fetch initial data once
    final initialComplaints = await fetchComplaints();
    if (initialComplaints.isNotEmpty) {
      yield initialComplaints;
    }

    // 3. Listen to real-time events pushed by the server (No periodic polling!)
    await for (final _ in socketService.onComplaintsChanged) {
      final updatedComplaints = await fetchComplaints();
      if (updatedComplaints.isNotEmpty) {
        yield updatedComplaints;
      }
    }
  }

  // 6. Toggle Like
  static Future<void> toggleLike(String complaintId, bool isCurrentlyLiked) async {
    final url = '${ApiClient.baseUrl}/complaints/$complaintId/like';
    final payload = jsonEncode({
      'citizenId': HiveService.citizenId,
      'isCurrentlyLiked': isCurrentlyLiked,
    });

    try {
      ApiClient.logRequest('POST', url, body: payload);

      final response = await http.post(
        Uri.parse(url),
        headers: ApiClient.defaultHeaders,
        body: payload,
      );

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
    } catch (e) {
      ApiClient.logError('POST', url, e);
    }
  }

  // 7. Add Comment
  static Future<void> addComment(String complaintId, String comment, String userName) async {
    final url = '${ApiClient.baseUrl}/complaints/$complaintId/comment';
    final payload = jsonEncode({
      'citizenId': HiveService.citizenId,
      'userName': userName,
      'comment': comment,
    });

    try {
      ApiClient.logRequest('POST', url, body: payload);

      final response = await http.post(
        Uri.parse(url),
        headers: ApiClient.defaultHeaders,
        body: payload,
      );

      ApiClient.logResponse('POST', url, response.statusCode, response.body);
    } catch (e) {
      ApiClient.logError('POST', url, e);
    }
  }
}
