import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

import '../../services/auth_service.dart';
import '../../utils/app_logger.dart';
import '../../l10n/tr.dart';

/// 🌊 شاشەی دەستپێک — ULTRA PRO MAX V2
///
/// Navigation now waits for BOTH:
///   • a minimum display time (so the logo is never a flash), and
///   • the session init (so Main never opens before the user is known).
/// The session init has its own timeout, so a bad network can never trap
/// the user on this screen.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  static const Duration _minShow = Duration(milliseconds: 1800);
  static const Duration _sessionTimeout = Duration(seconds: 3);
  static const String _logoAsset = 'assets/images/kalar.png';

  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _textFade;

  bool _navigated = false;
  bool _precached = false;
  String _status = 'ئامادەکردن...';

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _scaleAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.7, curve: Curves.easeIn),
    );

    // Texts fade in slightly after the logo
    _textFade = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.4, 1.0, curve: Curves.easeIn),
    );

    _controller.forward();
    _start();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // ♿ Respect the system "reduce motion" setting
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    }

    // 🖼 Load the logo before first paint of the image → no pop-in
    if (!_precached) {
      _precached = true;
      precacheImage(const AssetImage(_logoAsset), context)
          .catchError((_) {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 🚀 Startup flow
  // ═══════════════════════════════════════════════════════════
  Future<void> _start() async {
    final minDelay = Future<void>.delayed(_minShow);
    final session = _initSession();

    await Future.wait<void>([minDelay, session]);
    await _navigate();
  }

  Future<void> _initSession() async {
    _setStatus('پشکنینی هەژمار...');
    try {
      AppLogger.i('🔐 Splash: دەستپێکردنی initSession');
      await AuthSessionManager.initSession().timeout(_sessionTimeout);
      AppLogger.i('✅ Splash: initSession تەواو بوو');
    } on TimeoutException {
      AppLogger.w('⚠️ Splash: initSession timeout — بەردەوام دەبین');
    } catch (e) {
      AppLogger.w('⚠️ Splash: initSession هەڵە — $e');
    }
    _setStatus('ئامادەیە');
  }

  void _setStatus(String text) {
    if (!mounted || _status == text) return;
    setState(() => _status = text);
  }

  Future<void> _navigate() async {
    if (!mounted || _navigated) return;
    _navigated = true;

    var seenOnboarding = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      seenOnboarding = prefs.getBool('onboarding_completed') ?? false;
    } catch (e) {
      // If prefs fail, take the user into the app rather than trapping them.
      AppLogger.w('⚠️ Splash: prefs هەڵە — $e');
      seenOnboarding = true;
    }

    if (!mounted) return;

    final route = seenOnboarding ? '/main' : '/onboarding';
    AppLogger.i('🚀 Splash → $route');
    Navigator.of(context).pushReplacementNamed(route);
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 UI
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colors = isDark
        ? const [Color(0xFF0F0F14), Color(0xFF1A1B2E)]
        : const [Color(0xFF1E88E5), Color(0xFF1E88E5)];

    return PopScope(
      // The splash must not be dismissible with the back button
      canPop: false,
      child: Scaffold(
        backgroundColor: colors.first,
        body: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Semantics(
              label: tr('ڕێبەری کەلار، ئەپ بار دەکرێت'),
              child: Center(
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
                              _logoAsset,
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
                      opacity: _textFade,
                      child: Text(
                        tr('ڕێبەری کەلار'),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1,
                          fontFamily: 'Rabar',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FadeTransition(
                      opacity: _textFade,
                      child: Text(
                        tr('ڕێبەری فەرمی شاری کەلار'),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                          letterSpacing: 0.5,
                          fontFamily: 'Rabar',
                        ),
                      ),
                    ),
                    const SizedBox(height: 60),
                    FadeTransition(
                      opacity: _textFade,
                      child: Column(
                        children: [
                          const SizedBox(
                            width: 30,
                            height: 30,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          const SizedBox(height: 14),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: Text(
                              tr(_status),
                              key: ValueKey(_status),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.7),
                                fontFamily: 'Rabar',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}