import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../config/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/presence_service.dart';

// Screens
import '../../screens/emergency/emergency_main_screen.dart';
import '../../screens/events/events_screen.dart';
import '../../screens/profile/profile_screen.dart';
import '../../screens/videos/user_videos.dart';
import '../../screens/admin/admin_dashboard.dart';
import '../../screens/about/about_screen.dart';
import '../../screens/auth/auth_screen.dart';
import '../../screens/favorites/favorites_screen.dart';

/// 📂 Drawer ی ئەپ — ULTRA PRO V4
class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer>
    with TickerProviderStateMixin {
  int _onlineUsers = 0;
  int _notifications = 3;
  int _favorites = 0;

  late AnimationController _headerController;
  late AnimationController _pulseController;
  late AnimationController _itemController;
  late Animation<double> _headerAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _itemController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _headerController.forward();
    _itemController.forward();
    _loadStats();
  }

  @override
  void dispose() {
    _headerController.dispose();
    _pulseController.dispose();
    _itemController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final stream = PresenceService.watchOnlineCount();
      stream.listen((count) {
        if (mounted) setState(() => _onlineUsers = count);
      });

      final prefs = await SharedPreferences.getInstance();
      final storeFavs = prefs.getStringList('store_favorites') ?? [];
      final newsFavs = prefs.getStringList('news_favorites') ?? [];
      if (mounted) {
        setState(() => _favorites = storeFavs.length + newsFavs.length);
      }
    } catch (e) {
      debugPrint('⚠️ Stats error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();
    final lang = settings.languageId;

    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.85,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(30)),
      ),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: AuthSessionManager.userNotifier,
            builder: (context, userProfile, _) {
              final isLogged = userProfile != null;
              final role =
                  userProfile?['role']?.toString().toLowerCase() ?? 'customer';
              final isAdmin = role == 'admin';
              final isVendor =
                  role == 'vendor' || role == 'department' || isAdmin;

              return Container(
                color: isDark
                    ? const Color(0xFF0F0F14)
                    : const Color(0xFFFCFAFC),
                child: Column(
                  children: [
                    _buildHeader(
                      isDark: isDark,
                      userProfile: userProfile,
                      isLogged: isLogged,
                    ),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.zero,
                        children: [
                          _buildSection('🚨 فریاکەوتن', isDark, 0),
                          _buildItem(
                            context,
                            icon: Icons.emergency_rounded,
                            color: const Color(0xFFDC2626),
                            title: 'فریاکەوتن',
                            subtitle: 'ژمارە گرنگەکان',
                            isDark: isDark,
                            isLive: true,
                            onTap: () =>
                                _push(context, const EmergencyScreen()),
                            itemIndex: 1,
                          ),
                          _buildItem(
                            context,
                            icon: Icons.event_rounded,
                            color: const Color(0xFF6C5CE7),
                            title: 'ڕووداوەکان',
                            subtitle: 'ڕووداوەکانی کەلار',
                            isDark: isDark,
                            isLive: true,
                            onTap: () => _push(context, const EventsScreen()),
                            itemIndex: 2,
                          ),
                          const SizedBox(height: 6),
                          _buildSection('📱 ڕێبەر', isDark, 3),
                          _buildItem(
                            context,
                            icon: Icons.person_rounded,
                            color: const Color(0xFF8B5CF6),
                            title: 'پرۆفایلم',
                            subtitle: isLogged
                                ? (userProfile?['name']?.toString() ?? '')
                                : 'میوان',
                            isDark: isDark,
                            onTap: () => _push(context, const ProfileScreen()),
                            itemIndex: 4,
                          ),
                          _buildItem(
                            context,
                            icon: Icons.favorite_rounded,
                            color: const Color(0xFFE91E63),
                            title: 'دڵخوازەکان',
                            subtitle: 'شوێن و هەواڵەکان',
                            isDark: isDark,
                            badge: _favorites > 0 ? _favorites : null,
                            onTap: () =>
                                _push(context, const FavoritesScreen()),
                            itemIndex: 5,
                          ),
                          _buildItem(
                            context,
                            icon: Icons.video_library_rounded,
                            color: const Color(0xFF6366F1),
                            title: 'ڤیدیۆ و ڕێنماییەکان',
                            subtitle: 'بینینی ڤیدیۆکان',
                            isDark: isDark,
                            onTap: () =>
                                _push(context, const UserVideosScreen()),
                            itemIndex: 6,
                          ),
                          if (isVendor) ...[
                            const SizedBox(height: 6),
                            _buildSection('👑 بەڕێوەبردن', isDark, 7),
                            _buildItem(
                              context,
                              icon: Icons.admin_panel_settings_rounded,
                              color: const Color(0xFF3B82F6),
                              title: isAdmin
                                  ? 'پانێڵی ئەدمین'
                                  : 'پانێڵی بەڕێوەبردن',
                              subtitle: isAdmin
                                  ? 'دەستڕاگەیشتنی تەواو'
                                  : 'دەستکاری شوێنەکان',
                              isDark: isDark,
                              isImportant: true,
                              onTap: () => _push(
                                context,
                                const AdminDashboardScreen(),
                              ),
                              itemIndex: 8,
                            ),
                          ],
                          const SizedBox(height: 6),
                          _buildSection('⚙️ ڕێکخستن', isDark, 9),
                          _buildItem(
                            context,
                            icon: Icons.settings_rounded,
                            color: const Color(0xFF6B7280),
                            title: 'ڕێکخستنەکان',
                            subtitle: 'زمان، فۆنت، ڕەنگ',
                            isDark: isDark,
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.pushNamed(context, '/settings');
                            },
                            itemIndex: 10,
                          ),
                          _buildThemeSwitch(
                            context,
                            themeProvider,
                            isDark,
                            itemIndex: 11,
                          ),
                          _buildLanguageSwitcher(
                            context,
                            settings,
                            isDark,
                            itemIndex: 12,
                          ),
                          _buildItem(
                            context,
                            icon: Icons.person_pin_rounded,
                            color: const Color(0xFF8B5CF6),
                            title: 'دەربارەی ئەپ',
                            subtitle: 'زانیاری زیاتر',
                            isDark: isDark,
                            onTap: () => _push(context, const AboutScreen()),
                            itemIndex: 13,
                          ),
                          const SizedBox(height: 6),
                          _buildLiveUsersBadge(isDark),
                          const Divider(height: 30),
                          if (!isLogged)
                            _buildLoginButton(
                              context,
                              isDark,
                              itemIndex: 14,
                            )
                          else
                            _buildLogoutButton(
                              context,
                              isDark,
                              userProfile!,
                              itemIndex: 14,
                            ),
                          _buildVersionInfo(isDark),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildHeader({
    required bool isDark,
    required Map<String, dynamic>? userProfile,
    required bool isLogged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF6C5CE7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const SizedBox(height: 10),
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: 1.0 + (_pulseAnimation.value - 1.0) * 0.5,
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
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.white,
                      child: Icon(
                        isLogged
                            ? Icons.person_rounded
                            : Icons.person_outline_rounded,
                        size: 42,
                        color: const Color(0xFF1E88E5),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            Text(
              isLogged
                  ? (userProfile?['name']?.toString() ?? 'بەکارهێنەر')
                  : 'میوانی خۆشەویست',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            if (isLogged)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  userProfile?['phone']?.toString() ?? '',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              const Text(
                'بەخێربێیت بۆ ڕێبەری کەلار',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            const SizedBox(height: 12),
            if (isLogged)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getRoleEmoji(
                        userProfile?['role']?.toString() ?? '',
                      ),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getRoleName(
                        userProfile?['role']?.toString() ?? '',
                      ),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
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

  Widget _buildSection(String title, bool isDark, int index) {
    return AnimatedBuilder(
      animation: _itemController,
      builder: (context, child) {
        final delay = (index * 0.06).clamp(0.0, 0.6);
        final progress = ((_itemController.value - delay) / 0.4)
            .clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(20 * (1 - progress), 0),
          child: Opacity(
            opacity: progress,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 6),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white54 : Colors.grey[600],
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItem(
      BuildContext context, {
        required IconData icon,
        required Color color,
        required String title,
        required String subtitle,
        required bool isDark,
        required VoidCallback onTap,
        required int itemIndex,
        bool isLive = false,
        bool isImportant = false,
        int? badge,
      }) {
    return AnimatedBuilder(
      animation: _itemController,
      builder: (context, child) {
        final delay = (itemIndex * 0.06).clamp(0.0, 0.6);
        final progress = ((_itemController.value - delay) / 0.4)
            .clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(30 * (1 - progress), 0),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isImportant
                    ? color.withValues(alpha: 0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: isImportant
                    ? Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: 1.5,
                )
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.2),
                          color.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: color.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1A2E),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isLive) ...[
                              const SizedBox(width: 6),
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, _) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
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
                                            boxShadow: [
                                              BoxShadow(
                                                color: color.withValues(
                                                  alpha:
                                                  _pulseAnimation.value *
                                                      0.8,
                                                ),
                                                blurRadius: 5,
                                              ),
                                            ],
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
                                  );
                                },
                              ),
                            ],
                            if (badge != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$badge',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_left_rounded,
                    size: 20,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSwitch(
      BuildContext context,
      ThemeProvider themeProvider,
      bool isDark, {
        required int itemIndex,
      }) {
    final effectiveIsDark = themeProvider.isDark(context);

    return AnimatedBuilder(
      animation: _itemController,
      builder: (context, child) {
        final delay = (itemIndex * 0.06).clamp(0.0, 0.6);
        final progress = ((_itemController.value - delay) / 0.4)
            .clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(30 * (1 - progress), 0),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      (effectiveIsDark ? Colors.orange : Colors.purple)
                          .withValues(alpha: 0.2),
                      (effectiveIsDark ? Colors.orange : Colors.purple)
                          .withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: (effectiveIsDark ? Colors.orange : Colors.purple)
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Icon(
                  effectiveIsDark
                      ? Icons.dark_mode_rounded
                      : Icons.light_mode_rounded,
                  color: effectiveIsDark ? Colors.orange : Colors.purple,
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      effectiveIsDark ? 'شێوازی تاریک' : 'شێوازی ڕووناک',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      effectiveIsDark ? '🌙 شەو' : '☀️ ڕۆژ',
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? Colors.white54
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: effectiveIsDark,
                onChanged: (value) {
                  HapticFeedback.selectionClick();
                  themeProvider.toggleTheme(value);
                },
                activeThumbColor: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSwitcher(
      BuildContext context,
      SettingsProvider settings,
      bool isDark, {
        required int itemIndex,
      }) {
    final languages = [
      {'id': 'ku', 'name': 'کوردی', 'flag': '🇮🇶'},
      {'id': 'ar', 'name': 'عەرەبی', 'flag': '🇸🇦'},
      {'id': 'en', 'name': 'ئینگلیزی', 'flag': '🇬🇧'},
    ];

    return AnimatedBuilder(
      animation: _itemController,
      builder: (context, child) {
        final delay = (itemIndex * 0.06).clamp(0.0, 0.6);
        final progress = ((_itemController.value - delay) / 0.4)
            .clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(30 * (1 - progress), 0),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF06B6D4).withValues(alpha: 0.2),
                      const Color(0xFF06B6D4).withValues(alpha: 0.08),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.language_rounded,
                  color: Color(0xFF06B6D4),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'زمان',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      languages
                          .firstWhere(
                            (l) => l['id'] == settings.languageId,
                        orElse: () => languages[0],
                      )['name']!,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark
                            ? Colors.white54
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: languages.map((lang) {
                  final isSelected = settings.languageId == lang['id'];
                  return Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        settings.setLanguage(lang['id']!);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF06B6D4)
                              .withValues(alpha: 0.2)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF06B6D4)
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          lang['flag']!,
                          style: const TextStyle(fontSize: 18),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveUsersBadge(bool isDark) {
    if (_onlineUsers == 0) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _itemController,
      builder: (context, child) {
        final delay = (15 * 0.06).clamp(0.0, 0.6);
        final progress = ((_itemController.value - delay) / 0.4)
            .clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(30 * (1 - progress), 0),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF10B981).withValues(alpha: 0.15),
                const Color(0xFF10B981).withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981)
                                .withValues(alpha: 0.6),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'ئێستا بەکارهێنەر ئۆنلاینە',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
              Text(
                '$_onlineUsers',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton(
      BuildContext context,
      bool isDark, {
        required int itemIndex,
      }) {
    return AnimatedBuilder(
      animation: _itemController,
      builder: (context, child) {
        final delay = (itemIndex * 0.06).clamp(0.0, 0.6);
        final progress = ((_itemController.value - delay) / 0.4)
            .clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(30 * (1 - progress), 0),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: GestureDetector(
          onTap: () async {
            HapticFeedback.mediumImpact();
            Navigator.pop(context);
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AuthScreen()),
            );
            await NotificationService.refreshToken();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.login_rounded, color: Colors.white, size: 20),
                SizedBox(width: 10),
                Text(
                  'چوونەژوورەوە',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(
      BuildContext context,
      bool isDark,
      Map<String, dynamic> userProfile, {
        required int itemIndex,
      }) {
    return AnimatedBuilder(
      animation: _itemController,
      builder: (context, child) {
        final delay = (itemIndex * 0.06).clamp(0.0, 0.6);
        final progress = ((_itemController.value - delay) / 0.4)
            .clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(30 * (1 - progress), 0),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: GestureDetector(
          onTap: () => _showLogoutDialog(context),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.red.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.logout_rounded, color: Colors.red, size: 20),
                SizedBox(width: 10),
                Text(
                  'چوونەدەرەوە',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w900,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVersionInfo(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Center(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.verified_rounded,
                  size: 12,
                  color: isDark ? Colors.white38 : Colors.grey[400],
                ),
                const SizedBox(width: 4),
                Text(
                  'ڕێبەری کەلار',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.grey[500],
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'وەشان ١.٠.٠',
              style: TextStyle(
                fontSize: 9,
                color: isDark ? Colors.white24 : Colors.grey[400],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.logout_rounded, color: Colors.red),
              SizedBox(width: 10),
              Text(
                'چوونەدەرەوە',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ],
          ),
          content: const Text(
            'ئایا دڵنیایت لە چوونەدەرەوە لە ئەکاونتەکەت؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('نەخێر'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'بەڵێ',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    await AuthSessionManager.clearSession();
    if (!mounted) return;

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          '✅ بە سەرکەوتوویی چوویتە دەرەوە',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        backgroundColor: Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  String _getRoleEmoji(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return '👑';
      case 'vendor':
        return '🏪';
      case 'department':
        return '🏛️';
      default:
        return '👤';
    }
  }

  String _getRoleName(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return 'ئەدمین';
      case 'vendor':
        return 'فرۆشیار';
      case 'department':
        return 'فەرمانگە';
      default:
        return 'بەکارهێنەر';
    }
  }
}