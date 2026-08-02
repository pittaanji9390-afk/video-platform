import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

class PermissionService {
  PermissionService._();

  static final PermissionService instance = PermissionService._();

  /// Checks the current status of camera permission
  Future<ph.PermissionStatus> getCameraPermissionStatus() async {
    if (kIsWeb) return ph.PermissionStatus.granted;
    return await ph.Permission.camera.status;
  }

  /// Requests camera permission from the OS
  Future<ph.PermissionStatus> requestCameraPermission() async {
    if (kIsWeb) return ph.PermissionStatus.granted;
    final status = await ph.Permission.camera.request();
    return status;
  }

  /// Opens system app settings when permission is permanently denied
  Future<bool> openAppSettings() async {
    if (kIsWeb) return true;
    return await ph.openAppSettings();
  }
}
