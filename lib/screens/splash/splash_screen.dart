import 'package:flutter/material.dart';
import 'dart:async';

import '../../services/auth_service.dart';
import '../../utils/app_logger.dart';

/// 🌊 شاشەی دەستپێک — PRO EDITION
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
  late Animation<Offset> _slideAnimation;

  bool _sessionReady = false;
  bool _animationsDone = false;
  bool _navigated = false;

  // ✅ Timer بۆ Fallback
  Timer? _fallbackTimer;

  @override
  void initState() {
    super.initState();

    // ═══════════════════════════════════════════
    // 🎬 Animation Setup
    // ═══════════════════════════════════════════
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
      ),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.5), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _controller,
            curve: const Interval(0.4, 1.0, curve: Curves.easeOut),
          ),
        );

    _controller.forward().then((_) {
      if (mounted) {
        _animationsDone = true;
        _tryNavigate();
      }
    });

    // ═══════════════════════════════════════════
    // 🔄 Session Wait
    // ═══════════════════════════════════════════
    _waitForSession();

    // ═══════════════════════════════════════════
    // ⏱️ Fallback Timer
    // ═══════════════════════════════════════════
    _fallbackTimer = Timer(const Duration(seconds: 4), () {
      if (mounted && !_navigated) {
        AppLogger.w('⚠️ Splash: Fallback navigation (timeout)');
        _navigate();
      }
    });
  }

  @override
  void dispose() {
    // ✅ Timer.cancel
    _fallbackTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // ⏳ چاوەڕوانی بۆ دانیشتن
  // ═══════════════════════════════════════════════════════════
  Future<void> _waitForSession() async {
    try {
      const maxWait = Duration(seconds: 3);
      final start = DateTime.now();

      while (!AuthSessionManager.isInitialized) {
        if (DateTime.now().difference(start) > maxWait) {
          AppLogger.w('⚠️ Splash: Session wait timeout');
          break;
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (mounted) {
        setState(() => _sessionReady = true);
      }
      AppLogger.i('✅ Splash: Session ready');
    } catch (e) {
      AppLogger.e('⚠️ Splash session wait error', e);
      if (mounted) {
        setState(() => _sessionReady = true);
      }
    } finally {
      _tryNavigate();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🚀 گەیشتن بە شاشەی سەرەکی
  // ═══════════════════════════════════════════════════════════
  void _tryNavigate() {
    if (!mounted || _navigated) return;
    if (_sessionReady && _animationsDone) {
      _navigate();
    }
  }

  void _navigate() {
    if (!mounted || _navigated) return;
    _navigated = true;

    // ✅ Timer.cancel پێش چوونە دەرەوە
    _fallbackTimer?.cancel();

    try {
      AppLogger.i('🚀 Splash → Main');
      Navigator.pushReplacementNamed(context, '/main');
    } catch (e) {
      AppLogger.e('❌ Splash navigation error', e);
      // ✅ ڕێگە بدە هەوڵدانەوە
      _navigated = false;
      _fallbackTimer?.cancel();
      _fallbackTimer = Timer(const Duration(seconds: 2), () {
        if (mounted && !_navigated) _navigate();
      });
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
    isDark ? const Color(0xFF0F0F14) : const Color(0xFF1E88E5);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // ═══════════════════════════════════════════
          // 🎨 ناوەڕۆکی سەرەکی
          // ═══════════════════════════════════════════
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🖼️ لۆگۆکە
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

                // 📝 ناوی ئەپەکە
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
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
                ),

                const SizedBox(height: 12),

                // 📝 دەقی بچووک
                SlideTransition(
                  position: _slideAnimation,
                  child: FadeTransition(
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
                ),

                const SizedBox(height: 60),

                // ⏳ Loading
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor:
                      AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 📌 وەشانی ئەپ
          Positioned(
            bottom: 30,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Center(
                child: Text(
                  'v1.0.0',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}