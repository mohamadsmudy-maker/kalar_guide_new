import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';

/// 📋 شاشەی ڕێنمایی مامەڵە فەرمانگەکان
class InstructionsScreen extends StatelessWidget {
  const InstructionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F1421) : const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: const Text(
            'ڕێنمایی مامەڵە فەرمانگەکان',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF1A1B2E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ═══════════════════════════════════════
            // 🚗 مۆڵەتی شۆفێری
            // ═══════════════════════════════════════
            _buildInstructionCard(
              icon: Icons.directions_car_rounded,
              title: 'مۆڵەتی شۆفێری',
              color: const Color(0xFF1E88E5),
              items: [
                {'label': '📍 فەرمانگە', 'value': 'بەڕێوەبەرایەتی هاتوچۆ'},
                {'label': '📄 ناسنامەی نیشتمانی', 'value': 'کارتی نیشتمانی (ڕەسەن)'},
                {'label': '📄 کارتی زانیاری', 'value': 'کارتی زانیاری (ڕەسەن)'},
                {'label': '📄 پاسپۆرت', 'value': 'پاسپۆرت (ڕەسەن)'},
                {'label': '📄 پشکنینی پزیشکی', 'value': 'لە فەرمانگەکە دەکرێت'},
                {'label': '💻 کۆدی سەردانیکردن', 'value': 'لە ماڵپەڕی هاتوچۆ وەربگرە'},
                {'label': '⏱️ ماوە', 'value': '٣٠-٦٠ خولەک'},
                {'label': '💰 نرخ', 'value': '٩١,٠٠٠ دینار'},
              ],
              isDark: isDark,
            ),

            const SizedBox(height: 16),

            // ═══════════════════════════════════════
            // 🏠 مۆڵەتی بیناکردن
            // ═══════════════════════════════════════
            _buildInstructionCard(
              icon: Icons.home_work_rounded,
              title: 'مۆڵەتی بیناکردن',
              color: const Color(0xFF10B981),
              items: [
                {'label': '📍 فەرمانگە', 'value': 'بەڕێوەبەرایەتی شارەوانی'},
                {'label': '📄 وێنەی تۆمار', 'value': 'لە ٣ مانگ کۆنتر نەبێت'},
                {'label': '📄 چەسپاندنی سنوور', 'value': 'لە ٣ مانگ کۆنتر نەبێت'},
                {'label': '📄 ناسنامەی بارى شارستانى', 'value': 'ڕەسەن'},
                {'label': '📄 بریکارنامە', 'value': 'ئەگەر بریکار هەبێت'},
                {'label': '💰 نرخ', 'value': 'لە ٢٠٠,٠٠٠ دینارەوە'},
                {'label': '📝 تێبینی', 'value': 'نرخ بەپێی قەبارە دەگۆڕێت'},
              ],
              isDark: isDark,
            ),

            const SizedBox(height: 16),

            // ═══════════════════════════════════════
            // 🛂 پاسپۆرت
            // ═══════════════════════════════════════
            _buildInstructionCard(
              icon: Icons.card_membership_rounded,
              title: 'پاسپۆرت',
              color: const Color(0xFF8B5CF6),
              items: [
                {'label': '📍 فەرمانگە', 'value': 'بەڕێوەبەرایەتی پاسپۆرت'},
                {'label': '📄 کارتی نیشتمانی', 'value': 'ڕەسەن'},
                {'label': '📄 کارتی زانیاری', 'value': 'ڕەسەن'},
                {'label': '📄 پاسپۆرتە کۆنەکە', 'value': 'ئەگەر هەبێت'},
                {'label': '⏱️ ماوە', 'value': '٣٠-٦٠ خولەک'},
                {'label': '💰 نرخ', 'value': '٩١,٠٠٠ دینار'},
                {'label': '💳 پارەدان', 'value': 'تەنها بە کارتی بانکی'},
              ],
              isDark: isDark,
            ),

            const SizedBox(height: 20),

            // ═══════════════════════════════════════
            // ⚠️ تێبینی گرنگ
            // ═══════════════════════════════════════
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    const Color(0xFFF59E0B).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                  width: 1.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.warning_amber_rounded,
                          color: Color(0xFFF59E0B),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'تێبینی گرنگ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildNote('نرخ و مەرجەکان دەگۆڕێن — بەردەوام بپشکنە'),
                  _buildNote('پێش چوونە ژوورەوە، پەیوەندی بە فەرمانگەکە بکە'),
                  _buildNote('بەڵگەنامە ڕەسەنەکان پێویستە (کۆپی وەرناگیرێت)'),
                  _buildNote('کۆدی سەردانیکردن لە ماڵپەڕی فەرمی وەربگرە'),
                  _buildNote('پشکنینی پزیشکی تەنها بۆ ٣ مانگ کار دەکات'),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ═══════════════════════════════════════
            // 📞 پەیوەندی
            // ═══════════════════════════════════════
            _buildSectionTitle('📞 پەیوەندی', isDark),
            const SizedBox(height: 12),
            _buildContactRow(
              icon: Icons.language_rounded,
              label: 'ماڵپەڕی خزمەتگوزاری',
              value: 'service.gov.krd',
              color: const Color(0xFF1E88E5),
              isDark: isDark,
              onTap: () => _launchUrl('https://service.gov.krd'),
            ),
            const SizedBox(height: 8),
            _buildContactRow(
              icon: Icons.directions_car_rounded,
              label: 'ماڵپەڕی هاتوچۆ',
              value: 'sultraffic.com',
              color: const Color(0xFF10B981),
              isDark: isDark,
              onTap: () => _launchUrl('https://www.sultraffic.com'),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 کارتی ڕێنمایی
  // ═══════════════════════════════════════════════════════════
  Widget _buildInstructionCard({
    required IconData icon,
    required String title,
    required Color color,
    required List<Map<String, String>> items,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.8)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Items
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          item['label']!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white70 : Colors.grey.shade700,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          item['value']!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                          ),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNote(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.circle,
            size: 6,
            color: Color(0xFFF59E0B),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFFF59E0B),
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFFB300)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }

  Widget _buildContactRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.open_in_new_rounded,
              size: 16,
              color: color,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      debugPrint('❌ $e');
    }
  }
}