// lib/screens/admin/admin_vendor_requests.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';

/// 👑 شاشەی داواکارییەکانی ئەدمین (Vendor Requests) — ULTRA PRO MAX
class AdminVendorRequestsScreen extends StatefulWidget {
  const AdminVendorRequestsScreen({super.key});

  @override
  State<AdminVendorRequestsScreen> createState() =>
      _AdminVendorRequestsScreenState();
}

class _AdminVendorRequestsScreenState extends State<AdminVendorRequestsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _approvedRequests = [];

  bool _isLoading = true;

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

  // ═══════════════════════════════════════════════════════════
  // 📡 هێنانی داتا لە Supabase
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      // ١. هێنانی ئەو داواکاریانەی چاوەڕوانی پەسەندکردنن
      // ⭐ گۆڕدرا بۆ is_approved و role = 'vendor'
      final pendingRes = await Supabase.instance.client
          .from('app_users')
          .select('*')
          .eq('is_approved', false)
          .eq('role', 'vendor')
          .order('created_at', ascending: false);

      // ٢. هێنانی ئەو ئەدمنانەی پەسەند کراون
      final approvedRes = await Supabase.instance.client
          .from('app_users')
          .select('*')
          .eq('is_approved', true)
          .eq('role', 'vendor')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _pendingRequests = List<Map<String, dynamic>>.from(pendingRes);
          _approvedRequests = List<Map<String, dynamic>>.from(approvedRes);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Fetch requests error: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar('هەڵە لە هێنانی داتا: $e', Colors.red);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✅ پەسەندکردن (Approve)
  // ═══════════════════════════════════════════════════════════
  Future<void> _approveRequest(int userId, String name) async {
    try {
      await Supabase.instance.client.from('app_users').update({
        'is_approved': true, // ⭐ چارەسەرکرا: ناوی کۆلۆمەکە گۆڕدرا
        'role': 'vendor',
      }).eq('id', userId);

      if (mounted) {
        _showSnackBar('بەڕێوبەرایەتی $name پەسەند کرا ✅', Colors.green);
        _fetchData(); // نوێکردنەوەی لیستەکە بۆ ئەوەی بچێتە تابی دووەم
      }
    } catch (e) {
      if (mounted) _showSnackBar('هەڵە لە پەسەندکردن: $e', Colors.red);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ❌ ڕەتکردنەوە (Reject)
  // ═══════════════════════════════════════════════════════════
  Future<void> _rejectRequest(int userId, String name) async {
    bool confirm = await _showConfirmDialog(
      'ڕەتکردنەوەی داواکاری',
      'ئایا دڵنیایت لە ڕەتکردنەوە یان سڕینەوەی داواکاری $name؟',
    );
    if (!confirm) return;

    try {
      await Supabase.instance.client
          .from('app_users')
          .delete()
          .eq('id', userId);

      if (mounted) {
        _showSnackBar('داواکاری $name ڕەتکرایەوە ❌', Colors.red);
        _fetchData();
      }
    } catch (e) {
      if (mounted) _showSnackBar('هەڵە لە ڕەتکردنەوە: $e', Colors.red);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 ڕووکار (UI)
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: const Text(
            'داواکاری ئەدمینەکان',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          backgroundColor: const Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: Column(
          children: [
            // ── تابی سەرەوە ──
            Container(
              color: const Color(0xFF1A1A2E),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Container(
                height: 45,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  labelColor: const Color(0xFF1A1A2E),
                  unselectedLabelColor: Colors.white70,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  indicatorSize: TabBarIndicatorSize.tab,
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.hourglass_empty, size: 16),
                          const SizedBox(width: 6),
                          Text('چاوەڕوانکراوەکان (${_pendingRequests.length})'),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified, size: 16),
                          const SizedBox(width: 6),
                          Text('پەسەندکراوەکان (${_approvedRequests.length})'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── ناوەڕۆک ──
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                controller: _tabController,
                children: [
                  _buildRequestList(_pendingRequests, isPending: true, isDark: isDark),
                  _buildRequestList(_approvedRequests, isPending: false, isDark: isDark),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── دروستکردنی لیستی داواکارییەکان ──
  Widget _buildRequestList(List<Map<String, dynamic>> requests, {required bool isPending, required bool isDark}) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPending ? Icons.check_circle_outline : Icons.inbox_rounded,
              size: 80,
              color: isPending ? Colors.green : Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isPending ? 'هیچ داواکارییەکی چاوەڕوانکراو نییە' : 'هیچ ئەدمینێکی پەسەندکراو نییە',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black87),
            ),
            const SizedBox(height: 8),
            Text(
              isPending ? 'هەموو داواکارییەکان پشکنین کراون' : 'لەم لیستەدا هیچ ئەدمینێک نییە',
              style: TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchData,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: requests.length,
        itemBuilder: (context, index) {
          final req = requests[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1A1A22) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isPending ? Colors.amber.shade200 : Colors.green.shade200,
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Column(
              children: [
                // ── سەرەوەی کارت ──
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isPending ? Colors.amber.shade50 : Colors.green.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.person_add_alt_1_rounded,
                        color: isPending ? Colors.amber.shade700 : Colors.green.shade700,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            req['name'] ?? 'بێ ناو',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: isDark ? Colors.white : Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.phone, size: 14, color: Colors.grey.shade500),
                              const SizedBox(width: 4),
                              Text(
                                req['phone'] ?? 'بێ ژمارە',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isPending ? Colors.amber.shade100 : Colors.green.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isPending ? 'چاوەڕوان' : 'پەسەندکراو',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isPending ? Colors.amber.shade800 : Colors.green.shade800,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 12),

                // ── دوگمەکان ──
                if (isPending)
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _rejectRequest(req['id'], req['name'] ?? ''),
                          icon: const Icon(Icons.close_rounded, size: 18),
                          label: const Text('ڕەتکردنەوە', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: () => _approveRequest(req['id'], req['name'] ?? ''),
                          icon: const Icon(Icons.check_rounded, size: 18),
                          label: const Text('پەسەندکردن', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green.shade600,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.verified_user_rounded, color: Colors.green, size: 18),
                        SizedBox(width: 8),
                        Text('ئەم بەکارهێنەرە پەسەندکراوە ✅', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  // ── دیالۆگی دڵنیابوونەوە ──
  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('نەخێر')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('بەڵێ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ) ??
        false;
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}