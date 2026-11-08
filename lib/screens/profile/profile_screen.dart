import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../auth/auth_screen.dart';
import '../favorites/favorites_screen.dart';
import '../videos/user_videos.dart';
import '../settings/settings_screen.dart';
import '../about/about_screen.dart';
import '../admin/admin_dashboard.dart';
import '../admin/admin_gallery.dart';
import '../gallery/gallery_screen.dart';
import '../../l10n/tr.dart';

class _QuickAction {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(this.icon, this.label, this.color, this.onTap);
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _profile;
  bool _profileLoading = true;
  bool _profileFailed = false;
  bool _refreshing = false;
  bool _loggingOut = false;
  bool _navigating = false;
  bool _reduceMotion = false;

  int _favoritesCount = 0;
  int _videosCount = 0;
  int _complaintsCount = 0;

  late final AnimationController _floatController;
  late final AnimationController _entryController;
  late final Animation<double> _floatAnimation;

  @override
  void initState() {
    super.initState();

    _floatController = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
    _floatAnimation = Tween<double>(begin: -6, end: 6).animate(CurvedAnimation(parent: _floatController, curve: Curves.easeInOut));

    _entryController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..forward();

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
      final p = await AuthSessionManager.fetchUserProfile().timeout(const Duration(seconds: 10));
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
      final videos = prefs.getStringList('watched_videos') ?? [];

      var favorites = 0;
      var complaints = 0;
      final uid = _userId;

      if (uid != null) {
        final client = Supabase.instance.client;
        final r = await Future.wait<int?>([
          _count(() => client.from('favorite_stores').select('id').eq('user_id', uid).count()),
          _count(() => client.from('news_favorites').select('id').eq('user_id', uid).count()),
          _count(() => client.from('complaints').select('id').eq('user_id', uid).count()),
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
        _videosCount = videos.length;
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
          content: Text(tr(msg), style: const TextStyle(fontWeight: FontWeight.w900)),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  Color _surface(bool isDark) => isDark ? const Color(0xFF1E293B) : Colors.white;
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
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _manualRefresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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

                      _buildSectionTitle(tr('⚡ کارە خێراکان'), isDark),
                      const SizedBox(height: 12),
                      _buildQuickActions(isDark),
                      const SizedBox(height: 24),

                      _buildSectionTitle(tr('📋 ڕێبەر'), isDark),
                      const SizedBox(height: 12),
                      _buildMenuItem(
                        isDark: isDark,
                        icon: Icons.favorite_rounded,
                        color: Colors.pink,
                        title: tr('دڵخوازەکانم'),
                        subtitle: tr('شوێن و هەواڵەکان'),
                        badge: _favoritesCount > 0 ? _favoritesCount : null,
                        onTap: () => _push(const FavoritesScreen()),
                        itemIndex: 2,
                      ),
                      _buildMenuItem(
                        isDark: isDark,
                        icon: Icons.video_library_rounded,
                        color: Colors.indigo,
                        title: tr('ڤیدیۆ و ڕێنماییەکان'),
                        subtitle: tr('بینینی ڤیدیۆکان'),
                        badge: _videosCount > 0 ? _videosCount : null,
                        onTap: () => _push(const UserVideosScreen()),
                        itemIndex: 3,
                      ),
                      _buildMenuItem(
                        isDark: isDark,
                        icon: Icons.photo_library_rounded,
                        color: Colors.amber,
                        title: tr('گەلەری کەلار'),
                        subtitle: tr('بینینی وێنەکان'),
                        onTap: () => _push(const GalleryScreen()),
                        itemIndex: 4,
                      ),

                      if (isLogged && (isAdmin || isVendor)) ...[
                        const SizedBox(height: 24),
                        _buildSectionTitle(tr('🛡️ بەڕێوەبردن'), isDark),
                        const SizedBox(height: 12),
                        _buildMenuItem(
                          isDark: isDark,
                          icon: Icons.admin_panel_settings_rounded,
                          color: const Color(0xFF3B82F6),
                          title: isAdmin ? tr('پانێڵی ئەدمین') : tr('پانێڵی بەڕێوەبردن'),
                          subtitle: isAdmin ? tr('دەستڕاگەیشتنی تەواو') : tr('دەستکاری شوێنەکان'),
                          isImportant: true,
                          onTap: () => _push(const AdminDashboardScreen()),
                          itemIndex: 5,
                        ),
                        if (isAdmin)
                          _buildMenuItem(
                            isDark: isDark,
                            icon: Icons.photo_camera_back_rounded,
                            color: const Color(0xFF8B5CF6),
                            title: tr('بەڕێوەبردنی گەلەری'),
                            subtitle: tr('زیادکردن و سڕینەوەی وێنە'),
                            onTap: () => _push(const AdminGallery()),
                            itemIndex: 6,
                          ),
                      ],

                      const SizedBox(height: 24),
                      _buildSectionTitle(tr('⚙️ ڕێکخستن'), isDark),
                      const SizedBox(height: 12),
                      _buildMenuItem(
                        isDark: isDark,
                        icon: Icons.settings_rounded,
                        color: Colors.blueGrey,
                        title: tr('ڕێکخستنەکان'),
                        subtitle: tr('زمان، فۆنت، ڕەنگ'),
                        onTap: () => _push(const SettingsScreen()),
                        itemIndex: 7,
                      ),
                      _buildMenuItem(
                        isDark: isDark,
                        icon: Icons.share_rounded,
                        color: const Color(0xFF06B6D4),
                        title: tr('هاوبەشکردنی ئەپ'),
                        subtitle: tr('بۆ هاوڕێکانت'),
                        onTap: _shareApp,
                        itemIndex: 8,
                      ),
                      _buildMenuItem(
                        isDark: isDark,
                        icon: Icons.info_rounded,
                        color: const Color(0xFF10B981),
                        title: tr('دەربارەی ئەپ و پشتگیری'),
                        subtitle: tr('زانیاری زیاتر و پەیوەندی'),
                        onTap: () => _push(const AboutScreen()),
                        itemIndex: 9,
                      ),

                      const SizedBox(height: 24),
                      isLogged ? _buildLogoutButton(isDark, 10) : _buildLoginButton(isDark, 10),
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
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
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
              child: const Icon(Icons.person_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              tr('پرۆفایل'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.3),
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
          color: Colors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.orange, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tr('نەتوانرا زانیارییەکانی پرۆفایل نوێ بکرێنەوە'),
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _text(isDark)),
              ),
            ),
            TextButton(
              onPressed: _refreshing ? null : _manualRefresh,
              child: Text(tr('دووبارە'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12)),
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
      decoration: BoxDecoration(color: _surface(isDark), borderRadius: BorderRadius.circular(24)),
      child: Column(
        children: [
          Container(
            width: 104,
            height: 104,
            decoration: BoxDecoration(shape: BoxShape.circle, color: isDark ? Colors.white10 : Colors.grey.shade200),
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
    final name = profile?['name']?.toString() ?? user?['name']?.toString() ?? 'بەکارهێنەر';
    final phone = profile?['phone']?.toString() ?? user?['phone']?.toString() ?? '';
    final role = (profile?['role'] ?? user?['role'])?.toString().toLowerCase() ?? 'customer';

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
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.2), width: 1.5),
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
                    colors: [Color(0xFF1E88E5), Color(0xFF6C5CE7), Color(0xFFE91E63)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(color: AppColors.primary.withValues(alpha: 0.4), blurRadius: 24, spreadRadius: 4),
                  ],
                ),
                child: CircleAvatar(
                  radius: 48,
                  backgroundColor: _surface(isDark),
                  child: isLogged && name.trim().isNotEmpty
                      ? Text(
                    tr(String.fromCharCode(name.trim().runes.first)),
                    style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: AppColors.primary),
                  )
                      : const Icon(Icons.person_outline_rounded, size: 56, color: AppColors.primary),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              tr(isLogged ? name : 'میوانی خۆشەویست'),
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _text(isDark), letterSpacing: 0.3),
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
                    label: trf('ژمارەی تەلەفۆن {0}، بۆ کۆپیکردن دابگرە', [phone]),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        Clipboard.setData(ClipboardData(text: phone));
                        _snack(tr('📋 ژمارە کۆپی کرا'), const Color(0xFF10B981));
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.phone_rounded, color: AppColors.primary, size: 13),
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
                            Icon(Icons.copy_rounded, color: AppColors.primary.withValues(alpha: 0.6), size: 12),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                    child: const Icon(Icons.verified_rounded, color: Colors.white, size: 12),
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
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                    Text(tr(_getRoleEmoji(role)), style: const TextStyle(fontSize: 14)),
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
              color: const Color(0xFFE91E63),
              onTap: () => _push(const FavoritesScreen()),
            ),
            _divider(isDark),
            _buildStatItem(
              isDark: isDark,
              icon: Icons.video_library_rounded,
              value: _videosCount,
              label: tr('ڤیدیۆ'),
              color: const Color(0xFF6366F1),
              onTap: () => _push(const UserVideosScreen()),
            ),
            _divider(isDark),
            _buildStatItem(
              isDark: isDark,
              icon: Icons.assignment_rounded,
              value: _complaintsCount,
              label: tr('سکاڵاکانم'),
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
    color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade200,
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
                  decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(height: 6),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: value.toDouble()),
                  duration: _reduceMotion ? Duration.zero : const Duration(milliseconds: 600),
                  curve: Curves.easeOutCubic,
                  builder: (context, v, _) => Text(
                    tr(_ku(v.round())),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: color, height: 1.0),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr(label),
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _sub(isDark)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions(bool isDark) {
    final actions = <_QuickAction>[
      _QuickAction(Icons.favorite_rounded, 'دڵخوازەکان', const Color(0xFFE91E63), () => _push(const FavoritesScreen())),
      _QuickAction(Icons.video_library_rounded, 'ڤیدیۆکان', const Color(0xFF6366F1), () => _push(const UserVideosScreen())),
      _QuickAction(Icons.settings_rounded, 'ڕێکخستن', const Color(0xFF6B7280), () => _push(const SettingsScreen())),
      _QuickAction(Icons.share_rounded, 'هاوبەشکردن', const Color(0xFF06B6D4), _shareApp),
    ];

    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);

    return GridView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 92.0 * scale,
      ),
      children: [
        for (final a in actions)
          Semantics(
            button: true,
            label: a.label,
            child: GestureDetector(
              onTap: () {
                HapticFeedback.lightImpact();
                a.onTap();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _surface(isDark),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: a.color.withValues(alpha: 0.2), width: 1.5),
                  boxShadow: [
                    BoxShadow(color: a.color.withValues(alpha: 0.1), blurRadius: 8, offset: const Offset(0, 3)),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [a.color, a.color.withValues(alpha: 0.7)]),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(color: a.color.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Icon(a.icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      tr(a.label),
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
            ),
          ),
      ],
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
              colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.6)],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          tr(title),
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: _text(isDark)),
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
        child: Semantics(
          button: true,
          label: '$title. $subtitle${badge != null ? '. ${_ku(badge)}' : ''}',
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
                  color: _surface(isDark),
                  borderRadius: BorderRadius.circular(16),
                  border: isImportant ? Border.all(color: color.withValues(alpha: 0.3), width: 1.5) : null,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
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
                          colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.08)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withValues(alpha: 0.25)),
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
                              Flexible(
                                child: Text(
                                  tr(title),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color: _text(isDark),
                                  ),
                                ),
                              ),
                              if (badge != null) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
                                  child: Text(
                                    tr(_ku(badge)),
                                    style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr(subtitle),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: _sub(isDark)),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: isDark ? Colors.white38 : Colors.grey[400],
                      size: 20,
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 3,
            shadowColor: AppColors.primary.withValues(alpha: 0.4),
          ),
          icon: const Icon(Icons.login_rounded, size: 22),
          label: Text(tr('چوونەژوورەوە'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
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
            backgroundColor: Colors.red.withValues(alpha: 0.1),
            foregroundColor: Colors.red,
            disabledBackgroundColor: Colors.red.withValues(alpha: 0.05),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.red.withValues(alpha: 0.3), width: 1.5),
            ),
            elevation: 0,
          ),
          icon: _loggingOut
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red))
              : const Icon(Icons.logout_rounded, size: 22),
          label: Text(tr('چوونەدەرەوە لە هەژمار'), style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.logout_rounded, color: Colors.red),
              const SizedBox(width: 10),
              Text(tr('چوونەدەرەوە'), style: const TextStyle(fontWeight: FontWeight.w900)),
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
                backgroundColor: Colors.red,
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
      _snack(tr('✅ بە سەرکەوتوویی چوویتە دەرەوە'), const Color(0xFF10B981));
      await _loadAll();
    } catch (e) {
      debugPrint('❌ Logout error: $e');
      _snack(tr('⚠️ چوونەدەرەوە سەرنەکەوت، دووبارە هەوڵبدەوە'), const Color(0xFFEF4444));
    } finally {
      if (mounted) setState(() => _loggingOut = false);
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
      _snack(tr('⚠️ نەتوانرا هاوبەش بکرێت'), const Color(0xFFEF4444));
    }
  }

  Widget _entryWrap({required int itemIndex, required Widget child}) {
    if (_reduceMotion) return child;
    return AnimatedBuilder(
      animation: _entryController,
      child: child,
      builder: (context, ch) {
        final delay = (itemIndex * 0.05).clamp(0.0, 0.5);
        final progress = ((_entryController.value - delay) / 0.5).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - progress)),
          child: Opacity(opacity: progress, child: ch),
        );
      },
    );
  }

  String _getRoleEmoji(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return '👑';
      case 'vendor': return '🏪';
      case 'department': return '🏛️';
      default: return '👤';
    }
  }

  String _getRoleName(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return 'ئەدمین';
      case 'vendor': return 'فرۆشیار';
      case 'department': return 'فەرمانگە';
      default: return 'بەکارهێنەر';
    }
  }

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return const Color(0xFFF59E0B);
      case 'vendor': return const Color(0xFFE91E63);
      case 'department': return const Color(0xFF8B5CF6);
      default: return const Color(0xFF1E88E5);
    }
  }

  List<Color> _getRoleGradient(String role) {
    switch (role.toLowerCase()) {
      case 'admin': return const [Color(0xFFF59E0B), Color(0xFFF97316)];
      case 'vendor': return const [Color(0xFFE91E63), Color(0xFF9C27B0)];
      case 'department': return const [Color(0xFF8B5CF6), Color(0xFF6366F1)];
      default: return const [Color(0xFF1E88E5), Color(0xFF6C5CE7)];
    }
  }
}