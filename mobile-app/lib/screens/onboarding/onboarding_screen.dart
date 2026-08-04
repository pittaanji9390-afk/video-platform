import 'package:flutter/material.dart';
import '../../config/routes/app_routes.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  void _onNext() {
    if (_currentPage == 0) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pushReplacementNamed(context, AppRoutes.login);
    }
  }

  void _onSkip() {
    Navigator.pushReplacementNamed(context, AppRoutes.login);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildRecordIllustration() {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft blue circular backdrop
          Container(
            width: 240,
            height: 240,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
          ),
          // Soft cloud shapes
          Positioned(
            top: 25,
            left: 25,
            child: Icon(Icons.cloud_rounded, size: 52, color: Colors.white.withValues(alpha: 0.9)),
          ),
          Positioned(
            top: 35,
            right: 20,
            child: Icon(Icons.cloud_rounded, size: 60, color: Colors.white.withValues(alpha: 0.9)),
          ),
          // Floating Gear Icons
          Positioned(
            right: 30,
            bottom: 75,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(color: Color(0xFF0052FF), shape: BoxShape.circle),
              child: const Icon(Icons.settings_rounded, size: 24, color: Colors.white),
            ),
          ),
          Positioned(
            right: 60,
            bottom: 35,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Color(0xFF0052FF), shape: BoxShape.circle),
              child: const Icon(Icons.settings_rounded, size: 18, color: Colors.white),
            ),
          ),
          // Central Camera Character Icon Box
          Center(
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0052FF).withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 28),
                        SizedBox(width: 4),
                        Icon(Icons.fiber_manual_record_rounded, color: Color(0xFFEF4444), size: 12),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Icon(Icons.person_rounded, size: 40, color: Color(0xFF0052FF)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadIllustration() {
    return SizedBox(
      width: 260,
      height: 260,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Soft blue circular backdrop
          Container(
            width: 240,
            height: 240,
            decoration: const BoxDecoration(
              color: Color(0xFFEFF6FF),
              shape: BoxShape.circle,
            ),
          ),
          // Soft cloud shapes
          Positioned(
            top: 25,
            left: 20,
            child: Icon(Icons.cloud_rounded, size: 65, color: Colors.white.withValues(alpha: 0.95)),
          ),
          Positioned(
            top: 20,
            right: 25,
            child: Icon(Icons.cloud_rounded, size: 55, color: Colors.white.withValues(alpha: 0.95)),
          ),
          // Sparkle stars
          Positioned(
            top: 55,
            left: 65,
            child: const Icon(Icons.auto_awesome_rounded, size: 16, color: Color(0xFF93C5FD)),
          ),
          Positioned(
            top: 70,
            right: 45,
            child: const Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF93C5FD)),
          ),
          // Large Blue Upload Cloud
          Center(
            child: Container(
              width: 170,
              height: 120,
              decoration: BoxDecoration(
                color: const Color(0xFF0052FF),
                borderRadius: BorderRadius.circular(60),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF0052FF).withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10)),
                ],
              ),
              child: const Center(
                child: Icon(Icons.arrow_upward_rounded, size: 58, color: Colors.white),
              ),
            ),
          ),
          // Lock Icon Overlay
          Positioned(
            right: 40,
            bottom: 55,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4)),
                ],
              ),
              child: const Icon(Icons.lock_rounded, size: 30, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          TextButton(
            onPressed: _onSkip,
            child: const Text(
              'Skip',
              style: TextStyle(
                color: Color(0xFF0052FF),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentPage = idx),
                children: [
                  // Page 1: Record Videos Easily
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildRecordIllustration(),
                        const SizedBox(height: 36),
                        const Text(
                          'Record Videos Easily',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Capture high-quality videos\nusing your phone.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF64748B),
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),

                  // Page 2: Secure Upload & Storage
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildUploadIllustration(),
                        const SizedBox(height: 36),
                        const Text(
                          'Secure Upload\n& Storage',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                            height: 1.2,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Your videos are encrypted and\nstored securely.',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF64748B),
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Page Dots & Bottom Next/Start Button
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // 2-Dots indicator (matches 2 onboarding screens)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      2,
                      (idx) => AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _currentPage == idx ? const Color(0xFF0052FF) : const Color(0xFFCBD5E1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Bottom Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _onNext,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0052FF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: Text(
                        _currentPage == 0 ? 'Next' : 'Start',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
