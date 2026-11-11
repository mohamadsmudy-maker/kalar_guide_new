import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../config/theme_provider.dart';
import '../../services/auth_service.dart';
import '../auth/auth_screen.dart';
import '../favorites/favorites_screen.dart';
import '../settings/settings_screen.dart';
import '../about/about_screen.dart';
import '../admin/admin_dashboard.dart';
import '../vendor/vendor_panel_screen.dart';
import '../admin/admin_gallery.dart';
import '../../l10n/tr.dart';
import '../../services/google_auth_service.dart';
import '../legal/privacy_policy_screen.dart';

/// ڕیزێکی گرووپی پرۆفایل. [themeSwitch] ڕیزی سویچی ڕووناک/تاریکە.
class _GroupRow {
  final IconData? icon;
  final String title;
  final String subtitle;
  final int? badge;
  final VoidCallback? onTap;
  final bool isThemeSwitch;

  const _GroupRow({
    required IconData this.icon,
    required this.title,
    required this.subtitle,
    this.badge,
    this.onTap,
  }) : isThemeSwitch = false;

  const _GroupRow.themeSwitch()
      : icon = null,
        title = '',
        subtitle = '',
        badge = null,
        onTap = null,
        isThemeSwitch = true;
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  bool _profileLoading = true;
  bool _profileFailed = false;
  bool _refreshing = false;
  bool _loggingOut = false;
  bool _navigating = false;
  bool _reduceMotion = false;

  int _favoritesCount = 0;
  int _complaintsCount = 0;

  late final AnimationController _floatController;
  late final AnimationController _entryController;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3000));
    _floatAnimation = Tween<double>(begin: -6, end: 6).animate(
        CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));

    _entryController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..forward();

    _loadAll();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _floatController.stop();
      _entryController.value = 1;
    } else if (!_floatController.isAnimating) {
      _floatController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _floatController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  String? get _userId => AuthSessionManager.currentUser?['id']?.toString();

  Future<void> _loadAll() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await Future.wait<void>([_fetchProfile(), _loadStats()]);
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _fetchProfile() async {
    if (AuthSessionManager.currentUser == null) {
      if (mounted) {
        setState(() {
          _profile = null;
          _profileLoading = false;
          _profileFailed = false;
        });
      }
      return;
    }

    try {
      final p = await AuthSessionManager.fetchUserProfile()
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      setState(() {
        _profile = p ?? _profile;
        _profileFailed = false;
      });
    } catch (e) {
      debugPrint('⚠️ Profile fetch error: $e');
      if (mounted) setState(() => _profileFailed = true);
    } finally {
      if (mounted) setState(() => _profileLoading = false);
    }
  }

  Future<int?> _count(Future<dynamic> Function() query) async {
    try {
      final res = await query();
      if (res is int) return res;
      if (res is PostgrestResponse) return res.count;
      return null;
    } catch (e) {
      debugPrint('⚠️ Count error: $e');
      return null;
    }
  }

  Future<void> _loadStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      var favorites = 0;
      var complaints = 0;
      final uid = _userId;

      if (uid != null) {
        final client = Supabase.instance.client;
        final r = await Future.wait<int?>([
          _count(() => client
              .from('favorite_stores')
              .select('id')
              .eq('user_id', uid)
              .count()),
          _count(() => client
              .from('news_favorites')
              .select('id')
              .eq('user_id', uid)
              .count()),
          _count(() => client
              .from('complaints')
              .select('id')
              .eq('user_id', uid)
              .count()),
        ]);

        if (r[0] == null && r[1] == null) {
          favorites = (prefs.getStringList('store_favorites') ?? []).length +
              (prefs.getStringList('news_favorites') ?? []).length;
        } else {
          favorites = (r[0] ?? 0) + (r[1] ?? 0);
        }
        complaints = r[2] ?? _complaintsCount;
      }

      if (!mounted) return;
      setState(() {
        _favoritesCount = favorites;
        _complaintsCount = complaints;
      });
    } catch (e) {
      debugPrint('⚠️ Stats error: $e');
    }
  }

  Future<void> _manualRefresh() async {
    HapticFeedback.mediumImpact();
    if (!_reduceMotion) _entryController.forward(from: 0);
    await _loadAll();
  }

  Future<void> _push(Widget screen) async {
    if (_navigating) return;
    _navigating = true;
    try {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    } finally {
      _navigating = false;
    }
    if (mounted) _loadAll();
  }

  String _ku(Object n) => n.toString().replaceAllMapped(
        RegExp(r'\d'),
        (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)],
      );

  void _snack(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(tr(msg),
              style: const TextStyle(fontWeight: FontWeight.w900)),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  Color _surface(bool isDark) =>
      isDark ? const Color(0xFF1E293B) : Colors.white;
  Color _text(bool isDark) => isDark ? Colors.white : const Color(0xFF1E293B);
  Color _sub(bool isDark) => isDark ? Colors.white54 : Colors.grey.shade600;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = AuthSessionManager.currentUser;
    final isLogged = user != null;
    final isAdmin = AuthSessionManager.isAdmin;
    final isVendor = AuthSessionManager.isVendor;
    final showSkeleton = isLogged && _profileLoading && _profile == null;

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _manualRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics()),
            slivers: [
              _buildAppBar(isDark),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      if (_profileFailed && isLogged) _buildErrorBanner(isDark),
                      showSkeleton
                          ? _buildProfileSkeleton(isDark)
                          : _buildProfileCard(
                              isDark: isDark,
                              user: user,
                              profile: _profile,
                              itemIndex: 0,
                            ),
                      const SizedBox(height: 20),
                      if (isLogged) ...[
                        _buildStatsRow(isDark, itemIndex: 1),
                        const SizedBox(height: 24),
                      ],
                      _entryWrap(
                        itemIndex: 2,
                        child: _buildGroup(
                          title: tr('هەژمار و ڕێکخستن'),
                          isDark: isDark,
                          rows: [
                            _GroupRow(
                              icon: Icons.favorite_rounded,
                              title: tr('دڵخوازەکانم'),
                              subtitle: tr('شوێن، هەواڵ، ڤیدیۆ و وێنە'),
                              badge:
                                  _favoritesCount > 0 ? _favoritesCount : null,
                              onTap: () => _push(const FavoritesScreen()),
                            ),
                            _GroupRow(
                              icon: Icons.settings_rounded,
                              title: tr('ڕێکخستنەکان'),
                              subtitle: tr('زمان، فۆنت، ڕەنگ'),
                              onTap: () => _push(const SettingsScreen()),
                            ),
                            const _GroupRow.themeSwitch(),
                            _GroupRow(
                              icon: Icons.share_rounded,
                              title: tr('هاوبەشکردنی ئەپ'),
                              subtitle: tr('بۆ هاوڕێکانت'),
                              onTap: _shareApp,
                            ),
                          ],
                        ),
                      ),
                      if (isLogged && (isAdmin || isVendor))
                        _entryWrap(
                          itemIndex: 3,
                          child: _buildGroup(
                            title: tr('بەڕێوەبردن'),
                            isDark: isDark,
                            rows: [
                              _GroupRow(
                                icon: Icons.admin_panel_settings_rounded,
                                title: isAdmin
                                    ? tr('پانێڵی ئەدمین')
                                    : tr('پانێڵەکەم'),
                                subtitle: isAdmin
                                    ? tr('دەستڕاگەیشتنی تەواو')
                                    : tr('نرخ و مێژووی نرخەکانم'),
                                onTap: () => _push(isAdmin ||
                                        AuthSessionManager.userRole != 'vendor'
                                    ? const AdminDashboardScreen()
                                    : const VendorPanelScreen()),
                              ),
                              if (isAdmin)
                                _GroupRow(
                                  icon: Icons.photo_camera_back_rounded,
                                  title: tr('بەڕێوەبردنی گەلەری'),
                                  subtitle: tr('زیادکردن و سڕینەوەی وێنە'),
                                  onTap: () => _push(const AdminGallery()),
                                ),
                            ],
                          ),
                        ),
                      _entryWrap(
                        itemIndex: 4,
                        child: _buildGroup(
                          title: tr('یارمەتی و پشتگیری'),
                          isDark: isDark,
                          rows: [
                            _GroupRow(
                              icon: Icons.info_rounded,
                              title: tr('دەربارەی ئەپ و پشتگیری'),
                              subtitle: tr('زانیاری زیاتر و پەیوەندی'),
                              onTap: () => _push(const AboutScreen()),
                            ),
                            _GroupRow(
                              icon: Icons.privacy_tip_rounded,
                              title: tr('سیاسەتی تایبەتمەندی'),
                              subtitle: tr('چ زانیارییەک کۆدەکرێتەوە و بۆچی'),
                              onTap: () => _push(const PrivacyPolicyScreen()),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      isLogged
                          ? _buildLogoutButton(isDark, 10)
                          : _buildLoginButton(isDark, 10),
                      if (isLogged && !AuthSessionManager.isAdmin) ...[
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton.icon(
                            onPressed:
                                _loggingOut ? null : _confirmDeleteAccount,
                            style: TextButton.styleFrom(
                              foregroundColor: isDark
                                  ? Colors.white54
                                  : const Color(0xFF94A3B8),
                            ),
                            icon: const Icon(Icons.delete_outline_rounded,
                                size: 18),
                            label: Text(tr('سڕینەوەی ئەکاونت'),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700, fontSize: 13)),
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
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

  Widget _buildAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 100,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: _refreshing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.refresh_rounded),
          onPressed: _refreshing ? null : _manualRefresh,
          tooltip: tr('نوێکردنەوە'),
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
              child: const Icon(Icons.person_rounded,
                  color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              tr('پرۆفایل'),
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 0.3),
            ),
          ],
        ),
        centerTitle: true,
      ),
    );
  }

  Widget _buildErrorBanner(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFD9822B).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border:
              Border.all(color: const Color(0xFFD9822B).withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded,
                color: Color(0xFFD9822B), size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr('نەتوانرا زانیارییەکانی پرۆفایل نوێ بکرێنەوە'),
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _text(isDark)),
              ),
            ),
            TextButton(
              onPressed: _refreshing ? null : _manualRefresh,
              child: Text(tr('دووبارە'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileSkeleton(bool isDark) {
    Widget bar(double w, double h) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(8),
          ),
        );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
          color: _surface(isDark), borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          const SizedBox(height: 16),
          bar(150, 20),
          const SizedBox(height: 10),
          bar(110, 14),
        ],
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
    final name = profile?['name']?.toString() ??
        user?['name']?.toString() ??
        'بەکارهێنەر';
    final phone =
        profile?['phone']?.toString() ?? user?['phone']?.toString() ?? '';
    final role =
        (profile?['role'] ?? user?['role'])?.toString().toLowerCase() ??
            'customer';

    return _entryWrap(
      itemIndex: itemIndex,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF1E293B), Color(0xFF334155)]
                : [Colors.white, AppColors.primary.withValues(alpha: 0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
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
              builder: (context, child) => Transform.translate(
                offset: Offset(0, _reduceMotion ? 0 : _floatAnimation.value),
                child: child,
              ),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1E88E5),
                      Color(0xFF4F5BD5),
                      Color(0xFFC2557A)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.4),
                        blurRadius: 24,
                        spreadRadius: 4),
                  ],
                ),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: _surface(isDark),
                  child: isLogged && name.trim().isNotEmpty
                      ? Text(
                          tr(String.fromCharCode(name.trim().runes.first)),
                          style: const TextStyle(
                              fontSize: 44,
                              fontWeight: FontWeight.w900,
                              color: AppColors.primary),
                        )
                      : const Icon(Icons.person_outline_rounded,
                          size: 56, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr(isLogged ? name : 'میوانی خۆشەویست'),
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _text(isDark),
                  letterSpacing: 0.3),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            if (isLogged && phone.isNotEmpty)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Semantics(
                    button: true,
                    label:
                        trf('ژمارەی تەلەفۆن {0}، بۆ کۆپیکردن دابگرە', [phone]),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Clipboard.setData(ClipboardData(text: phone));
                        _snack(
                            tr('📋 ژمارە کۆپی کرا'), const Color(0xFF0F9D7A));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.phone_rounded,
                                color: AppColors.primary, size: 13),
                            const SizedBox(width: 6),
                            Text(
                              tr(phone),
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(Icons.copy_rounded,
                                color: AppColors.primary.withValues(alpha: 0.6),
                                size: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(
                        color: Color(0xFF0F9D7A), shape: BoxShape.circle),
                    child: const Icon(Icons.verified_rounded,
                        color: Colors.white, size: 12),
                  ),
                ],
              )
            else if (!isLogged)
              Text(
                tr('بچۆ ژوورەوە بۆ بینینی پرۆفایلەکەت'),
                style: TextStyle(fontSize: 12, color: _sub(isDark)),
              ),
            if (isLogged) ...[
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _getRoleGradient(role)),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _getRoleColor(role).withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(tr(_getRoleEmoji(role)),
                        style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      tr(_getRoleName(role)),
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
          color: _surface(isDark),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
        ),
        child: Row(
          children: [
            _buildStatItem(
              isDark: isDark,
              icon: Icons.favorite_rounded,
              value: _favoritesCount,
              label: tr('دڵخواز'),
              color: const Color(0xFFC2557A),
              onTap: () => _push(const FavoritesScreen()),
            ),
            _divider(isDark),
            _buildStatItem(
              isDark: isDark,
              icon: Icons.assignment_rounded,
              value: _complaintsCount,
              label: tr('سکاڵاکانم'),
              color: const Color(0xFFD9822B),
            ),
          ],
        ),
      ),
    );
  }

  /// گرووپێک: ناونیشانی بچووک + یەک کارتی سپی کە چەند ڕیزێکی تێدایە
  Widget _buildGroup({
    required String title,
    required bool isDark,
    required List<_GroupRow> rows,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white60 : const Color(0xFF6B7280),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: _surface(isDark),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++) ...[
                    if (i > 0)
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 70,
                        endIndent: 16,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.07)
                            : const Color(0xFFEEF0F4),
                      ),
                    rows[i].isThemeSwitch
                        ? _buildThemeRow(isDark)
                        : _buildGroupRow(rows[i], isDark),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _rowIcon(IconData icon, bool isDark) => Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: AppColors.primary, size: 22),
      );

  Widget _rowTexts(String title, String subtitle, bool isDark, {int? badge}) =>
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Flexible(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: _text(isDark),
                    ),
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      _ku(badge),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white54 : const Color(0xFF8A90A0),
                ),
              ),
            ],
          ],
        ),
      );

  Widget _buildGroupRow(_GroupRow r, bool isDark) {
    return Semantics(
      button: true,
      label: '${r.title}. ${r.subtitle}',
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          r.onTap?.call();
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              _rowIcon(r.icon!, isDark),
              const SizedBox(width: 14),
              _rowTexts(r.title, r.subtitle, isDark, badge: r.badge),
              Icon(
                AppLang.isRtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: isDark ? Colors.white30 : const Color(0xFFB4B9C6),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// ڕیزی ڕووناک/تاریک بە سویچ، ڕاستەوخۆ لە لیستەکەدا
  Widget _buildThemeRow(bool isDark) {
    return Consumer<ThemeProvider>(
      builder: (context, theme, _) {
        final dark = theme.isDark(context);
        return Semantics(
          toggled: dark,
          label: tr('دۆخی تاریک'),
          child: InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              theme.toggleTheme(!dark);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  _rowIcon(
                      dark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                      isDark),
                  const SizedBox(width: 14),
                  _rowTexts(
                      tr('دۆخی تاریک'), tr('گۆڕینی ڕووناک / تاریک'), isDark),
                  Switch(
                    value: dark,
                    activeThumbColor: AppColors.primary,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      theme.toggleTheme(v);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _divider(bool isDark) => Container(
        width: 1,
        height: 40,
        color:
            isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
      );

  Widget _buildStatItem({
    required bool isDark,
    required IconData icon,
    required int value,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: Semantics(
        button: onTap != null,
        label: '$label: ${_ku(value)}',
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onTap();
                },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: value.toDouble()),
                  duration: _reduceMotion
                      ? Duration.zero
                      : const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Text(
                    tr(_ku(v.round())),
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: color,
                        height: 1.0),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(label),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _sub(isDark)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton(bool isDark, int itemIndex) {
    return _entryWrap(
      itemIndex: itemIndex,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: () async {
            HapticFeedback.mediumImpact();
            await _push(const AuthScreen());
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 3,
            shadowColor: AppColors.primary.withValues(alpha: 0.4),
          ),
          icon: const Icon(Icons.login_rounded, size: 22),
          label: Text(tr('چوونەژوورەوە'),
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ),
      ),
    );
  }

  Widget _buildLogoutButton(bool isDark, int itemIndex) {
    return _entryWrap(
      itemIndex: itemIndex,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _loggingOut ? null : _showLogoutDialog,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC3545).withValues(alpha: 0.1),
            foregroundColor: const Color(0xFFDC3545),
            disabledBackgroundColor:
                const Color(0xFFDC3545).withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                  color: const Color(0xFFDC3545).withValues(alpha: 0.3),
                  width: 1.5),
            ),
            elevation: 0,
          ),
          icon: _loggingOut
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Color(0xFFDC3545)))
              : const Icon(Icons.logout_rounded, size: 22),
          label: Text(tr('چوونەدەرەوە لە هەژمار'),
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ),
      ),
    );
  }

  Future<void> _showLogoutDialog() async {
    HapticFeedback.mediumImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.logout_rounded, color: Color(0xFFDC3545)),
              const SizedBox(width: 10),
              Text(tr('چوونەدەرەوە'),
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          content: Text(tr('ئایا دڵنیایت لە چوونەدەرەوە لە ئەکاونتەکەت؟')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('نەخێر')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC3545),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('بەڵێ'),
                  style: const TextStyle(fontWeight: FontWeight.w900)),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !mounted) return;

    setState(() => _loggingOut = true);
    try {
      await AuthSessionManager.clearSession();
      if (!mounted) return;
      setState(() {
        _profile = null;
        _profileFailed = false;
        _favoritesCount = 0;
        _complaintsCount = 0;
      });
      _snack(tr('✅ بە سەرکەوتوویی چوویتە دەرەوە'), const Color(0xFF0F9D7A));
      await _loadAll();
    } catch (e) {
      debugPrint('❌ Logout error: $e');
      _snack(tr('⚠️ چوونەدەرەوە سەرنەکەوت، دووبارە هەوڵبدەوە'),
          const Color(0xFFDC3545));
    } finally {
      if (mounted) setState(() => _loggingOut = false);
    }
  }

  /// Google Play داوا دەکات بەکارهێنەر بتوانێت ئەکاونتەکەی لە ناو ئەپەکەدا بسڕێتەوە
  Future<void> _confirmDeleteAccount() async {
    HapticFeedback.mediumImpact();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(tr('سڕینەوەی ئەکاونت'),
              style: const TextStyle(fontWeight: FontWeight.w900)),
          content: Text(
            tr('ئەکاونتەکەت و دڵخواز، لایک و هەڵسەنگاندنەکانت بە یەکجاری دەسڕێنەوە. ئەمە ناگەڕێتەوە.'),
            style: const TextStyle(height: 1.6),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr('نەخێر'))),
            FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFDC3545)),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('سڕینەوە')),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loggingOut = true);
    final status = await GoogleAuthService.deleteAccount();
    if (!mounted) return;
    setState(() => _loggingOut = false);
    if (status == 'ok') {
      setState(() {
        _profile = null;
        _favoritesCount = 0;
        _complaintsCount = 0;
      });
      _snack(tr('ئەکاونتەکەت سڕایەوە'), const Color(0xFF0F9D7A));
      await _loadAll();
    } else {
      _snack(tr('سڕینەوە سەرکەوتوو نەبوو، دواتر هەوڵ بدەرەوە'),
          const Color(0xFFDC3545));
    }
  }

  Future<void> _shareApp() async {
    try {
      await Share.share(
        tr('🏙️ ئەپی ڕێبەری کەلار — ڕێبەری فەرمی شاری کەلار\n\n✅ ٥٩ گەڕەک\n✅ ١٠٠+ شوێن\n✅ سکاڵا و ڕووداو\n✅ دراو و سووتەمەنی\n\nداگرتن: https://kalar-guide.com/app'),
        subject: tr('ڕێبەری کەلار — ئەپی فەرمی شاری کەلار'),
      );
    } catch (e) {
      debugPrint('❌ Share error: $e');
      _snack(tr('⚠️ نەتوانرا هاوبەش بکرێت'), const Color(0xFFDC3545));
    }
  }

  Widget _entryWrap({required int itemIndex, required Widget child}) {
    if (_reduceMotion) return child;
    return AnimatedBuilder(
      animation: _entryController,
      child: child,
      builder: (context, ch) {
        final delay = (itemIndex * 0.05).clamp(0.0, 0.5);
        final progress =
            ((_entryController.value - delay) / 0.5).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - progress)),
          child: Opacity(opacity: progress, child: ch),
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
        return const Color(0xFFD9822B);
      case 'vendor':
        return const Color(0xFFC2557A);
      case 'department':
        return const Color(0xFF4F5BD5);
      default:
        return const Color(0xFF1E88E5);
    }
  }

  List<Color> _getRoleGradient(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return const [Color(0xFFD9822B), Color(0xFFD9822B)];
      case 'vendor':
        return const [Color(0xFFC2557A), Color(0xFFC2557A)];
      case 'department':
        return const [Color(0xFF4F5BD5), Color(0xFF4F5BD5)];
      default:
        return const [Color(0xFF1E88E5), Color(0xFF4F5BD5)];
    }
  }
}
