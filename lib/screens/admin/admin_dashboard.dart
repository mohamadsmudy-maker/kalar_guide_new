import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import 'admin_stores.dart';
import 'admin_news.dart';
import 'admin_complaints.dart' show AdminComplaintsProScreen;
import 'admin_videos.dart';
import 'admin_fuel.dart';
import 'admin_currency.dart';
import 'admin_banners.dart';
import 'admin_weather.dart';
import 'admin_ai_chat.dart';
import 'admin_notifications.dart';
import 'admin_categories_management.dart';
import 'admin_database_viewer.dart';
import 'all_complaints_map.dart';
import 'admin_complaint_instructions.dart';
import 'admin_vendor_requests.dart';
import 'admin_neighborhoods_screen.dart';
import 'admin_emergency_services_screen.dart';
import 'admin_events_screen.dart';
import 'admin_emergency_services_screen.dart';
/// 👑 پانێڵی بەڕێوەبردن — بە ٢ دۆخ: Admin + Vendor
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  int _totalStores = 0;
  int _totalProducts = 0;
  int _pendingVendors = 0;
  int _pendingComplaints = 0;

  @override
  void initState() {
    super.initState();
    _fetchAllStats();
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 هێنانی ئامارەکان
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchAllStats() async {
    if (!mounted) return;
    setState(() => _loading = true);

    try {
      final supa = Supabase.instance.client;

      final results = await Future.wait([
        supa.from('dukan').select('id').count(CountOption.exact),
        supa.from('products').select('id').count(CountOption.exact),
        supa
            .from('complaints')
            .select('id')
            .eq('status', 'pending')
            .count(CountOption.exact),
        supa
            .from('app_users')
            .select('id')
            .eq('role', 'vendor')
            .eq('is_approved', false)
            .count(CountOption.exact),
      ]);

      if (!mounted) return;

      setState(() {
        _totalStores = results[0].count ?? 0;
        _totalProducts = results[1].count ?? 0;
        _pendingComplaints = results[2].count ?? 0;
        _pendingVendors = results[3].count ?? 0;
        _loading = false;
      });
    } on PostgrestException catch (e) {
      debugPrint('❌ Postgrest error: ${e.message}');
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('❌ Unexpected error: $e');
      if (mounted) setState(() => _loading = false);
    }
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
          child: CircularProgressIndicator(
            color: Color(0xFFE91E63),
          ),
        )
            : RefreshIndicator(
          color: const Color(0xFFE91E63),
          onRefresh: _fetchAllStats,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ═══════════════════════════════════════
              // 🎯 بەشی ١: بۆ Admin
              // ═══════════════════════════════════════
              if (isAdmin) ...[
                _buildAiChatBanner(),
                const SizedBox(height: 18),
                _buildStatsSection(isDark),
                const SizedBox(height: 22),
              ],

              // ═══════════════════════════════════════
              // 🎯 بەشی ٢: بۆ Vendor
              // ═══════════════════════════════════════
              if (isVendorOnly) ...[
                _buildVendorBanner(),
                const SizedBox(height: 18),
                _buildVendorStats(isDark),
                const SizedBox(height: 22),
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

                // لە دوای _buildMenuTile ی "نەخشەی گشتی سکاڵاکان"

                _buildMenuTile(
                  "بەڕێوەبردنی فریاکەوتن 🚑",
                  "زیادکردن و دەستکاری ژمارەکانی فریاکەوتن",
                  Icons.emergency_rounded,
                  const Color(0xFFE53935),
                      () => _navigate(const AdminEmergencyServicesScreen()),
                  isDark: isDark,
                ),

                _buildMenuTile(
                  "بەڕێوەبردنی ڕووداوەکان 📅",
                  "زیادکردن و دەستکاری ڕووداوەکان",
                  Icons.event_rounded,
                  const Color(0xFF6C5CE7),
                      () => _navigate(const AdminEventsScreen()),
                  isDark: isDark,
                ),
                _buildMenuTile(
                  "بڵاوکردنەوەی هەواڵ 📰",
                  "زیادکردن و دەستکاریکردنی هەواڵ",
                  Icons.post_add_rounded,
                  Colors.green,
                      () => _navigate(const AdminNewsScreen()),
                  isDark: isDark,
                ),
                _buildMenuTile(
                  "دەستکاریکردنی هەواڵەکان ✏️",
                  "بینین و دەستکاریکردنی هەموو هەواڵەکان",
                  Icons.edit_note_rounded,
                  Colors.blue,
                      () => _navigate(const AdminNewsScreen()),
                  isDark: isDark,
                ),
                _buildMenuTile(
                  "زانیاری شوێنەکەم 🏪",
                  "بینین و دەستکاریکردنی زانیاری",
                  Icons.storefront_rounded,
                  Colors.orange,
                      () => _navigate(const AdminStoresScreen()),
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
                const SizedBox(height: 18),
              ],

              // ═══════════════════════════════════════
              // 🎯 بەشی ٣: بۆ Admin
              // ═══════════════════════════════════════
              if (isAdmin) ...[
                _buildSectionTitle('⚡ بەشی گرنگ', isDark),
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
                  "بەڕێوەبردنی ڕێنماییەکانی سکاڵا 📢",
                  "دەستکاری و گۆڕینی پۆپئاپی سکاڵا",
                  Icons.announcement_rounded,
                  Colors.deepOrange,
                      () => _navigate(
                    const AdminComplaintInstructionsListScreen(),
                  ),
                  isDark: isDark,
                ),
                const SizedBox(height: 18),

                _buildSectionTitle('🏪 بەڕێوەبردنی شوێن', isDark),
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
                  "بەشە سەرەکی و ژێربەشەکان 🗂️",
                  "زیادکردن و دەستکاری بەشەکان",
                  Icons.category_rounded,
                  Colors.purple,
                      () => _navigate(
                    const AdminCategoriesManagementScreen(),
                  ),
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
                const SizedBox(height: 18),

                _buildSectionTitle(
                  '⚡ خزمەتگوزارییە ڕۆژانەکان',
                  isDark,
                ),
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
                  "بەڕێوەبردنی کەشوهەوا 🌤️",
                  "نوێکردنەوەی پلەی گەرما و دۆخ",
                  Icons.cloud_rounded,
                  Colors.lightBlue,
                      () => _navigate(const AdminWeatherScreen()),
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
                const SizedBox(height: 18),

                _buildSectionTitle('⚙️ ڕێکخستن و سیستەم', isDark),
                const SizedBox(height: 12),
                _buildMenuTile(
                  "داواکاری ئەدمینەکان 👑",
                  "پەسەندکردنی ئەدمینە نوێکان",
                  Icons.admin_panel_settings_rounded,
                  Colors.purple,
                      () => _navigate(const AdminVendorRequestsScreen()),
                  isDark: isDark,
                ),
                _buildMenuTile(
                  "تەیبڵەکانی سۆپابەیس 🗄️",
                  "بینینی گشت خشتەکانی داتابەیس",
                  Icons.table_chart_rounded,
                  Colors.indigo,
                      () => _navigate(
                    const AdminDatabaseViewerScreen(),
                  ),
                  isDark: isDark,
                ),
              ],

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
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
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 10,
                    ),
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
                "شوێنە گشتیەکان",
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
                "سکاڵای چاوەڕوان",
                "$_pendingComplaints",
                Icons.assignment_late_rounded,
                Colors.red,
                isDark: isDark,
                onTap: () =>
                    _navigate(const AdminComplaintsProScreen()),
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
            padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
                          color:
                          isDark ? Colors.white : Colors.black87,
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