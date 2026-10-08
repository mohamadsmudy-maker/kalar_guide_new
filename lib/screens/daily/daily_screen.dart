import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/intl.dart' as intl;
import '../emergency/emergency_screen.dart';

import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../services/auth_service.dart';
import '../../widgets/weather_widget.dart';
import 'prayer_times_screen.dart';
import 'qibla_finder_screen.dart';
import '../videos/user_videos.dart';
import '../fuel/fuel_types_screen.dart';
import '../currency/currency_rates_screen.dart';

/// ⚡ شاشەی ڕۆژانە — ULTRA PRO EDITION
class DailyScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;

  const DailyScreen({super.key, this.onMenuTap});

  @override
  State<DailyScreen> createState() => _DailyScreenState();
}

class _DailyScreenState extends State<DailyScreen>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
  late Timer _clockTimer;
  DateTime _now = DateTime.now();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;

  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _pulseAnimation;

  // ═══════════════════════════════════════════════════════════
  // 🚀 Lifecycle
  // ═══════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();

    // ⏰ کاتژمێری زیندوو
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });

    // ✨ ئەنیمەیشنەکان
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideController,
        curve: Curves.easeOutCubic,
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildUltraAppBar(isDark, lang),
            _buildWeatherSection(isDark),
            _buildServicesHeader(isDark),
            _buildServicesGrid(isDark, lang),
            _buildStatsSection(isDark, lang),
            _buildVideoCard(isDark),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 ULTRA AppBar — بە کاتژمێری زیندوو و ئاماری ڕۆژ
  // ═══════════════════════════════════════════════════════════
  Widget _buildUltraAppBar(bool isDark, String lang) {
    return SliverAppBar(
      floating: true,
      pinned: true,
      expandedHeight: 180,
      backgroundColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      leading: IconButton(
        icon: Icon(
          Icons.menu_rounded,
          color: isDark ? Colors.white : AppColors.primary,
        ),
        onPressed: () => widget.onMenuTap?.call(),
      ),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6C5CE7), Color(0xFFE91E63)],
              ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6C5CE7).withValues(alpha: 0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'ڕۆژانە',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : AppColors.primary,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
      actions: [
        // 🔔 ئاگاداری
        AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _pulseAnimation.value,
              child: IconButton(
                icon: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Icon(
                      Icons.notifications_none_rounded,
                      color: isDark ? Colors.white : AppColors.primary,
                    ),
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
                onPressed: () {},
              ),
            );
          },
        ),
        const SizedBox(width: 6),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1A1A22), const Color(0xFF252530)]
                  : [Colors.white, const Color(0xFF6C5CE7).withValues(alpha: 0.08)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 70, 16, 12),
              child: Row(
                children: [
                  // ⏰ کارتی کاتژمێر
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.access_time_filled_rounded,
                      iconColor: const Color(0xFF6C5CE7),
                      title: 'کاتی ئێستا',
                      value: intl.DateFormat('HH:mm').format(_now),
                      subtitle: intl.DateFormat('EEEE').format(_now),
                      isDark: isDark,
                    ),
                  ),
                  const SizedBox(width: 10),

                  // 👤 کارتی بەکارهێنەر
                  Expanded(
                    child: _buildInfoCard(
                      icon: Icons.person_rounded,
                      iconColor: const Color(0xFFE91E63),
                      title: 'بەکارهێنەر',
                      value: _getRoleLabel(),
                      subtitle: _getUserName(),
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📇 Info Card (بۆ AppBar)
  // ═══════════════════════════════════════════════════════════
  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
    required String subtitle,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F14) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: iconColor.withValues(alpha: 0.2),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: iconColor, size: 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                  ),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                    height: 1.1,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: iconColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🌤️ Weather Section
  // ═══════════════════════════════════════════════════════════
  Widget _buildWeatherSection(bool isDark) {
    return SliverToBoxAdapter(
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: const WeatherWidget(),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📝 Section Header
  // ═══════════════════════════════════════════════════════════
  Widget _buildServicesHeader(bool isDark) {
    return SliverToBoxAdapter(
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary.withValues(alpha: 0.2),
                        AppColors.primary.withValues(alpha: 0.05),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      width: 1.2,
                    ),
                  ),
                  child: const Icon(
                    Icons.apps_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'خزمەتگوزارییەکان',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : AppColors.textPrimary,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '٤ خزمەتگوزاری بۆ ڕۆژانەت',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? Colors.white54
                              : Colors.grey.shade600,
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
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Services Grid — Ultra Pro
  // ═══════════════════════════════════════════════════════════
  Widget _buildServicesGrid(bool isDark, String lang) {
    return SliverToBoxAdapter(
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.0,
              children: [
                _buildUltraServiceCard(
                  title: 'کاتەکانی نوێژ',
                  subtitle: 'زانیاری و کاتەکان',
                  icon: Icons.mosque_rounded,
                  color: const Color(0xFF6C5CE7),
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const PrayerTimesScreen(),
                    ),
                  ),
                ),
                _buildUltraServiceCard(
                  title: 'فریاکەوتن',
                  subtitle: 'ژمارە گرنگەکان',
                  icon: Icons.emergency_rounded,
                  color: const Color(0xFFDC2626),
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const EmergencyScreen(),
                    ),
                  ),
                ),
                _buildUltraServiceCard(
                  title: 'قیبلە دۆزەرەوە',
                  subtitle: 'ئاراستەی کەعبە',
                  icon: Icons.explore_rounded,
                  color: const Color(0xFFF39C12),
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const QiblaFinderScreen(),
                    ),
                  ),
                ),
                _buildUltraServiceCard(
                  title: 'دراوەکان',
                  subtitle: 'نرخی دۆلار و زێڕ',
                  icon: Icons.attach_money_rounded,
                  color: const Color(0xFF2ECC71),
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CurrencyRatesScreen(),
                    ),
                  ),
                ),
                _buildUltraServiceCard(
                  title: 'سوتەمەنی',
                  subtitle: 'نرخی بەنزین',
                  icon: Icons.local_gas_station_rounded,
                  color: const Color(0xFFE67E22),
                  isDark: isDark,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FuelTypesScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 ULTRA Service Card — بە Shimmer Effect
  // ═══════════════════════════════════════════════════════════
  Widget _buildUltraServiceCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1A1A22) : Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: color.withValues(alpha: 0.25),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: isDark ? 0.18 : 0.15),
                blurRadius: 18,
                offset: const Offset(0, 8),
                spreadRadius: -3,
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ✨ Shimmer Effect (Top)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _shimmerController,
                    builder: (context, child) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          gradient: LinearGradient(
                            begin: Alignment(-1.0 + _shimmerController.value * 2, -1.0),
                            end: Alignment(1.0 + _shimmerController.value * 2, 1.0),
                            colors: [
                              Colors.transparent,
                              color.withValues(alpha: 0.08),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.5, 1.0],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ✨ Decorative circle (top-right)
              Positioned(
                top: -25,
                right: -25,
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        color.withValues(alpha: 0.18),
                        color.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),

              // ✨ Decorative circle (bottom-left)
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.06),
                  ),
                ),
              ),

              // 🎯 Content
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon + Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                color,
                                Color.lerp(color, Colors.white, 0.2)!,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: color.withValues(alpha: 0.5),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                                spreadRadius: -2,
                              ),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: 22),
                        ),
                        // 🔴 Badge ی زیندوو
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: color.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'زیندوو',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w900,
                                  color: color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Text
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A2E),
                            height: 1.2,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        // ➡️ دوگمە
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'بینین',
                                    style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                      color: color,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Icon(
                                    Icons.arrow_back_ios_rounded,
                                    size: 8,
                                    color: color,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Stats Section — ئاماری ڕۆژانە
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatsSection(bool isDark, String lang) {
    // ✅ وەرگرتنی بەرواری هیجری
    final hijri = HijriCalendar.fromDate(_now);
    final hijriString =
        '${hijri.hYear}/${hijri.hMonth}/${hijri.hDay}';

    return SliverToBoxAdapter(
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFF39C12).withValues(alpha: 0.2),
                            const Color(0xFFF39C12).withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFF39C12).withValues(alpha: 0.25),
                          width: 1.2,
                        ),
                      ),
                      child: const Icon(
                        Icons.event_rounded,
                        size: 18,
                        color: Color(0xFFF39C12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'ئاماری ڕۆژانە',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.calendar_today_rounded,
                        label: 'ڕۆژی ئەمڕۆ',
                        value: intl.DateFormat('dd').format(_now),
                        subValue: intl.DateFormat('MMM').format(_now),
                        color: const Color(0xFF1E88E5),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.brightness_2_rounded,
                        label: 'مانگی هیجری',
                        value: '${hijri.hMonth}',
                        subValue: '${hijri.hYear} هـ',
                        color: const Color(0xFF8B5CF6),
                        isDark: isDark,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildStatCard(
                        icon: Icons.today_rounded,
                        label: 'ڕۆژی هەفتە',
                        value: intl.DateFormat('EEEE').format(_now).substring(0, 3),
                        subValue: 'هەفتە',
                        color: const Color(0xFF10B981),
                        isDark: isDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String label,
    required String value,
    required String subValue,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subValue,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 8,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white38 : Colors.grey.shade500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎬 ULTRA Video Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildVideoCard(bool isDark) {
    return SliverToBoxAdapter(
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UserVideosScreen(),
                  ),
                ),
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE91E63).withValues(alpha: 0.4),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                        spreadRadius: -4,
                      ),
                      BoxShadow(
                        color: const Color(0xFF9C27B0).withValues(alpha: 0.2),
                        blurRadius: 32,
                        offset: const Offset(0, 16),
                        spreadRadius: -8,
                      ),
                    ],
                  ),
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        top: -35,
                        right: -35,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.08),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: -30,
                        left: -30,
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white.withValues(alpha: 0.06),
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (context, child) {
                              return Transform.scale(
                                scale: _pulseAnimation.value,
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.25),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withValues(alpha: 0.4),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        blurRadius: 20,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 30,
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 16),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'ڤیدیۆ و ڕێنماییەکان 🎬',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 16,
                                    letterSpacing: 0.3,
                                    shadows: [
                                      Shadow(
                                        color: Colors.black26,
                                        blurRadius: 6,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'بینینی ڕێنماییە ڤیدیۆییەکان',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                              size: 14,
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
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🛠️ Helpers
  // ═══════════════════════════════════════════════════════════
  String _getRoleLabel() {
    final role = AuthSessionManager.userRole;
    switch (role) {
      case 'admin':
        return 'ئەدمین 👑';
      case 'vendor':
        return 'فرۆشیار 🏪';
      case 'department':
        return 'فەرمانگە 🏛️';
      default:
        return 'بەکارهێنەر 👤';
    }
  }

  String _getUserName() {
    return AuthSessionManager.userName ?? 'میوان';
  }
}