import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/settings_provider.dart';
import '../../services/auth_service.dart';
import '../../utils/app_logger.dart';

/// 🚀 شاشەی دەستپێک — بە Splash Animation + چاوەڕوانی Init
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

  bool _minTimeElapsed = false;
  bool _sessionReady = false;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _startInitWaiters();
  }

  void _initAnimations() {
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

    _controller.forward();
  }

  void _startInitWaiters() {
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        _minTimeElapsed = true;
        _tryNavigate();
      }
    });

    _waitForSession();
  }

  Future<void> _waitForSession() async {
    try {
      final maxWait = const Duration(seconds: 5);
      final start = DateTime.now();

      while (!AuthSessionManager.isInitialized) {
        if (DateTime.now().difference(start) > maxWait) {
          AppLogger.w('⚠️ Session init timeout — continuing anyway');
          break;
        }
        await Future.delayed(const Duration(milliseconds: 100));
      }

      _sessionReady = true;
      AppLogger.i('✅ Splash: Session ready');
    } catch (e) {
      AppLogger.e('⚠️ Splash session wait error', e);
      _sessionReady = true;
    } finally {
      if (mounted) _tryNavigate();
    }
  }

  void _tryNavigate() {
    if (_navigated) return;
    if (!_minTimeElapsed) return;
    if (!_sessionReady) return;

    _navigated = true;
    AppLogger.i('🚀 Splash: navigating to /main');

    if (mounted) {
      Navigator.pushReplacementNamed(context, '/main');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor =
    isDark ? const Color(0xFF0F0F14) : const Color(0xFF1E88E5);

    final settings = context.watch<SettingsProvider>();

    if (_sessionReady && !settings.isLoaded) {
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted && settings.isLoaded) _tryNavigate();
      });
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          Center(
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