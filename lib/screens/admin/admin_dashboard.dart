import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import 'admin_stores.dart';
import 'admin_news.dart';
import 'admin_complaints.dart';
import 'admin_flash_sale.dart';
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
import 'super_admin_report.dart';

/// 👑 پانێڵی سەرەکی ئەدمین (Updated with all screens)
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _loading = true;
  int _totalStores = 0;
  int _totalProducts = 0;
  int _totalUsers = 0;
  int _pendingVendors = 0;
  int _pendingComplaints = 0;

  @override
  void initState() {
    super.initState();
    _fetchAllStats();
  }

  Future<void> _fetchAllStats() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final supa = Supabase.instance.client;
      final results = await Future.wait([
        supa.from('dukan').select('id'),
        supa.from('products').select('id'),
        supa.from('app_users').select('id, role, is_approved'),
        supa.from('complaints').select('id, status'),
      ]);

      final stores = List<Map<String, dynamic>>.from(results[0] as List);
      final products = List<Map<String, dynamic>>.from(results[1] as List);
      final users = List<Map<String, dynamic>>.from(results[2] as List);
      final complaints = List<Map<String, dynamic>>.from(results[3] as List);

      if (mounted) {
        setState(() {
          _totalStores = stores.length;
          _totalProducts = products.length;
          _totalUsers = users.length;
          _pendingVendors = users
              .where((u) =>
          u['role'] == 'vendor' && u['is_approved'] == false)
              .length;
          _pendingComplaints =
              complaints.where((c) => c['status'] == 'pending').length;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _navigate(Widget screen) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => screen),
    ).then((_) => _fetchAllStats());
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFF1A1A2E),
          title: const Text(
            "پانێڵی بەڕێوەبەر - Pro",
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: _fetchAllStats,
            ),
          ],
        ),
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(color: Color(0xFFE91E63)),
        )
            : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ═══════════════════════════════════════
            // 🤖 AI Chat Banner
            // ═══════════════════════════════════════
            InkWell(
              onTap: () => _navigate(const AdminAiChatScreen()),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
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
            ),
            const SizedBox(height: 18),

            // ═══════════════════════════════════════
            // 📊 ئامارە سەرەکییەکان
            // ═══════════════════════════════════════
            const Text(
              "ئامارە سەرەکییەکان",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildModernStatCard(
                    "شوێنە گشتیەکان",
                    "$_totalStores",
                    Icons.storefront_rounded,
                    Colors.orange,
                    Colors.orange.shade50,
                        () => _navigate(const AdminStoresScreen()),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildModernStatCard(
                    "سکاڵای چاوەڕوان",
                    "$_pendingComplaints",
                    Icons.assignment_late_rounded,
                    Colors.red,
                    Colors.red.shade50,
                        () => _navigate(const AdminComplaintsScreen()),
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
                    Colors.deepOrange.shade50,
                    null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildModernStatCard(
                    "داواکاری ئەدمین",
                    "$_pendingVendors",
                    Icons.pending_actions_rounded,
                    Colors.purple,
                    Colors.purple.shade50,
                        () => _navigate(const AdminVendorRequestsScreen()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),

            // ═══════════════════════════════════════
            // ⚡ بەشی گرنگ
            // ═══════════════════════════════════════
            const Text(
              "⚡ بەشی گرنگ",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),

            // 📋 سکاڵاکان
            _buildMenuTile(
              "بەڕێوەبردنی سکاڵاکان 📋",
              "بینین و جێبەجێکردنی سکاڵاکان",
              Icons.assignment_late_rounded,
              Colors.red,
                  () => _navigate(const AdminComplaintsScreen()),
            ),

            // 🗺️ نەخشەی سکاڵاکان
            _buildMenuTile(
              "نەخشەی گشتی سکاڵاکان 🗺️",
              "بینینی گشت سکاڵاکان لەسەر ماپ",
              Icons.map_rounded,
              Colors.redAccent,
                  () => _navigate(const AllComplaintsMapScreen()),
            ),

            // 📢 ڕێنماییەکانی سکاڵا
            _buildMenuTile(
              "بەڕێوەبردنی ڕێنماییەکانی سکاڵا 📢",
              "دەستکاری و گۆڕینی پۆپئاپی سکاڵا",
              Icons.announcement_rounded,
              Colors.deepOrange,
                  () =>
                  _navigate(const AdminComplaintInstructionsListScreen()),
            ),

            const SizedBox(height: 18),

            // ═══════════════════════════════════════
            // 📊 ڕاپۆرت
            // ═══════════════════════════════════════
            const Text(
              "ڕاپۆرت",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),

            _buildMenuTile(
              "ڕاپۆرتی پرۆ (Super Report) 📈",
              "شیکاری داهات و ئۆردەرەکان",
              Icons.insert_chart_rounded,
              Colors.deepPurple,
                  () => _navigate(const SuperAdminReportScreen()),
            ),



            const SizedBox(height: 18),

            // ═══════════════════════════════════════
            // 🏪 بەڕێوەبردنی شوێن
            // ═══════════════════════════════════════
            const Text(
              "بەڕێوەبردنی شوێن",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),

            _buildMenuTile(
              "بەڕێوەبردنی شوێنەکان 🏪",
              "سەرجەم شوێنە تۆمارکراوەکان",
              Icons.storefront_rounded,
              Colors.indigo,
                  () => _navigate(const AdminStoresScreen()),
            ),

            _buildMenuTile(
              "بەشە سەرەکی و ژێربەشەکان 🗂️",
              "زیادکردن و دەستکاری بەشەکان",
              Icons.category_rounded,
              Colors.purple,
                  () => _navigate(const AdminCategoriesManagementScreen()),
            ),

            const SizedBox(height: 18),

            // ═══════════════════════════════════════
            // 📰 ناوەڕۆک
            // ═══════════════════════════════════════
            const Text(
              "بەڕێوەبردنی ناوەڕۆک",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),

            _buildMenuTile(
              "بەڕێوەبردنی هەواڵ 📰",
              "زیادکردن و دەستکاری هەواڵەکان",
              Icons.post_add_rounded,
              Colors.green,
                  () => _navigate(const AdminNewsScreen()),
            ),

            _buildMenuTile(
              "بەڕێوەبردنی ڤیدیۆکان 🎬",
              "زیادکردن و دەستکاری ڤیدیۆکان",
              Icons.video_library_rounded,
              Colors.indigo,
                  () => _navigate(const AdminVideosScreen()),
            ),

            _buildMenuTile(
              "ڕێکخستنی سلایدەکان 🎨",
              "ڕێکخستن و گۆڕینی بانەرەکان",
              Icons.view_carousel_rounded,
              Colors.pink,
                  () => _navigate(const AdminReorderBannersScreen()),
            ),

            const SizedBox(height: 18),

            // ═══════════════════════════════════════
            // ⚡ خزمەتگوزارییەکان
            // ═══════════════════════════════════════
            const Text(
              "خزمەتگوزارییە ڕۆژانەکان",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),

            _buildMenuTile(
              "ناردنی ئاگاداری 🔔",
              "ناردنی ئاگاداری بۆ بەکارهێنەران",
              Icons.notifications_active_rounded,
              Colors.orange,
                  () => _navigate(const AdminNotificationsScreen()),
            ),

            _buildMenuTile(
              "سەرسوڕمانی ڕۆژ ⚡",
              "بەڕێوەبردنی ئۆفەری تایبەت",
              Icons.bolt_rounded,
              Colors.amber.shade800,
                  () => _navigate(const AdminFlashSaleScreen()),
            ),

            _buildMenuTile(
              "بەڕێوەبردنی کەشوهەوا 🌤️",
              "نوێکردنەوەی پلەی گەرما و دۆخ",
              Icons.cloud_rounded,
              Colors.lightBlue,
                  () => _navigate(const AdminWeatherScreen()),
            ),

            _buildMenuTile(
              "بەڕێوەبردنی سوتەمەنی ⛽",
              "نوێکردنەوەی نرخی بەنزین و گاز",
              Icons.local_gas_station_rounded,
              Colors.deepOrange,
                  () => _navigate(const AdminFuelScreen()),
            ),

            _buildMenuTile(
              "بەڕێوەبردنی دراوەکان 💵",
              "نوێکردنەوەی نرخی دۆلار و زێڕ",
              Icons.currency_exchange_rounded,
              Colors.green,
                  () => _navigate(const AdminCurrencyScreen()),
            ),

            const SizedBox(height: 18),

            // ═══════════════════════════════════════
            // ⚙️ ڕێکخستن
            // ═══════════════════════════════════════
            const Text(
              "ڕێکخستن و سیستەم",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 12),

            _buildMenuTile(
              "داواکاری ئەدمینەکان 👑",
              "پەسەندکردنی ئەدمینە نوێکان",
              Icons.admin_panel_settings_rounded,
              Colors.purple,
                  () => _navigate(const AdminVendorRequestsScreen()),
            ),

            _buildMenuTile(
              "تەیبڵەکانی سۆپابەیس 🗄️",
              "بینینی گشت خشتەکانی داتابەیس",
              Icons.table_chart_rounded,
              Colors.indigo,
                  () => _navigate(const AdminDatabaseViewerScreen()),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildModernStatCard(
      String title,
      String value,
      IconData icon,
      Color color,
      Color bgColor,
      VoidCallback? onTap,
      ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 95,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
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
                  const Icon(
                    Icons.chevron_left_rounded,
                    size: 18,
                    color: Colors.grey,
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
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
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
      VoidCallback onTap,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 10,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}