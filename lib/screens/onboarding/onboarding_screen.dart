// lib/screens/onboarding/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_colors.dart';

/// 🎉 شاشەی ئۆن بۆردینگ — ULTRA PRO MAX V2
class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;
  bool _isCompleting = false;

  static const List<_OnboardingData> _pages = [
    _OnboardingData(
      icon: Icons.explore_rounded,
      title: 'بەخێربێیت بۆ ڕێبەری کەلار',
      description:
      'هەموو شتێک دەربارەی شاری کەلار — گەڕەکان، شوێنەکان، ڕووداوەکان، و زۆر شتی تر.',
      color: AppColors.primary,
    ),
    _OnboardingData(
      icon: Icons.location_city_rounded,
      title: '٥٩ گەڕەکی کەلار',
      description:
      'هەموو گەڕەکان بە ناو و سنوور و زانیاری تەواو. لەسەر نەخشە بیانبینە و بیانناسە.',
      color: AppColors.green,
    ),
    _OnboardingData(
      icon: Icons.storefront_rounded,
      title: '١٨٩ شوێن لە شارەکەدا',
      description:
      'نەخۆشخانە، قوتابخانە، بەنزینخانە، بانک، مۆڵ، و هەموو شوێنەکانی تر بە دووری و شوێن.',
      color: AppColors.orange,
    ),
    _OnboardingData(
      icon: Icons.campaign_rounded,
      title: 'سکاڵا و خزمەتگوزاری',
      description:
      'سکاڵاکانت بنێرە، نرخی دراو و بەنزین ببینە، کاتەکانی نوێژ و قیبلە بدۆزەرەوە.',
      color: AppColors.pink,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ تەواوکردن
  // ═══════════════════════════════════════════════════════════
  Future<void> _complete() async {
    if (_isCompleting) return;

    setState(() => _isCompleting = true);
    HapticFeedback.mediumImpact();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('onboarding_completed', true);

      if (!mounted) return;
      widget.onComplete();
    } catch (e) {
      debugPrint('❌ Onboarding complete error: $e');
      if (!mounted) return;

      setState(() => _isCompleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'هەڵە لە پاشەکەوتکردن، تکایە دووبارە هەوڵبدەرەوە',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: AppColors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  void _next() {
    HapticFeedback.selectionClick();

    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    } else {
      _complete();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🏗️ Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.surface;
    final currentColor = _pages[_currentPage].color;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Column(
            children: [
              // ⏭️ دوگمەی پەڕاندن
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: _isCompleting ? null : _complete,
                  child: Text(
                    'پەڕاندن',
                    style: TextStyle(
                      color: isDark
                          ? Colors.white54
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),

              // 🎨 شاشەکان
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  onPageChanged: (i) {
                    HapticFeedback.selectionClick();
                    setState(() => _currentPage = i);
                  },
                  itemCount: _pages.length,
                  itemBuilder: (context, index) {
                    return _buildPage(_pages[index], isDark);
                  },
                ),
              ),

              // 🔘 ئیندیکەیتەر
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: SmoothPageIndicator(
                  controller: _controller,
                  count: _pages.length,
                  effect: ExpandingDotsEffect(
                    activeDotColor: currentColor,
                    dotColor: currentColor.withValues(alpha: 0.3),
                    dotHeight: 10,
                    dotWidth: 10,
                    expansionFactor: 4,
                    spacing: 8,
                  ),
                ),
              ),

              // 🚀 دوگمەی داهاتوو
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isCompleting ? null : _next,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: currentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: currentColor.withValues(alpha: 0.4),
                    ),
                    child: _isCompleting
                        ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                        : Text(
                      _currentPage == _pages.length - 1
                          ? 'دەستپێکردن 🚀'
                          : 'داهاتوو',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 Page
  // ═══════════════════════════════════════════════════════════
  Widget _buildPage(_OnboardingData data, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 🎨 ئایکۆنی گەورە
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  data.color.withValues(alpha: 0.2),
                  data.color.withValues(alpha: 0.05),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: data.color.withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: Icon(
              data.icon,
              size: 80,
              color: data.color,
            ),
          ),
          const SizedBox(height: 40),

          // 📝 ناونیشان
          Text(
            data.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.textPrimary,
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // 📄 وەسف
          Text(
            data.description,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark ? Colors.white70 : AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🧱 Data Model
// ═══════════════════════════════════════════════════════════
class _OnboardingData {
  final IconData icon;
  final String title;
  final String description;
  final Color color;

  const _OnboardingData({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });
}