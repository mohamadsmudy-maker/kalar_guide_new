// lib/screens/onboarding/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  static const List<_OnboardingData> _pages = [
    _OnboardingData(
      icon: Icons.explore_rounded,
      title: 'بەخێربێیت بۆ ڕێبەری کەلار',
      description:
      'هەموو شتێک دەربارەی شاری کەلار — گەڕەکان، شوێنەکان، ڕووداوەکان، و زۆر شتی تر.',
      color: Color(0xFF1E88E5),
    ),
    _OnboardingData(
      icon: Icons.location_city_rounded,
      title: '٥٩ گەڕەکی کەلار',
      description:
      'هەموو گەڕەکان بە ناو و سنوور و زانیاری تەواو. لەسەر نەخشە بیانبینە و بیانناسە.',
      color: Color(0xFF10B981),
    ),
    _OnboardingData(
      icon: Icons.storefront_rounded,
      title: '١٨٩ شوێن لە شارەکەدا',
      description:
      'نەخۆشخانە، قوتابخانە، بەنزینخانە، بانک، مۆڵ، و هەموو شوێنەکانی تر بە دووری و شوێن.',
      color: Color(0xFFFF9800),
    ),
    _OnboardingData(
      icon: Icons.campaign_rounded,
      title: 'سکاڵا و خزمەتگوزاری',
      description:
      'سکاڵاکانت بنێرە، نرخی دراو و بەنزین ببینە، کاتەکانی نوێژ و قیبلە بدۆزەرەوە.',
      color: Color(0xFFE91E63),
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    widget.onComplete();
  }

  void _next() {
    if (_currentPage < _pages.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    } else {
      _complete();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
      isDark ? const Color(0xFF0F0F14) : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Skip
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: _complete,
                child: Text(
                  'پەڕاندن',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            // Pages
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return _buildPage(_pages[index], isDark);
                },
              ),
            ),

            // Indicator
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: SmoothPageIndicator(
                controller: _controller,
                count: _pages.length,
                effect: ExpandingDotsEffect(
                  activeDotColor: _pages[_currentPage].color,
                  dotColor: _pages[_currentPage].color.withValues(alpha: 0.3),
                  dotHeight: 10,
                  dotWidth: 10,
                  expansionFactor: 4,
                  spacing: 8,
                ),
              ),
            ),

            // Button
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _next,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _pages[_currentPage].color,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  child: Text(
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
    );
  }

  Widget _buildPage(_OnboardingData data, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Icon Circle
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

          // Title
          Text(
            data.title,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color:
              isDark ? Colors.white : const Color(0xFF1A1A2E),
              height: 1.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            data.description,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: isDark ? Colors.white70 : Colors.grey.shade700,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

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