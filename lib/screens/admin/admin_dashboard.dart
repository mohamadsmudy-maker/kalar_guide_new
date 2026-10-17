import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'admin_ai_chat.dart';
import 'admin_complaint_instructions.dart';
import 'admin_news.dart';
import 'admin_database_viewer.dart';
import 'admin_banners.dart';
import 'admin_videos.dart';

/// 👑 پانێڵی بەڕێوەبەر — ULTRA PRO V4
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
  bool _loading = true;
  int _onlineUsers = 0;
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  int _totalStores = 0;
  int _totalDepartments = 0;
  int _totalComplaints = 0;
  int _pendingComplaints = 0;
  int _pendingRequests = 0;
  int _totalProducts = 0;

  // ⭐ Stream subscription بۆ live users
  StreamSubscription<int>? _onlineSub;

  final Map<String, bool> _expandedSections = {
    'complaints': true,
    'stores': true,
    'daily': true,
    'system': true,
  };

  late AnimationController _headerController;
  late AnimationController _pulseController;
  late AnimationController _shimmerController;
  late AnimationController _entryController;
  late Animation<double> _headerAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

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
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..repeat();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _headerController.forward();
    _entryController.forward();
    _loadData();
    _watchLiveUsers();
  }

  @override
  void dispose() {
    // ⭐ Stream cancel بکە — لیکج نەمێنێت
    _onlineSub?.cancel();

    _headerController.dispose();
    _pulseController.dispose();
    _shimmerController.dispose();
    _entryController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _loading = true);

    try {
      final client = Supabase.instance.client;

      final results = await Future.wait([
        client.from('dukan').select('id').count(),
        client.from('departments').select('id').count(),
        client.from('complaints').select('id').count(),
        client.from('complaints').select('id').eq('status', 'pending').count(),
        client.from('app_users').select('id').eq('is_approved', false).count(),
        client.from('products').select('id').count(),
      ]);

      if (mounted) {
        setState(() {
          _totalStores = (results[0] as PostgrestResponse).count;
          _totalDepartments = (results[1] as PostgrestResponse).count;
          _totalComplaints = (results[2] as PostgrestResponse).count;
          _pendingComplaints = (results[3] as PostgrestResponse).count;
          _pendingRequests = (results[4] as PostgrestResponse).count;
          _totalProducts = (results[5] as PostgrestResponse).count;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Load stats error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  // ⭐ subscription پارێزراوە و لە dispose دا cancel دەکرێت
  void _watchLiveUsers() {
    try {
      _onlineSub = PresenceService.watchOnlineCount().listen(
            (count) {
          if (mounted) setState(() => _onlineUsers = count);
        },
        onError: (error) {
          debugPrint('⚠️ Live users stream error: $error');
        },
      );
    } catch (e) {
      debugPrint('⚠️ Live users setup error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAdmin = AuthSessionManager.isAdmin;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF0F4F9),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async {
            HapticFeedback.mediumImpact();
            _entryController.forward(from: 0);
            await _loadData();
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              _buildAppBar(isDark, isAdmin),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // ⭐ Loading indicator — بەکارهێنراوی _loading
                      AnimatedSize(
                        duration: const Duration(milliseconds: 300),
                        child: _loading
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
                            : const SizedBox.shrink(),
                      ),

                      _buildLiveUsersCard(isDark, itemIndex: 0),
                      const SizedBox(height: 12),
                      _buildAiChatCard(isDark, itemIndex: 1),
                      const SizedBox(height: 20),
                      _buildSectionHeader(
                        '📊 ئامارە سەرەکییەکان',
                        isDark,
                        itemIndex: 2,
                      ),
                      const SizedBox(height: 12),
                      _buildStatsGrid(isDark, isAdmin),
                      const SizedBox(height: 24),
                      _buildSearchBar(isDark),
                      const SizedBox(height: 16),
                      _buildSection(
                        id: 'complaints',
                        title: '🔥 بەشی گرنگ',
                        isDark: isDark,
                        items: _getComplaintsItems(context, isAdmin),
                        itemIndex: 10,
                      ),
                      _buildSection(
                        id: 'stores',
                        title: '🏪 بەڕێوەبردنی شوێن و فەرمانگە',
                        isDark: isDark,
                        items: _getStoresItems(context, isAdmin),
                        itemIndex: 15,
                      ),
                      _buildSection(
                        id: 'daily',
                        title: '⚡ خزمەتگوزارییە ڕۆژانەکان',
                        isDark: isDark,
                        items: _getDailyItems(context, isAdmin),
                        itemIndex: 20,
                      ),
                      _buildSection(
                        id: 'system',
                        title: '⚙️ ڕێکخستن و سیستەم',
                        isDark: isDark,
                        items: _getSystemItems(context, isAdmin),
                        itemIndex: 25,
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
  Widget _buildAppBar(bool isDark, bool isAdmin) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: const Color(0xFF1A1B2E),
      foregroundColor: Colors.white,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _loadData,
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
                  builder: (context, child) {
                    return Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                    );
                  },
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
                        builder: (context, child) {
                          return Transform.scale(
                            scale: 1.0 + (_pulseAnimation.value - 1.0) * 0.4,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    Color(0xFFFFD700),
                                    Color(0xFFFF8F00),
                                  ],
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
                          );
                        },
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
                            // ⭐ _headerAnimation بەکارهێنرا
                            FadeTransition(
                              opacity: _headerAnimation,
                              child: Row(
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'سیستەم چالاکە',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.white70,
                                      fontWeight: FontWeight.w600,
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
  // 🔴 Live Users Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildLiveUsersCard(bool isDark, {required int itemIndex}) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        final delay = (itemIndex * 0.08).clamp(0.0, 0.6);
        final progress =
        ((_entryController.value - delay) / 0.4).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - progress)),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminLiveUsersScreen(),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: 0.4),
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
                builder: (context, child) {
                  return Transform.scale(
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
                      child: const Icon(
                        Icons.people_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  );
                },
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
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white
                                    .withValues(alpha: 0.8),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_onlineUsers ئێستا لە خەتە',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
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
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🤖 AI Chat Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildAiChatCard(bool isDark, {required int itemIndex}) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        final delay = (itemIndex * 0.08).clamp(0.0, 0.6);
        final progress =
        ((_entryController.value - delay) / 0.4).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - progress)),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: GestureDetector(
        onTap: () {
          HapticFeedback.mediumImpact();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const AdminAiChatScreen(),
            ),
          );
        },
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5CF6), Color(0xFFE91E63)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
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
                    builder: (context, child) {
                      return Transform.scale(
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
                          child: const Icon(
                            Icons.auto_awesome_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'ڕاپۆرتی زیرەک بە چات',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'پرسبارە لەبارەی داتاکانت',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
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
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _shimmerController,
                  builder: (context, _) {
                    return Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
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
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
      String title,
      bool isDark, {
        required int itemIndex,
      }) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        final delay = (itemIndex * 0.08).clamp(0.0, 0.6);
        final progress =
        ((_entryController.value - delay) / 0.4).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(20 * (1 - progress), 0),
          child: Opacity(
            opacity: progress,
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
                    color: isDark
                        ? Colors.white
                        : const Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatsGrid(bool isDark, bool isAdmin) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 1.3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildStatCard(
          isDark: isDark,
          icon: Icons.storefront_rounded,
          label: 'شوێنەکان',
          value: _totalStores,
          color: const Color(0xFFF59E0B),
          itemIndex: 3,
        ),
        _buildStatCard(
          isDark: isDark,
          icon: Icons.business_rounded,
          label: 'فەرمانگەکان',
          value: _totalDepartments,
          color: const Color(0xFF10B981),
          itemIndex: 4,
        ),
        _buildStatCard(
          isDark: isDark,
          icon: Icons.report_rounded,
          label: 'کۆی سکاڵاکان',
          value: _totalComplaints,
          color: const Color(0xFFE91E63),
          itemIndex: 5,
        ),
        _buildStatCard(
          isDark: isDark,
          icon: Icons.hourglass_empty_rounded,
          label: 'سکاڵای چاوەڕوان',
          value: _pendingComplaints,
          color: const Color(0xFFEF4444),
          itemIndex: 6,
          isImportant: _pendingComplaints > 0,
        ),
        _buildStatCard(
          isDark: isDark,
          icon: Icons.assignment_ind_rounded,
          label: 'داوکاری ئەدمین',
          value: _pendingRequests,
          color: const Color(0xFF8B5CF6),
          itemIndex: 7,
          isImportant: _pendingRequests > 0,
        ),
        _buildStatCard(
          isDark: isDark,
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
    required bool isDark,
    required IconData icon,
    required String label,
    required int value,
    required Color color,
    required int itemIndex,
    bool isImportant = false,
  }) {
    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        final delay = (itemIndex * 0.08).clamp(0.0, 0.6);
        final progress =
        ((_entryController.value - delay) / 0.4).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 30 * (1 - progress)),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isImportant
                ? color.withValues(alpha: 0.5)
                : color.withValues(alpha: 0.15),
            width: isImportant ? 2 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
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
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
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
                    builder: (context, _) {
                      return Container(
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
                      );
                    },
                  ),
              ],
            ),
            const Spacer(),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1.0,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _searchQuery.isNotEmpty
              ? AppColors.primary.withValues(alpha: 0.4)
              : (isDark
              ? Colors.white.withValues(alpha: 0.06)
              : Colors.grey.shade200),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          const SizedBox(width: 14),
          const Icon(
            Icons.search_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              onChanged: (val) =>
                  setState(() => _searchQuery = val.trim()),
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black87,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              decoration: InputDecoration(
                hintText: 'گەڕان لە پانێڵ...',
                hintStyle: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.grey,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: Icon(
                Icons.close_rounded,
                size: 18,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
              onPressed: () {
                _searchCtrl.clear();
                setState(() => _searchQuery = '');
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildSection({
    required String id,
    required String title,
    required bool isDark,
    required List<Map<String, dynamic>> items,
    required int itemIndex,
  }) {
    final isExpanded = _expandedSections[id] ?? true;
    final filteredItems = _searchQuery.isEmpty
        ? items
        : items
        .where((item) => (item['title'] as String)
        .toLowerCase()
        .contains(_searchQuery.toLowerCase()))
        .toList();

    if (filteredItems.isEmpty && _searchQuery.isNotEmpty) {
      return const SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _entryController,
      builder: (context, child) {
        final delay = (itemIndex * 0.08).clamp(0.0, 0.6);
        final progress =
        ((_entryController.value - delay) / 0.4).clamp(0.0, 1.0);
        return Transform.translate(
          offset: Offset(0, 20 * (1 - progress)),
          child: Opacity(opacity: progress, child: child),
        );
      },
      child: Column(
        children: [
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _expandedSections[id] = !isExpanded);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.03)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                      AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${filteredItems.length}',
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
                      color: isDark
                          ? Colors.white54
                          : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: isExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: filteredItems.map((item) {
                return _buildItem(
                  isDark: isDark,
                  icon: item['icon'] as IconData,
                  iconColor: item['color'] as Color,
                  title: item['title'] as String,
                  subtitle: item['subtitle'] as String,
                  badge: item['badge'] as int?,
                  isImportant: item['isImportant'] == true,
                  onTap: item['onTap'] as VoidCallback,
                );
              }).toList(),
            ),
            secondChild: const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildItem({
    required bool isDark,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    int? badge,
    bool isImportant = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
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
              border: Border.all(
                color: isImportant
                    ? iconColor.withValues(alpha: 0.4)
                    : Colors.transparent,
                width: isImportant ? 1.5 : 0,
              ),
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
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        iconColor.withValues(alpha: 0.2),
                        iconColor.withValues(alpha: 0.08),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(13),
                    border: Border.all(
                      color: iconColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
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
                                color: iconColor,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: iconColor
                                        .withValues(alpha: 0.4),
                                    blurRadius: 6,
                                  ),
                                ],
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_left_rounded,
                  size: 20,
                  color: isDark ? Colors.white38 : Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 Items Lists
  // ═══════════════════════════════════════════════════════════
  List<Map<String, dynamic>> _getComplaintsItems(
      BuildContext context,
      bool isAdmin,
      ) {
    return [
      {
        'icon': Icons.assignment_rounded,
        'color': const Color(0xFFEF4444),
        'title': 'بەڕێوەبردنی سکاڵاکان',
        'subtitle': 'بینین و جێبەجێکردنی سکاڵاکان',
        'badge': _pendingComplaints,
        'isImportant': _pendingComplaints > 0,
        'onTap': () => _push(context, const AdminComplaintsProScreen()),
      },
      {
        'icon': Icons.map_rounded,
        'color': const Color(0xFFE91E63),
        'title': 'نەخشەی گشتی سکاڵاکان',
        'subtitle': 'بینینی گشت سکاڵاکان لەسەر نەخشە',
        'onTap': () => _push(context, const AllComplaintsMapScreen()),
      },
      {
        'icon': Icons.campaign_rounded,
        'color': const Color(0xFFF97316),
        'title': 'ڕێنماییەکانی سکاڵا',
        'subtitle': 'دەستکاری و گۆڕینی پۆپئاپی سکاڵا',
        'onTap': () => _push(
          context,
          const AdminComplaintInstructionsListScreen(),
        ),
      },
    ];
  }

  List<Map<String, dynamic>> _getStoresItems(
      BuildContext context,
      bool isAdmin,
      ) {
    return [
      {
        'icon': Icons.storefront_rounded,
        'color': const Color(0xFF3B82F6),
        'title': 'بەڕێوەبردنی شوێنەکان',
        'subtitle': 'سەرجەم شوێنە تۆمارکراوەکان',
        'badge': _totalStores,
        'onTap': () => _push(context, const AdminStoresScreen()),
      },
      {
        'icon': Icons.business_rounded,
        'color': const Color(0xFF10B981),
        'title': 'بەڕێوەبردنی فەرمانگەکان',
        'subtitle': 'زیادکردن و دەستکاری مامەڵەکانی فەرمانگەکان',
        'badge': _totalDepartments,
        'onTap': () => _push(context, const AdminDepartmentsScreen()),
      },
      {
        'icon': Icons.category_rounded,
        'color': const Color(0xFF8B5CF6),
        'title': 'بەشە سەرەکی و ژێربەشەکان',
        'subtitle': 'زیادکردن و دەستکاری بەشەکان',
        'onTap': () => _push(
          context,
          const AdminCategoriesManagementScreen(),
        ),
      },
      {
        'icon': Icons.location_city_rounded,
        'color': const Color(0xFF06B6D4),
        'title': 'بەڕێوەبردنی گەڕەکەکان',
        'subtitle': 'زیادکردن و دەستکاری گەڕەکانی کەلار',
        'onTap': () => _push(
          context,
          const AdminNeighborhoodsScreen(),
        ),
      },
      {
        'icon': Icons.newspaper_rounded,
        'color': const Color(0xFF6366F1),
        'title': 'بەڕێوەبردنی هەواڵ',
        'subtitle': 'زیادکردن و دەستکاری هەواڵەکان',
        'onTap': () => _push(context, const AdminNewsScreen()),
      },
      {
        'icon': Icons.slideshow_rounded,
        'color': const Color(0xFFE91E63),
        'title': 'ڕێکخستنی سلایدەکان',
        'subtitle': 'ڕێکخستن و گۆڕینی بانەرەکان',
        'onTap': () => _push(
          context,
          const AdminReorderBannersScreen(),
        ),
      },
      {
        'icon': Icons.video_library_rounded,
        'color': const Color(0xFF8B5CF6),
        'title': 'بەڕێوەبردنی ڤیدیۆکان',
        'subtitle': 'زیادکردن و دەستکاری ڤیدیۆکان',
        'onTap': () => _push(context, const AdminVideosScreen()),
      },
      {
        'icon': Icons.event_rounded,
        'color': const Color(0xFF6C5CE7),
        'title': 'ڕووداوەکان',
        'subtitle': 'زیادکردن و دەستکاری ڕووداوەکان',
        'onTap': () => _push(context, const AdminEventsScreen()),
      },
    ];
  }

  List<Map<String, dynamic>> _getDailyItems(
      BuildContext context,
      bool isAdmin,
      ) {
    return [
      {
        'icon': Icons.emergency_rounded,
        'color': const Color(0xFFDC2626),
        'title': 'بەڕێوەبردنی فریاکەوتن',
        'subtitle': 'ژمارەکانی فریاکەوتن',
        'onTap': () => _push(
          context,
          const AdminEmergencyServicesScreen(),
        ),
      },
      {
        'icon': Icons.local_gas_station_rounded,
        'color': const Color(0xFFFFD700),
        'title': 'بەڕێوەبردنی سووتەمەنی',
        'subtitle': 'نوێکردنەوەی نرخی بەنزین و گاز',
        'onTap': () => _push(
          context,
          const AdminFuelStationsScreen(),
        ),
      },
      {
        'icon': Icons.attach_money_rounded,
        'color': const Color(0xFF10B981),
        'title': 'بەڕێوەبردنی دراوەکان',
        'subtitle': 'نوێکردنەوەی نرخی دۆلار و زێڕ',
        'onTap': () => _push(
          context,
          const AdminCurrencyStationsScreen(),
        ),
      },
      {
        'icon': Icons.cloud_rounded,
        'color': const Color(0xFF3B82F6),
        'title': 'بەڕێوەبردنی کەشوهەوا',
        'subtitle': 'نوێکردنەوەی پلەی گەرما و دۆخ',
        'onTap': () => _push(context, const AdminWeatherScreen()),
      },
    ];
  }

  List<Map<String, dynamic>> _getSystemItems(
      BuildContext context,
      bool isAdmin,
      ) {
    return [
      {
        'icon': Icons.notifications_active_rounded,
        'color': const Color(0xFFF59E0B),
        'title': 'ناردنی ئاگاداری',
        'subtitle': 'ناردنی ئاگاداری بۆ بەکارهێنەران',
        'onTap': () => _push(
          context,
          const AdminNotificationsScreen(),
        ),
      },
      {
        'icon': Icons.assignment_ind_rounded,
        'color': const Color(0xFF8B5CF6),
        'title': 'داوکاری ئەدمینەکان',
        'subtitle': 'پەسەندکردنی ئەدمینە نوێکان',
        'badge': _pendingRequests,
        'isImportant': _pendingRequests > 0,
        'onTap': () => _push(
          context,
          const AdminVendorRequestsScreen(),
        ),
      },
      {
        'icon': Icons.storage_rounded,
        'color': const Color(0xFF3B82F6),
        'title': 'خشتەکانی داتابەیس',
        'subtitle': 'بینینی گشت خشتەکانی داتابەیس',
        'onTap': () => _push(
          context,
          const AdminDatabaseViewerScreen(),
        ),
      },
    ];
  }

  void _push(BuildContext context, Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }
}