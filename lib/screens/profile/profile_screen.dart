import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../auth/auth_screen.dart';
import '../favorites/favorites_screen.dart';
import '../videos/user_videos.dart';
import '../settings/settings_screen.dart';
import '../about/about_screen.dart';
import '../admin/admin_dashboard.dart';
import '../prayer/notification_test_screen.dart'; // ✅ زیادکرا شاشەی تاقیکردنەوە

// ❌ import ی flutter_local_notifications لابرا، چونکە لێرە بەکارنەهاتووە

/// 👤 شاشەی پرۆفایل — ULTRA PRO V4
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  late Future<Map<String, dynamic>?> _profileFuture;
  int _favoritesCount = 0;
  int _videosCount = 0;

  // ✨ Animations (تنها ئەوانەی بەکارهاتوون)
  late AnimationController _floatController;
  late AnimationController _entryController;
  late Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);
    _floatAnimation = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _profileFuture = AuthSessionManager.fetchUserProfile();
    _entryController.forward();
    _loadStats();
  }

  @override
  void dispose() {
    _floatController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favorites = prefs.getStringList('store_favorites') ?? [];
      final newsFavs = prefs.getStringList('news_favorites') ?? [];
      final videos = prefs.getStringList('watched_videos') ?? [];

      if (mounted) {
        setState(() {
          _favoritesCount = favorites.length + newsFavs.length;
          _videosCount = videos.length;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Stats error: $e');
    }
  }

  void _refreshProfile() {
    HapticFeedback.mediumImpact();
    setState(() {
      _profileFuture = AuthSessionManager.fetchUserProfile();
    });
    _loadStats();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = AuthSessionManager.currentUser;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            _refreshProfile();
            await Future.delayed(const Duration(milliseconds: 500));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              _buildAppBar(isDark),
              SliverToBoxAdapter(
                child: FutureBuilder<Map<String, dynamic>?>(
                  future: _profileFuture,
                  builder: (context, snapshot) {
                    final profile = snapshot.data;

                    if (snapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(60),
                        child: Center(
                          child: CircularProgressIndicator(
                            color: AppColors.primary,
                          ),
                        ),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildProfileCard(
                            isDark: isDark,
                            user: user,
                            profile: profile,
                            itemIndex: 0,
                          ),
                          const SizedBox(height: 20),

                          if (user != null)
                            _buildStatsRow(isDark, itemIndex: 1),
                          if (user != null) const SizedBox(height: 20),

                          _buildSectionTitle('⚡ کارە خێراکان', isDark),
                          const SizedBox(height: 12),
                          _buildQuickActions(isDark),

                          const SizedBox(height: 20),

                          _buildSectionTitle('📋 ڕێبەر', isDark),
                          const SizedBox(height: 12),
                          _buildMenuItem(
                            isDark: isDark,
                            icon: Icons.favorite_rounded,
                            color: Colors.pink,
                            title: 'دڵخوازەکانم',
                            subtitle: 'شوێن و هەواڵەکان',
                            badge: _favoritesCount > 0
                                ? _favoritesCount
                                : null,
                            onTap: () => _push(
                              context,
                              const FavoritesScreen(),
                            ),
                            itemIndex: 2,
                          ),
                          _buildMenuItem(
                            isDark: isDark,
                            icon: Icons.video_library_rounded,
                            color: Colors.indigo,
                            title: 'ڤیدیۆ و ڕێنماییەکان',
                            subtitle: 'بینینی ڤیدیۆکان',
                            badge:
                            _videosCount > 0 ? _videosCount : null,
                            onTap: () => _push(
                              context,
                              const UserVideosScreen(),
                            ),
                            itemIndex: 3,
                          ),
                          if (user != null &&
                              (AuthSessionManager.isAdmin ||
                                  AuthSessionManager.isVendor))
                            _buildMenuItem(
                              isDark: isDark,
                              icon: Icons.admin_panel_settings_rounded,
                              color: const Color(0xFF3B82F6),
                              title: AuthSessionManager.isAdmin
                                  ? 'پانێڵی ئەدمین'
                                  : 'پانێڵی بەڕێوەبردن',
                              subtitle: AuthSessionManager.isAdmin
                                  ? 'دەستڕاگەیشتنی تەواو'
                                  : 'دەستکاری شوێنەکان',
                              isImportant: true,
                              onTap: () => _push(
                                context,
                                const AdminDashboardScreen(),
                              ),
                              itemIndex: 4,
                            ),

                          const SizedBox(height: 20),

                          _buildSectionTitle('⚙️ ڕێکخستن', isDark),
                          const SizedBox(height: 12),
                          _buildMenuItem(
                            isDark: isDark,
                            icon: Icons.settings_rounded,
                            color: Colors.blueGrey,
                            title: 'ڕێکخستنەکان',
                            subtitle: 'زمان، فۆنت، ڕەنگ',
                            onTap: () => _push(
                              context,
                              const SettingsScreen(),
                            ),
                            itemIndex: 5,
                          ),
                          _buildMenuItem(
                            isDark: isDark,
                            icon: Icons.share_rounded,
                            color: const Color(0xFF06B6D4),
                            title: 'هاوبەشکردنی ئەپ',
                            subtitle: 'بۆ هاوڕێکانت',
                            onTap: _shareApp,
                            itemIndex: 6,
                          ),
                          _buildMenuItem(
                            isDark: isDark,
                            icon: Icons.support_agent_rounded,
                            color: const Color(0xFF10B981),
                            title: 'پشتگیری',
                            subtitle: 'پەیوەندی بە گەشەپێدەر',
                            onTap: () =>
                                _push(context, const AboutScreen()),
                            itemIndex: 7,
                          ),
                          _buildMenuItem(
                            isDark: isDark,
                            icon: Icons.info_rounded,
                            color: const Color(0xFF8B5CF6),
                            title: 'دەربارەی ئەپ',
                            subtitle: 'زانیاری زیاتر',
                            onTap: () =>
                                _push(context, const AboutScreen()),
                            itemIndex: 8,
                          ),

                          // ⭐ تەنها لە Debug Mode
                          if (kDebugMode)
                            _buildMenuItem(
                              isDark: isDark,
                              icon: Icons.notifications_active_rounded,
                              color: const Color(0xFFFFD700),
                              title: '🧪 تاقیکردنەوەی Notifications',
                              subtitle: 'تەنها بۆ گەشەپێدان',
                              onTap: () => _push(
                                context,
                                const NotificationTestScreen(),
                              ),
                              itemIndex: 9,
                            ),

                          const SizedBox(height: 24),

                          if (user == null)
                            _buildLoginButton(context, isDark, 10)
                          else
                            _buildLogoutButton(context, isDark, 10),

                          const SizedBox(height: 40),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 100,
      pinned: true,
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _refreshProfile,
          tooltip: 'نوێکردنەوە',
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'پرۆفایل',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
    );
  }

  Widget _buildProfileCard({
    required bool isDark,
    required Map<String, dynamic>? user,
    required Map<String, dynamic>? profile,
    required int itemIndex,
  }) {
    final isLogged = user != null;
    // ⭐ fallback: profile -> user
    final name = profile?['name']?.toString() ??
        user?['name']?.toString() ??
        'بەکارهێنەر';
    final phone = profile?['phone']?.toString() ??
        user?['phone']?.toString() ??
        '';
    final role = (profile?['role'] ?? user?['role'])
        ?.toString()
        .toLowerCase() ??
        'customer';

    return _entryWrap(
      itemIndex: itemIndex,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? [
              const Color(0xFF1A1A22),
              const Color(0xFF252530),
            ]
                : [
              Colors.white,
              AppColors.primary.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.2),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Column(
          children: [
            AnimatedBuilder(
              animation: _floatController,
              builder: (context, child) {
                return Transform.translate(
                  offset: Offset(0, _floatAnimation.value),
                  child: child,
                );
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1E88E5),
                      Color(0xFF6C5CE7),
                      Color(0xFFE91E63),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      blurRadius: 24,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor:
                  isDark ? const Color(0xFF1A1A22) : Colors.white,
                  child: Icon(
                    isLogged
                        ? Icons.person_rounded
                        : Icons.person_outline_rounded,
                    size: 56,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              isLogged ? name : 'میوانی خۆشەویست',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w900,
                color:
                isDark ? Colors.white : const Color(0xFF1A1A2E),
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            if (isLogged && phone.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.phone_rounded,
                          color: AppColors.primary,
                          size: 13,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          phone,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.verified_rounded,
                      color: Colors.white,
                      size: 12,
                    ),
                  ),
                ],
              )
            else if (!isLogged)
              Text(
                'بچۆ ژوورەوە بۆ بینینی پرۆفایلەکەت',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                ),
              ),
            if (isLogged) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient:
                  LinearGradient(colors: _getRoleGradient(role)),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _getRoleColor(role)
                          .withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _getRoleEmoji(role),
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _getRoleName(role),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow(bool isDark, {required int itemIndex}) {
    return _entryWrap(
      itemIndex: itemIndex,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            _buildStatItem(
              isDark: isDark,
              icon: Icons.favorite_rounded,
              value: '$_favoritesCount',
              label: 'دڵخواز',
              color: const Color(0xFFE91E63),
            ),
            _divider(isDark),
            _buildStatItem(
              isDark: isDark,
              icon: Icons.video_library_rounded,
              value: '$_videosCount',
              label: 'ڤیدیۆ',
              color: const Color(0xFF6366F1),
            ),
            _divider(isDark),
            _buildStatItem(
              isDark: isDark,
              icon: Icons.star_rounded,
              value: '٥.٠',
              label: 'هەڵسەنگاندن',
              color: const Color(0xFFF59E0B),
            ),
          ],
        ),
      ),
    );
  }

  Widget _divider(bool isDark) => Container(
    width: 1,
    height: 40,
    color: isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.grey.shade200,
  );

  Widget _buildStatItem({
    required bool isDark,
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: color,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    final actions = [
      {
        'icon': Icons.favorite_rounded,
        'label': 'دڵخوازەکان',
        'color': const Color(0xFFE91E63),
        'onTap': () => _push(context, const FavoritesScreen()),
      },
      {
        'icon': Icons.video_library_rounded,
        'label': 'ڤیدیۆکان',
        'color': const Color(0xFF6366F1),
        'onTap': () => _push(context, const UserVideosScreen()),
      },
      {
        'icon': Icons.settings_rounded,
        'label': 'ڕێکخستن',
        'color': const Color(0xFF6B7280),
        'onTap': () => _push(context, const SettingsScreen()),
      },
      {
        'icon': Icons.share_rounded,
        'label': 'هاوبەشکردن',
        'color': const Color(0xFF06B6D4),
        'onTap': _shareApp,
      },
    ];

    return GridView.count(
      crossAxisCount: 4,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 0.85,
      children: actions.map((action) {
        final color = action['color'] as Color;
        return GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            (action['onTap'] as Function)();
          },
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A22) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
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
                  child: Icon(
                    action['icon'] as IconData,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  action['label'] as String,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white70 : Colors.grey.shade700,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primary.withValues(alpha: 0.6),
              ],
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

  Widget _buildMenuItem({
    required bool isDark,
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    required int itemIndex,
    bool isImportant = false,
    int? badge,
  }) {
    return _entryWrap(
      itemIndex: itemIndex,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A22) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: isImportant
                    ? Border.all(
                  color: color.withValues(alpha: 0.3),
                  width: 1.5,
                )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color:
                    Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.2),
                          color.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: color.withValues(alpha: 0.25),
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
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1A1A2E),
                                ),
                              ),
                            ),
                            if (badge != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: color,
                                  borderRadius:
                                  BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '$badge',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
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
                            fontSize: 11,
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_left_rounded,
                    color: isDark ? Colors.white38 : Colors.grey[400],
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton(
      BuildContext context, bool isDark, int itemIndex) {
    return _entryWrap(
      itemIndex: itemIndex,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: () async {
            HapticFeedback.mediumImpact();
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AuthScreen()),
            );
            _refreshProfile();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 3,
            shadowColor: AppColors.primary.withValues(alpha: 0.4),
          ),
          icon: const Icon(Icons.login_rounded, size: 22),
          label: const Text(
            'چوونەژوورەوە',
            style:
            TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(
      BuildContext context, bool isDark, int itemIndex) {
    return _entryWrap(
      itemIndex: itemIndex,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: () => _showLogoutDialog(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.withValues(alpha: 0.1),
            foregroundColor: Colors.red,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: Colors.red.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            elevation: 0,
          ),
          icon: const Icon(Icons.logout_rounded, size: 22),
          label: const Text(
            'چوونەدەرەوە لە هەژمار',
            style:
            TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog(BuildContext context) async {
    HapticFeedback.mediumImpact();

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

    _refreshProfile();
  }

  Future<void> _shareApp() async {
    try {
      await Share.share(
        '🏙️ ئەپی ڕێبەری کەلار — ڕێبەری فەرمی شاری کەلار\n\n'
            '✅ ٥٩ گەڕەک\n'
            '✅ ١٠٠+ شوێن\n'
            '✅ سکاڵا و ڕووداو\n'
            '✅ دراو و سووتەمەنی\n\n'
            'داگرتن: https://kalar-guide.com/app',
        subject: 'ڕێبەری کەلار — ئەپی فەرمی شاری کەلار',
      );
    } catch (e) {
      debugPrint('❌ Share error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ نەتوانرا هاوبەش بکرێت'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  // ⭐ Entry animation helper (یەک شوێن بۆ هەموو)
  Widget _entryWrap({
    required int itemIndex,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, _) {
        // 0.05 بۆ هەر ئایتمێک، max delay 0.5
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

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return const Color(0xFFF59E0B);
      case 'vendor':
        return const Color(0xFFE91E63);
      case 'department':
        return const Color(0xFF8B5CF6);
      default:
        return const Color(0xFF1E88E5);
    }
  }

  List<Color> _getRoleGradient(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return [const Color(0xFFF59E0B), const Color(0xFFF97316)];
      case 'vendor':
        return [const Color(0xFFE91E63), const Color(0xFF9C27B0)];
      case 'department':
        return [const Color(0xFF8B5CF6), const Color(0xFF6366F1)];
      default:
        return [const Color(0xFF1E88E5), const Color(0xFF6C5CE7)];
    }
  }
}