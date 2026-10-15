import 'package:flutter/material.dart';
import 'dart:async';

import '../../services/auth_service.dart';
import '../../utils/app_logger.dart';

/// 🌊 شاشەی دەستپێک — SIMPLE EDITION
///
/// ✅ چارەسەرکرا:
/// - Timeout ی جێگیر (2.5 چرکە)
/// - هەرگیز گیرۆدە نابێت
/// - `initSession()` لە پاشەوە (Fire and Forget)
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  bool _navigated = false;
  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    // ═══════════════════════════════════════════
    // 🎬 Animation
    // ═══════════════════════════════════════════
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutBack,
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _controller.forward();

    // ═══════════════════════════════════════════
    // 🚀 Navigation — دوای ٢.٥ چرکە
    // ═══════════════════════════════════════════
    _navigationTimer = Timer(const Duration(milliseconds: 2500), () {
      _navigateToMain();
    });

    // ═══════════════════════════════════════════
    // 🔥 Init Session — Fire and Forget
    // ═══════════════════════════════════════════
    _initSessionInBackground();
  }

  Future<void> _initSessionInBackground() async {
    try {
      AppLogger.i('🔐 Splash: دەستپێکردنی initSession');
      await AuthSessionManager.initSession()
          .timeout(const Duration(seconds: 3));
      AppLogger.i('✅ Splash: initSession تەواو بوو');
    } catch (e) {
      AppLogger.w('⚠️ Splash: initSession timeout — $e');
    }
  }

  void _navigateToMain() {
    if (!mounted || _navigated) return;
    _navigated = true;

    AppLogger.i('🚀 Splash → Main');
    Navigator.of(context).pushReplacementNamed('/main');
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
    isDark ? const Color(0xFF0F0F14) : const Color(0xFF1E88E5);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FadeTransition(
              opacity: _fadeAnimation,
              child: ScaleTransition(
                scale: _scaleAnimation,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(20),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/kalar.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.explore_rounded,
                          size: 80,
                          color: Color(0xFF1E88E5),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            FadeTransition(
              opacity: _fadeAnimation,
              child: const Text(
                'ڕێبەری کەلار',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                'ڕێبەری فەرمی شاری کەلار',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.85),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(height: 60),
            FadeTransition(
              opacity: _fadeAnimation,
              child: const SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}