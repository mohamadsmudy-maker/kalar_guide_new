import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// 👨‍💻 شاشەی دەربارەی من — ULTRA PRO V4
class AboutScreen extends StatefulWidget {
  const AboutScreen({super.key});

  @override
  State<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends State<AboutScreen>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════
  // 📊 Info
  // ═══════════════════════════════════════════════════════════
  static const String _developerName = 'محمد احمد محمد';
  static const String _developerTitle = 'ئەندازیاری شارستانی';
  static const String _phone = '07701574997';
  static const String _whatsapp = '9647701574997';
  static const String _appUrl = 'https://kalar-guide.com/app';
  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.muhammad.kalar.kalar_guide';

  String _appVersion = '1.0.0';
  String _buildNumber = '1';

  // ✨ Animations
  late AnimationController _headerController;
  late AnimationController _floatController;
  late AnimationController _pulseController;
  late AnimationController _entryController;
  late Animation<double> _headerAnimation;
  late Animation<double> _floatAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _headerController.forward();
    _entryController.forward();
    _loadVersion();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _floatController.dispose();
    _pulseController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = info.version;
          _buildNumber = info.buildNumber;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Version error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAppBar(isDark),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildSectionTitle('📝 دەربارەی من', isDark),
                    const SizedBox(height: 12),
                    _buildBioCard(isDark, 0),
                    const SizedBox(height: 20),
                    _buildSectionTitle('📞 پەیوەندی', isDark),
                    const SizedBox(height: 12),
                    _buildContactCard(
                      isDark: isDark,
                      icon: Icons.phone_rounded,
                      iconColor: const Color(0xFF10B981),
                      title: 'ژمارەی مۆبایل',
                      value: _phone,
                      onTap: () => _call(_phone),
                      itemIndex: 1,
                    ),
                    const SizedBox(height: 10),
                    _buildContactCard(
                      isDark: isDark,
                      icon: Icons.chat_bubble_rounded,
                      iconColor: const Color(0xFF25D366),
                      title: 'واتسئاپ',
                      value: _phone,
                      onTap: () => _openWhatsApp(),
                      itemIndex: 2,
                    ),
                    const SizedBox(height: 20),
                    _buildSectionTitle('🎯 خزمەتگوزارییەکان', isDark),
                    const SizedBox(height: 12),
                    _buildServicesCard(isDark, 3),
                    const SizedBox(height: 20),
                    _buildSectionTitle('🌐 هاوبەشکردن', isDark),
                    const SizedBox(height: 12),
                    _buildShareCard(isDark, 4),
                    const SizedBox(height: 20),
                    _buildSectionTitle('⭐ هەڵسەنگاندن', isDark),
                    const SizedBox(height: 12),
                    _buildRateCard(isDark, 5),
                    const SizedBox(height: 24),
                    _buildThanksCard(isDark, 6),
                    const SizedBox(height: 20),
                    _buildVersionCard(isDark, 7),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 AppBar
  // ═══════════════════════════════════════════════════════════
  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: const Color(0xFF1A1B2E),
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF1A1B2E),
                Color(0xFF2D1B4E),
                Color(0xFF8B5CF6),
              ],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -60,
                right: -60,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Positioned(
                bottom: -40,
                left: -40,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedBuilder(
                        animation: _floatController,
                        builder: (context, child) {
                          return Transform.translate(
                            offset: Offset(0, _floatAnimation.value),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFD700),
                                    Color(0xFFFF8F00),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFFFD700)
                                        .withValues(alpha: 0.5),
                                    blurRadius: 24,
                                    spreadRadius: 4,
                                  ),
                                ],
                              ),
                              child: const CircleAvatar(
                                radius: 42,
                                backgroundColor: Colors.white,
                                child: Icon(
                                  Icons.person_rounded,
                                  size: 50,
                                  color: Color(0xFF8B5CF6),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 14),
                      FadeTransition(
                        opacity: _headerAnimation,
                        child: const Text(
                          _developerName,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FadeTransition(
                        opacity: _headerAnimation,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: const Text(
                            _developerTitle,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
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
  // 📝 Section Title
  // ═══════════════════════════════════════════════════════════
  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD700), Color(0xFFFF8F00)],
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

  // ═══════════════════════════════════════════════════════════
  // 📝 Bio Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildBioCard(bool isDark, int itemIndex) {
    return _entryWrap(
      itemIndex: itemIndex,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color:
                    const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.emoji_emotions_rounded,
                    color: Color(0xFF8B5CF6),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'سڵاو! من $_developerNameم',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1A1A2E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'ئەندازیاری شارستانی و گەشەپێدەری ئەپی "ڕێبەری کەلار". '
                  'ئەم ئەپەم بە مەبەستی خزمەتکردنی خەڵکی شاری کەلار '
                  'دروستکردووە، بەبێ چاوەڕوانی هیچ داهاتێک. '
                  'هیوادارم ئەم ئەپە ببێتە هۆکاری ئاسانکاری بۆ '
                  'هاوڵاتییانی خۆشەویستمان.',
              style: TextStyle(
                fontSize: 13,
                height: 1.7,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildMiniStat(
                  isDark: isDark,
                  icon: Icons.apps_rounded,
                  value: '١٠+',
                  label: 'تایبەتمەندی',
                  color: const Color(0xFF3B82F6),
                ),
                _buildMiniStat(
                  isDark: isDark,
                  icon: Icons.people_rounded,
                  value: '٥٩',
                  label: 'گەڕەک',
                  color: const Color(0xFF10B981),
                ),
                _buildMiniStat(
                  isDark: isDark,
                  icon: Icons.storefront_rounded,
                  value: '١٠٠+',
                  label: 'شوێن',
                  color: const Color(0xFFF59E0B),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniStat({
    required bool isDark,
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📞 Contact Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildContactCard({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required VoidCallback onTap,
    required int itemIndex,
  }) {
    return _entryWrap(
      itemIndex: itemIndex,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A22) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: iconColor.withValues(alpha: 0.25),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: iconColor.withValues(alpha: 0.1),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        iconColor,
                        iconColor.withValues(alpha: 0.7),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: iconColor.withValues(alpha: 0.4),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(icon, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white54
                              : Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A2E),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: value));
                    HapticFeedback.mediumImpact();
                    _showSnack('✅ کۆپی کرا', const Color(0xFF10B981));
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.copy_rounded,
                      size: 16,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_left_rounded,
                  color: isDark ? Colors.white38 : Colors.grey[400],
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 Services Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildServicesCard(bool isDark, int itemIndex) {
    final services = [
      {
        'icon': Icons.business_rounded,
        'label': 'دیزاینی بینا',
        'color': const Color(0xFF3B82F6),
      },
      {
        'icon': Icons.architecture_rounded,
        'label': 'نەخشەکێشان',
        'color': const Color(0xFF8B5CF6),
      },
      {
        'icon': Icons.engineering_rounded,
        'label': 'سەرپەرشتی پڕۆژە',
        'color': const Color(0xFF10B981),
      },
      {
        'icon': Icons.calculate_rounded,
        'label': 'حسابکردنی بڕیار',
        'color': const Color(0xFFF59E0B),
      },
      {
        'icon': Icons.phone_android_rounded,
        'label': 'گەشەپێدانی ئەپ',
        'color': const Color(0xFFE91E63),
      },
      {
        'icon': Icons.palette_rounded,
        'label': 'دیزاینی گرافیک',
        'color': const Color(0xFF06B6D4),
      },
    ];

    return _entryWrap(
      itemIndex: itemIndex,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
          ),
        ),
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.0,
          children: services.map((s) {
            final color = s['color'] as Color;
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.15),
                    color.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border:
                Border.all(color: color.withValues(alpha: 0.25)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(s['icon'] as IconData, color: color, size: 22),
                  const SizedBox(height: 6),
                  Text(
                    s['label'] as String,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? Colors.white70
                          : Colors.grey.shade700,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🌐 Share Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildShareCard(bool isDark, int itemIndex) {
    return _entryWrap(
      itemIndex: itemIndex,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: _appUrl,
                version: QrVersions.auto,
                size: 140,
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF1A1A2E),
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'سکان بکە بۆ داگرتنی ئەپ',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildShareButton(
                    icon: Icons.share_rounded,
                    label: 'هاوبەشکردن',
                    color: const Color(0xFF3B82F6),
                    onTap: _shareApp,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildShareButton(
                    icon: Icons.link_rounded,
                    label: 'کۆپیکردنی لینک',
                    color: const Color(0xFF8B5CF6),
                    onTap: () {
                      Clipboard.setData(
                        const ClipboardData(text: _appUrl),
                      );
                      HapticFeedback.mediumImpact();
                      _showSnack(
                        '✅ لینک کۆپی کرا',
                        const Color(0xFF10B981),
                      );
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ⭐ Rate Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildRateCard(bool isDark, int itemIndex) {
    return _entryWrap(
      itemIndex: itemIndex,
      child: GestureDetector(
        onTap: _rateApp,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFFFFD700).withValues(alpha: 0.15),
                const Color(0xFFFF8F00).withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFFFD700).withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFD700), Color(0xFFFF8F00)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFFD700)
                          .withValues(alpha: 0.5),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.star_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'ئەپەکە بەدڵتە؟',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تکایە ٥ ئەستێرەمان پێبدە ⭐',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.white54
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left_rounded,
                color: Color(0xFFFFD700),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 💚 Thanks Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildThanksCard(bool isDark, int itemIndex) {
    return _entryWrap(
      itemIndex: itemIndex,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF10B981), Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF10B981).withValues(alpha: 0.4),
              blurRadius: 24,
              offset: const Offset(0, 12),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            const Text(
              'سوپاس بۆ هەموو ئەوانەی',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'یارمەتییان دا لەم کارە خزمەتگوزارییەدا',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 14),
            Container(
              height: 1,
              color: Colors.white.withValues(alpha: 0.2),
            ),
            const SizedBox(height: 14),
            const Text(
              '💚 بە خۆشەویستی دروستکراوە بۆ خەڵکی کەلار',
              style: TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📱 Version Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildVersionCard(bool isDark, int itemIndex) {
    return _entryWrap(
      itemIndex: itemIndex,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.grey.shade200,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.info_rounded,
                color: Color(0xFF8B5CF6),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'وەشانی ئەپ',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white54
                          : Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'v$_appVersion (build $_buildNumber)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? Colors.white
                          : const Color(0xFF1A1A2E),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 5,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF10B981),
                    size: 12,
                  ),
                  SizedBox(width: 4),
                  Text(
                    'نوێترین',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF10B981),
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

  // ═══════════════════════════════════════════════════════════
  // ⭐ Entry animation wrapper (کەمکردنەوەی دووبارەبوونەوە)
  // ═══════════════════════════════════════════════════════════
  Widget _entryWrap({
    required int itemIndex,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, _) {
        final delay = (itemIndex * 0.05).clamp(0.0, 0.5);
        final progress =
        ((_entryController.value - delay) / 0.5).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - progress)),
          child: Opacity(opacity: progress, child: child),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🛠️ Actions
  // ═══════════════════════════════════════════════════════════
  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Future<void> _call(String phone) async {
    try {
      final uri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showSnack('⚠️ نەتوانرا پەیوەندی بکرێت', const Color(0xFFEF4444));
      }
    } catch (e) {
      debugPrint('❌ Call error: $e');
      _showSnack('⚠️ هەڵە لە پەیوەندیدا', const Color(0xFFEF4444));
    }
  }

  Future<void> _openWhatsApp() async {
    try {
      final message = Uri.encodeComponent(
        'سڵاو! دەربارەی ئەپی ڕێبەری کەلار قسەم پێوە بکە',
      );
      final uri = Uri.parse('https://wa.me/$_whatsapp?text=$message');
      if (await canLaunchUrl(uri)) {
        await launchUrl(
          uri,
          mode: LaunchMode.externalNonBrowserApplication,
        );
      } else {
        _showSnack('⚠️ واتسئاپ دەستنەکەوێت', const Color(0xFFEF4444));
      }
    } catch (e) {
      debugPrint('❌ WhatsApp error: $e');
      _showSnack('⚠️ هەڵە لە واتسئاپدا', const Color(0xFFEF4444));
    }
  }

  Future<void> _shareApp() async {
    try {
      // ✅ شێوازی کۆن بۆ share_plus 10.x
      await Share.share(
        '🏙️ ئەپی ڕێبەری کەلار — ڕێبەری فەرمی شاری کەلار\n\n'
            '✅ ٥٩ گەڕەک\n'
            '✅ ١٠٠+ شوێن\n'
            '✅ سکاڵا و ڕووداو\n'
            '✅ دراو و سووتەمەنی\n\n'
            'داگرتن: $_appUrl',
        subject: 'ڕێبەری کەلار — ئەپی فەرمی شاری کەلار',
      );
    } catch (e) {
      debugPrint('❌ Share error: $e');
      _showSnack('⚠️ نەتوانرا هاوبەش بکرێت', const Color(0xFFEF4444));
    }
  }

  Future<void> _rateApp() async {
    try {
      final uri = Uri.parse(_playStoreUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        _showSnack(
          '⚠️ نەتوانرا Play Store بکرێتەوە',
          const Color(0xFFEF4444),
        );
      }
    } catch (e) {
      debugPrint('❌ Rate error: $e');
      _showSnack('⚠️ هەڵە لە کردنەوەی Play Store', const Color(0xFFEF4444));
    }
  }
}