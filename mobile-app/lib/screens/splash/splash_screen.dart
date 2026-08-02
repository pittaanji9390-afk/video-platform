import 'package:flutter/material.dart';
import '../../config/routes/app_routes.dart';
import '../../services/auth_service.dart';
import '../../services/update_service.dart';
import '../../widgets/powered_by_footer.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSessionAndNavigate();
  }

  Future<void> _checkSessionAndNavigate() async {
    // Check for in-app updates in background
    UpdateService.checkForUpdates(context);

    // Smooth splash load delay (1.5s) to display branding
    await Future.delayed(const Duration(milliseconds: 1500));

    if (!mounted) return;

    // Check if user has an active, authenticated session in SharedPreferences
    final session = await AuthService.restoreSession();
    if (session != null && session['token'] != null && session['token']!.isNotEmpty) {
      final role = (session['role'] ?? 'candidate').toLowerCase();
      if (role == 'admin') {
        Navigator.pushReplacementNamed(context, AppRoutes.adminDashboard);
      } else if (role == 'qc_team' || role == 'qc' || role == 'qc_reviewer' || role.contains('qc')) {
        Navigator.pushReplacementNamed(context, AppRoutes.qcDashboard);
      } else if (role == 'vendor') {
        Navigator.pushReplacementNamed(context, AppRoutes.vendorDashboard);
      } else {
        Navigator.pushReplacementNamed(context, AppRoutes.home);
      }
    } else {
      // If no valid authenticated session, direct user to Login Screen
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D4ED8),
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 90,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(50),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.videocam_rounded,
                  size: 52,
                  color: Color(0xFF1D4ED8),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Video Data\nCollection Platform',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Collect. Upload. Earn.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white70,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 60),
              const Text(
                'Loading...',
                style: TextStyle(fontSize: 12, color: Colors.white70),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    backgroundColor: Colors.white24,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    minHeight: 4,
                  ),
                ),
              ),
              const SizedBox(height: 30),
              const PoweredByFooter(
                textColor: Colors.white70,
                brandColor: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
