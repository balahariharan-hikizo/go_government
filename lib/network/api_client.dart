import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiClient {
  static String? _resolvedBaseUrl;

  // Active Wi-Fi IP is 192.168.1.24
  static String get defaultBaseUrl => 'http://192.168.1.24:5000/api';

  static String get baseUrl => _resolvedBaseUrl ?? defaultBaseUrl;

  static void setBaseUrl(String url) {
    _resolvedBaseUrl = url;
    debugPrint('🔄 [ApiClient] Base URL updated to: $url');
  }

  static Map<String, String> get defaultHeaders => {
    'Content-Type': 'application/json',
  };

  /// Auto-candidate hosts for seamless switching between PG, Office, Emulator & Localhost
  static List<String> get candidateHosts => [
    'http://192.168.1.24:5000/api',  // Current Wi-Fi IP
    'http://192.168.1.12:5000/api',  // Previous Wi-Fi IP
    'http://192.168.1.11:5000/api',  // Previous Wi-Fi IP
    'http://192.168.1.8:5000/api',   // PG / Home Wi-Fi
    'http://127.0.0.1:5000/api',     // Localhost / Web / Desktop
    if (!kIsWeb && Platform.isAndroid) 'http://10.0.2.2:5000/api', // Android Emulator
  ];

  /// Normalizes image URLs so localhost/127.0.0.1 URLs from the database
  /// resolve to the currently reachable backend baseUrl (e.g. 192.168.1.10:5000)
  /// Normalizes image URLs so any /uploads/ paths (whether localhost, old LAN IP, or relative)
  /// resolve to the currently reachable backend serverOrigin (e.g. http://192.168.1.11:5000)
  static String normalizeImageUrl(String? url) {
    if (url == null || url.trim().isEmpty) return '';
    final trimmed = url.trim();

    // 1. Relative /uploads/... or uploads/...
    if (trimmed.startsWith('/uploads/') || trimmed.startsWith('uploads/')) {
      final cleanPath = trimmed.startsWith('/') ? trimmed : '/$trimmed';
      final serverOrigin = baseUrl.replaceAll('/api', '');
      return '$serverOrigin$cleanPath';
    }

    // 2. Full URL containing /uploads/ (replace old IP/localhost with active server origin)
    if (trimmed.contains('/uploads/')) {
      final serverOrigin = baseUrl.replaceAll('/api', '');
      final uploadsIndex = trimmed.indexOf('/uploads/');
      return '$serverOrigin${trimmed.substring(uploadsIndex)}';
    }

    return trimmed;
  }

  // ================= DEBUG LOGGER ================= //
  static void logRequest(String method, String url, {dynamic body}) {
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('🌐 [API REQUEST] $method $url');
    if (body != null) {
      debugPrint('📦 Body: $body');
    }
  }

  static void logResponse(String method, String url, int statusCode, String responseBody) {
    final emoji = (statusCode >= 200 && statusCode < 300) ? '✅' : '⚠️';
    debugPrint('$emoji [API RESPONSE] [$statusCode] $method $url');
    debugPrint('📄 Response Body: $responseBody');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }

  static void logError(String method, String url, dynamic error) {
    debugPrint('❌ [API ERROR] $method $url');
    debugPrint('💥 Exception: $error');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  }
}
