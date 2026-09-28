import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../widgets/common/optimized_network_image.dart';

/// 👑 شاشەی بەڕێوەبردنی ئەدمینەکان (Full Pro Version)
class AdminVendorRequestsScreen extends StatefulWidget {
  const AdminVendorRequestsScreen({super.key});

  @override
  State<AdminVendorRequestsScreen> createState() =>
      _AdminVendorRequestsScreenState();
}

class _AdminVendorRequestsScreenState extends State<AdminVendorRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingAdmins = [];
  List<Map<String, dynamic>> _approvedAdmins = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// 📥 هێنانی داتا لە سۆپابەیس
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('app_users')
            .select()
            .eq('role', 'vendor')
            .eq('is_approved', false)
            .order('created_at', ascending: false),
        Supabase.instance.client
            .from('app_users')
            .select()
            .eq('role', 'vendor')
            .eq('is_approved', true)
            .order('created_at', ascending: false),
      ]);

      if (mounted) {
        setState(() {
          _pendingAdmins = List<Map<String, dynamic>>.from(results[0] as List);
          _approvedAdmins = List<Map<String, dynamic>>.from(results[1] as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ هەڵە لە هێنانی داتا: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// ✅ پەسەندکردنی ئەدمین
  Future<void> _approveAdmin(Map<String, dynamic> user) async {
    try {
      await Supabase.instance.client
          .from('app_users')
          .update({'is_approved': true}).eq('id', user['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("✅ ${user['name']} ئەپڕۆڤ کرا و گواستراوەوە بۆ لیستی ئەدمینەکان"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchData(); // نوێکردنەوەی لیستەکە
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ هەڵە: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// 🗑 لابردنی دەسەڵات یان ڕەتکردنەوە
  Future<void> _deleteAdmin(Map<String, dynamic> user, bool isPending) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                isPending ? "ڕەتکردنەوەی داواکاری" : "لابردنی دەسەڵات",
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          content: Text(
            isPending
                ? "ئایا دڵنیایت لە ڕەتکردنەوەی داواکاری (${user['name']})؟"
                : "ئایا دڵنیایت لە لابردنی دەسەڵاتی ئەدمینی (${user['name']})؟",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("نەخێر", style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.delete_rounded, size: 18),
              label: const Text("بەڵێ", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ) ??
        false;

    if (!confirm) return;

    try {
      await Supabase.instance.client.from('app_users').delete().eq('id', user['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isPending ? "🗑 داواکاری ڕەتکرایەوە" : "🗑 دەسەڵات لابرا"),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        _fetchData(); // نوێکردنەوەی لیستەکە
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ هەڵە: $e"),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 180,
                pinned: true,
                backgroundColor: const Color(0xFF1E1B2E),
                foregroundColor: Colors.white,
                elevation: 0,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1E1B2E), Color(0xFF2D2A45)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.amber.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.amber, size: 24),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    "بەڕێوەبردنی ئەدمینەکان 👑",
                                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.white),
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
                bottom: PreferredSize(
                  preferredSize: const Size.fromHeight(60),
                  child: Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2))],
                      ),
                      labelColor: AppColors.primary,
                      unselectedLabelColor: Colors.white,
                      labelStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12),
                      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      tabs: const [
                        Tab(text: "چاوەڕوانکراوەکان ⏳"),
                        Tab(text: "پەسەندکراوەکان ✅"),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
          body: _isLoading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : TabBarView(
            controller: _tabController,
            children: [
              _buildPendingList(),
              _buildApprovedList(),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════
  // 1️⃣ لیستی چاوەڕوانکراوەکان
  // ═══════════════════════════════════════
  Widget _buildPendingList() {
    if (_pendingAdmins.isEmpty) {
      return _buildEmptyState(
        icon: Icons.check_circle_rounded,
        color: Colors.green,
        title: "هیچ داواکارییەکی چاوەڕوانکراو نییە ✅",
        subtitle: "هەموو داواکارییەکان پشکنین کراوە",
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingAdmins.length,
      itemBuilder: (context, i) => _buildPendingCard(_pendingAdmins[i]),
    );
  }

  Widget _buildPendingCard(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
        border: Border.all(color: Colors.orange.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.person_add_rounded, color: Colors.orange, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user['name'] ?? 'بێ ناو', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1A1A2E))),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.phone_rounded, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(user['phone'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                      ]),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: const Row(children: [
                    Icon(Icons.hourglass_top_rounded, color: Colors.orange, size: 12),
                    SizedBox(width: 4),
                    Text("چاوەڕوان", style: TextStyle(color: Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)),
                  ]),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      elevation: 0,
                    ),
                    onPressed: () => _approveAdmin(user),
                    icon: const Icon(Icons.check_circle_rounded, size: 18),
                    label: const Text("پەسەندکردن ✅", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () => _deleteAdmin(user, true),
                    icon: const Icon(Icons.cancel_rounded, size: 18),
                    label: const Text("ڕەتکردنەوە", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // 2️⃣ لیستی پەسەندکراوەکان
  // ═══════════════════════════════════════
  Widget _buildApprovedList() {
    if (_approvedAdmins.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline_rounded,
        color: Colors.grey,
        title: "هیچ ئەدمینێکی پەسەندکراو نییە 📭",
        subtitle: "لەم لیستەدا هیچ ئەدمینێک نییە",
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _approvedAdmins.length,
      itemBuilder: (context, i) {
        var adminUser = _approvedAdmins[i];
        // 🖼️ هێنانی وێنەی شوێن بەپێی ژمارەی مۆبایل
        return FutureBuilder<Map<String, dynamic>?>(
          future: Supabase.instance.client
              .from('dukan')
              .select()
              .eq('phone', adminUser['phone'])
              .maybeSingle(),
          builder: (ctx, storeSnap) {
            var store = storeSnap.data;
            return _buildApprovedCard(adminUser, store);
          },
        );
      },
    );
  }

  Widget _buildApprovedCard(Map<String, dynamic> adminUser, Map<String, dynamic>? store) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // 🖼️ وێنەی شوێن
                Container(
                  width: 55,
                  height: 55,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3), width: 2),
                  ),
                  child: ClipOval(
                    child: (store != null && store['image'] != null && store['image'].toString().isNotEmpty)
                        ? OptimizedNetworkImage(imageUrl: store['image'], width: 55, height: 55, fit: BoxFit.cover)
                        : Container(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      child: const Icon(Icons.verified_user_rounded, color: AppColors.primary, size: 26),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // 📝 زانیاری
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Flexible(
                          child: Text(
                            adminUser['name'] ?? 'بێ ناو',
                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1A1A2E)),
                            maxLines: 1, overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Icon(Icons.verified_rounded, color: Color(0xFF2ECC71), size: 16),
                      ]),
                      const SizedBox(height: 4),
                      Row(children: [
                        const Icon(Icons.phone_rounded, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(adminUser['phone'] ?? '', style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.bold)),
                      ]),
                      if (store != null) ...[
                        const SizedBox(height: 4),
                        Row(children: [
                          const Icon(Icons.storefront_rounded, size: 12, color: Colors.blue),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              store['name'] ?? '',
                              style: const TextStyle(fontSize: 11, color: Colors.blue, fontWeight: FontWeight.bold),
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ]),
                      ],
                    ],
                  ),
                ),
                // 🗑 دوگمەی لابردن
                GestureDetector(
                  onTap: () => _deleteAdmin(adminUser, false),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.block_rounded, color: Colors.red, size: 20),
                  ),
                ),
              ],
            ),
          ),
          if (store != null && store['address'] != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FA),
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(children: [
                const Icon(Icons.location_on_rounded, size: 14, color: Colors.amber),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    store['address'],
                    style: const TextStyle(fontSize: 11, color: Colors.black54, fontWeight: FontWeight.w600),
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════
  // 🎨 Helper
  // ═══════════════════════════════════════
  Widget _buildEmptyState({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(icon, size: 70, color: color),
          ),
          const SizedBox(height: 20),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF1A1A2E)), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600), textAlign: TextAlign.center),
        ],
      ),
    );
  }
}