import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// ℹ️ شاشەی دەربارەی گەشەپێدەر
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  // ═══════════════════════════════════════════════
  // 📝 زانیارییەکان — لێرە بگۆڕە
  // ═══════════════════════════════════════════════
  static const String _developerName = 'محمد احمد محمد';
  static const String _developerPhone = '07701574997';
  static const String _developerPhoneIntl = '9647701574997';
  static const String _developerRole = 'ئەندازیاری شارستانی • گەشەپێدەری ئەپ';
  static const String _developerEmail = '';
  static const String _facebookUrl = '';
  static const String _instagramUrl = '';
  static const String _telegramUser = '';

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
            'دەربارەی من',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 17,
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
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C5CE7), Color(0xFFE91E63)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 15,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.engineering_rounded,
                        size: 60,
                        color: Color(0xFF6C5CE7),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _developerName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _developerRole,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('📝 دەربارەی من', isDark),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade200,
                ),
              ),
              child: Text(
                'سڵاو! من $_developerName م، $_developerRole. '
                    'ئەم ئەپەم بە مەبەستی خزمەتکردنی خەڵکی شاری کەلار '
                    'دروستکردووە، بەبێ چاوەڕوانی هیچ داهاتێک. '
                    'هیوادارم ئەم ئەپە ببێتە هۆکاری ئاسانکاری بۆ '
                    'هاوڵاتیانی خۆشەویستمان.',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white70 : Colors.grey.shade800,
                  height: 1.8,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('📞 پەیوەندی', isDark),
            const SizedBox(height: 12),
            _buildContactCard(
              icon: Icons.phone_rounded,
              title: 'ژمارەی مۆبایل',
              value: _developerPhone,
              color: const Color(0xFF10B981),
              isDark: isDark,
              onTap: () => _launchUrl('tel:$_developerPhone'),
            ),
            const SizedBox(height: 10),
            if (_developerEmail.isNotEmpty) ...[
              _buildContactCard(
                icon: Icons.email_rounded,
                title: 'ئیمەیڵ',
                value: _developerEmail,
                color: const Color(0xFF1E88E5),
                isDark: isDark,
                onTap: () => _launchUrl('mailto:$_developerEmail'),
              ),
              const SizedBox(height: 10),
            ],
            _buildContactCard(
              icon: Icons.chat_rounded,
              title: 'واتسئاپ',
              value: _developerPhone,
              color: const Color(0xFF25D366),
              isDark: isDark,
              onTap: () => _launchUrl('https://wa.me/$_developerPhoneIntl'),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF10B981), Color(0xFF059669)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Column(
                children: [
                  Icon(Icons.favorite_rounded, color: Colors.white, size: 40),
                  SizedBox(height: 12),
                  Text(
                    'سوپاس بۆ هەموو ئەوانەی',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'یارمەتییان دا لەم کارە خزمەتگوزارییەدا',
                    style: TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                  SizedBox(height: 16),
                  Divider(color: Colors.white24),
                  SizedBox(height: 10),
                  Text(
                    'بە خۆشەویستی دروستکراوە بۆ خەڵکی کەلار ❤️',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
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

  Widget _buildContactCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
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
                      color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 14,
              color: isDark ? Colors.white38 : Colors.grey,
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