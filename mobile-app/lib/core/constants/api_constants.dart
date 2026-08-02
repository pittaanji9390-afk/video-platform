import 'package:flutter/foundation.dart';

class ApiConstants {
  // Prevent instantiation
  ApiConstants._();

  /// Base URL for backend server
  /// Handles localhost for Web/Desktop/iOS vs 10.0.2.2 for Android Emulator
  static String get baseUrl {
    if (kReleaseMode || !kDebugMode) {
      return 'https://elevateiq-softtech.com/video-platform-api';
    }
    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
      final scheme = Uri.base.scheme.isNotEmpty ? Uri.base.scheme : 'http';
      if (host != 'localhost' && host != '127.0.0.1') {
        return '$scheme://$host/video-platform-api';
      }
      return 'http://$host:5000';
    }
    // Default fallback to live production VPS server
    return 'https://elevateiq-softtech.com/video-platform-api';
  }

  static const String apiVersion = '/api/v1';

  // API Endpoints
  static String get healthEndpoint => '/health';
  static String get adminsEndpoint => '$apiVersion/admins';
  static String get vendorsEndpoint => '$apiVersion/vendors';
  static String get candidatesEndpoint => '$apiVersion/candidates';
  static String get videosEndpoint => '$apiVersion/videos';
  static String get videoUploadEndpoint => '$apiVersion/videos/upload';
  static String get qcReviewsEndpoint => '$apiVersion/qc-reviews';

  // Request Headers
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static Map<String, String> getHeadersWithAuth([String? token]) {
    final Map<String, String> headers = Map.from(defaultHeaders);
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }
}
