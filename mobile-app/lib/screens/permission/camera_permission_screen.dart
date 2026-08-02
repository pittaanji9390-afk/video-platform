import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../config/routes/app_routes.dart';
import '../../core/theme/app_colors.dart';

class CameraPermissionScreen extends StatefulWidget {
  const CameraPermissionScreen({super.key});

  @override
  State<CameraPermissionScreen> createState() => _CameraPermissionScreenState();
}

class _CameraPermissionScreenState extends State<CameraPermissionScreen> {
  PermissionStatus _cameraStatus = PermissionStatus.denied;
  PermissionStatus _micStatus = PermissionStatus.denied;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkInitialStatus();
  }

  Future<void> _checkInitialStatus() async {
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _cameraStatus = PermissionStatus.granted;
          _micStatus = PermissionStatus.granted;
          _isLoading = false;
        });
      }
      return;
    }
    final camStatus = await Permission.camera.status;
    final micStatus = await Permission.microphone.status;
    setState(() {
      _cameraStatus = camStatus;
      _micStatus = micStatus;
      _isLoading = false;
    });
  }

  bool get _allGranted => _cameraStatus.isGranted && _micStatus.isGranted;

  Future<void> _requestPermission() async {
    if (kIsWeb) {
      setState(() {
        _cameraStatus = PermissionStatus.granted;
        _micStatus = PermissionStatus.granted;
        _isLoading = false;
      });
      return;
    }
    setState(() => _isLoading = true);

    final newCamStatus = await Permission.camera.request();
    final newMicStatus = await Permission.microphone.request();

    setState(() {
      _cameraStatus = newCamStatus;
      _micStatus = newMicStatus;
      _isLoading = false;
    });

    if (mounted) {
      if (newCamStatus.isGranted && newMicStatus.isGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Camera and microphone permissions granted!'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        final List<String> denied = [];
        if (!newCamStatus.isGranted) denied.add('Camera');
        if (!newMicStatus.isGranted) denied.add('Microphone');

        if (newCamStatus.isPermanentlyDenied || newMicStatus.isPermanentlyDenied) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${denied.join(" and ")} permission permanently denied. Please enable in App Settings.'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${denied.join(" and ")} permission denied. Both are required for video recording.'),
              backgroundColor: AppColors.warning,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Future<void> _openSettings() async {
    await openAppSettings();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Permissions Required'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 450),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildStatusIcon(),
                        const SizedBox(height: 32),

                        Text(
                          _getStatusTitle(),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDarkMode
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),

                        Text(
                          _getStatusDescription(),
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.5,
                            color: isDarkMode
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),

                        // Permission status cards
                        _buildPermissionCard(
                          icon: Icons.videocam_rounded,
                          label: 'Camera',
                          status: _cameraStatus,
                        ),
                        const SizedBox(height: 10),
                        _buildPermissionCard(
                          icon: Icons.mic_rounded,
                          label: 'Microphone',
                          status: _micStatus,
                        ),
                        const SizedBox(height: 40),

                        _buildActionButton(),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildPermissionCard({
    required IconData icon,
    required String label,
    required PermissionStatus status,
  }) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    if (status.isGranted) {
      statusColor = AppColors.success;
      statusText = 'Granted';
      statusIcon = Icons.check_circle_rounded;
    } else if (status.isPermanentlyDenied) {
      statusColor = AppColors.error;
      statusText = 'Blocked';
      statusIcon = Icons.block_rounded;
    } else if (status.isDenied) {
      statusColor = AppColors.warning;
      statusText = 'Denied';
      statusIcon = Icons.cancel_rounded;
    } else {
      statusColor = AppColors.textSecondaryLight;
      statusText = 'Not checked';
      statusIcon = Icons.help_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: statusColor.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withAlpha(80)),
      ),
      child: Row(
        children: [
          Icon(icon, color: statusColor, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: statusColor)),
          ),
          Icon(statusIcon, color: statusColor, size: 18),
          const SizedBox(width: 6),
          Text(statusText, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
        ],
      ),
    );
  }

  Widget _buildStatusIcon() {
    IconData iconData;
    Color iconColor;
    Color bgColor;

    if (_allGranted) {
      iconData = Icons.check_circle_rounded;
      iconColor = AppColors.success;
      bgColor = AppColors.success.withAlpha(30);
    } else if (_cameraStatus.isPermanentlyDenied || _micStatus.isPermanentlyDenied) {
      iconData = Icons.settings_applications_rounded;
      iconColor = AppColors.error;
      bgColor = AppColors.error.withAlpha(30);
    } else {
      iconData = Icons.security_rounded;
      iconColor = AppColors.primary;
      bgColor = AppColors.primary.withAlpha(30);
    }

    return Container(
      height: 110,
      width: 110,
      decoration: BoxDecoration(
        color: bgColor,
        shape: BoxShape.circle,
      ),
      child: Icon(iconData, size: 56, color: iconColor),
    );
  }

  String _getStatusTitle() {
    if (_allGranted) return 'Permissions Granted';
    if (_cameraStatus.isPermanentlyDenied || _micStatus.isPermanentlyDenied) {
      return 'Permissions Blocked';
    }
    return 'Camera & Microphone Required';
  }

  String _getStatusDescription() {
    if (_allGranted) {
      return 'Camera and microphone permissions are active. You are ready to record video with audio.';
    }
    if (_cameraStatus.isPermanentlyDenied || _micStatus.isPermanentlyDenied) {
      return 'One or more permissions are permanently blocked. Please tap "Open App Settings" to manually enable them.';
    }
    return 'This app needs access to your camera and microphone to record high-quality video data samples with audio.';
  }

  Widget _buildActionButton() {
    if (_allGranted) {
      return ElevatedButton.icon(
        onPressed: () {
          Navigator.pushReplacementNamed(context, AppRoutes.recordVideo);
        },
        icon: const Icon(Icons.videocam_rounded),
        label: const Text('Proceed to Record Video'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.success,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    if (_cameraStatus.isPermanentlyDenied || _micStatus.isPermanentlyDenied) {
      return ElevatedButton.icon(
        onPressed: _openSettings,
        icon: const Icon(Icons.settings_rounded),
        label: const Text('Open App Settings'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: _requestPermission,
      icon: const Icon(Icons.security_rounded),
      label: const Text('Grant Camera & Microphone'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
