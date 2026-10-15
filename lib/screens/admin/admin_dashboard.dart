import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/auth_service.dart';
import '../../utils/app_logger.dart';
import '../../services/presence_service.dart';
import 'admin_live_users.dart';

// ═══════════════════════════════════════════════════════════
// 📦 Admin Screens
// ═══════════════════════════════════════════════════════════
import 'admin_ai_chat.dart';
import 'admin_banners.dart';
import 'admin_categories_management.dart';
import 'admin_complaint_instructions.dart';
import 'admin_complaints.dart' show AdminComplaintsProScreen;
import 'admin_currency.dart';
import 'admin_database_viewer.dart';
import 'admin_departments.dart';
import 'admin_emergency_services_screen.dart';
import 'admin_events_screen.dart';
import 'admin_fuel.dart';
import 'admin_neighborhoods_screen.dart';
import 'admin_news.dart';
import 'admin_notifications.dart';
import 'admin_store_services_screen.dart';
import 'admin_stores.dart';
import 'admin_vendor_requests.dart';
import 'admin_videos.dart';
import 'admin_weather.dart';
import 'all_complaints_map.dart';

/// 👑 پانێڵی بەڕێوەبردن — ULTRA PRO EDITION
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  // ═══════════════════════════════════════════════════════════
  // 📊 Stats State
  // ═══════════════════════════════════════════════════════════
  bool _loading = true;
  int _totalStores = 0;
  int _totalProducts = 0;
  int _pendingVendors = 0;
  int _pendingComplaints = 0;
  int _totalDepartments = 0;
  int _totalComplaints = 0;
  String? _statsError;

  @override
  void initState() {
    super.initState();
    _fetchAllStats();
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 هێنانی ئامارەکان — Partial Failure Safe
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchAllStats() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _statsError = null;
    });

    final supa = Supabase.instance.client;

    int stores = 0, products = 0, pendingComplaints = 0;
    int pendingVendors = 0, departments = 0, allComplaints = 0;
    final errors = <String>[];

    // ─── ١. شوێنەکان ───
    try {
      final res = await supa
          .from('dukan')
          .select('id')
          .count(CountOption.exact);
      stores = res.count ?? 0;
    } catch (e) {
      AppLogger.w('⚠️ Stats: dukan error: $e');
      errors.add('شوێنەکان');
    }

    // ─── ٢. کاڵاکان ───
    try {
      final res = await supa
          .from('products')
          .select('id')
          .count(CountOption.exact);
      products = res.count ?? 0;
    } catch (e) {
      AppLogger.w('⚠️ Stats: products error: $e');
      errors.add('کاڵاکان');
    }

    // ─── ٣. سکاڵای چاوەڕوان ───
    try {
      final res = await supa
          .from('complaints')
          .select('id')
          .eq('status', 'pending')
          .count(CountOption.exact);
      pendingComplaints = res.count ?? 0;
    } catch (e) {
      AppLogger.w('⚠️ Stats: pending complaints error: $e');
      errors.add('سکاڵاکان');
    }

    // ─── ٤. هەموو سکاڵاکان ───
    try {
      final res = await supa
          .from('complaints')
          .select('id')
          .count(CountOption.exact);
      allComplaints = res.count ?? 0;
    } catch (e) {
      AppLogger.w('⚠️ Stats: all complaints error: $e');
    }

    // ─── ٥. داواکاری ئەدمین ───
    try {
      final res = await supa
          .from('app_users')
          .select('id')
          .eq('role', 'vendor')
          .eq('is_approved', false)
          .count(CountOption.exact);
      pendingVendors = res.count ?? 0;
    } catch (e) {
      AppLogger.w('⚠️ Stats: vendors error: $e');
      errors.add('داواکاری');
    }

    // ─── ٦. فەرمانگەکان ───
    try {
      final res = await supa
          .from('departments')
          .select('id')
          .count(CountOption.exact);
      departments = res.count ?? 0;
    } catch (e) {
      AppLogger.w('⚠️ Stats: departments error: $e');
      errors.add('فەرمانگەکان');
    }

    if (!mounted) return;

    setState(() {
      _totalStores = stores;
      _totalProducts = products;
      _pendingComplaints = pendingComplaints;
      _totalComplaints = allComplaints;
      _pendingVendors = pendingVendors;
      _totalDepartments = departments;
      _loading = false;
      _statsError = errors.isEmpty
          ? null
          : '⚠️ هەندێک ئامار بار نەکران: ${errors.join("، ")}';
    });
  }

  // ═══════════════════════════════════════════════════════════
  // 🚀 Navigation Helper
  // ═══════════════════════════════════════════════════════════
  Future<void> _navigate(Widget screen) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    );
    if (mounted) await _fetchAllStats();
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role = AuthSessionManager.userRole.toLowerCase();
    final isAdmin = role == 'admin';
    final isVendorOnly = role == 'vendor' && !isAdmin;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor:
          isDark ? const Color(0xFF1A1A22) : const Color(0xFF1A1A2E),
          title: Text(
            isAdmin ? 'پانێڵی بەڕێوەبەر 👑' : 'پانێڵی بەڕێوەبردن 🏪',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              tooltip: 'نوێکردنەوە',
              onPressed: _fetchAllStats,
            ),
          ],
        ),
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(color: Color(0xFFE91E63)),
        )
            : RefreshIndicator(
          color: const Color(0xFFE91E63),
          onRefresh: _fetchAllStats,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ─── Partial Error Banner ───
              if (_statsError != null) ...[
                _buildErrorBanner(_statsError!),
                const SizedBox(height: 12),
              ],

              // ═══════════════════════════════════════
              // 👑 ADMIN ONLY
              // ═══════════════════════════════════════
              if (isAdmin) ...[
                _buildLiveUsersCard(isDark),  // ⭐ Live Users
                const SizedBox(height: 12),
                _buildAiChatBanner(),
                const SizedBox(height: 18),
                _buildStatsSection(isDark),
                const SizedBox(height: 22),
                _buildAdminMenu(isDark),
              ],

              // ═══════════════════════════════════════
              // 🏪 VENDOR ONLY
              // ═══════════════════════════════════════
              if (isVendorOnly) ...[
                _buildVendorBanner(),
                const SizedBox(height: 18),
                _buildVendorStats(isDark),
                const SizedBox(height: 22),
                _buildVendorMenu(isDark),
              ],

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 👥 Live Users Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildLiveUsersCard(bool isDark) {
    return StreamBuilder<int>(
      stream: PresenceService.watchOnlineCount(),
      builder: (context, snapshot) {
        final count = snapshot.data ?? 0;
        return InkWell(
          onTap: () => _navigate(const AdminLiveUsersScreen()),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF10B981), Color(0xFF059669)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10B981).withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.people_alt_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'بەکارهێنەرانی چالاک',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '$count ئێستا لە خەتە',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_left_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 ADMIN MENU
  // ═══════════════════════════════════════════════════════════
  Widget _buildAdminMenu(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ═══ بەشی گرنگ ═══
        _buildSectionTitle('🔥 بەشی گرنگ', isDark),
        const SizedBox(height: 12),

        _buildMenuTile(
          "بەڕێوەبردنی سکاڵاکان 📋",
          "بینین و جێبەجێکردنی سکاڵاکان",
          Icons.assignment_late_rounded,
          Colors.red,
              () => _navigate(const AdminComplaintsProScreen()),
          isDark: isDark,
        ),
        _buildMenuTile(
          "نەخشەی گشتی سکاڵاکان 🗺️",
          "بینینی گشت سکاڵاکان لەسەر ماپ",
          Icons.map_rounded,
          Colors.redAccent,
              () => _navigate(const AllComplaintsMapScreen()),
          isDark: isDark,
        ),
        _buildMenuTile(
          "ڕێنماییەکانی سکاڵا 📢",
          "دەستکاری و گۆڕینی پۆپئاپی سکاڵا",
          Icons.announcement_rounded,
          Colors.deepOrange,
              () => _navigate(const AdminComplaintInstructionsListScreen()),
          isDark: isDark,
        ),

        const SizedBox(height: 18),

        // ═══ شوێن و فەرمانگە ═══
        _buildSectionTitle('🏪 بەڕێوەبردنی شوێن و فەرمانگە', isDark),
        const SizedBox(height: 12),

        _buildMenuTile(
          "بەڕێوەبردنی شوێنەکان 🏪",
          "سەرجەم شوێنە تۆمارکراوەکان",
          Icons.storefront_rounded,
          Colors.indigo,
              () => _navigate(const AdminStoresScreen()),
          isDark: isDark,
        ),
        _buildMenuTile(
          "بەڕێوەبردنی فەرمانگەکان 🏛️",
          "زیادکردن و دەستکاری مامەڵەکانی فەرمانگەکان",
          Icons.business_rounded,
          const Color(0xFF10B981),
              () => _navigate(const AdminDepartmentsScreen()),
          isDark: isDark,
        ),
        _buildMenuTile(
          "بەشە سەرەکی و ژێربەشەکان 🗂️",
          "زیادکردن و دەستکاری بەشەکان",
          Icons.category_rounded,
          Colors.purple,
              () => _navigate(const AdminCategoriesManagementScreen()),
          isDark: isDark,
        ),
        _buildMenuTile(
          "بەڕێوەبردنی گەڕەکەکان 🏘️",
          "زیادکردن و دەستکاری گەڕەکەکانی کەلار",
          Icons.location_city_rounded,
          const Color(0xFF1E88E5),
              () => _navigate(const AdminNeighborhoodsScreen()),
          isDark: isDark,
        ),

        const SizedBox(height: 18),

        // ═══ ناوەڕۆک ═══
        _buildSectionTitle('📰 بەڕێوەبردنی ناوەڕۆک', isDark),
        const SizedBox(height: 12),

        _buildMenuTile(
          "بەڕێوەبردنی هەواڵ 📰",
          "زیادکردن و دەستکاری هەواڵەکان",
          Icons.post_add_rounded,
          Colors.green,
              () => _navigate(const AdminNewsScreen()),
          isDark: isDark,
        ),
        _buildMenuTile(
          "بەڕێوەبردنی ڤیدیۆکان 🎬",
          "زیادکردن و دەستکاری ڤیدیۆکان",
          Icons.video_library_rounded,
          Colors.indigo,
              () => _navigate(const AdminVideosScreen()),
          isDark: isDark,
        ),
        _buildMenuTile(
          "ڕێکخستنی سلایدەکان 🎨",
          "ڕێکخستن و گۆڕینی بانەرەکان",
          Icons.view_carousel_rounded,
          Colors.pink,
              () => _navigate(const AdminReorderBannersScreen()),
          isDark: isDark,
        ),
        _buildMenuTile(
          "ڕووداوەکان 📅",
          "زیادکردن و دەستکاری ڕووداوەکان",
          Icons.event_rounded,
          const Color(0xFF6C5CE7),
              () => _navigate(const AdminEventsScreen()),
          isDark: isDark,
        ),

        const SizedBox(height: 18),

        // ═══ خزمەتگوزارییە ڕۆژانەکان ═══
        _buildSectionTitle('⚡ خزمەتگوزارییە ڕۆژانەکان', isDark),
        const SizedBox(height: 12),

        _buildMenuTile(
          "بەڕێوەبردنی فریاکەوتن 🚑",
          "ژمارەکانی فریاکەوتن",
          Icons.emergency_rounded,
          const Color(0xFFE53935),
              () => _navigate(const AdminEmergencyServicesScreen()),
          isDark: isDark,
        ),
        _buildMenuTile(
          "بەڕێوەبردنی سووتەمەنی ⛽",
          "نوێکردنەوەی نرخی بەنزین و گاز",
          Icons.local_gas_station_rounded,
          const Color(0xFFFFD700),
              () => _navigate(const AdminFuelScreen()),
          isDark: isDark,
        ),
        _buildMenuTile(
          "بەڕێوەبردنی دراوەکان 💵",
          "نوێکردنەوەی نرخی دۆلار و زێڕ",
          Icons.currency_exchange_rounded,
          Colors.green,
              () => _navigate(const AdminCurrencyScreen()),
          isDark: isDark,
        ),
        _buildMenuTile(
          "بەڕێوەبردنی کەشوهەوا 🌤️",
          "نوێکردنەوەی پلەی گەرما و دۆخ",
          Icons.cloud_rounded,
          Colors.lightBlue,
              () => _navigate(const AdminWeatherScreen()),
          isDark: isDark,
        ),

        const SizedBox(height: 18),

        // ═══ ڕێکخستن ═══
        _buildSectionTitle('⚙️ ڕێکخستن و سیستەم', isDark),
        const SizedBox(height: 12),

        _buildMenuTile(
          "ناردنی ئاگاداری 🔔",
          "ناردنی ئاگاداری بۆ بەکارهێنەران",
          Icons.notifications_active_rounded,
          Colors.orange,
              () => _navigate(const AdminNotificationsScreen()),
          isDark: isDark,
        ),
        _buildMenuTile(
          "داواکاری ئەدمینەکان 👑",
          "پەسەندکردنی ئەدمینە نوێکان",
          Icons.admin_panel_settings_rounded,
          Colors.purple,
              () => _navigate(const AdminVendorRequestsScreen()),
          isDark: isDark,
        ),
        _buildMenuTile(
          "خشتەکانی داتابەیس 🗄️",
          "بینینی گشت خشتەکانی داتابەیس",
          Icons.table_chart_rounded,
          Colors.indigo,
              () => _navigate(const AdminDatabaseViewerScreen()),
          isDark: isDark,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏪 VENDOR MENU
  // ═══════════════════════════════════════════════════════════
  Widget _buildVendorMenu(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('⚡ شوێنەکەم', isDark),
        const SizedBox(height: 12),

        _buildMenuTile(
          "بەنزینخانەکەم ⛽",
          "نوێکردنەوەی نرخی سووتەمەنی",
          Icons.local_gas_station_rounded,
          const Color(0xFFFFD700),
              () => _navigate(const AdminFuelScreen()),
          isDark: isDark,
        ),
        _buildMenuTile(
          "نوسینگەی دراوەکەم 💵",
          "نوێکردنەوەی نرخی دراو و زێڕ",
          Icons.currency_exchange_rounded,
          Colors.green,
              () => _navigate(const AdminCurrencyScreen()),
          isDark: isDark,
        ),

        const SizedBox(height: 18),

        _buildSectionTitle('📰 ناوەڕۆک', isDark),
        const SizedBox(height: 12),

        _buildMenuTile(
          "بڵاوکردنەوەی هەواڵ 📰",
          "زیادکردن و دەستکاریکردنی هەواڵ",
          Icons.post_add_rounded,
          Colors.green,
              () => _navigate(const AdminNewsScreen()),
          isDark: isDark,
        ),
        _buildMenuTile(
          "کاڵاکانم 🛍️",
          "زیادکردن و دەستکاریکردنی کاڵاکان",
          Icons.shopping_bag_rounded,
          Colors.purple,
              () => _navigate(const AdminStoresScreen()),
          isDark: isDark,
        ),
        _buildMenuTile(
          "ڕووداوەکان 📅",
          "زیادکردن و دەستکاری ڕووداوەکان",
          Icons.event_rounded,
          const Color(0xFF6C5CE7),
              () => _navigate(const AdminEventsScreen()),
          isDark: isDark,
        ),

        const SizedBox(height: 18),

        _buildSectionTitle('🏪 شوێنەکەم', isDark),
        const SizedBox(height: 12),

        _buildMenuTile(
          "زانیاری شوێنەکەم 🏪",
          "بینین و دەستکاریکردنی زانیاری",
          Icons.storefront_rounded,
          Colors.orange,
              () => _navigate(const AdminStoresScreen()),
          isDark: isDark,
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 AI Chat Banner
  // ═══════════════════════════════════════════════════════════
  Widget _buildAiChatBanner() {
    return InkWell(
      onTap: () => _navigate(const AdminAiChatScreen()),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF6C5CE7), Color(0xFFE91E63)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.purple.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome,
                color: Colors.white,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "ڕاپۆرتی زیرەک بە چات (AI Chat) 🤖",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "لێرەدا پرسیار لەبارەی داهات و داواکارییەکان بکە",
                    style: TextStyle(color: Colors.white70, fontSize: 10),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_left_rounded,
              color: Colors.white,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🏪 Vendor Banner
  // ═══════════════════════════════════════════════════════════
  Widget _buildVendorBanner() {
    final userName = AuthSessionManager.userName ?? 'بەکارهێنەر';

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFB300), Color(0xFFFF8F00)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB300).withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.storefront_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'بەخێربێیت بۆ پانێڵی بەڕێوەبردن 🏪',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  userName,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Error Banner
  // ═══════════════════════════════════════════════════════════
  Widget _buildErrorBanner(String message) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Colors.orange,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.orange,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Stats Section (Admin)
  // ═══════════════════════════════════════════════════════════
  Widget _buildStatsSection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('📊 ئامارە سەرەکییەکان', isDark),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildModernStatCard(
                "شوێنەکان",
                "$_totalStores",
                Icons.storefront_rounded,
                Colors.orange,
                isDark: isDark,
                onTap: () => _navigate(const AdminStoresScreen()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildModernStatCard(
                "فەرمانگەکان",
                "$_totalDepartments",
                Icons.business_rounded,
                const Color(0xFF10B981),
                isDark: isDark,
                onTap: () => _navigate(const AdminDepartmentsScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildModernStatCard(
                "سکاڵای چاوەڕوان",
                "$_pendingComplaints",
                Icons.assignment_late_rounded,
                Colors.red,
                isDark: isDark,
                onTap: () => _navigate(const AdminComplaintsProScreen()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildModernStatCard(
                "کۆی سکاڵاکان",
                "$_totalComplaints",
                Icons.assignment_rounded,
                Colors.pink,
                isDark: isDark,
                onTap: () => _navigate(const AdminComplaintsProScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildModernStatCard(
                "کاڵاکان",
                "$_totalProducts",
                Icons.shopping_bag_rounded,
                Colors.deepOrange,
                isDark: isDark,
                onTap: () => _navigate(const AdminStoresScreen()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildModernStatCard(
                "داواکاری ئەدمین",
                "$_pendingVendors",
                Icons.pending_actions_rounded,
                Colors.purple,
                isDark: isDark,
                onTap: () => _navigate(const AdminVendorRequestsScreen()),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Vendor Stats
  // ═══════════════════════════════════════════════════════════
  Widget _buildVendorStats(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('📊 ئاماری شوێنەکەم', isDark),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildModernStatCard(
                "کاڵاکان",
                "$_totalProducts",
                Icons.shopping_bag_rounded,
                Colors.deepOrange,
                isDark: isDark,
                onTap: () => _navigate(const AdminStoresScreen()),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildModernStatCard(
                "ئۆردەرەکان",
                "0",
                Icons.receipt_long_rounded,
                Colors.teal,
                isDark: isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📝 Section Title
  // ═══════════════════════════════════════════════════════════
  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w900,
        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 Stat Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildModernStatCard(
      String title,
      String value,
      IconData icon,
      Color color, {
        required bool isDark,
        VoidCallback? onTap,
      }) {
    final bgColor = color.withValues(alpha: isDark ? 0.20 : 0.10);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 95,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_left_rounded,
                    size: 18,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 1),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 Menu Tile
  // ═══════════════════════════════════════════════════════════
  Widget _buildMenuTile(
      String title,
      String subtitle,
      IconData icon,
      Color color,
      VoidCallback onTap, {
        required bool isDark,
      }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: isDark ? 0.20 : 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          color: isDark ? Colors.white54 : Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: isDark ? Colors.white54 : Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}