import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:kalar_guide_new/config/app_colors.dart';
import '../../l10n/tr.dart';
import 'package:kalar_guide_new/config/theme.dart'; // بۆ AppThemeColors

part 'about_screen_ui.dart';

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
  static final List<_ServiceItem> _services = [
    _ServiceItem(
      icon: Icons.business_rounded,
      label: tr('دیزاینی بینا'),
      color: AppColors.primary,
    ),
    _ServiceItem(
      icon: Icons.architecture_rounded,
      label: tr('نەخشەکێشان'),
      color: AppColors.purple,
    ),
    _ServiceItem(
      icon: Icons.engineering_rounded,
      label: tr('سەرپەرشتی پڕۆژە'),
      color: AppColors.green,
    ),
    _ServiceItem(
      icon: Icons.calculate_rounded,
      label: tr('حسابکردنی بڕیار'),
      color: AppColors.orange,
    ),
    _ServiceItem(
      icon: Icons.phone_android_rounded,
      label: tr('گەشەپێدانی ئەپ'),
      color: AppColors.pink, // ⚠️ دڵنیابە لەوەی ئەم ڕەنگە لە AppColors دا هەیە، ئەگەنا بیکە بە Colors.pink
    ),
    _ServiceItem(
      icon: Icons.palette_rounded,
      label: tr('دیزاینی گرافیک'),
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
      textDirection: AppLang.direction,
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
                  _buildSectionTitle(tr('📝 دەربارەی من'), isDark, textTheme),
                  const SizedBox(height: 12),
                  _buildBioCard(isDark, 0, textTheme),
                  const SizedBox(height: 20),
                  _buildSectionTitle(tr('📞 پەیوەندی'), isDark, textTheme),
                  const SizedBox(height: 12),
                  _buildContactCard(
                    isDark: isDark,
                    icon: Icons.phone_rounded,
                    iconColor: successColor,
                    title: tr('ژمارەی مۆبایل'),
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
                    title: tr('واتسئاپ'),
                    value: _phone,
                    onTap: () => _openWhatsApp(),
                    itemIndex: 2,
                    textTheme: textTheme,
                  ),
                  const SizedBox(height: 20),
                  _buildSectionTitle(tr('🎯 خزمەتگوزارییەکان'), isDark, textTheme),
                  const SizedBox(height: 12),
                  _buildServicesCard(isDark, 3, textTheme),
                  const SizedBox(height: 20),
                  _buildSectionTitle(tr('🌐 هاوبەشکردن'), isDark, textTheme),
                  const SizedBox(height: 12),
                  _buildShareCard(isDark, 4, textTheme),
                  const SizedBox(height: 20),
                  _buildSectionTitle(tr('⭐ هەڵسەنگاندن'), isDark, textTheme),
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
  // 🛠️ Actions
  // ═══════════════════════════════════════════════════════════
  void _showSnack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            tr(msg),
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
        _showSnack(tr('⚠️ نەتوانرا پەیوەندی بکرێت'), AppColors.red);
      }
    } catch (e) {
      debugPrint('❌ Call error: $e');
      _showSnack(tr('⚠️ هەڵە لە پەیوەندیدا'), AppColors.red);
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
      if (!ok) _showSnack(tr('⚠️ واتسئاپ دەستنەکەوێت'), AppColors.red);
    } catch (e) {
      debugPrint('❌ WhatsApp error: $e');
      _showSnack(tr('⚠️ هەڵە لە واتسئاپدا'), AppColors.red);
    }
  }

  Future<void> _shareApp() async {
    try {
      await Share.share(
        trf(
          '🏙️ ئەپی ڕێبەری کەلار — ڕێبەری فەرمی شاری کەلار\n\n✅ {0} گەڕەک\n✅ {1} شوێن\n✅ سکاڵا و ڕووداو\n✅ دراو و سووتەمەنی\n\nداگرتن: {2}',
          [_neighborhoodsText, _storesText, _appUrl],
        ),
        subject: tr('ڕێبەری کەلار — ئەپی فەرمی شاری کەلار'),
      );
    } catch (e) {
      debugPrint('❌ Share error: $e');
      _showSnack(tr('⚠️ نەتوانرا هاوبەش بکرێت'), AppColors.red);
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
      if (!ok) _showSnack(tr('⚠️ نەتوانرا Play Store بکرێتەوە'), AppColors.red);
    } catch (e) {
      debugPrint('❌ Rate error: $e');
      _showSnack(tr('⚠️ هەڵە لە کردنەوەی Play Store'), AppColors.red);
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