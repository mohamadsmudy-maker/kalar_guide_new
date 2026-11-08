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
import 'admin_prayer_times.dart';
import 'admin_translations.dart';
import 'admin_osm_import.dart';
import 'admin_place_suggestions.dart';
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
import '../../l10n/tr.dart';

part 'admin_dashboard_ui.dart';

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
  int _totalNews = 0;

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
        _count(() => client.from('news').select('id').count()),
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
      _totalNews = results[5] ?? _totalNews;

      _loading = false;
      if (failed < results.length) {
        _hasLoadedOnce = true;
        _lastUpdated = DateTime.now();
      }
      _loadError = failed == 0
          ? null
          : (failed == results.length
          ? 'نەتوانرا ئامارەکان بهێنرێن. پەیوەندی ئینتەرنێتەکەت بپشکنە.'
          : trf('بەشێک لە ئامارەکان نەهێنران ({0} لە {1}).', [_ku(failed), _ku(results.length)]));
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
          color: const Color(0xFFDC3545),
          title: tr('بەڕێوەبردنی سکاڵاکان'),
          subtitle: tr('بینین و جێبەجێکردنی سکاڵاکان'),
          badge: _pendingComplaints,
          important: _pendingComplaints > 0,
          screen: () => const AdminComplaintsProScreen(),
        ),
        _DashItem(
          id: 'complaints_map',
          icon: Icons.map_rounded,
          color: const Color(0xFFC2557A),
          title: tr('نەخشەی گشتی سکاڵاکان'),
          subtitle: tr('بینینی گشت سکاڵاکان لەسەر نەخشە'),
          screen: () => const AllComplaintsMapScreen(),
        ),
        _DashItem(
          id: 'complaint_instructions',
          icon: Icons.campaign_rounded,
          color: const Color(0xFFD9822B),
          title: tr('ڕێنماییەکانی سکاڵا'),
          subtitle: tr('دەستکاری و گۆڕینی پۆپئاپی سکاڵا'),
          screen: () => const AdminComplaintInstructionsListScreen(),
        ),
      ]),
      _DashSection('stores', '🏪 بەڕێوەبردنی شوێن و فەرمانگە', [
        _DashItem(
          id: 'stores',
          icon: Icons.storefront_rounded,
          color: const Color(0xFF1E88E5),
          title: tr('بەڕێوەبردنی شوێنەکان'),
          subtitle: tr('سەرجەم شوێنە تۆمارکراوەکان'),
          badge: _totalStores,
          screen: () => const AdminStoresScreen(),
        ),
        _DashItem(
          id: 'departments',
          icon: Icons.business_rounded,
          color: const Color(0xFF0F9D7A),
          title: tr('بەڕێوەبردنی فەرمانگەکان'),
          subtitle: tr('زیادکردن و دەستکاری مامەڵەکانی فەرمانگەکان'),
          badge: _totalDepartments,
          screen: () => const AdminDepartmentsScreen(),
        ),
        _DashItem(
          id: 'categories',
          icon: Icons.category_rounded,
          color: const Color(0xFF4F5BD5),
          title: tr('بەشە سەرەکی و ژێربەشەکان'),
          subtitle: tr('زیادکردن و دەستکاری بەشەکان'),
          screen: () => const AdminCategoriesManagementScreen(),
        ),
        _DashItem(
          id: 'neighborhoods',
          icon: Icons.location_city_rounded,
          color: const Color(0xFF1E88E5),
          title: tr('بەڕێوەبردنی گەڕەکەکان'),
          subtitle: tr('زیادکردن و دەستکاری گەڕەکانی کەلار'),
          screen: () => const AdminNeighborhoodsScreen(),
        ),
        _DashItem(
          id: 'news',
          icon: Icons.newspaper_rounded,
          color: const Color(0xFF4F5BD5),
          title: tr('بەڕێوەبردنی هەواڵ'),
          subtitle: tr('زیادکردن و دەستکاری هەواڵەکان'),
          screen: () => const AdminNewsScreen(),
        ),
        _DashItem(
          id: 'gallery',
          icon: Icons.photo_library_rounded,
          color: const Color(0xFFD9822B),
          title: tr('بەڕێوەبردنی گەلەری'),
          subtitle: tr('زیادکردن و دەستکاریکردنی وێنەکان'),
          screen: () => const AdminGallery(),
        ),
        _DashItem(
          id: 'banners',
          icon: Icons.slideshow_rounded,
          color: const Color(0xFFC2557A),
          title: tr('ڕێکخستنی سلایدەکان'),
          subtitle: tr('ڕێکخستن و گۆڕینی بانەرەکان'),
          screen: () => const AdminReorderBannersScreen(),
        ),
        _DashItem(
          id: 'videos',
          icon: Icons.video_library_rounded,
          color: const Color(0xFF4F5BD5),
          title: tr('بەڕێوەبردنی ڤیدیۆکان'),
          subtitle: tr('زیادکردن و دەستکاری ڤیدیۆکان'),
          screen: () => const AdminVideosScreen(),
        ),
        _DashItem(
          id: 'events',
          icon: Icons.event_rounded,
          color: const Color(0xFF4F5BD5),
          title: tr('ڕووداوەکان'),
          subtitle: tr('زیادکردن و دەستکاری ڕووداوەکان'),
          screen: () => const AdminEventsScreen(),
        ),
      ]),
      _DashSection('daily', '⚡ خزمەتگوزارییە ڕۆژانەکان', [
        _DashItem(
          id: 'emergency',
          icon: Icons.emergency_rounded,
          color: const Color(0xFFDC3545),
          title: tr('بەڕێوەبردنی فریاکەوتن'),
          subtitle: tr('ژمارەکانی فریاکەوتن'),
          screen: () => const AdminEmergencyServicesScreen(),
        ),
        _DashItem(
          id: 'fuel',
          icon: Icons.local_gas_station_rounded,
          color: const Color(0xFFD9822B),
          title: tr('بەڕێوەبردنی سووتەمەنی'),
          subtitle: tr('نوێکردنەوەی نرخی بەنزین و گاز'),
          screen: () => const AdminFuelStationsScreen(),
        ),
        _DashItem(
          id: 'currency',
          icon: Icons.attach_money_rounded,
          color: const Color(0xFF0F9D7A),
          title: tr('بەڕێوەبردنی دراوەکان'),
          subtitle: tr('نوێکردنەوەی نرخی دۆلار و زێڕ'),
          screen: () => const AdminCurrencyStationsScreen(),
        ),
        _DashItem(
          id: 'weather',
          icon: Icons.cloud_rounded,
          color: const Color(0xFF1E88E5),
          title: tr('بەڕێوەبردنی کەشوهەوا'),
          subtitle: tr('نوێکردنەوەی پلەی گەرما و دۆخ'),
          screen: () => const AdminWeatherScreen(),
        ),
        _DashItem(
          id: 'prayer_times',
          icon: Icons.mosque_rounded,
          color: const Color(0xFF0F9D7A),
          title: tr('کاتەکانی نوێژ'),
          subtitle: tr('دەستکاری یان پەیستکردنی خشتەی ئامۆژگاری'),
          adminOnly: true,
          screen: () => const AdminPrayerTimesScreen(),
        ),
        _DashItem(
          id: 'translations',
          icon: Icons.translate_rounded,
          color: const Color(0xFF4F5BD5),
          title: tr('وەرگێڕانەکان'),
          subtitle: tr('ڕاستکردنەوەی وەرگێڕانی ناوی شوێن و هەواڵ'),
          adminOnly: true,
          screen: () => const AdminTranslationsScreen(),
        ),
        _DashItem(
          id: 'place_suggestions',
          icon: Icons.add_location_alt_rounded,
          color: const Color(0xFF0F9D7A),
          title: tr('پێشنیاری شوێنەکان'),
          subtitle: tr('پێشنیاری هاوڵاتیان — چالاک/ناچالاک و پەسەندکردن'),
          adminOnly: true,
          screen: () => const AdminPlaceSuggestionsScreen(),
        ),
        _DashItem(
          id: 'osm_import',
          icon: Icons.travel_explore_rounded,
          color: const Color(0xFF1E88E5),
          title: tr('هێنانی شوێن لە OpenStreetMap'),
          subtitle: tr('زیادکردنی شوێنەکانی کەلار بە کۆمەڵ'),
          adminOnly: true,
          screen: () => const AdminOsmImportScreen(),
        ),
      ]),
      _DashSection('system', '⚙️ ڕێکخستن و سیستەم', [
        _DashItem(
          id: 'notifications',
          icon: Icons.notifications_active_rounded,
          color: const Color(0xFFD9822B),
          title: tr('ناردنی ئاگاداری'),
          subtitle: tr('ناردنی ئاگاداری بۆ بەکارهێنەران'),
          screen: () => const AdminNotificationsScreen(),
        ),
        _DashItem(
          id: 'vendor_requests',
          icon: Icons.assignment_ind_rounded,
          color: const Color(0xFF4F5BD5),
          title: tr('داوکاری ئەدمینەکان'),
          subtitle: tr('پەسەندکردنی ئەدمینە نوێکان'),
          badge: _pendingRequests,
          important: _pendingRequests > 0,
          adminOnly: true,
          screen: () => const AdminVendorRequestsScreen(),
        ),
        _DashItem(
          id: 'database',
          icon: Icons.storage_rounded,
          color: const Color(0xFF1E88E5),
          title: tr('خشتەکانی داتابەیس'),
          subtitle: tr('بینینی گشت خشتەکانی داتابەیس'),
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
      textDirection: AppLang.direction,
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
                      _buildSectionHeader(tr('📊 ئامارە سەرەکییەکان'), p,
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
                hintText: tr('گەڕان لە پانێڵ...'),
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
              tooltip: tr('سڕینەوەی گەڕان'),
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
            tr('هیچ ئەنجامێک نەدۆزرایەوە'),
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
            child: Text(tr('سڕینەوەی گەڕان')),
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
                tr('دوایین بەکارهاتوو'),
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
                    tr('پاککردنەوە'),
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
                              tr(item.title),
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
            tr(allOpen ? 'داخستنی هەموو بەشەکان' : 'کردنەوەی هەموو بەشەکان'),
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
                          tr(section.title),
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
                          tr(_ku(section.items.length)),
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

}