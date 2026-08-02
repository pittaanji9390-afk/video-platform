import 'package:camera/camera.dart';

class CameraService {
  CameraService._();

  static final CameraService instance = CameraService._();

  List<CameraDescription> _cameras = [];

  List<CameraDescription> get cameras => _cameras;

  /// Initializes available cameras on device
  Future<List<CameraDescription>> initCameras() async {
    try {
      _cameras = await availableCameras();
    } catch (e) {
      _cameras = [];
    }
    return _cameras;
  }

  /// Gets front or back camera (defaults to back camera)
  CameraDescription? get defaultCamera {
    if (_cameras.isEmpty) return null;
    return _cameras.firstWhere(
      (c) => c.lensDirection == CameraLensDirection.back,
      orElse: () => _cameras.first,
    );
  }
}
