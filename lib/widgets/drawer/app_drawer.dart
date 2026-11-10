import 'package:flutter/material.dart';
import '../common/language_flag.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../config/theme_provider.dart';
import '../../services/auth_service.dart';
import '../../services/notification_service.dart';
import '../../services/presence_service.dart';

// Screens
import '../../screens/emergency/emergency_main_screen.dart';
import '../../screens/events/events_screen.dart';
import '../../screens/neighborhoods/neighborhoods_map_screen.dart';
import '../../screens/auth/auth_screen.dart';
import '../../l10n/tr.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> with TickerProviderStateMixin {
  int _onlineUsers = 0;

  late AnimationController _pulseController;
  late AnimationController _itemController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    _itemController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _itemController.forward();

    _loadStats();
  }

  @override
  void dispose() {
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
    } catch (e) {
      debugPrint('⚠️ Stats error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = context.watch<SettingsProvider>();

    return Drawer(
      width: MediaQuery.sizeOf(context).width * 0.82,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(left: Radius.circular(30)),
      ),
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return ValueListenableBuilder<Map<String, dynamic>?>(
            valueListenable: AuthSessionManager.userNotifier,
            builder: (context, userProfile, _) {
              final isLogged = userProfile != null;

              return Container(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                child: Column(
                  children: [
                    _buildHeader(isDark: isDark, userProfile: userProfile, isLogged: isLogged),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        children: [
                          // 🚨 خزمەتگوزارییەکان (تەنها ئەوانەی لە پرۆفایل نین)
                          _buildSection(tr('🚨 فریاکەوتن و ڕووداوەکان'), isDark, 0),
                          _buildItem(
                            context,
                            icon: Icons.emergency_rounded,
                            color: const Color(0xFFDC3545),
                            title: tr('فریاکەوتن'),
                            subtitle: tr('ژمارە گرنگەکان'),
                            isDark: isDark,
                            onTap: () => _push(context, const EmergencyScreen()),
                            itemIndex: 1,
                          ),
                          _buildItem(
                            context,
                            icon: Icons.event_rounded,
                            color: const Color(0xFF4F5BD5),
                            title: tr('ڕووداوەکان'),
                            subtitle: tr('ڕووداوەکانی کەلار'),
                            isDark: isDark,
                            onTap: () => _push(context, const EventsScreen()),
                            itemIndex: 2,
                          ),

                          const SizedBox(height: 8),

                          // 🗺️ ڕێبەر (تەنها نەخشە)
                          _buildSection(tr('🗺️ ڕێبەر'), isDark, 3),
                          _buildItem(
                            context,
                            icon: Icons.map_rounded,
                            color: const Color(0xFF0F9D7A),
                            title: tr('نەخشەی گەڕەکان'),
                            subtitle: tr('بینینی نەخشەی تەواوی کەلار'),
                            isDark: isDark,
                            onTap: () => _push(context, const NeighborhoodsMapScreen()),
                            itemIndex: 4,
                          ),

                          const SizedBox(height: 8),

                          // ⚙️ ڕێکخستنەکان (تەنها ڕووکاز و زمان)
                          _buildSection(tr('⚙️ ڕێکخستن'), isDark, 5),
                          _buildThemeSwitch(context, themeProvider, isDark, itemIndex: 6),
                          _buildLanguageSwitcher(context, settings, isDark, itemIndex: 7),

                          const SizedBox(height: 16),

                          if (_onlineUsers > 0) _buildLiveUsersBadge(isDark),

                          const Divider(height: 30, indent: 20, endIndent: 20),

                          if (isLogged)
                            _buildLogoutButton(context, isDark, itemIndex: 8)
                          else
                            _buildLoginButton(context, isDark, itemIndex: 8),

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
      padding: const EdgeInsets.only(top: 50, bottom: 25, left: 20, right: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF4F5BD5)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(35),
          bottomRight: Radius.circular(35),
        ),
      ),
      child: Column(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Transform.scale(
                scale: 1.0 + (_pulseAnimation.value - 1.0) * 0.3,
                child: Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFD9822B), Color(0xFFD9822B)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD9822B).withValues(alpha: 0.4),
                        blurRadius: 15,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white,
                    child: Icon(
                      isLogged ? Icons.person_rounded : Icons.person_outline_rounded,
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
            tr(isLogged ? (userProfile?['name']?.toString() ?? 'بەکارهێنەر') : 'میوانی خۆشەویست'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          if (isLogged)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tr(_getRoleEmoji(userProfile?['role']?.toString())), style: const TextStyle(fontSize: 14)),
                  const SizedBox(width: 6),
                  Text(
                    tr(_getRoleName(userProfile?['role']?.toString())),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            )
          else
            Text(
              tr('بەخێربێیت بۆ ڕێبەری کەلار'),
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, bool isDark, int index) {
    return AnimatedBuilder(
      animation: _itemController,
      builder: (context, child) {
        final delay = (index * 0.05).clamp(0.0, 0.5);
        final progress = ((_itemController.value - delay) / 0.5).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(20 * (1 - progress), 0),
          child: Opacity(
            opacity: progress,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 6),
              child: Text(
                tr(title),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white54 : Colors.grey[600],
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
      }) {
    return AnimatedBuilder(
      animation: _itemController,
      builder: (context, child) {
        final delay = (itemIndex * 0.05).clamp(0.0, 0.5);
        final progress = ((_itemController.value - delay) / 0.5).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(30 * (1 - progress), 0),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
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
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tr(title),
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: isDark ? Colors.white : const Color(0xFF1E293B),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr(subtitle),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white54 : Colors.grey.shade500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
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

  Widget _buildThemeSwitch(BuildContext context, ThemeProvider themeProvider, bool isDark, {required int itemIndex}) {
    final effectiveIsDark = themeProvider.isDark(context);

    return AnimatedBuilder(
      animation: _itemController,
      builder: (context, child) {
        final delay = (itemIndex * 0.05).clamp(0.0, 0.5);
        final progress = ((_itemController.value - delay) / 0.5).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(30 * (1 - progress), 0),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: (effectiveIsDark ? const Color(0xFFD9822B) : const Color(0xFF4F5BD5)).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  effectiveIsDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: effectiveIsDark ? const Color(0xFFD9822B) : const Color(0xFF4F5BD5),
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
                      tr('ڕووکاز'),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr(effectiveIsDark ? 'شێوازی تاریک' : 'شێوازی ڕووناک'),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.grey.shade500,
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

  Widget _buildLanguageSwitcher(BuildContext context, SettingsProvider settings, bool isDark, {required int itemIndex}) {
    final languages = [
      {'id': 'ku', 'name': 'کوردی', 'flag': '☀️'},
      {'id': 'ar', 'name': 'عەرەبی', 'flag': '🇮🇶'},
      {'id': 'en', 'name': 'ئینگلیزی', 'flag': '🇬🇧'},
    ];

    return AnimatedBuilder(
      animation: _itemController,
      builder: (context, child) {
        final delay = (itemIndex * 0.05).clamp(0.0, 0.5);
        final progress = ((_itemController.value - delay) / 0.5).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(30 * (1 - progress), 0),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFF1E88E5).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.language_rounded, color: Color(0xFF1E88E5), size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      tr('زمان'),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: isDark ? Colors.white : const Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr(languages.firstWhere((l) => l['id'] == settings.languageId, orElse: () => languages[0])['name']!),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.grey.shade500,
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
                          color: isSelected ? const Color(0xFF1E88E5).withValues(alpha: 0.15) : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF1E88E5) : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: LanguageFlag(languageId: lang['id']!, emoji: lang['flag']!, width: 24),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFF0F9D7A).withValues(alpha: 0.1),
              const Color(0xFF0F9D7A).withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF0F9D7A).withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F9D7A),
                      shape: BoxShape.circle,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr('ئێستا بەکارهێنەر ئۆنلاینە'),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0F9D7A)),
              ),
            ),
            Text(
              '$_onlineUsers',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF0F9D7A)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoginButton(BuildContext context, bool isDark, {required int itemIndex}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: GestureDetector(
        onTap: () async {
          HapticFeedback.mediumImpact();
          Navigator.pop(context);
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const AuthScreen()));
          await NotificationService.refreshToken();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F9D7A), Color(0xFF0F9D7A)],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0F9D7A).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.login_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(tr('چوونەژوورەوە'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(BuildContext context, bool isDark, {required int itemIndex}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: GestureDetector(
        onTap: () => _showLogoutDialog(context),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFDC3545).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFDC3545).withValues(alpha: 0.3), width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.logout_rounded, color: Color(0xFFDC3545), size: 20),
              const SizedBox(width: 10),
              Text(tr('چوونەدەرەوە لە هەژمار'), style: const TextStyle(color: Color(0xFFDC3545), fontWeight: FontWeight.w900, fontSize: 15)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVersionInfo(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_rounded, size: 12, color: isDark ? Colors.white38 : Colors.grey[400]),
                const SizedBox(width: 4),
                Text(
                  tr('ڕێبەری کەلار'),
                  style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.grey[500], fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(tr('وەشان ١.٠.٠'), style: TextStyle(fontSize: 9, color: isDark ? Colors.white24 : Colors.grey[400])),
          ],
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.logout_rounded, color: Color(0xFFDC3545)),
              const SizedBox(width: 10),
              Text(tr('چوونەدەرەوە'), style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          content: Text(tr('ئایا دڵنیایت لە چوونەدەرەوە لە ئەکاونتەکەت؟')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('نەخێر'))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC3545),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('بەڵێ'), style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) return;

    await AuthSessionManager.clearSession();
    if (!mounted || !context.mounted) return;

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('✅ بە سەرکەوتوویی چوویتە دەرەوە'), style: const TextStyle(fontWeight: FontWeight.w900)),
        backgroundColor: const Color(0xFF0F9D7A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  String _getRoleEmoji(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin': return '👑';
      case 'vendor': return '🏪';
      case 'department': return '🏛️';
      default: return '👤';
    }
  }

  String _getRoleName(String? role) {
    switch (role?.toLowerCase()) {
      case 'admin': return 'ئەدمین';
      case 'vendor': return 'فرۆشیار';
      case 'department': return 'فەرمانگە';
      default: return 'بەکارهێنەر';
    }
  }
}