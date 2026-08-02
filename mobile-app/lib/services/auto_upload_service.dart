import 'package:shared_preferences/shared_preferences.dart';

class AutoUploadService {
  AutoUploadService._();
  static final AutoUploadService instance = AutoUploadService._();

  static const String keyAutoUploadEnabled = 'auto_upload_enabled';
  static const String keyPendingUploadQueue = 'pending_upload_queue';

  /// Check if auto upload is enabled
  Future<bool> isAutoUploadEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(keyAutoUploadEnabled) ?? false; // Default false
  }

  /// Toggle auto upload preference
  Future<void> setAutoUploadEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyAutoUploadEnabled, enabled);
  }

  /// Add a video file path to the upload retry queue
  Future<void> addToQueue(String filePath, String? environmentTag) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(keyPendingUploadQueue) ?? [];
    final item = '$filePath|${environmentTag ?? ''}';
    if (!queue.contains(item)) {
      queue.add(item);
      await prefs.setStringList(keyPendingUploadQueue, queue);
    }
  }

  /// Get list of pending uploads in queue
  Future<List<Map<String, String>>> getQueue() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(keyPendingUploadQueue) ?? [];

    return queue.map((item) {
      final parts = item.split('|');
      return {
        'filePath': parts[0],
        'environmentTag': parts.length > 1 ? parts[1] : '',
      };
    }).toList();
  }

  /// Clear item from queue
  Future<void> removeFromQueue(String filePath) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> queue = prefs.getStringList(keyPendingUploadQueue) ?? [];
    queue.removeWhere((item) => item.startsWith(filePath));
    await prefs.setStringList(keyPendingUploadQueue, queue);
  }
}
