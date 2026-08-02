import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeviceService {
  DeviceService._();
  static final DeviceService instance = DeviceService._();

  static const String keyDeviceId = 'device_unique_id';

  /// Get or generate a persistent device identifier
  Future<String> getDeviceId() async {
    final prefs = await SharedPreferences.getInstance();
    String? existingId = prefs.getString(keyDeviceId);

    if (existingId == null || existingId.isEmpty) {
      final prefix = kIsWeb
          ? 'WEB'
          : (defaultTargetPlatform == TargetPlatform.android
              ? 'AND'
              : (defaultTargetPlatform == TargetPlatform.iOS ? 'IOS' : 'DEV'));
      
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString().substring(5);
      existingId = '$prefix-$timestamp';
      await prefs.setString(keyDeviceId, existingId);
    }

    return existingId;
  }

  /// Get detailed device info summary string
  Future<Map<String, String>> getDeviceInfo() async {
    final deviceId = await getDeviceId();
    final platformName = kIsWeb ? 'Web Browser' : defaultTargetPlatform.name.toUpperCase();

    return {
      'deviceId': deviceId,
      'platform': platformName,
      'deviceSummary': '$platformName ($deviceId)',
    };
  }
}
