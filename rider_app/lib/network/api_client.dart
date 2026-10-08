import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiClient {
  static String? _resolvedBaseUrl;

  // Active Wi-Fi backend URL
  static String get defaultBaseUrl => 'http://192.168.1.24:5000/api';

  static String get baseUrl => _resolvedBaseUrl ?? defaultBaseUrl;

  static void setBaseUrl(String url) {
    _resolvedBaseUrl = url;
    debugPrint('🔄 [Rider ApiClient] Base URL updated to: $url');
  }

  static Map<String, String> get defaultHeaders => {
        'Content-Type': 'application/json',
      };

  /// Candidate hosts for automatic resolution
  static List<String> get candidateHosts => [
        'http://192.168.1.24:5000/api', // Active Wi-Fi IP
        'http://192.168.1.12:5000/api', // Previous Wi-Fi IP
        'http://192.168.1.11:5000/api', // Previous Wi-Fi IP
        'http://192.168.1.8:5000/api',  // Home Wi-Fi
        'http://127.0.0.1:5000/api',    // Localhost / Web / Desktop
        if (!kIsWeb && Platform.isAndroid) 'http://10.0.2.2:5000/api', // Emulator
      ];

  // ================= DEBUG LOGGER ================= //
  static void logRequest(String method, String url, {dynamic body}) {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🚴 [RIDER API REQUEST] $method $url');
    if (body != null) {
      debugPrint('📦 Body: $body');
    }
  }

  static void logResponse(String method, String url, int statusCode, String responseBody) {
    final emoji = (statusCode >= 200 && statusCode < 300) ? '✅' : '⚠️';
    debugPrint('$emoji [RIDER API RESPONSE] [$statusCode] $method $url');
    debugPrint('📄 Response Body: $responseBody');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  static void logError(String method, String url, dynamic error) {
    debugPrint('❌ [RIDER API ERROR] $method $url');
    debugPrint('💥 Exception: $error');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
}
