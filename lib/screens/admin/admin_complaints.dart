import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/translations.dart';
import '../../config/settings_provider.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../services/complaints_pdf_service.dart';
import '../../services/storage_service.dart';
import 'all_complaints_map.dart';
import 'complaint_details_pro_sheet.dart';
import 'complaint_filter_sheet.dart';

/// 📋 شاشەی بەڕێوەبردنی سکاڵاکان — ULTRA PRO
class AdminComplaintsProScreen extends StatefulWidget {
  const AdminComplaintsProScreen({super.key});

  @override
  State<AdminComplaintsProScreen> createState() =>
      _AdminComplaintsProScreenState();
}

class _AdminComplaintsProScreenState extends State<AdminComplaintsProScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  String _filter = 'all';
  String _sortBy = 'priority';
  String _q = '';
  List<Map<String, dynamic>> _complaints = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  bool _isDeleting = false;
  bool _generatingPdf = false;
  bool _isRefreshing = false;
  bool _selectMode = false;

  final TextEditingController _searchCtrl = TextEditingController();
  final ScrollController _scrollCtrl = ScrollController();
  final Set<String> _selectedIds = {};
  final Set<String> _hiddenIds = {};

  DateTime _fromDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _toDate = DateTime.now();
  String? _filterAuthority;
  Set<String> _filterStatuses = {};
  bool _onlyWithVoice = false;
  bool _onlyWithImages = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late AnimationController _staggerController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _tabController.addListener(_onTabChange);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _fetchComplaints();
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChange);
    _tabController.dispose();
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    _pulseController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  void _onTabChange() {
    // ✅ پشکنینی mounted بۆ ڕێگریکردن لە Error
    if (!mounted) return;

    // ✅ پشکنینی dispose بوونی TabController
    if (_tabController.indexIsChanging) return;

    // ✅ پشکنینی سنووری index
    final index = _tabController.index;
    if (index < 0 || index >= 5) return;

    const filters = ['all', 'pending', 'approved', 'completed', 'rejected'];

    // ✅ تەنها ئەگەر گۆڕانکاری هەبوو، setState بانگ بکە
    if (_filter != filters[index]) {
      setState(() => _filter = filters[index]);
      _applyFilters();
    }
  }

  Future<void> _fetchComplaints({bool showLoader = true}) async {
    if (!mounted) return;
    if (showLoader) setState(() => _loading = true);

    try {
      final res = await Supabase.instance.client
          .from('complaints')
          .select()
          .order('created_at', ascending: false)
          .limit(500);

      final complaints = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      // ✅ دۆزینەوەی ID ی ئەوانەی لە داتابەیس نەماون
      final fetchedIds = complaints.map((c) => c['id'].toString()).toSet();
      final idsToRemove = _hiddenIds
          .where((id) => !fetchedIds.contains(id))
          .toList();

      // ✅ پاککردنەوەی _hiddenIds لەوانەی نەماون
      _hiddenIds.removeAll(idsToRemove);

      // ✅ پاککردنەوەی _selectedIds لەوانەی نەماون
      _selectedIds.removeWhere((id) => !fetchedIds.contains(id));

      // ✅ ئەگەر هیچ هەڵبژێردراو نەما، _selectMode دابخە
      if (_selectedIds.isEmpty && _selectMode) {
        _selectMode = false;
      }

      // ✅ سنوور بۆ _hiddenIds — ئەگەر ١٠٠٠ تێپەڕی، بەتاڵی بکەرەوە
      if (_hiddenIds.length > 1000) {
        debugPrint('⚠️ _hiddenIds گەورە بوو — پاککردنەوە');
        _hiddenIds.clear();
      }

      if (mounted) {
        setState(() {
          _complaints = complaints;
          _loading = false;
          _isRefreshing = false;
        });
        _applyFilters();
        _staggerController.forward(from: 0);
      }
    } catch (e) {
      debugPrint('❌ Fetch error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _isRefreshing = false;
        });
      }
    }
  }

  void _applyFilters() {
    var list = List<Map<String, dynamic>>.from(_complaints);

    if (_filter != 'all') {
      if (_filter == 'approved') {
        list = list
            .where((c) =>
        c['status'] == 'approved' || c['status'] == 'in_progress')
            .toList();
      } else {
        list = list.where((c) => c['status'] == _filter).toList();
      }
    }

    if (_filterStatuses.isNotEmpty) {
      list = list
          .where((c) => _filterStatuses.contains(c['status']))
          .toList();
    }

    if (_filterAuthority != null) {
      list = list
          .where((c) => c['responsible_authority'] == _filterAuthority)
          .toList();
    }

    if (_onlyWithVoice) {
      list = list
          .where((c) =>
      c['voice_url'] != null &&
          c['voice_url'].toString().isNotEmpty)
          .toList();
    }

    if (_onlyWithImages) {
      list = list.where((c) {
        final imgs = c['images'];
        return imgs is List && imgs.isNotEmpty;
      }).toList();
    }

    if (_q.isNotEmpty) {
      list = list.where((c) {
        final text =
        "${c['title']}${c['description']}${c['responsible_authority']}"
            .toLowerCase();
        return text.contains(_q);
      }).toList();
    }

    switch (_sortBy) {
      case 'oldest':
        list.sort(_sortByDate);
        break;
      case 'priority':
        list.sort((a, b) {
          final pa = _priorityScore(a);
          final pb = _priorityScore(b);
          if (pa != pb) return pb.compareTo(pa);
          return _sortByDateDesc(a, b);
        });
        break;
      case 'newest':
      default:
        list.sort(_sortByDateDesc);
    }

    if (mounted) setState(() => _filtered = list);
  }

  int _sortByDate(Map<String, dynamic> a, Map<String, dynamic> b) {
    final da = DateTime.tryParse(a['created_at']?.toString() ?? '');
    final db = DateTime.tryParse(b['created_at']?.toString() ?? '');
    if (da == null || db == null) return 0;
    return da.compareTo(db);
  }

  int _sortByDateDesc(Map<String, dynamic> a, Map<String, dynamic> b) {
    return _sortByDate(b, a);
  }

  int _priorityScore(Map<String, dynamic> c) {
    int score = 0;
    final s = c['status']?.toString();
    if (s == 'pending') score += 100;
    if (s == 'in_progress') score += 60;

    final created = DateTime.tryParse(c['created_at']?.toString() ?? '');
    if (created != null) {
      final hours = DateTime.now().difference(created).inHours;
      if (hours < 6) score += 50;
      else if (hours < 24) score += 30;
      else if (hours < 72) score += 15;
    }

    final voice = c['voice_url']?.toString() ?? '';
    if (voice.isNotEmpty) score += 20;

    final imgs = c['images'];
    if (imgs is List && imgs.isNotEmpty) score += 10;

    return score;
  }

  int get _allCount => _complaints.length;
  int get _pendingCount =>
      _complaints.where((c) => c['status'] == 'pending').length;
  int get _approvedCount => _complaints
      .where((c) =>
  c['status'] == 'approved' || c['status'] == 'in_progress')
      .length;
  int get _rejectedCount =>
      _complaints.where((c) => c['status'] == 'rejected').length;
  int get _completedCount =>
      _complaints.where((c) => c['status'] == 'completed').length;

  double get _completionRate {
    if (_allCount == 0) return 0;
    return (_completedCount / _allCount) * 100;
  }

  Color _color(String? s) {
    switch (s) {
      case 'pending':
        return const Color(0xFFFF9800);
      case 'approved':
      case 'in_progress':
        return const Color(0xFF2ECC71);
      case 'rejected':
        return const Color(0xFFE74C3C);
      case 'completed':
        return const Color(0xFF3498DB);
      default:
        return Colors.grey;
    }
  }

  IconData _icon(String? s) {
    switch (s) {
      case 'pending':
        return Icons.hourglass_top_rounded;
      case 'approved':
      case 'in_progress':
        return Icons.verified_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _statusText(String? s) {
    switch (s) {
      case 'pending':
        return 'چاوەڕوان';
      case 'approved':
        return 'پەسەندکراو';
      case 'in_progress':
        return 'لە ئارادایە';
      case 'rejected':
        return 'ڕەتکراو';
      case 'completed':
        return 'جێبەجێکرا';
      default:
        return s ?? '';
    }
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr);
    if (date == null) return '';

    final diff = DateTime.now().difference(date);

    if (diff.inMinutes < 1) return 'ئێستا';
    if (diff.inMinutes < 60) return '${diff.inMinutes} خولەک لەمەوبەر';
    if (diff.inHours < 24) return '${diff.inHours} کاتژمێر لەمەوبەر';
    if (diff.inDays < 7) return '${diff.inDays} ڕۆژ لەمەوبەر';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} هەفتە لەمەوبەر';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} مانگ لەمەوبەر';
    return '${(diff.inDays / 365).floor()} ساڵ لەمەوبەر';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lang = context.watch<SettingsProvider>().languageId;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF4F6F9),
        body: _loading
            ? _buildSkeleton(isDark)
            : NestedScrollView(
          headerSliverBuilder: (context, inner) => [
            _buildSliverAppBar(isDark),
            _buildSliverTabBar(isDark),
            _buildSliverStats(isDark),
            _buildSliverSearch(isDark),
          ],
          body: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: () async {
              setState(() => _isRefreshing = true);
              await _fetchComplaints(showLoader: false);
            },
            child: TabBarView(
              controller: _tabController,
              children:
              List.generate(5, (i) => _buildList(isDark, lang)),
            ),
          ),
        ),
        floatingActionButton: _selectMode
            ? _buildBulkActionsFab(isDark)
            : _buildFilterFab(isDark),
      ),
    );
  }

  Widget _buildSliverAppBar(bool isDark) {
    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: const Color(0xFF0A0A0F),
      foregroundColor: Colors.white,
      elevation: 0,
      leading: _selectMode
          ? IconButton(
        icon: const Icon(Icons.close_rounded),
        onPressed: () {
          setState(() {
            _selectMode = false;
            _selectedIds.clear();
          });
        },
      )
          : null,
      title: _selectMode
          ? Text(
        '${_selectedIds.length} هەڵبژێردراو',
        style: const TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 16,
        ),
      )
          : null,
      actions: [
        if (!_selectMode) ...[
          IconButton(
            icon: const Icon(Icons.map_rounded),
            tooltip: 'نەخشە',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AllComplaintsMapScreen(),
                ),
              );
            },
          ),
          IconButton(
            icon: _generatingPdf
                ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
                : const Icon(Icons.picture_as_pdf_rounded),
            tooltip: 'ڕاپۆرتی PDF',
            onPressed: _generatingPdf ? null : _generatePdf,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            onSelected: (v) {
              switch (v) {
                case 'select':
                  setState(() => _selectMode = true);
                  break;
                case 'refresh':
                  _fetchComplaints(showLoader: false);
                  break;
                case 'sort':
                  _showSortSheet(isDark);
                  break;
              }
            },
            itemBuilder: (_) => [
              _popupItem(
                'select',
                'هەڵبژاردنی چەند',
                Icons.checklist_rounded,
              ),
              _popupItem('sort', 'ڕیزبەندکردن', Icons.sort_rounded),
              _popupItem('refresh', 'نوێکردنەوە', Icons.refresh_rounded),
            ],
          ),
        ] else ...[
          IconButton(
            icon: Icon(
              _selectedIds.length == _filtered.length
                  ? Icons.deselect_rounded
                  : Icons.select_all_rounded,
            ),
            onPressed: () {
              setState(() {
                if (_selectedIds.length == _filtered.length) {
                  _selectedIds.clear();
                } else {
                  _selectedIds.addAll(
                    _filtered.map((c) => c['id'].toString()),
                  );
                }
              });
            },
          ),
        ],
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0A0A0F), Color(0xFF1E1B2E)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE91E63), Color(0xFF9C27B0)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE91E63)
                              .withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.assignment_late_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'بەڕێوەبردنی سکاڵاکان',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              size: 12,
                              color: Color(0xFF4CAF50),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'ULTRA PRO • ADMIN',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF4CAF50),
                                fontWeight: FontWeight.w900,
                                letterSpacing: 1,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  PopupMenuItem<String> _popupItem(
      String value, String label, IconData icon) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverTabBar(bool isDark) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverTabBarDelegate(
        TabBar(
          controller: _tabController,
          isScrollable: true,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: Colors.transparent,
          tabs: [
            _buildTab('هەموو', _allCount, Icons.apps_rounded),
            _buildTab('چاوەڕوان', _pendingCount, Icons.hourglass_top_rounded),
            _buildTab('پەسەند', _approvedCount, Icons.verified_rounded),
            _buildTab('تەواو', _completedCount, Icons.check_circle_rounded),
            _buildTab('ڕەتکراو', _rejectedCount, Icons.cancel_rounded),
          ],
        ),
        isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF4F6F9),
      ),
    );
  }

  Tab _buildTab(String label, int count, IconData icon) {
    return Tab(
      height: 56,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$count',
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w900,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverStats(bool isDark) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _buildMiniStat(
                  'کۆی',
                  _allCount,
                  Icons.assignment_rounded,
                  const Color(0xFF6C5CE7),
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildMiniStat(
                  'چاوەڕوان',
                  _pendingCount,
                  Icons.hourglass_top_rounded,
                  const Color(0xFFFF9800),
                  isDark,
                ),
                const SizedBox(width: 8),
                _buildMiniStat(
                  'تەواو',
                  _completedCount,
                  Icons.check_circle_rounded,
                  const Color(0xFF3498DB),
                  isDark,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF10B981).withValues(alpha: 0.15),
                    const Color(0xFF10B981).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF10B981).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.trending_up_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ڕێژەی جێبەجێکردن',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              '${_completionRate.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFF10B981),
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '$_completedCount لە $_allCount',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
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
    );
  }

  Widget _buildMiniStat(
      String label, int value, IconData icon, Color color, bool isDark) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(height: 6),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w900,
                color: color,
                height: 1,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSliverSearch(bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1A1A22) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color:
                    Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) {
                  setState(() => _q = v.toLowerCase());
                  _applyFilters();
                },
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
                decoration: InputDecoration(
                  hintText: 'گەڕان بەدوای ناونیشان، وەسف، لایەن...',
                  hintStyle: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.primary,
                    size: 22,
                  ),
                  suffixIcon: _q.isNotEmpty
                      ? IconButton(
                    icon: const Icon(Icons.close_rounded, size: 18),
                    onPressed: () {
                      _searchCtrl.clear();
                      setState(() => _q = '');
                      _applyFilters();
                    },
                  )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.filter_alt_rounded,
                        size: 12,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_filtered.length} ئەنجام',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_sortBy != 'newest' ||
                    _filterAuthority != null ||
                    _filterStatuses.isNotEmpty ||
                    _onlyWithVoice ||
                    _onlyWithImages)
                  GestureDetector(
                    onTap: _clearAllFilters,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.filter_alt_off_rounded,
                            size: 12,
                            color: Colors.red,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'سڕینەوەی فلتەر',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _clearAllFilters() {
    _searchCtrl.clear();
    setState(() {
      _q = '';
      _sortBy = 'newest';
      _filterAuthority = null;
      _filterStatuses.clear();
      _onlyWithVoice = false;
      _onlyWithImages = false;
    });
    _applyFilters();
  }

  Widget _buildList(bool isDark, String lang) {
    if (_filtered.isEmpty) return _buildEmpty(isDark);

    return ListView.builder(
      controller: _scrollCtrl,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: _filtered.length,
      itemBuilder: (context, i) {
        final c = _filtered[i];
        if (_hiddenIds.contains(c['id'].toString())) {
          return const SizedBox.shrink();
        }
        return AnimatedBuilder(
          animation: _staggerController,
          builder: (context, child) {
            final delay = (i * 0.05).clamp(0.0, 1.0);
            final progress =
            ((_staggerController.value - delay) / 0.5).clamp(0.0, 1.0);
            return Transform.translate(
              offset: Offset(0, 30 * (1 - progress)),
              child: Opacity(opacity: progress, child: child),
            );
          },
          child: _buildCard(c, isDark, lang),
        );
      },
    );
  }

  Widget _buildCard(
      Map<String, dynamic> c, bool isDark, String lang) {
    final id = c['id'].toString();
    final status = c['status'] ?? 'pending';
    final color = _color(status);
    final icon = _icon(status);
    final statusText = _statusText(status);
    final priority = _priorityScore(c);
    final isSelected = _selectedIds.contains(id);
    final isPending = status == 'pending';
    final isInProgress = status == 'in_progress' || status == 'approved';

    List images = [];
    try {
      if (c['images'] is List) images = c['images'];
      else if (c['images'] is String) images = [c['images']];
    } catch (_) {}

    final voiceUrl = c['voice_url']?.toString() ?? '';
    final hasVoice = voiceUrl.isNotEmpty;
    final timeAgo = _timeAgo(c['created_at']?.toString());

    return GestureDetector(
      onLongPress: () {
        if (!_selectMode) {
          HapticFeedback.mediumImpact();
          setState(() {
            _selectMode = true;
            _selectedIds.add(id);
          });
        }
      },
      onTap: () {
        if (_selectMode) {
          HapticFeedback.selectionClick();
          setState(() {
            if (isSelected) {
              _selectedIds.remove(id);
              if (_selectedIds.isEmpty) _selectMode = false;
            } else {
              _selectedIds.add(id);
            }
          });
        } else {
          _showDetails(c);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 2.5)
              : isPending
              ? Border.all(
            color: color.withValues(alpha: 0.4),
            width: 1.5,
          )
              : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
            if (isPending && !isSelected)
              BoxShadow(
                color: color.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            if (isSelected)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Column(
          children: [
            if (isPending)
              Container(
                height: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      color.withValues(alpha: 0.3),
                      color,
                      color.withValues(alpha: 0.3),
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(20),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (_selectMode)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : (isDark
                                ? Colors.white38
                                : Colors.grey.shade400),
                            width: 2,
                          ),
                        ),
                        child: isSelected
                            ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 16,
                        )
                            : null,
                      ),
                    ),
                  if (priority >= 100 && !_selectMode)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, _) => Transform.scale(
                          scale: _pulseAnimation.value,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red.shade600,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color:
                                  Colors.red.withValues(alpha: 0.5),
                                  blurRadius: 8,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.priority_high_rounded,
                              color: Colors.white,
                              size: 12,
                            ),
                          ),
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: color.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, color: color, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(
                    timeAgo,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (images.isNotEmpty)
                    Hero(
                      tag: 'complaint_img_$id',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Stack(
                          children: [
                            OptimizedNetworkImage(
                              imageUrl: images.first.toString(),
                              width: 70,
                              height: 70,
                              fit: BoxFit.cover,
                            ),
                            if (images.length > 1)
                              Positioned(
                                bottom: 4,
                                left: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                    Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    '+${images.length - 1}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withValues(alpha: 0.2),
                            color.withValues(alpha: 0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: color.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Icon(icon, color: color, size: 30),
                    ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c['title'] ?? 'بێ ناونیشان',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A2E),
                            height: 1.3,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            if (hasVoice)
                              _buildTag(
                                'دەنگ',
                                Icons.mic_rounded,
                                const Color(0xFF1E88E5),
                              ),
                            if (c['responsible_authority'] != null)
                              _buildTag(
                                c['responsible_authority'].toString(),
                                Icons.account_balance_rounded,
                                Colors.indigo,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (!_selectMode)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF0F0F14)
                      : const Color(0xFFF8F9FA),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    if (isPending) ...[
                      Expanded(
                        child: _buildAction(
                          icon: Icons.check_circle_rounded,
                          label: 'پەسەند',
                          color: const Color(0xFF2ECC71),
                          onTap: () => _quickUpdate(c, 'in_progress'),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: _buildAction(
                          icon: Icons.cancel_rounded,
                          label: 'ڕەتکردنەوە',
                          color: const Color(0xFFE74C3C),
                          onTap: () => _quickUpdate(c, 'rejected'),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ] else if (isInProgress) ...[
                      Expanded(
                        child: _buildAction(
                          icon: Icons.check_circle_rounded,
                          label: 'تەواوکردن',
                          color: const Color(0xFF3498DB),
                          onTap: () => _quickUpdate(c, 'completed'),
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    _buildIconBtn(
                      Icons.visibility_rounded,
                      AppColors.primary,
                          () => _showDetails(c),
                    ),
                    const SizedBox(width: 6),
                    _buildIconBtn(
                      Icons.delete_rounded,
                      Colors.red,
                      _isDeleting ? null : () => _delete(c),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 3),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAction({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.8)],
          ),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIconBtn(IconData icon, Color color, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Icon(icon, color: color, size: 16),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(height: MediaQuery.sizeOf(context).height * 0.15),
        Center(
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(30),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.assignment_outlined,
                  size: 70,
                  color: isDark ? Colors.white24 : AppColors.primary,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'هیچ سکاڵایەک نەدۆزرایەوە',
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  color: isDark ? Colors.white70 : const Color(0xFF1A1A2E),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'لەم فلتەر و بەروارەدا هیچ ئەنجامێک نییە',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 20),
              if (_q.isNotEmpty ||
                  _filterAuthority != null ||
                  _filterStatuses.isNotEmpty)
                ElevatedButton.icon(
                  onPressed: _clearAllFilters,
                  icon: const Icon(Icons.filter_alt_off_rounded),
                  label: const Text('سڕینەوەی فلتەرەکان'),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 6,
      itemBuilder: (_, i) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        height: 160,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterFab(bool isDark) {
    return FloatingActionButton.extended(
      onPressed: () => _showFilterSheet(isDark),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.tune_rounded),
      label: const Text(
        'فلتەر',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }

  Widget _buildBulkActionsFab(bool isDark) {
    return FloatingActionButton.extended(
      onPressed: _showBulkActions,
      backgroundColor: Colors.red.shade600,
      foregroundColor: Colors.white,
      icon: const Icon(Icons.delete_sweep_rounded),
      label: Text(
        'سڕینەوە (${_selectedIds.length})',
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
    );
  }

  void _showFilterSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ComplaintFilterSheet(
        initialSortBy: _sortBy,
        initialFromDate: _fromDate,
        initialToDate: _toDate,
        initialAuthority: _filterAuthority,
        initialStatuses: _filterStatuses,
        onlyWithVoice: _onlyWithVoice,
        onlyWithImages: _onlyWithImages,
        complaints: _complaints,
        onApply: (result) {
          setState(() {
            _sortBy = result.sortBy;
            _fromDate = result.fromDate;
            _toDate = result.toDate;
            _filterAuthority = result.authority;
            _filterStatuses = result.statuses;
            _onlyWithVoice = result.onlyWithVoice;
            _onlyWithImages = result.onlyWithImages;
          });
          _applyFilters();
        },
      ),
    );
  }

  void _showSortSheet(bool isDark) {
    _showFilterSheet(isDark);
  }

  void _showDetails(Map<String, dynamic> c) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ComplaintDetailsProSheet(
        complaint: c,
        onStatusChanged: () => _fetchComplaints(showLoader: false),
      ),
    );
  }

  Future<void> _quickUpdate(
      Map<String, dynamic> c, String newStatus) async {
    try {
      await Supabase.instance.client
          .from('complaints')
          .update({'status': newStatus}).eq('id', c['id']);

      if (mounted) {
        setState(() => c['status'] = newStatus);
        _applyFilters();
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ گۆڕدرا بۆ: ${_statusText(newStatus)}'),
            backgroundColor: _color(newStatus),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('هەڵە: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('سڕینەوەی سکاڵا'),
            ],
          ),
          content: const Text(
            'ئایا دڵنیایت؟ هەموو وێنە و دەنگەکانیشی دەسڕدرێنەوە.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('نەخێر'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('بەڵێ، بسڕەوە'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;
    setState(() => _isDeleting = true);

    try {
      // ✅ سڕینەوە لە DB سەرەتا
      await Supabase.instance.client
          .from('complaints')
          .delete()
          .eq('id', c['id']);

      // ⭐ دوای DB، فایلەکان بسڕەوە
      try {
        await StorageService.deleteComplaintFiles(complaint: c);
      } catch (_) {}

      if (mounted) {
        setState(() {
          _hiddenIds.add(c['id'].toString());
          _complaints.removeWhere(
                (x) => x['id'].toString() == c['id'].toString(),
          );
        });
        _applyFilters();
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ سکاڵا سڕایەوە'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('هەڵە: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _showBulkActions() async {
    if (_selectedIds.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text('سڕینەوەی ${_selectedIds.length} سکاڵا'),
          content: const Text(
            'ئایا دڵنیایت لە سڕینەوەی هەموو ئەم سکاڵایانە؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('نەخێر'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('بەڵێ'),
            ),
          ],
        ),
      ),
    );

    if (ok != true) return;

    try {
      final ids = _selectedIds.toList();

      // ⭐ ١. کۆکردنەوەی داتای سکاڵاکان بۆ سڕینەوەی فایلەکان
      final complaintsToDelete = _complaints
          .where((c) => ids.contains(c['id'].toString()))
          .toList();

      // ⭐ ٢. سڕینەوە لە DB (بە یەکجار)
      await Supabase.instance.client
          .from('complaints')
          .delete()
          .inFilter('id', ids);

      // ⭐ ٣. سڕینەوەی فایلەکان (دوای DB)
      for (final c in complaintsToDelete) {
        try {
          await StorageService.deleteComplaintFiles(complaint: c);
        } catch (_) {}
      }

      if (mounted) {
        setState(() {
          _hiddenIds.addAll(ids);
          _complaints.removeWhere((c) => ids.contains(c['id'].toString()));
          _selectMode = false;
          _selectedIds.clear();
        });
        _applyFilters();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${ids.length} سکاڵا سڕانەوە'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('هەڵە: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _generatePdf() async {
    if (_generatingPdf) return;
    setState(() => _generatingPdf = true);
    try {
      if (_filtered.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('هیچ سکاڵایەک نییە'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      await ComplaintsPdfService.generateReport(
        context: context,
        complaints: _filtered,
        fromDate: _fromDate,
        toDate: _toDate,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('هەڵە: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _generatingPdf = false);
    }
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  final Color backgroundColor;

  _SliverTabBarDelegate(this.tabBar, this.backgroundColor);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return Container(color: backgroundColor, child: tabBar);
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate old) =>
      old.tabBar != tabBar || old.backgroundColor != backgroundColor;
}