import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kalar_guide_new/config/app_colors.dart';
import 'package:kalar_guide_new/config/theme.dart'; // بۆ AppThemeColors

/// 👨‍💻 شاشەی دەربارەی من — ULTRA PRO MAX V7
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
  static const String _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.muhammad.kalar.kalar_guide';

  /// ✅ QR و لینکی هاوبەشکردن ڕاستەوخۆ بۆ Play Store دەچن
  ///    (kalar-guide.com/app نەپشکنرا — ئەگەر کار دەکات، دەتوانیت بیگەڕێنیتەوە)
  static const String _appUrl = _playStoreUrl;

  // 📊 ئاماری ڕاستەقینە لە بنکەدراوەوە — تا دەگات، ژمارە کۆنەکان نیشان دەدرێن
  int? _neighborhoodCount;
  int? _storeCount;
  bool _reduceMotion = false;

  String _appVersion = '1.0.0';
  String _buildNumber = '1';

  // ✨ Animations
  late final AnimationController _headerController;
  late final AnimationController _floatController;
  late final AnimationController _pulseController;
  late final AnimationController _entryController;
  late final Animation<double> _headerAnimation;
  late final Animation<double> _floatAnimation;
  late final Animation<double> _pulseAnimation;

  // ═══════════════════════════════════════════════════════════
  // 🎯 Services Data (const — بۆ ئەدای باشتر)
  // ═══════════════════════════════════════════════════════════
  static const List<_ServiceItem> _services = [
    _ServiceItem(
      icon: Icons.business_rounded,
      label: 'دیزاینی بینا',
      color: AppColors.primary,
    ),
    _ServiceItem(
      icon: Icons.architecture_rounded,
      label: 'نەخشەکێشان',
      color: AppColors.purple,
    ),
    _ServiceItem(
      icon: Icons.engineering_rounded,
      label: 'سەرپەرشتی پڕۆژە',
      color: AppColors.green,
    ),
    _ServiceItem(
      icon: Icons.calculate_rounded,
      label: 'حسابکردنی بڕیار',
      color: AppColors.orange,
    ),
    _ServiceItem(
      icon: Icons.phone_android_rounded,
      label: 'گەشەپێدانی ئەپ',
      color: AppColors.pink, // ⚠️ دڵنیابە لەوەی ئەم ڕەنگە لە AppColors دا هەیە، ئەگەنا بیکە بە Colors.pink
    ),
    _ServiceItem(
      icon: Icons.palette_rounded,
      label: 'دیزاینی گرافیک',
      color: AppColors.teal,
    ),
  ];

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
    _loadStats();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ♿ ڕێزگرتن لە «کەمکردنەوەی جووڵە»ی سیستەم
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _floatController.stop();
      _pulseController.stop();
      _entryController.value = 1;
    } else {
      if (!_floatController.isAnimating) _floatController.repeat(reverse: true);
      if (!_pulseController.isAnimating) _pulseController.repeat(reverse: true);
    }
  }

  Future<int?> _count(String table) async {
    try {
      final res = await Supabase.instance.client.from(table).select('id').count();
      return res.count;
    } catch (e) {
      debugPrint('⚠️ count $table: $e');
      return null;
    }
  }

  Future<void> _loadStats() async {
    final results = await Future.wait([_count('neighborhoods'), _count('dukan')]);
    if (!mounted) return;
    setState(() {
      _neighborhoodCount = results[0];
      _storeCount = results[1];
    });
  }

  static String _ku(Object n) => n.toString().replaceAllMapped(
        RegExp(r'\d'),
        (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)],
      );

  /// ١٠٠+ بۆ ژمارە گەورەکان، ژمارەی ڕاستەقینە بۆ بچووکەکان
  String _statText(int? n, String fallback) {
    if (n == null || n <= 0) return fallback;
    if (n >= 1000) return '${_ku((n ~/ 100) * 100)}+';
    if (n >= 100) return '${_ku((n ~/ 10) * 10)}+';
    return _ku(n);
  }

  String get _neighborhoodsText => _statText(_neighborhoodCount, '٥٩');
  String get _storesText => _statText(_storeCount, '١٠٠+');

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
      if (!mounted) return;
      setState(() {
        _appVersion = info.version;
        _buildNumber = info.buildNumber;
      });
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
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final textTheme = Theme.of(context).textTheme;

    // ✅ بەکارهێنانی ThemeExtension بۆ ڕەنگی سەرکەوتوو و هەڵە
    final ext = Theme.of(context).extension<AppThemeColors>();
    final successColor = ext?.success ?? AppColors.green;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
      backgroundColor: bgColor,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildAppBar(isDark),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildSectionTitle('📝 دەربارەی من', isDark, textTheme),
                  const SizedBox(height: 12),
                  _buildBioCard(isDark, 0, textTheme),
                  const SizedBox(height: 20),
                  _buildSectionTitle('📞 پەیوەندی', isDark, textTheme),
                  const SizedBox(height: 12),
                  _buildContactCard(
                    isDark: isDark,
                    icon: Icons.phone_rounded,
                    iconColor: successColor,
                    title: 'ژمارەی مۆبایل',
                    value: _phone,
                    onTap: () => _call(_phone),
                    itemIndex: 1,
                    textTheme: textTheme,
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
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle('🎯 خزمەتگوزارییەکان', isDark, textTheme),
                  const SizedBox(height: 12),
                  _buildServicesCard(isDark, 3, textTheme),
                  const SizedBox(height: 20),
                  _buildSectionTitle('🌐 هاوبەشکردن', isDark, textTheme),
                  const SizedBox(height: 12),
                  _buildShareCard(isDark, 4, textTheme),
                  const SizedBox(height: 20),
                  _buildSectionTitle('⭐ هەڵسەنگاندن', isDark, textTheme),
                  const SizedBox(height: 12),
                  _buildRateCard(5, textTheme),
                  const SizedBox(height: 24),
                  _buildThanksCard(6),
                  const SizedBox(height: 20),
                  _buildVersionCard(isDark, 7, textTheme, successColor),
                  const SizedBox(height: 10),
                  _buildReportCard(isDark, 8, textTheme),
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
  // 🐞 ناردنی ڕاپۆرتی کێشە — وەشان خۆکارانە زیاد دەکرێت
  // ═══════════════════════════════════════════════════════════
  Widget _buildReportCard(bool isDark, int itemIndex, TextTheme textTheme) {
    return _entryWrap(
      itemIndex: itemIndex,
      child: Material(
        color: isDark ? AppColors.darkCard : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            HapticFeedback.lightImpact();
            _openWhatsApp(
              text: 'سڵاو، کێشەیەکم هەیە لە ئەپی ڕێبەری کەلار:\n\n'
                  '...\n\n'
                  '— وەشان: v$_appVersion ($_buildNumber)',
            );
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.red.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.red.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.bug_report_rounded, color: AppColors.red, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'ناردنی ڕاپۆرتی کێشە',
                        style: textTheme.titleSmall?.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ڕاستەوخۆ لە واتسئاپ، وەشانی ئەپەکەش دەنێردرێت',
                        style: textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          color: isDark ? Colors.white54 : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_left_rounded, color: isDark ? Colors.white38 : Colors.grey[400]),
              ],
            ),
          ),
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
      backgroundColor: AppColors.darkBackground,
      foregroundColor: Colors.white,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.darkBackground,
                Color(0xFF2D1B4E),
                AppColors.purple,
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
                                    AppColors.yellow,
                                    AppColors.orange,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.yellow
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
                                  color: AppColors.purple,
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
  Widget _buildSectionTitle(String title, bool isDark, TextTheme textTheme) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.yellow, AppColors.orange],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: textTheme.titleMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📝 Bio Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildBioCard(bool isDark, int itemIndex, TextTheme textTheme) {
    return _entryWrap(
      itemIndex: itemIndex,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.purple.withValues(alpha: 0.2),
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
                    color: AppColors.purple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.emoji_emotions_rounded,
                    color: AppColors.purple,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'سڵاو! من $_developerNameم',
                    style: textTheme.titleSmall?.copyWith(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textPrimary,
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
              style: textTheme.bodyMedium?.copyWith(
                fontSize: 13,
                height: 1.7,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
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
                  color: AppColors.primary,
                  textTheme: textTheme,
                ),
                _buildMiniStat(
                  isDark: isDark,
                  icon: Icons.people_rounded,
                  value: _neighborhoodsText,
                  label: 'گەڕەک',
                  color: AppColors.green,
                  textTheme: textTheme,
                ),
                _buildMiniStat(
                  isDark: isDark,
                  icon: Icons.storefront_rounded,
                  value: _storesText,
                  label: 'شوێن',
                  color: AppColors.orange,
                  textTheme: textTheme,
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
    required TextTheme textTheme,
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
              style: textTheme.titleMedium?.copyWith(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: textTheme.labelSmall?.copyWith(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white60 : AppColors.textSecondary,
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
    required TextTheme textTheme,
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
              color: isDark ? AppColors.darkCard : AppColors.surface,
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
                        style: textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white54
                              : AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: textTheme.titleMedium?.copyWith(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color:
                          isDark ? Colors.white : AppColors.textPrimary,
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
                    _showSnack('✅ کۆپی کرا', AppColors.green);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : AppColors.backgroundGrey,
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
  Widget _buildServicesCard(bool isDark, int itemIndex, TextTheme textTheme) {
    return _entryWrap(
      itemIndex: itemIndex,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.purple.withValues(alpha: 0.15),
          ),
        ),
        child: GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.0,
          children: _services.map((s) {
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    s.color.withValues(alpha: 0.15),
                    s.color.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: s.color.withValues(alpha: 0.25)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(s.icon, color: s.color, size: 22),
                  const SizedBox(height: 6),
                  Text(
                    s.label,
                    style: textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isDark
                          ? Colors.white70
                          : AppColors.textSecondary,
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
  Widget _buildShareCard(bool isDark, int itemIndex, TextTheme textTheme) {
    return _entryWrap(
      itemIndex: itemIndex,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
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
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: AppColors.textPrimary,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: AppColors.textPrimary,
                ),
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'سکان بکە بۆ داگرتنی ئەپ',
              style: textTheme.labelMedium?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildShareButton(
                    icon: Icons.share_rounded,
                    label: 'هاوبەشکردن',
                    color: AppColors.primary,
                    onTap: _shareApp,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildShareButton(
                    icon: Icons.link_rounded,
                    label: 'کۆپیکردنی لینک',
                    color: AppColors.purple,
                    onTap: () {
                      Clipboard.setData(
                        const ClipboardData(text: _appUrl),
                      );
                      HapticFeedback.mediumImpact();
                      _showSnack('✅ لینک کۆپی کرا', AppColors.green);
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
  Widget _buildRateCard(int itemIndex, TextTheme textTheme) {
    return _entryWrap(
      itemIndex: itemIndex,
      child: GestureDetector(
        onTap: _rateApp,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.yellow.withValues(alpha: 0.15),
                AppColors.orange.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: AppColors.yellow.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.yellow, AppColors.orange],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.yellow.withValues(alpha: 0.5),
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
                      style: textTheme.titleMedium?.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'تکایە ٥ ئەستێرەمان پێبدە ⭐',
                      style: textTheme.bodySmall?.copyWith(fontSize: 11),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_left_rounded,
                color: AppColors.yellow,
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
  Widget _buildThanksCard(int itemIndex) {
    return _entryWrap(
      itemIndex: itemIndex,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppColors.green, Color(0xFF059669)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.green.withValues(alpha: 0.4),
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
  Widget _buildVersionCard(bool isDark, int itemIndex, TextTheme textTheme, Color successColor) {
    return _entryWrap(
      itemIndex: itemIndex,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.info_rounded,
                color: AppColors.purple,
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
                    style: textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? Colors.white54
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'v$_appVersion (build $_buildNumber)',
                    style: textTheme.titleSmall?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color:
                      isDark ? Colors.white : AppColors.textPrimary,
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
                color: successColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: successColor.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    color: successColor,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'دامەزراوە',
                    style: textTheme.labelSmall?.copyWith(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: successColor,
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
  // ⭐ Entry animation wrapper
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
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            msg,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          backgroundColor: color,
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
  }

  Future<void> _call(String phone) async {
    try {
      final uri = Uri(scheme: 'tel', path: phone);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        _showSnack('⚠️ نەتوانرا پەیوەندی بکرێت', AppColors.red);
      }
    } catch (e) {
      debugPrint('❌ Call error: $e');
      _showSnack('⚠️ هەڵە لە پەیوەندیدا', AppColors.red);
    }
  }

  Future<void> _openWhatsApp({String? text}) async {
    try {
      final message = Uri.encodeComponent(
        text ?? 'سڵاو! دەربارەی ئەپی ڕێبەری کەلار قسەم پێوە بکە',
      );
      final uri = Uri.parse('https://wa.me/$_whatsapp?text=$message');
      // ✅ canLaunchUrl لە Android 11+ بۆ https زۆرجار false دەداتەوە —
      //    سەرەتا ئەپی واتسئاپ، ئەگەر نەبوو وێبگەڕ
      var ok = false;
      try {
        ok = await launchUrl(uri, mode: LaunchMode.externalNonBrowserApplication);
      } catch (_) {}
      if (!ok) ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok) _showSnack('⚠️ واتسئاپ دەستنەکەوێت', AppColors.red);
    } catch (e) {
      debugPrint('❌ WhatsApp error: $e');
      _showSnack('⚠️ هەڵە لە واتسئاپدا', AppColors.red);
    }
  }

  Future<void> _shareApp() async {
    try {
      await Share.share(
        '🏙️ ئەپی ڕێبەری کەلار — ڕێبەری فەرمی شاری کەلار\n\n'
            '✅ $_neighborhoodsText گەڕەک\n'
            '✅ $_storesText شوێن\n'
            '✅ سکاڵا و ڕووداو\n'
            '✅ دراو و سووتەمەنی\n\n'
            'داگرتن: $_appUrl',
        subject: 'ڕێبەری کەلار — ئەپی فەرمی شاری کەلار',
      );
    } catch (e) {
      debugPrint('❌ Share error: $e');
      _showSnack('⚠️ نەتوانرا هاوبەش بکرێت', AppColors.red);
    }
  }

  Future<void> _rateApp() async {
    try {
      // ✅ سەرەتا ئەپی Play Store، ئەگەر نەبوو وێبگەڕ
      final market = Uri.parse('market://details?id=com.muhammad.kalar.kalar_guide');
      var ok = false;
      try {
        ok = await launchUrl(market, mode: LaunchMode.externalApplication);
      } catch (_) {}
      if (!ok) ok = await launchUrl(Uri.parse(_playStoreUrl), mode: LaunchMode.externalApplication);
      if (!ok) _showSnack('⚠️ نەتوانرا Play Store بکرێتەوە', AppColors.red);
    } catch (e) {
      debugPrint('❌ Rate error: $e');
      _showSnack('⚠️ هەڵە لە کردنەوەی Play Store', AppColors.red);
    }
  }
}

// ═══════════════════════════════════════════════════════════
// 🧱 Data Model
// ═══════════════════════════════════════════════════════════
class _ServiceItem {
  final IconData icon;
  final String label;
  final Color color;

  const _ServiceItem({
    required this.icon,
    required this.label,
    required this.color,
  });
}