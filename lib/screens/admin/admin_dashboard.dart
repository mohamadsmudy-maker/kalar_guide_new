import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';

import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/presence_service.dart';
import 'all_complaints_map.dart';

// Sub-screens
import 'admin_complaints.dart';
import 'admin_stores.dart';
import 'admin_departments.dart';
import 'admin_categories_management.dart';
import 'admin_neighborhoods_screen.dart';
import 'admin_events_screen.dart';
import 'admin_emergency_services_screen.dart';
import 'admin_fuel_stations.dart';
import 'admin_currency_stations.dart';
import 'admin_weather.dart';
import 'admin_notifications.dart';
import 'admin_vendor_requests.dart';
import 'admin_live_users.dart';
import 'admin_complaint_instructions.dart';
import 'admin_news.dart';
import 'admin_database_viewer.dart';
import 'admin_banners.dart';
import 'admin_videos.dart';
// ✅ گەلەری ئەدمین
import 'admin_gallery.dart';

// ═══════════════════════════════════════════════════════════
// ⚙️ Config
// ═══════════════════════════════════════════════════════════

/// If true, sensitive tools (database viewer, admin requests) are hidden
/// from non-admin users. Set to false to restore the old behaviour
/// where every user of this panel sees every tool.
const bool _kRestrictSensitiveToAdmin = true;

/// Silent auto-refresh interval for the stats
const Duration _kAutoRefresh = Duration(seconds: 90);

/// If the app was in the background longer than this, refresh on resume
const Duration _kStaleAfter = Duration(seconds: 60);

/// How many "recently used" tools to remember
const int _kMaxRecents = 4;

const String _kPrefCollapsed = 'admin_dash_collapsed';
const String _kPrefRecents = 'admin_dash_recents';

const Color _kAppBarColor = Color(0xFF1A1B2E);

/// 🎨 Theme palette
class _Palette {
  final bool isDark;
  const _Palette(this.isDark);

  Color get bg => isDark ? const Color(0xFF0F0F14) : const Color(0xFFF0F4F9);
  Color get card => isDark ? const Color(0xFF1A1A22) : Colors.white;
  Color get text => isDark ? Colors.white : const Color(0xFF1A1A2E);
  Color get textSub => isDark ? Colors.white54 : Colors.grey.shade600;
  Color get chevron => isDark ? Colors.white38 : Colors.grey.shade400;
  Color get chip =>
      isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.shade100;
  Color get border =>
      isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey.shade200;

  List<BoxShadow> shadow([double light = 0.04]) => [
    BoxShadow(
      color: Colors.black.withValues(alpha: isDark ? 0.3 : light),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];
}

// ═══════════════════════════════════════════════════════════
// 🧱 Models
// ═══════════════════════════════════════════════════════════
class _DashItem {
  /// Stable id (used to remember "recently used" tools)
  final String id;
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final int? badge;
  final bool important;
  final bool adminOnly;
  final Widget Function() screen;

  const _DashItem({
    required this.id,
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.screen,
    this.badge,
    this.important = false,
    this.adminOnly = false,
  });
}

class _DashSection {
  final String id;
  final String title;
  final List<_DashItem> items;
  const _DashSection(this.id, this.title, this.items);
}

// ═══════════════════════════════════════════════════════════
// ✨ Reusable entry animation
// ═══════════════════════════════════════════════════════════
class _Entry extends StatelessWidget {
  final Animation<double> animation;
  final int index;
  final Offset from;
  final Widget child;

  const _Entry({
    required this.animation,
    required this.index,
    required this.child,
    this.from = const Offset(0, 20),
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, ch) {
        final delay = (index * 0.08).clamp(0.0, 0.6);
        final raw = ((animation.value - delay) / 0.4).clamp(0.0, 1.0);
        final t = Curves.easeOutCubic.transform(raw);
        return Transform.translate(
          offset: Offset(from.dx * (1 - t), from.dy * (1 - t)),
          child: Opacity(opacity: t, child: ch),
        );
      },
    );
  }
}

/// 👑 پانێڵی بەڕێوەبەر — ULTRA PRO MAX V6
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
  bool _loading = true;
  bool _hasLoadedOnce = false;
  bool _fetching = false;
  bool _navigating = false;
  bool _inForeground = true;
  String? _loadError;
  DateTime? _lastUpdated;

  int _onlineUsers = 0;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  int _totalStores = 0;
  int _totalDepartments = 0;
  int _totalComplaints = 0;
  int _pendingComplaints = 0;
  int _pendingRequests = 0;
  int _totalProducts = 0;

  StreamSubscription<int>? _onlineSub;
  Timer? _autoRefreshTimer;
  Timer? _realtimeDebounce;
  RealtimeChannel? _channel;

  /// Section ids the admin collapsed (persisted)
  final Set<String> _collapsed = {};

  /// Most recent first
  List<String> _recentIds = [];

  late final AnimationController _headerController;
  late final AnimationController _pulseController;
  late final AnimationController _shimmerController;
  late final AnimationController _entryController;
  late final Animation<double> _headerAnimation;
  late final Animation<double> _pulseAnimation;

  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _headerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _headerAnimation = CurvedAnimation(
      parent: _headerController,
      curve: Curves.easeOutCubic,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _headerController.forward();
    _entryController.forward();
    _restorePrefs();
    _loadData();
    _watchLiveUsers();
    _subscribeRealtime();

    // 🔄 Silent auto refresh — skipped in background / when another
    // screen is on top, so we don't burn requests nobody sees.
    _autoRefreshTimer = Timer.periodic(_kAutoRefresh, (_) {
      if (!mounted || _fetching || !_inForeground) return;
      final route = ModalRoute.of(context);
      if (route != null && !route.isCurrent) return;
      _loadData(silent: true);
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ♿ Respect "reduce motion" system setting
    _reduceMotion = MediaQuery.disableAnimationsOf(context);
    if (_reduceMotion) {
      _pulseController.stop();
      _shimmerController.stop();
      _entryController.value = 1;
    } else {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
      if (!_shimmerController.isAnimating) _shimmerController.repeat();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    _inForeground = active;
    if (active && mounted) {
      final t = _lastUpdated;
      if (t == null || DateTime.now().difference(t) > _kStaleAfter) {
        _loadData(silent: true);
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _onlineSub?.cancel();
    _autoRefreshTimer?.cancel();
    _realtimeDebounce?.cancel();
    if (_channel != null) {
      try {
        Supabase.instance.client.removeChannel(_channel!);
      } catch (_) {}
    }
    _headerController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _entryController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 💾 Preferences (collapsed sections + recent tools)
  // ═══════════════════════════════════════════════════════════
  Future<void> _restorePrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final collapsed = prefs.getStringList(_kPrefCollapsed) ?? const [];
      final recents = prefs.getStringList(_kPrefRecents) ?? const [];
      if (!mounted) return;
      setState(() {
        _collapsed
          ..clear()
          ..addAll(collapsed);
        _recentIds = recents.take(_kMaxRecents).toList();
      });
    } catch (e) {
      debugPrint('⚠️ restore prefs: $e');
    }
  }

  Future<void> _saveCollapsed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kPrefCollapsed, _collapsed.toList());
    } catch (_) {}
  }

  Future<void> _saveRecents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kPrefRecents, _recentIds);
    } catch (_) {}
  }

  void _rememberRecent(String id) {
    final next = [id, ..._recentIds.where((e) => e != id)]
        .take(_kMaxRecents)
        .toList();
    setState(() => _recentIds = next);
    _saveRecents();
  }

  // ═══════════════════════════════════════════════════════════
  // 🌐 Data
  // ═══════════════════════════════════════════════════════════

  /// One failing table no longer wipes out every other number.
  Future<int?> _count(Future<dynamic> Function() query) async {
    try {
      final res = await query();
      if (res is int) return res;
      if (res is PostgrestResponse) return res.count;
      return null;
    } catch (e) {
      debugPrint('❌ Count error: $e');
      return null;
    }
  }

  Future<void> _loadData({bool silent = false}) async {
    if (_fetching) return;
    _fetching = true;
    if (!silent && mounted) setState(() => _loading = true);

    final client = Supabase.instance.client;

    List<int?> results;
    try {
      results = await Future.wait<int?>([
        _count(() => client.from('dukan').select('id').count()),
        _count(() => client.from('departments').select('id').count()),
        _count(() => client.from('complaints').select('id').count()),
        _count(() => client
            .from('complaints')
            .select('id')
            .eq('status', 'pending')
            .count()),
        _count(() => client
            .from('app_users')
            .select('id')
            .eq('is_approved', false)
            .count()),
        _count(() => client.from('products').select('id').count()),
      ]);
    } catch (e) {
      debugPrint('❌ loadData error: $e');
      results = List<int?>.filled(6, null);
    } finally {
      _fetching = false;
    }

    if (!mounted) return;

    final failed = results.where((r) => r == null).length;

    setState(() {
      _totalStores = results[0] ?? _totalStores;
      _totalDepartments = results[1] ?? _totalDepartments;
      _totalComplaints = results[2] ?? _totalComplaints;
      _pendingComplaints = results[3] ?? _pendingComplaints;
      _pendingRequests = results[4] ?? _pendingRequests;
      _totalProducts = results[5] ?? _totalProducts;

      _loading = false;
      if (failed < results.length) {
        _hasLoadedOnce = true;
        _lastUpdated = DateTime.now();
      }
      _loadError = failed == 0
          ? null
          : (failed == results.length
          ? 'نەتوانرا ئامارەکان بهێنرێن. پەیوەندی ئینتەرنێتەکەت بپشکنە.'
          : 'بەشێک لە ئامارەکان نەهێنران (${_ku(failed)} لە ${_ku(results.length)}).');
    });
  }

  void _watchLiveUsers() {
    try {
      _onlineSub = PresenceService.watchOnlineCount().listen(
            (count) {
          if (mounted) setState(() => _onlineUsers = count);
        },
        onError: (error) => debugPrint('⚠️ Live users stream error: $error'),
      );
    } catch (e) {
      debugPrint('⚠️ Live users setup error: $e');
    }
  }

  /// 📡 Counters update by themselves when a complaint / request changes.
  /// If Realtime isn't enabled for those tables this simply never fires and
  /// the 90s auto-refresh still covers it.
  void _subscribeRealtime() {
    try {
      void onChange(PostgresChangePayload _) {
        _realtimeDebounce?.cancel();
        _realtimeDebounce = Timer(const Duration(seconds: 2), () {
          if (mounted && !_fetching) _loadData(silent: true);
        });
      }

      _channel = Supabase.instance.client
          .channel('admin-dashboard-live')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'complaints',
        callback: onChange,
      )
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'app_users',
        callback: onChange,
      )
          .subscribe();
    } catch (e) {
      debugPrint('⚠️ realtime unavailable: $e');
    }
  }

  /// Push a screen, then silently refresh badges when coming back.
  /// The guard stops a double-tap from opening the screen twice.
  Future<void> _push(Widget screen) async {
    if (_navigating) return;
    _navigating = true;
    try {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    } finally {
      _navigating = false;
    }
    if (mounted) _loadData(silent: true);
  }

  Future<void> _open(_DashItem item) async {
    _rememberRecent(item.id);
    await _push(item.screen());
  }

  // ═══════════════════════════════════════════════════════════
  // 🧰 Helpers
  // ═══════════════════════════════════════════════════════════
  String _ku(Object n) => n.toString().replaceAllMapped(
    RegExp(r'\d'),
        (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)],
  );

  /// Makes Arabic / Kurdish letter variants match each other in search.
  String _norm(String s) => s
      .toLowerCase()
      .replaceAll('ي', 'ی')
      .replaceAll('ى', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('ہ', 'ە')
      .replaceAll('ۀ', 'ە')
      .replaceAll(RegExp(r'[\u064B-\u065F]'), ''); // diacritics

  String get _lastUpdatedText {
    final t = _lastUpdated;
    if (t == null) return '';
    final h = t.hour.toString().padLeft(2, '0');
    final m = t.minute.toString().padLeft(2, '0');
    return _ku('$h:$m');
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 Sections data
  // ═══════════════════════════════════════════════════════════
  List<_DashSection> _buildSections(bool isAdmin) {
    final sections = <_DashSection>[
      _DashSection('complaints', '🔥 بەشی گرنگ', [
        _DashItem(
          id: 'complaints',
          icon: Icons.assignment_rounded,
          color: const Color(0xFFEF4444),
          title: 'بەڕێوەبردنی سکاڵاکان',
          subtitle: 'بینین و جێبەجێکردنی سکاڵاکان',
          badge: _pendingComplaints,
          important: _pendingComplaints > 0,
          screen: () => const AdminComplaintsProScreen(),
        ),
        _DashItem(
          id: 'complaints_map',
          icon: Icons.map_rounded,
          color: const Color(0xFFE91E63),
          title: 'نەخشەی گشتی سکاڵاکان',
          subtitle: 'بینینی گشت سکاڵاکان لەسەر نەخشە',
          screen: () => const AllComplaintsMapScreen(),
        ),
        _DashItem(
          id: 'complaint_instructions',
          icon: Icons.campaign_rounded,
          color: const Color(0xFFF97316),
          title: 'ڕێنماییەکانی سکاڵا',
          subtitle: 'دەستکاری و گۆڕینی پۆپئاپی سکاڵا',
          screen: () => const AdminComplaintInstructionsListScreen(),
        ),
      ]),
      _DashSection('stores', '🏪 بەڕێوەبردنی شوێن و فەرمانگە', [
        _DashItem(
          id: 'stores',
          icon: Icons.storefront_rounded,
          color: const Color(0xFF3B82F6),
          title: 'بەڕێوەبردنی شوێنەکان',
          subtitle: 'سەرجەم شوێنە تۆمارکراوەکان',
          badge: _totalStores,
          screen: () => const AdminStoresScreen(),
        ),
        _DashItem(
          id: 'departments',
          icon: Icons.business_rounded,
          color: const Color(0xFF10B981),
          title: 'بەڕێوەبردنی فەرمانگەکان',
          subtitle: 'زیادکردن و دەستکاری مامەڵەکانی فەرمانگەکان',
          badge: _totalDepartments,
          screen: () => const AdminDepartmentsScreen(),
        ),
        _DashItem(
          id: 'categories',
          icon: Icons.category_rounded,
          color: const Color(0xFF8B5CF6),
          title: 'بەشە سەرەکی و ژێربەشەکان',
          subtitle: 'زیادکردن و دەستکاری بەشەکان',
          screen: () => const AdminCategoriesManagementScreen(),
        ),
        _DashItem(
          id: 'neighborhoods',
          icon: Icons.location_city_rounded,
          color: const Color(0xFF06B6D4),
          title: 'بەڕێوەبردنی گەڕەکەکان',
          subtitle: 'زیادکردن و دەستکاری گەڕەکانی کەلار',
          screen: () => const AdminNeighborhoodsScreen(),
        ),
        _DashItem(
          id: 'news',
          icon: Icons.newspaper_rounded,
          color: const Color(0xFF6366F1),
          title: 'بەڕێوەبردنی هەواڵ',
          subtitle: 'زیادکردن و دەستکاری هەواڵەکان',
          screen: () => const AdminNewsScreen(),
        ),
        _DashItem(
          id: 'gallery',
          icon: Icons.photo_library_rounded,
          color: const Color(0xFFF59E0B),
          title: 'بەڕێوەبردنی گەلەری',
          subtitle: 'زیادکردن و دەستکاریکردنی وێنەکان',
          screen: () => const AdminGallery(),
        ),
        _DashItem(
          id: 'banners',
          icon: Icons.slideshow_rounded,
          color: const Color(0xFFE91E63),
          title: 'ڕێکخستنی سلایدەکان',
          subtitle: 'ڕێکخستن و گۆڕینی بانەرەکان',
          screen: () => const AdminReorderBannersScreen(),
        ),
        _DashItem(
          id: 'videos',
          icon: Icons.video_library_rounded,
          color: const Color(0xFF8B5CF6),
          title: 'بەڕێوەبردنی ڤیدیۆکان',
          subtitle: 'زیادکردن و دەستکاری ڤیدیۆکان',
          screen: () => const AdminVideosScreen(),
        ),
        _DashItem(
          id: 'events',
          icon: Icons.event_rounded,
          color: const Color(0xFF6C5CE7),
          title: 'ڕووداوەکان',
          subtitle: 'زیادکردن و دەستکاری ڕووداوەکان',
          screen: () => const AdminEventsScreen(),
        ),
      ]),
      _DashSection('daily', '⚡ خزمەتگوزارییە ڕۆژانەکان', [
        _DashItem(
          id: 'emergency',
          icon: Icons.emergency_rounded,
          color: const Color(0xFFDC2626),
          title: 'بەڕێوەبردنی فریاکەوتن',
          subtitle: 'ژمارەکانی فریاکەوتن',
          screen: () => const AdminEmergencyServicesScreen(),
        ),
        _DashItem(
          id: 'fuel',
          icon: Icons.local_gas_station_rounded,
          color: const Color(0xFFFFD700),
          title: 'بەڕێوەبردنی سووتەمەنی',
          subtitle: 'نوێکردنەوەی نرخی بەنزین و گاز',
          screen: () => const AdminFuelStationsScreen(),
        ),
        _DashItem(
          id: 'currency',
          icon: Icons.attach_money_rounded,
          color: const Color(0xFF10B981),
          title: 'بەڕێوەبردنی دراوەکان',
          subtitle: 'نوێکردنەوەی نرخی دۆلار و زێڕ',
          screen: () => const AdminCurrencyStationsScreen(),
        ),
        _DashItem(
          id: 'weather',
          icon: Icons.cloud_rounded,
          color: const Color(0xFF3B82F6),
          title: 'بەڕێوەبردنی کەشوهەوا',
          subtitle: 'نوێکردنەوەی پلەی گەرما و دۆخ',
          screen: () => const AdminWeatherScreen(),
        ),
      ]),
      _DashSection('system', '⚙️ ڕێکخستن و سیستەم', [
        _DashItem(
          id: 'notifications',
          icon: Icons.notifications_active_rounded,
          color: const Color(0xFFF59E0B),
          title: 'ناردنی ئاگاداری',
          subtitle: 'ناردنی ئاگاداری بۆ بەکارهێنەران',
          screen: () => const AdminNotificationsScreen(),
        ),
        _DashItem(
          id: 'vendor_requests',
          icon: Icons.assignment_ind_rounded,
          color: const Color(0xFF8B5CF6),
          title: 'داوکاری ئەدمینەکان',
          subtitle: 'پەسەندکردنی ئەدمینە نوێکان',
          badge: _pendingRequests,
          important: _pendingRequests > 0,
          adminOnly: true,
          screen: () => const AdminVendorRequestsScreen(),
        ),
        _DashItem(
          id: 'database',
          icon: Icons.storage_rounded,
          color: const Color(0xFF3B82F6),
          title: 'خشتەکانی داتابەیس',
          subtitle: 'بینینی گشت خشتەکانی داتابەیس',
          adminOnly: true,
          screen: () => const AdminDatabaseViewerScreen(),
        ),
      ]),
    ];

    if (!_kRestrictSensitiveToAdmin || isAdmin) return sections;

    return sections
        .map((s) => _DashSection(
      s.id,
      s.title,
      s.items.where((i) => !i.adminOnly).toList(),
    ))
        .where((s) => s.items.isNotEmpty)
        .toList();
  }

  // ═══════════════════════════════════════════════════════════
  // 🏗️ Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final p = _Palette(Theme.of(context).brightness == Brightness.dark);
    final isAdmin = AuthSessionManager.isAdmin;
    final sections = _buildSections(isAdmin);
    final query = _norm(_searchQuery);

    // 🔎 Filter once (title + subtitle)
    final visible = <_DashSection>[];
    for (final s in sections) {
      final items = query.isEmpty
          ? s.items
          : s.items
          .where((i) =>
      _norm(i.title).contains(query) ||
          _norm(i.subtitle).contains(query))
          .toList();
      if (items.isNotEmpty) visible.add(_DashSection(s.id, s.title, items));
    }

    final searching = _searchQuery.isNotEmpty;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: p.bg,
        body: RefreshIndicator(
          color: AppColors.primary,
          edgeOffset: 140,
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            if (!_reduceMotion) _entryController.forward(from: 0);
            await _loadData(silent: true);
          },
          child: CustomScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              _buildAppBar(isAdmin),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        child: _loading && _hasLoadedOnce
                            ? Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: const LinearProgressIndicator(
                              color: AppColors.primary,
                              backgroundColor: Colors.transparent,
                              minHeight: 3,
                            ),
                          ),
                        )
                            : const SizedBox(width: double.infinity),
                      ),
                      if (_loadError != null) _buildErrorBanner(p),
                      _buildLiveUsersCard(itemIndex: 0),
                      const SizedBox(height: 12),
                      _buildAttentionBanner(p, isAdmin),
                      const SizedBox(height: 20),
                      _buildSectionHeader('📊 ئامارە سەرەکییەکان', p,
                          itemIndex: 2),
                      const SizedBox(height: 12),
                      _buildStatsGrid(p, isAdmin),
                      const SizedBox(height: 24),
                      _buildSearchBar(p),
                      if (!searching) _buildRecents(p, sections),
                      if (!searching && visible.length > 1)
                        _buildExpandCollapseRow(p, visible),
                      const SizedBox(height: 4),
                      if (visible.isEmpty && searching)
                        _buildNoResults(p)
                      else
                        for (var i = 0; i < visible.length; i++)
                          _buildSection(
                            section: visible[i],
                            p: p,
                            itemIndex: 10 + i * 5,
                          ),
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

  // ═══════════════════════════════════════════════════════════
  // 🎨 AppBar
  // ═══════════════════════════════════════════════════════════
  Widget _buildAppBar(bool isAdmin) {
    final hasError = _loadError != null;

    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: _kAppBarColor,
      foregroundColor: Colors.white,
      elevation: 0,
      title: const Text(''),
      actions: [
        IconButton(
          icon: _loading
              ? const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : const Icon(Icons.refresh_rounded),
          onPressed: _loading
              ? null
              : () {
            HapticFeedback.selectionClick();
            if (!_reduceMotion) _entryController.forward(from: 0);
            _loadData();
          },
          tooltip: 'نوێکردنەوە',
        ),
        const SizedBox(width: 8),
      ],
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
                top: -50,
                right: -50,
                child: AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) => Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 60, 20, 16),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) => Transform.scale(
                          scale: 1.0 + (_pulseAnimation.value - 1.0) * 0.4,
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFD700), Color(0xFFFF8F00)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFFFFD700)
                                      .withValues(alpha: 0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.workspace_premium_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              isAdmin ? 'پانێڵی ئەدمین' : 'پانێڵی بەڕێوەبردن',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 4),
                            FadeTransition(
                              opacity: _headerAnimation,
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: hasError
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      hasError
                                          ? (_lastUpdated == null
                                          ? 'کێشەی پەیوەندی'
                                          : 'کێشەی پەیوەندی • دوایین نوێکردنەوە $_lastUpdatedText')
                                          : (_lastUpdated == null
                                          ? 'سیستەم چالاکە'
                                          : 'سیستەم چالاکە • $_lastUpdatedText'),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.white70,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
  // ⚠️ Banners
  // ═══════════════════════════════════════════════════════════
  Widget _buildErrorBanner(_Palette p) {
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
                _loadError ?? '',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: p.text,
                ),
              ),
            ),
            TextButton(
              onPressed: _loading ? null : () => _loadData(),
              child: const Text(
                'دووبارە',
                style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🚨 Shows only when something needs the admin's attention
  Widget _buildAttentionBanner(_Palette p, bool isAdmin) {
    final showRequests =
        _pendingRequests > 0 && (isAdmin || !_kRestrictSensitiveToAdmin);
    if (_pendingComplaints <= 0 && !showRequests) {
      return const SizedBox.shrink();
    }

    Widget chip(String label, IconData icon, VoidCallback onTap) {
      return Semantics(
        button: true,
        label: label,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            HapticFeedback.lightImpact();
            onTap();
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.white, size: 14),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _Entry(
      animation: _entryController,
      index: 2,
      child: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEF4444), Color(0xFFF97316)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFEF4444).withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.notification_important_rounded,
                      color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'پێویستی بە سەرنجە',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (_pendingComplaints > 0)
                    chip(
                      '${_ku(_pendingComplaints)} سکاڵای چاوەڕوان',
                      Icons.hourglass_empty_rounded,
                          () => _push(const AdminComplaintsProScreen()),
                    ),
                  if (showRequests)
                    chip(
                      '${_ku(_pendingRequests)} داوکاری ئەدمین',
                      Icons.assignment_ind_rounded,
                          () => _push(const AdminVendorRequestsScreen()),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🦸 Hero cards (live users + AI chat share one builder)
  // ═══════════════════════════════════════════════════════════
  Widget _heroCard({
    required int itemIndex,
    required List<Color> colors,
    required IconData icon,
    required String title,
    required Widget subtitle,
    required String semanticsLabel,
    required VoidCallback onTap,
    bool shimmer = false,
  }) {
    return _Entry(
      animation: _entryController,
      index: itemIndex,
      child: Semantics(
        button: true,
        label: semanticsLabel,
        child: GestureDetector(
          onTap: () {
            HapticFeedback.mediumImpact();
            onTap();
          },
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: colors.first.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) => Transform.scale(
                        scale: _pulseAnimation.value,
                        child: Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                              width: 2,
                            ),
                          ),
                          child: Icon(icon, color: Colors.white, size: 24),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          subtitle,
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                        size: 14,
                      ),
                    ),
                  ],
                ),
              ),
              if (shimmer && !_reduceMotion)
                Positioned.fill(
                  child: IgnorePointer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedBuilder(
                        animation: _shimmerController,
                        builder: (context, _) => DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment(
                                -1.0 + _shimmerController.value * 3,
                                -1.0,
                              ),
                              end: Alignment(
                                1.0 + _shimmerController.value * 3,
                                1.0,
                              ),
                              colors: [
                                Colors.transparent,
                                Colors.white.withValues(alpha: 0.1),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.5, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveUsersCard({required int itemIndex}) {
    return _heroCard(
      itemIndex: itemIndex,
      colors: const [Color(0xFF10B981), Color(0xFF059669)],
      icon: Icons.people_rounded,
      title: 'بەکارهێنەرانی چالاک',
      semanticsLabel:
      'بەکارهێنەرانی چالاک، ${_ku(_onlineUsers)} ئێستا لە خەتە',
      onTap: () => _push(const AdminLiveUsersScreen()),
      subtitle: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.8),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${_ku(_onlineUsers)} ئێستا لە خەتە',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Section header + Stats
  // ═══════════════════════════════════════════════════════════
  Widget _buildSectionHeader(String title, _Palette p,
      {required int itemIndex}) {
    return _Entry(
      animation: _entryController,
      index: itemIndex,
      from: const Offset(20, 0),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF6C5CE7)],
              ),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w900,
              color: p.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(_Palette p, bool isAdmin) {
    final canOpenRequests = isAdmin || !_kRestrictSensitiveToAdmin;
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.5);

    return GridView(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        // ✅ بەرزی کارتەکە زیادکرا بۆ ١١٨ بۆ ئەوەی کێشەی ئۆڤەرفلۆ نەبێت
        mainAxisExtent: 118.0 * scale,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          p: p,
          icon: Icons.storefront_rounded,
          label: 'شوێنەکان',
          value: _totalStores,
          color: const Color(0xFFF59E0B),
          itemIndex: 3,
          onTap: () => _push(const AdminStoresScreen()),
        ),
        _buildStatCard(
          p: p,
          icon: Icons.business_rounded,
          label: 'فەرمانگەکان',
          value: _totalDepartments,
          color: const Color(0xFF10B981),
          itemIndex: 4,
          onTap: () => _push(const AdminDepartmentsScreen()),
        ),
        _buildStatCard(
          p: p,
          icon: Icons.report_rounded,
          label: 'کۆی سکاڵاکان',
          value: _totalComplaints,
          color: const Color(0xFFE91E63),
          itemIndex: 5,
          onTap: () => _push(const AdminComplaintsProScreen()),
        ),
        _buildStatCard(
          p: p,
          icon: Icons.hourglass_empty_rounded,
          label: 'سکاڵای چاوەڕوان',
          value: _pendingComplaints,
          color: const Color(0xFFEF4444),
          itemIndex: 6,
          isImportant: _pendingComplaints > 0,
          onTap: () => _push(const AdminComplaintsProScreen()),
        ),
        _buildStatCard(
          p: p,
          icon: Icons.assignment_ind_rounded,
          label: 'داوکاری ئەدمین',
          value: _pendingRequests,
          color: const Color(0xFF8B5CF6),
          itemIndex: 7,
          isImportant: _pendingRequests > 0,
          onTap: canOpenRequests
              ? () => _push(const AdminVendorRequestsScreen())
              : null,
        ),
        _buildStatCard(
          p: p,
          icon: Icons.shopping_bag_rounded,
          label: 'کاڵاکان',
          value: _totalProducts,
          color: const Color(0xFFF97316),
          itemIndex: 8,
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required _Palette p,
    required IconData icon,
    required String label,
    required int value,
    required Color color,
    required int itemIndex,
    bool isImportant = false,
    VoidCallback? onTap,
  }) {
    final showSkeleton = _loading && !_hasLoadedOnce;

    return _Entry(
      animation: _entryController,
      index: itemIndex,
      from: const Offset(0, 30),
      child: Semantics(
        button: onTap != null,
        label: '$label: ${_ku(value)}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: onTap == null
                ? null
                : () {
              HapticFeedback.lightImpact();
              onTap();
            },
            child: Container(
              // ✅ پادینگی ناوەوە کەمکرایەوە بۆ ئەوەی بۆشایی زیاتر بۆ دەق بمێنێت
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isImportant
                      ? color.withValues(alpha: 0.5)
                      : color.withValues(alpha: 0.15),
                  width: isImportant ? 2 : 1.2,
                ),
                boxShadow: [
                  ...p.shadow(),
                  if (isImportant)
                    BoxShadow(
                      color: color.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                      spreadRadius: -4,
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: color, size: 18),
                      ),
                      const Spacer(),
                      if (isImportant)
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) => Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(
                                    alpha: _pulseAnimation.value * 0.8,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (onTap != null)
                        Icon(Icons.north_west_rounded,
                            size: 14, color: p.chevron),
                    ],
                  ),
                  // ✅ بەشی خوارەوە (ژمارە و ناو) بە FittedBox
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showSkeleton)
                        AnimatedBuilder(
                          animation: _shimmerController,
                          builder: (context, _) {
                            final t = (_shimmerController.value * 2) % 2;
                            final a = 0.12 + 0.12 * (t < 1 ? t : 2 - t);
                            return Container(
                              width: 54,
                              height: 24,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: a),
                                borderRadius: BorderRadius.circular(6),
                              ),
                            );
                          },
                        )
                      else
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: AlignmentDirectional.centerStart,
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                                begin: 0, end: value.toDouble()),
                            duration: _reduceMotion
                                ? Duration.zero
                                : const Duration(milliseconds: 700),
                            curve: Curves.easeOutCubic,
                            builder: (context, v, _) => Text(
                              _ku(v.round()),
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: color,
                                height: 1.0,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: p.textSub,
                          ),
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
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 Search
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchBar(_Palette p) {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 0),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _searchQuery.isNotEmpty
              ? AppColors.primary.withValues(alpha: 0.4)
              : p.border,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              style: TextStyle(
                color: p.isDark ? Colors.white : Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'گەڕان لە پانێڵ...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: p.isDark ? Colors.white38 : Colors.grey,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              tooltip: 'سڕینەوەی گەڕان',
              icon: Icon(Icons.close_rounded, size: 18, color: p.textSub),
              onPressed: () {
                _searchCtrl.clear();
                FocusScope.of(context).unfocus();
                setState(() => _searchQuery = '');
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildNoResults(_Palette p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded, size: 52, color: p.textSub),
          const SizedBox(height: 10),
          Text(
            'هیچ ئەنجامێک نەدۆزرایەوە',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 14,
              color: p.textSub,
            ),
          ),
          const SizedBox(height: 6),
          TextButton(
            onPressed: () {
              _searchCtrl.clear();
              setState(() => _searchQuery = '');
            },
            child: const Text('سڕینەوەی گەڕان'),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🕘 Recents + expand/collapse
  // ═══════════════════════════════════════════════════════════
  Widget _buildRecents(_Palette p, List<_DashSection> sections) {
    // Resolve ids against what this user is allowed to see
    final byId = {
      for (final s in sections)
        for (final i in s.items) i.id: i,
    };
    final items = [
      for (final id in _recentIds)
        if (byId[id] != null) byId[id]!,
    ];
    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.history_rounded, size: 16, color: p.textSub),
              const SizedBox(width: 6),
              Text(
                'دوایین بەکارهاتوو',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: p.textSub,
                ),
              ),
              const Spacer(),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _recentIds = []);
                  _saveRecents();
                },
                child: Padding(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  child: Text(
                    'پاککردنەوە',
                    style: TextStyle(fontSize: 11, color: p.textSub),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final item = items[i];
                return Semantics(
                  button: true,
                  label: item.title,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _open(item);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: item.color.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(item.icon, size: 16, color: item.color),
                          const SizedBox(width: 6),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: p.text,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandCollapseRow(_Palette p, List<_DashSection> visible) {
    final allOpen = visible.every((s) => !_collapsed.contains(s.id));

    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: Padding(
        padding: const EdgeInsets.only(top: 8),
        child: TextButton.icon(
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            foregroundColor: p.textSub,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            setState(() {
              if (allOpen) {
                _collapsed.addAll(visible.map((s) => s.id));
              } else {
                _collapsed.removeAll(visible.map((s) => s.id));
              }
            });
            _saveCollapsed();
          },
          icon: Icon(
            allOpen ? Icons.unfold_less_rounded : Icons.unfold_more_rounded,
            size: 18,
          ),
          label: Text(
            allOpen ? 'داخستنی هەموو بەشەکان' : 'کردنەوەی هەموو بەشەکان',
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📂 Section + Item
  // ═══════════════════════════════════════════════════════════
  Widget _buildSection({
    required _DashSection section,
    required _Palette p,
    required int itemIndex,
  }) {
    // While searching, every matching section is forced open
    final searching = _searchQuery.isNotEmpty;
    final isExpanded = searching || !_collapsed.contains(section.id);

    return _Entry(
      animation: _entryController,
      index: itemIndex,
      child: Column(
        children: [
          const SizedBox(height: 20),
          Semantics(
            button: !searching,
            expanded: isExpanded,
            label: section.title,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: searching
                    ? null
                    : () {
                  HapticFeedback.selectionClick();
                  setState(() {
                    if (isExpanded) {
                      _collapsed.add(section.id);
                    } else {
                      _collapsed.remove(section.id);
                    }
                  });
                  _saveCollapsed();
                },
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: p.chip,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          section.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: p.text,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _ku(section.items.length),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 250),
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: p.textSub,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            sizeCurve: Curves.easeOutCubic,
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                for (final item in section.items) _buildItem(p, item),
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(_Palette p, _DashItem item) {
    final badge = item.badge;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Semantics(
        button: true,
        label: '${item.title}. ${item.subtitle}'
            '${badge != null && badge > 0 ? '. ${_ku(badge)}' : ''}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _open(item);
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: item.important
                      ? item.color.withValues(alpha: 0.4)
                      : Colors.transparent,
                  width: item.important ? 1.5 : 0,
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                    Colors.black.withValues(alpha: p.isDark ? 0.3 : 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          item.color.withValues(alpha: 0.2),
                          item.color.withValues(alpha: 0.08),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: item.color.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Icon(item.icon, color: item.color, size: 20),
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
                                item.title,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w900,
                                  color: p.text,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (badge != null && badge > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: item.color,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(
                                      color: item.color.withValues(alpha: 0.4),
                                      blurRadius: 6,
                                    ),
                                  ],
                                ),
                                child: Text(
                                  _ku(badge),
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
                          item.subtitle,
                          style: TextStyle(fontSize: 11, color: p.textSub),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_left_rounded, size: 20, color: p.chevron),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}