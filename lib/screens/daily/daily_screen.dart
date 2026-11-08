// lib/screens/daily/daily_screen.dart
// ULTRA PRO MAX V2 — Daily services dashboard
//
// ✅ هەموو دەقەکان بە سێ زمان (ku / ar / en)
// ✅ مانگە عەرەبییەکان بۆ زمانی عەرەبی
// ✅ کاتژمێر تەنها کاتێک خولەک دەگۆڕێت ڕیبیلد دەکات
// ✅ گرید لەگەڵ قەبارەی فۆنت گەورە دەبێت (overflow نییە)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../services/weather_service.dart';

import '../currency/currency_rates_screen.dart';
import '../departments/departments_screen.dart';
import '../emergency/emergency_main_screen.dart';
import '../fuel/fuel_types_screen.dart';
import '../videos/user_videos.dart';
import 'prayer_times_screen.dart';
import 'qibla_finder_screen.dart';
import '../weather/weather_screen.dart';
import '../../l10n/tr.dart';

class DailyScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;

  const DailyScreen({super.key, this.onMenuTap});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen>
    with AutomaticKeepAliveClientMixin {
  late final Timer _clockTimer;
  final ValueNotifier<DateTime> _now = ValueNotifier<DateTime>(DateTime.now());

  String _lang = 'ku';
  bool _isRefreshing = false;

  @override
  bool get wantKeepAlive => true;

  bool get _isEn => _lang == 'en';
  bool get _isAr => _lang == 'ar';
  bool get _isRtl => !_isEn;

  static const Map<String, Map<String, String>> _tr = {
    'title': {'ku': 'ڕۆژانە', 'ar': 'يومي', 'en': 'Daily'},
    'menu': {'ku': 'کردنەوەی مێنیو', 'ar': 'فتح القائمة', 'en': 'Open menu'},
    'refresh': {'ku': 'نوێکردنەوە', 'ar': 'تحديث', 'en': 'Refresh'},
    'refresh_error': {
      'ku': 'نوێکردنەوەی زانیاری کەشوهەوا سەرکەوتوو نەبوو.',
      'ar': 'تعذر تحديث بيانات الطقس. حاول مرة أخرى.',
      'en': 'Could not refresh weather data. Please try again.',
    },
    'hub': {'ku': 'ناوەندی ڕۆژانەت', 'ar': 'مركزك اليومي', 'en': 'YOUR DAILY HUB'},
    'hero': {'ku': 'ڕۆژەکەت ئاسانتر بکە.', 'ar': 'اجعل يومك أسهل.', 'en': 'Make your day easier.'},
    'hero_sub': {
      'ku': 'هەموو ئەو شتانەی پێویستتە لە یەک شوێندا.',
      'ar': 'كل ما تحتاجه في مكان واحد.',
      'en': 'Everything you need, in one place.',
    },
    'services': {'ku': 'خزمەتگوزارییەکان', 'ar': 'الخدمات', 'en': 'Services'},
    'services_sub': {
      'ku': 'هەموو پێداویستییەکانی ڕۆژانەت',
      'ar': 'كل احتياجاتك اليومية',
      'en': 'All your daily essentials',
    },
    'live': {'ku': 'زیندوو', 'ar': 'مباشر', 'en': 'Live'},
    'emergency': {'ku': 'فریاکەوتن', 'ar': 'الطوارئ', 'en': 'Emergency'},
    'emergency_sub': {'ku': 'ژمارەکانی فریاکەوتن', 'ar': 'أرقام الطوارئ', 'en': 'Emergency numbers'},
    'prayer': {'ku': 'نوێژەکان', 'ar': 'الصلاة', 'en': 'Prayer'},
    'prayer_sub': {'ku': 'کاتەکانی بانگ', 'ar': 'أوقات الأذان', 'en': 'Prayer times'},
    'currency': {'ku': 'دراوەکان', 'ar': 'العملات', 'en': 'Currency'},
    'currency_sub': {'ku': 'نرخی دۆلار و دینار', 'ar': 'سعر الدولار والدينار', 'en': 'USD & IQD rates'},
    'qibla': {'ku': 'قیبلە', 'ar': 'القبلة', 'en': 'Qibla'},
    'qibla_sub': {'ku': 'ئاراستەی قیبلە', 'ar': 'اتجاه القبلة', 'en': 'Qibla direction'},
    'fuel': {'ku': 'سووتەمەنی', 'ar': 'الوقود', 'en': 'Fuel'},
    'fuel_sub': {'ku': 'نرخی بەنزین', 'ar': 'أسعار البنزين', 'en': 'Fuel prices'},
    'weather': {'ku': 'کەشوهەوا', 'ar': 'الطقس', 'en': 'Weather'},
    'weather_sub': {'ku': 'پلەی گەرمی', 'ar': 'درجة الحرارة', 'en': 'Temperature'},
    'departments': {'ku': 'بەشەکان', 'ar': 'الدوائر', 'en': 'Departments'},
    'departments_sub': {'ku': 'خزمەتگوزارییەکانی شار', 'ar': 'خدمات المدينة', 'en': 'City services'},
    'videos': {'ku': 'ڤیدیۆکان', 'ar': 'الفيديوهات', 'en': 'Videos'},
    'videos_sub': {'ku': 'ڕێنماییەکان و گەشتەکان', 'ar': 'إرشادات وجولات', 'en': 'Guides & tours'},
    'footer': {
      'ku': 'دروستکراوە بۆ جوانترکردنی ڕۆژەکەت',
      'ar': 'صُنع ليجعل يومك أجمل',
      'en': 'Made to brighten your day',
    },
  };

  String _t(String key) => _tr[key]?[_lang] ?? _tr[key]?['ku'] ?? key;

  @override
  void initState() {
    super.initState();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      final prev = _now.value;
      // تەنها کاتێک خولەک دەگۆڕێت → ڕیبیلدی کەمتر
      if (now.minute != prev.minute || now.hour != prev.hour || now.day != prev.day) {
        _now.value = now;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        WeatherService.instance.ensureFresh(
          maxAge: const Duration(minutes: 10),
        ),
      );
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _now.dispose();
    super.dispose();
  }

  void _open(Widget screen) {
    HapticFeedback.mediumImpact();
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;

    HapticFeedback.mediumImpact();
    setState(() => _isRefreshing = true);
    _now.value = DateTime.now();

    try {
      await Future.wait<void>([
        WeatherService.instance.refresh(),
        Future<void>.delayed(const Duration(milliseconds: 450)),
      ]);
    } catch (error, stackTrace) {
      debugPrint('DailyScreen refresh error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(_t('refresh_error')),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          );
      }
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  String _digits(String value) {
    if (_isEn) return value;
    const english = '0123456789';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    var result = value;
    for (var i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], arabic[i]);
    }
    return result;
  }

  String _dateLabel(DateTime date) {
    const kuWeekdays = [
      'دووشەممە', 'سێشەممە', 'چوارشەممە', 'پێنجشەممە',
      'هەینی', 'شەممە', 'یەکشەممە',
    ];
    const kuMonths = [
      'کانوونی دووەم', 'شوبات', 'ئازار', 'نیسان', 'ئایار', 'حوزەیران',
      'تەممووز', 'ئاب', 'ئەیلوول', 'تشرینی یەکەم', 'تشرینی دووەم',
      'کانوونی یەکەم',
    ];

    final weekday = date.weekday - 1;
    final month = date.month - 1;

    const arWeekdays = [
      'الإثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت', 'الأحد',
    ];
    const arMonths = [
      'كانون الثاني', 'شباط', 'آذار', 'نيسان', 'أيار', 'حزيران',
      'تموز', 'آب', 'أيلول', 'تشرين الأول', 'تشرين الثاني', 'كانون الأول',
    ];
    const enWeekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const enMonths = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    if (_isEn) {
      return '${enWeekdays[weekday]}, ${date.day} ${enMonths[month]} ${date.year}';
    }
    if (_isAr) {
      return _digits('${arWeekdays[weekday]}، ${date.day} ${arMonths[month]} ${date.year}');
    }
    return _digits('${tr(kuWeekdays[weekday])}، ${date.day}ی ${tr(kuMonths[month])} ${date.year}');
  }

  String _timeLabel(DateTime date) {
    final hour = date.hour;
    final minute = date.minute.toString().padLeft(2, '0');

    if (_isEn) {
      final period = hour >= 12 ? 'PM' : 'AM';
      final displayHour = hour % 12 == 0 ? 12 : hour % 12;
      return '${displayHour.toString().padLeft(2, '0')}:$minute $period';
    }
    return _digits('${hour.toString().padLeft(2, '0')}:$minute');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    _lang = context.select<SettingsProvider, String>((settings) => settings.languageId);

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    final services = <_ServiceData>[
      _ServiceData(
        title: _t('emergency'),
        subtitle: _t('emergency_sub'),
        icon: Icons.emergency_rounded,
        color: AppColors.toneRed,
        tag: 'SOS',
        onTap: () => _open(const EmergencyScreen()),
      ),
      _ServiceData(
        title: _t('prayer'),
        subtitle: _t('prayer_sub'),
        icon: Icons.mosque_rounded,
        color: AppColors.toneIndigo,
        onTap: () => _open(const PrayerTimesScreen()),
      ),
      _ServiceData(
        title: _t('currency'),
        subtitle: _t('currency_sub'),
        icon: Icons.currency_exchange_rounded,
        color: AppColors.toneTeal,
        isLive: true,
        onTap: () => _open(const CurrencyRatesScreen()),
      ),
      _ServiceData(
        title: _t('qibla'),
        subtitle: _t('qibla_sub'),
        icon: Icons.explore_rounded,
        color: AppColors.toneAmber,
        onTap: () => _open(const QiblaFinderScreen()),
      ),
      _ServiceData(
        title: _t('fuel'),
        subtitle: _t('fuel_sub'),
        icon: Icons.local_gas_station_rounded,
        color: AppColors.toneAmber,
        isLive: true,
        onTap: () => _open(const FuelTypesScreen()),
      ),
      _ServiceData(
        title: _t('weather'),
        subtitle: _t('weather_sub'),
        icon: Icons.cloud_rounded,
        color: AppColors.toneBlue,
        trailing: _WeatherPill(
          color: AppColors.toneBlue,
          lang: _lang,
          liveLabel: _t('live'),
        ),
        onTap: () => _open(const WeatherScreen()),
      ),
    ];

    return Directionality(
      textDirection: _isRtl ? TextDirection.rtl : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: background,
        body: RefreshIndicator(
          color: AppColors.primary,
          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
          strokeWidth: 2.8,
          displacement: 58,
          onRefresh: _onRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              _buildAppBar(isDark),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 14),
                sliver: SliverToBoxAdapter(
                  child: _Reveal(index: 0, child: _buildWelcomeCard(isDark)),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 14),
                sliver: SliverToBoxAdapter(
                  child: _Reveal(
                    index: 1,
                    child: _buildSectionHeader(isDark, services.length),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverLayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.crossAxisExtent;
                    final columns = width >= 900 ? 4 : width >= 620 ? 3 : 2;
                    // بەرزی کارت لەگەڵ قەبارەی فۆنت گەورە دەبێت
                    final textScale = MediaQuery.textScalerOf(context).scale(1);
                    final extent = 150 + 48 * (textScale - 1).clamp(0.0, 1.0);

                    return SliverGrid(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        mainAxisExtent: extent,
                      ),
                      delegate: SliverChildBuilderDelegate(
                            (context, index) {
                          final service = services[index];
                          return _Reveal(
                            index: index + 2,
                            child: _ServiceCard(
                              service: service,
                              isDark: isDark,
                              isRtl: _isRtl,
                              liveLabel: _t('live'),
                            ),
                          );
                        },
                        childCount: services.length,
                      ),
                    );
                  },
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _Reveal(
                    index: 8,
                    child: _PromoCard(
                      title: _t('departments'),
                      subtitle: _t('departments_sub'),
                      icon: Icons.account_balance_rounded,
                      colors: const [Color(0xFF0F9D7A), Color(0xFF0B7A60)],
                      onTap: () => _open(const DepartmentsScreen()),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                sliver: SliverToBoxAdapter(
                  child: _Reveal(
                    index: 9,
                    child: _PromoCard(
                      title: _t('videos'),
                      subtitle: _t('videos_sub'),
                      icon: Icons.play_circle_fill_rounded,
                      colors: const [Color(0xFF4F5BD5), Color(0xFF3B47B8)],
                      onTap: () => _open(const UserVideosScreen()),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 0),
                  child: _buildFooter(isDark),
                ),
              ),
              SliverToBoxAdapter(child: SizedBox(height: 24 + MediaQuery.paddingOf(context).bottom)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      stretch: true,
      toolbarHeight: 68,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 1,
      leadingWidth: widget.onMenuTap == null ? 12 : 64,
      leading: widget.onMenuTap == null
          ? null
          : Padding(
        padding: const EdgeInsetsDirectional.only(start: 12),
        child: IconButton(
          tooltip: _t('menu'),
          onPressed: () {
            HapticFeedback.selectionClick();
            widget.onMenuTap?.call();
          },
          icon: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.16)),
            ),
            child: Icon(
              Icons.menu_rounded,
              color: isDark ? Colors.white : AppColors.primary,
              size: 22,
            ),
          ),
        ),
      ),
      titleSpacing: 8,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1E88E5), Color(0xFF1565C0)],
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.22),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 21),
          ),
          const SizedBox(width: 11),
          Flexible(
            child: Text(
              _t('title'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.2,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ),
        ],
      ),
      actions: [
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 14),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: _isRefreshing
                  ? const SizedBox(
                key: ValueKey('loading'),
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : IconButton(
                key: const ValueKey('refresh'),
                tooltip: _t('refresh'),
                onPressed: _onRefresh,
                icon: Icon(
                  Icons.refresh_rounded,
                  color: isDark ? Colors.white70 : Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWelcomeCard(bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D47A1), Color(0xFF1565C0), Color(0xFF1E88E5)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          PositionedDirectional(
            top: -55,
            end: -35,
            child: _GlowCircle(size: 170, color: Colors.white.withValues(alpha: 0.08)),
          ),
          PositionedDirectional(
            bottom: -85,
            start: 80,
            child: _GlowCircle(size: 160, color: Colors.white.withValues(alpha: 0.06)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFDE68A), size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _t('hub'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const Icon(Icons.wb_sunny_rounded, color: Color(0xFFFDE68A), size: 26),
                ],
              ),
              const SizedBox(height: 19),
              Text(
                _t('hero'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  height: 1.2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _t('hero_sub'),
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 22),
              ValueListenableBuilder<DateTime>(
                valueListenable: _now,
                builder: (context, now, _) {
                  return Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, size: 14, color: Colors.white70),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tr(_dateLabel(now)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tr(_timeLabel(now)),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(bool isDark, int count) {
    return Row(
      children: [
        Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary.withValues(alpha: 0.18),
                AppColors.primary.withValues(alpha: 0.06),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.18)),
          ),
          child: const Icon(Icons.grid_view_rounded, color: AppColors.primary, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('services'),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                _t('services_sub'),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.07) : AppColors.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            tr(_digits('$count')),
            style: TextStyle(
              color: isDark ? Colors.white70 : AppColors.primary,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool isDark) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite_rounded, size: 12, color: isDark ? Colors.white38 : Colors.grey.shade500),
          const SizedBox(width: 6),
          Text(
            _t('footer'),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Data
// -----------------------------------------------------------------------------

class _ServiceData {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool isLive;
  final String? tag;
  final Widget? trailing;

  const _ServiceData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.isLive = false,
    this.tag,
    this.trailing,
  });
}

// -----------------------------------------------------------------------------
// Reveal animation
// -----------------------------------------------------------------------------

class _Reveal extends StatelessWidget {
  final int index;
  final Widget child;

  const _Reveal({required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final delay = index.clamp(0, 10) * 45;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

// -----------------------------------------------------------------------------
// Service card
// -----------------------------------------------------------------------------

class _ServiceCard extends StatelessWidget {
  final _ServiceData service;
  final bool isDark;
  final String liveLabel;
  final bool isRtl;

  const _ServiceCard({
    required this.service,
    required this.isDark,
    required this.liveLabel,
    required this.isRtl,
  });

  @override
  Widget build(BuildContext context) {
    final color = service.color;

    return Semantics(
      button: true,
      label: '${service.title}. ${service.subtitle}',
      child: Container(
        // ✅ چاککرا: سێبەرەکان لێرەدان بۆ ئەوەی کارتەکە خڕ بێت
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.045),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: service.onTap,
              splashColor: color.withValues(alpha: 0.08),
              highlightColor: color.withValues(alpha: 0.04),
              child: Ink(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : const Color(0xFFE8EDF3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: isDark ? 0.18 : 0.10),
                            borderRadius: BorderRadius.circular(15),
                          ),
                          child: Icon(service.icon, color: color, size: 25),
                        ),
                        const Spacer(),
                        if (service.trailing != null)
                          service.trailing!
                        else if (service.isLive)
                          _LivePill(color: color, label: liveLabel)
                        else
                          Container(
                            width: 30,
                            height: 30,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.06)
                                  : const Color(0xFFF1F4F8),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.arrow_forward_rounded,
                              size: 16,
                              color: isDark ? Colors.white54 : const Color(0xFF94A3B8),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      tr(service.title),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        height: 1.2,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      tr(service.subtitle),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
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

// -----------------------------------------------------------------------------
// Promotional cards
// -----------------------------------------------------------------------------

class _PromoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final VoidCallback onTap;

  const _PromoCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {

    return Semantics(
      button: true,
      label: '$title. $subtitle',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: colors.first.withValues(alpha: 0.23),
              blurRadius: 20,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(25),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              child: Ink(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: colors,
                  ),
                ),
                child: Stack(
                  children: [
                    PositionedDirectional(
                      top: -55,
                      end: -35,
                      child: _GlowCircle(size: 145, color: Colors.white.withValues(alpha: 0.09)),
                    ),
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white.withValues(alpha: 0.28), width: 1.3),
                          ),
                          child: Icon(icon, color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                tr(title),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                tr(subtitle),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.82),
                                  fontSize: 12,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.16),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.arrow_forward_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ],
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

// -----------------------------------------------------------------------------
// Small reusable decorations
// -----------------------------------------------------------------------------

class _GlowCircle extends StatelessWidget {
  final double size;
  final Color color;

  const _GlowCircle({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
    );
  }
}

class _LivePill extends StatelessWidget {
  final Color color;
  final String label;
  final double fontSize;

  const _LivePill({required this.color, required this.label, this.fontSize = 9});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 100),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 5)],
            ),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              tr(label),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherPill extends StatelessWidget {
  final Color color;
  final String lang;
  final String liveLabel;

  const _WeatherPill({
    required this.color,
    required this.lang,
    required this.liveLabel,
  });

  String _digits(String value) {
    if (lang == 'en') return value;
    const english = '0123456789';
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    var result = value;
    for (var i = 0; i < english.length; i++) {
      result = result.replaceAll(english[i], arabic[i]);
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<WeatherSnapshot?>(
      valueListenable: WeatherService.instance.snapshot,
      builder: (context, snapshot, _) {
        if (snapshot == null) {
          return _LivePill(color: color, label: liveLabel);
        }

        final current = snapshot.current;
        final condition = WeatherService.conditionOf(
          current.code,
          current.temp,
          current.isDay,
        );
        final emoji = current.emojiOverride ?? condition.emoji;

        return _LivePill(
          color: color,
          label: '$emoji ${current.temp < 0 ? '\u200E' : ''}${_digits('${current.temp}')}°',
          fontSize: 11,
        );
      },
    );
  }
}
