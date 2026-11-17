// lib/screens/admin/admin_complaints.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../services/complaints_pdf_service.dart';
import '../../services/storage_service.dart';
import '../../services/whatsapp_complaint_service.dart';
import 'all_complaints_map.dart';
import 'complaint_details_pro_sheet.dart';
import 'complaint_filter_sheet.dart';
import '../../l10n/tr.dart';

part 'admin_complaints_ui.dart';
part 'admin_complaints_helpers.dart';

/// 📋 شاشەی بەڕێوەبردنی سکاڵاکان — ULTRA PRO MAX V4
class AdminComplaintsProScreen extends StatefulWidget {
  const AdminComplaintsProScreen({super.key});

  @override
  State<AdminComplaintsProScreen> createState() =>
      _AdminComplaintsProScreenState();
}

class _AdminComplaintsProScreenState extends State<AdminComplaintsProScreen>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
  static const List<String> _tabKeys = [
    'all',
    'pending',
    'approved',
    'completed',
    'rejected',
  ];
  static const int _fetchLimit = 500;
  static const Duration _overdueAfter = Duration(hours: 72);
  static const String _defaultSort = 'priority';

  late final TabController _tabController;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;
  late final AnimationController _staggerController;

  final TextEditingController _searchCtrl = TextEditingController();
  final Set<String> _selectedIds = {};

  List<Map<String, dynamic>> _complaints = [];
  List<String> _neighborhoods = [];

  // Cached derived data (rebuilt by _recompute)
  final Map<String, List<Map<String, dynamic>>> _tabLists = {
    for (final k in _tabKeys) k: <Map<String, dynamic>>[],
  };
  final Map<String, int> _scores = {};
  final Map<String, int> _nbCounts = {};
  int _allCount = 0;
  int _pendingCount = 0;
  int _approvedCount = 0;
  int _completedCount = 0;
  int _rejectedCount = 0;
  int _overdueCount = 0;

  bool _loading = true;
  bool _loadFailed = false;
  bool _isDeleting = false;
  bool _generatingPdf = false;
  bool _selectMode = false;

  // Filters
  String _sortBy = _defaultSort;
  String _q = '';
  String? _filterNeighborhood;
  String? _filterAuthority;
  Set<String> _filterStatuses = {};
  bool _onlyWithVoice = false;
  bool _onlyWithImages = false;
  bool _dateFilterActive = false;
  late DateTime _fromDate;
  late DateTime _toDate;
  late final DateTime _defaultFrom;

  Timer? _searchDebounce;
  Timer? _realtimeDebounce;
  RealtimeChannel? _channel;

  String get _currentTabKey => _tabKeys[_tabController.index];
  List<Map<String, dynamic>> get _currentList => _tabLists[_currentTabKey]!;

  bool get _hasActiveFilters =>
      _q.isNotEmpty ||
      _sortBy != _defaultSort ||
      _filterAuthority != null ||
      _filterStatuses.isNotEmpty ||
      _onlyWithVoice ||
      _onlyWithImages ||
      _filterNeighborhood != null ||
      _dateFilterActive;

  // ═══════════════════════════════════════════════════════════
  // 🔁 Lifecycle
  // ═══════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _defaultFrom = now.subtract(const Duration(days: 30));
    _fromDate = _defaultFrom;
    _toDate = now;

    _tabController = TabController(length: _tabKeys.length, vsync: this)
      ..addListener(_onTabChange);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fetchComplaints();
    _fetchNeighborhoods();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _realtimeDebounce?.cancel();
    if (_channel != null) {
      try {
        Supabase.instance.client.removeChannel(_channel!);
      } catch (_) {}
    }
    _tabController
      ..removeListener(_onTabChange)
      ..dispose();
    _searchCtrl.dispose();
    _pulseController.dispose();
    _staggerController.dispose();
    super.dispose();
  }

  void _onTabChange() {
    if (!mounted || _tabController.indexIsChanging) return;
    setState(() {}); // refresh "N results" + select-all target
  }

  // ═══════════════════════════════════════════════════════════
  // 📥 Fetch
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchNeighborhoods() async {
    try {
      final res = await Supabase.instance.client
          .from('neighborhoods')
          .select('name_ku')
          .order('name_ku');
      if (!mounted) return;
      setState(() {
        _neighborhoods = (res as List)
            .map((e) => e['name_ku']?.toString() ?? '')
            .where((s) => s.isNotEmpty)
            .toList();
        _recompute();
      });
    } catch (e) {
      debugPrint('⚠️ fetch neighborhoods error: $e');
    }
  }

  Future<void> _fetchComplaints({bool showLoader = true}) async {
    if (!mounted) return;
    if (showLoader) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }

    try {
      final res = await Supabase.instance.client
          .from('complaints')
          .select()
          .order('created_at', ascending: false)
          .limit(_fetchLimit);

      final complaints = (res as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      if (!mounted) return;
      final fetchedIds = complaints.map((c) => c['id'].toString()).toSet();

      setState(() {
        _complaints = complaints;
        _loading = false;
        _loadFailed = false;
        _selectedIds.removeWhere((id) => !fetchedIds.contains(id));
        if (_selectedIds.isEmpty) _selectMode = false;
        _recompute();
      });
      if (showLoader) _staggerController.forward(from: 0);
    } catch (e) {
      debugPrint('❌ Fetch error: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = _complaints.isEmpty;
      });
      if (_complaints.isNotEmpty) {
        _snack(tr('نوێکردنەوە سەرنەکەوت — ئینتەرنێت بپشکنە'),
            const Color(0xFFD9822B));
      }
    }
  }

  void _refilter() {
    if (!mounted) return;
    setState(_recompute);
  }

  double get _completionRate =>
      _allCount == 0 ? 0 : (_completedCount / _allCount) * 100;

  void _exitSelectMode() => setState(() {
        _selectMode = false;
        _selectedIds.clear();
      });

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget body;
    if (_loading && _complaints.isEmpty) {
      body = _buildSkeleton(isDark);
    } else if (_loadFailed) {
      body = _buildError(isDark);
    } else {
      body = NestedScrollView(
        headerSliverBuilder: (context, inner) => [
          _buildSliverAppBar(isDark),
          _buildSliverTabBar(isDark),
          _buildSliverStats(isDark),
          _buildSliverNeighborhoodFilter(isDark),
          _buildSliverSearch(isDark),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [for (final k in _tabKeys) _buildList(k, isDark)],
        ),
      );
    }

    return PopScope(
      canPop: !_selectMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selectMode) _exitSelectMode();
      },
      child: Directionality(
        textDirection: AppLang.direction,
        child: Scaffold(
          backgroundColor: _bg(isDark),
          body: body,
          floatingActionButton: (_loading && _complaints.isEmpty) || _loadFailed
              ? null
              : (_selectMode ? _buildBulkActionsFab() : _buildFilterFab()),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📱 AppBar
  // ═══════════════════════════════════════════════════════════
  Widget _buildSliverAppBar(bool isDark) {
    final list = _currentList;
    final allSelected = list.isNotEmpty &&
        list.every((c) => _selectedIds.contains('${c['id']}'));

    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: isDark ? const Color(0xFF1A1B2E) : AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      leading: _selectMode
          ? IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: _exitSelectMode,
            )
          : null,
      title: _selectMode
          ? Text(trf('{0} هەڵبژێردراو', [_ku(_selectedIds.length)]),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16))
          : null,
      actions: [
        if (!_selectMode) ...[
          IconButton(
            icon: const Icon(Icons.map_rounded),
            tooltip: tr('نەخشە'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AllComplaintsMapScreen()),
            ),
          ),
          IconButton(
            icon: _generatingPdf
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.picture_as_pdf_rounded),
            tooltip: tr('ڕاپۆرتی PDF'),
            onPressed: _generatingPdf ? null : _generatePdf,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert_rounded),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            onSelected: (v) {
              switch (v) {
                case 'select':
                  setState(() => _selectMode = true);
                  break;
                case 'refresh':
                  _fetchComplaints(showLoader: false);
                  break;
                case 'sort':
                  _showFilterSheet();
                  break;
              }
            },
            itemBuilder: (_) => [
              _popupItem('select', 'هەڵبژاردنی چەند', Icons.checklist_rounded),
              _popupItem('sort', 'ڕیزبەندکردن', Icons.sort_rounded),
              _popupItem('refresh', 'نوێکردنەوە', Icons.refresh_rounded),
            ],
          ),
        ] else
          IconButton(
            tooltip: allSelected ? tr('لابردنی هەڵبژاردن') : tr('هەموو'),
            icon: Icon(allSelected
                ? Icons.deselect_rounded
                : Icons.select_all_rounded),
            onPressed: () => setState(() {
              final ids = list.map((c) => c['id'].toString());
              if (allSelected) {
                _selectedIds.removeAll(ids);
              } else {
                _selectedIds.addAll(ids);
              }
            }),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? const [Color(0xFF1A1B2E), Color(0xFF232334)]
                  : const [Color(0xFF1565C0), Color(0xFF1E88E5)],
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
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: const Icon(Icons.assignment_late_rounded,
                        color: Colors.white, size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(tr('بەڕێوەبردنی سکاڵاکان'),
                            style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                                color: Colors.white)),
                        const SizedBox(height: 4),
                        Row(children: [
                          AnimatedBuilder(
                            animation: _pulseAnimation,
                            builder: (_, __) => Transform.scale(
                              scale: _pulseAnimation.value,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                    color: Color(0xFF0F9D7A),
                                    shape: BoxShape.circle),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(trf('{0} سکاڵای چاوەڕوان', [_ku(_pendingCount)]),
                              style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white70,
                                  fontWeight: FontWeight.w700)),
                        ]),
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

  // ═══════════════════════════════════════════════════════════
  // 🔎 Search
  // ═══════════════════════════════════════════════════════════
  Widget _buildSliverSearch(bool isDark) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(children: [
          Container(
            decoration: BoxDecoration(
              color: _surface(isDark),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onChanged: (v) {
                _searchDebounce?.cancel();
                _searchDebounce = Timer(const Duration(milliseconds: 250), () {
                  _q = v.trim().toLowerCase();
                  _refilter();
                });
                setState(() {}); // keeps the clear button in sync
              },
              style: TextStyle(color: isDark ? Colors.white : Colors.black87),
              decoration: InputDecoration(
                hintText: tr('گەڕان بەدوای ناونیشان، گەڕەک، لایەن...'),
                hintStyle: TextStyle(
                    fontSize: 12, color: isDark ? Colors.white54 : Colors.grey),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.primary, size: 22),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () {
                          _searchDebounce?.cancel();
                          _searchCtrl.clear();
                          _q = '';
                          _refilter();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(children: [
                const Icon(Icons.filter_alt_rounded,
                    size: 12, color: AppColors.primary),
                const SizedBox(width: 4),
                Text(trf('{0} ئەنجام', [_ku(_currentList.length)]),
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary)),
              ]),
            ),
            const Spacer(),
            if (_hasActiveFilters)
              GestureDetector(
                onTap: _clearAllFilters,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC3545).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.filter_alt_off_rounded,
                        size: 12, color: Color(0xFFDC3545)),
                    const SizedBox(width: 4),
                    Text(tr('سڕینەوەی فلتەر'),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFDC3545))),
                  ]),
                ),
              ),
          ]),
        ]),
      ),
    );
  }

  void _toggleSelect(String id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
      if (_selectedIds.isEmpty) _selectMode = false;
    });
  }

  Widget _buildCard(Map<String, dynamic> c, bool isDark) {
    final id = c['id'].toString();
    final status = c['status']?.toString() ?? 'pending';
    final color = _color(status);
    final icon = _icon(status);
    final priority = _scores[id] ?? 0;
    final isSelected = _selectedIds.contains(id);
    final isPending = status == 'pending';
    final isInProgress = status == 'in_progress' || status == 'approved';
    final overdue = _isOverdue(c);

    final nbName = c['neighborhood_name']?.toString();

    final List images = c['images'] is List
        ? c['images'] as List
        : (c['images'] is String && (c['images'] as String).isNotEmpty
            ? [c['images']]
            : const []);

    final hasVoice = (c['voice_url']?.toString() ?? '').isNotEmpty;
    final userPhone = (c['user_phone']?.toString() ??
            c['phone']?.toString() ??
            c['contact_phone']?.toString() ??
            '')
        .trim();
    // تێبینی: ئێمە چیتر پێویستمان بەمە نییە بۆ شاردنەوەی دوگمەکە، بەڵام بۆ پەیوەندی بەکاردێت
    final hasPhone = userPhone.isNotEmpty;
    final title = (c['title']?.toString().trim().isNotEmpty ?? false)
        ? c['title'].toString()
        : 'بێ ناونیشان';

    return GestureDetector(
      onLongPress: () {
        if (_selectMode) return;
        HapticFeedback.mediumImpact();
        setState(() {
          _selectMode = true;
          _selectedIds.add(id);
        });
      },
      onTap: () => _selectMode ? _toggleSelect(id) : _showDetails(c),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _surface(isDark),
          borderRadius: BorderRadius.circular(20),
          border: isSelected
              ? Border.all(color: AppColors.primary, width: 2.5)
              : isPending
                  ? Border.all(
                      color: (overdue ? const Color(0xFFDC3545) : color)
                          .withValues(alpha: 0.4),
                      width: 1.5)
                  : null,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.06),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
            if (isSelected)
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              if (_selectMode)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 8),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color:
                          isSelected ? AppColors.primary : Colors.transparent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : (isDark ? Colors.white38 : Colors.grey.shade400),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 16)
                        : null,
                  ),
                ),
              if (priority >= 100 && !_selectMode)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, _) => Transform.scale(
                      scale: _pulseAnimation.value,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red.shade600,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                                color: const Color(0xFFDC3545)
                                    .withValues(alpha: 0.5),
                                blurRadius: 8),
                          ],
                        ),
                        child: const Icon(Icons.priority_high_rounded,
                            color: Colors.white, size: 12),
                      ),
                    ),
                  ),
                ),
              _chip(_statusText(status), icon, color),
              if (overdue) ...[
                const SizedBox(width: 6),
                _chip('دواکەوتوو', Icons.warning_amber_rounded,
                    const Color(0xFFDC3545)),
              ],
              if (nbName != null && nbName.isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: _chip(
                      nbName, Icons.place_rounded, const Color(0xFF64748B),
                      maxWidth: 90),
                ),
              ],
              const Spacer(),
              Text(tr(_timeAgo(c['created_at']?.toString())),
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white54 : Colors.grey.shade600)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (images.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Stack(children: [
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
                                horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('+${_ku(images.length - 1)}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold)),
                          ),
                        ),
                    ]),
                  )
                else
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        color.withValues(alpha: 0.2),
                        color.withValues(alpha: 0.05),
                      ]),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: color.withValues(alpha: 0.3)),
                    ),
                    child: Icon(icon, color: color, size: 30),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr(title),
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 14,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1A1A2E),
                              height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        if (hasVoice)
                          _buildTag('دەنگ', Icons.mic_rounded,
                              const Color(0xFF64748B)),
                        if (hasPhone)
                          _buildTag(userPhone, Icons.phone_rounded,
                              const Color(0xFF64748B)),
                        if (c['responsible_authority'] != null)
                          _buildTag(
                              c['responsible_authority'].toString(),
                              Icons.account_balance_rounded,
                              const Color(0xFF64748B)),
                      ]),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!_selectMode)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF0F0F14) : const Color(0xFFF8F9FA),
                borderRadius:
                    const BorderRadius.vertical(bottom: Radius.circular(20)),
              ),
              child: Row(children: [
                if (isPending) ...[
                  Expanded(
                    child: _buildAction(
                      icon: Icons.check_circle_rounded,
                      label: tr('پەسەند'),
                      color: const Color(0xFF0F9D7A),
                      onTap: () => _quickUpdate(c, 'in_progress'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildAction(
                      icon: Icons.cancel_rounded,
                      label: tr('ڕەتکردنەوە'),
                      color: const Color(0xFFDC3545),
                      onTap: () => _quickUpdate(c, 'rejected'),
                    ),
                  ),
                  const SizedBox(width: 6),
                ] else if (isInProgress) ...[
                  Expanded(
                    child: _buildAction(
                      icon: Icons.check_circle_rounded,
                      label: tr('تەواوکردن'),
                      color: const Color(0xFF1E88E5),
                      onTap: () => _quickUpdate(c, 'completed'),
                    ),
                  ),
                  const SizedBox(width: 6),
                ] else
                  const Spacer(),
                _buildCardMenu(c, hasPhone),
              ]),
            ),
        ]),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // ⚡ Status updates (optimistic + undo)
  // ═══════════════════════════════════════════════════════════
  Future<void> _quickUpdate(Map<String, dynamic> c, String newStatus) async {
    final old = c['status']?.toString() ?? 'pending';
    if (old == newStatus) return;

    setState(() {
      c['status'] = newStatus;
      _recompute();
    });

    try {
      await Supabase.instance.client
          .from('complaints')
          .update({'status': newStatus}).eq('id', c['id']);
    } catch (e) {
      debugPrint('❌ quickUpdate error: $e');
      if (!mounted) return;
      setState(() {
        c['status'] = old;
        _recompute();
      });
      _snack(tr('گۆڕینی دۆخ سەرنەکەوت، دووبارە هەوڵبدەوە'),
          const Color(0xFFDC3545));
      return;
    }

    if (!mounted) return;
    HapticFeedback.mediumImpact();
    _snack(
      trf('✅ گۆڕدرا بۆ: {0}', [_statusText(newStatus)]),
      _color(newStatus),
      action: SnackBarAction(
        label: tr('گەڕاندنەوە'),
        textColor: Colors.white,
        onPressed: () => _revertStatus(c, old),
      ),
    );

    // 🟢 ناردنی بۆ واتسئاپ ئەگەر پەسەندکرا
    if (newStatus == 'in_progress') {
      await Future.delayed(const Duration(milliseconds: 300));
      if (!mounted) return;
      HapticFeedback.heavyImpact();
      await _shareComplaintToWhatsApp(c);
    }
  }

  Future<void> _revertStatus(Map<String, dynamic> c, String old) async {
    try {
      await Supabase.instance.client
          .from('complaints')
          .update({'status': old}).eq('id', c['id']);
      if (!mounted) return;
      setState(() {
        c['status'] = old;
        _recompute();
      });
    } catch (e) {
      debugPrint('❌ revert error: $e');
      _snack(tr('گەڕاندنەوە سەرنەکەوت'), const Color(0xFFDC3545));
    }
  }

  Future<void> _bulkSetStatus(String status) async {
    final ids = _selectedIds.toList();
    final previous = <String, String>{
      for (final c in _complaints)
        if (ids.contains(c['id'].toString()))
          c['id'].toString(): c['status']?.toString() ?? 'pending',
    };

    try {
      await Supabase.instance.client
          .from('complaints')
          .update({'status': status}).inFilter('id', ids);
    } catch (e) {
      debugPrint('❌ bulk status error: $e');
      _snack(tr('گۆڕین سەرنەکەوت، دووبارە هەوڵبدەوە'), const Color(0xFFDC3545));
      return;
    }

    if (!mounted) return;
    setState(() {
      for (final c in _complaints) {
        if (ids.contains(c['id'].toString())) c['status'] = status;
      }
      _selectMode = false;
      _selectedIds.clear();
      _recompute();
    });
    HapticFeedback.mediumImpact();
    _snack(
      trf('✅ {0} سکاڵا گۆڕدرا بۆ: {1}', [_ku(ids.length), _statusText(status)]),
      _color(status),
      action: SnackBarAction(
        label: tr('گەڕاندنەوە'),
        textColor: Colors.white,
        onPressed: () async {
          try {
            // group by previous status to restore each correctly
            final groups = <String, List<String>>{};
            previous.forEach((id, s) => (groups[s] ??= []).add(id));
            for (final e in groups.entries) {
              await Supabase.instance.client
                  .from('complaints')
                  .update({'status': e.key}).inFilter('id', e.value);
            }
            await _fetchComplaints(showLoader: false);
          } catch (_) {
            _snack(tr('گەڕاندنەوە سەرنەکەوت'), const Color(0xFFDC3545));
          }
        },
      ),
    );
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    if (_isDeleting) return;
    if (!await _confirm(
        'سڕینەوەی سکاڵا',
        'ئایا دڵنیایت؟ هەموو وێنە و دەنگەکانیشی دەسڕدرێنەوە و ناگەڕێتەوە.',
        'بەڵێ، بسڕەوە')) {
      return;
    }

    setState(() => _isDeleting = true);
    try {
      await Supabase.instance.client
          .from('complaints')
          .delete()
          .eq('id', c['id']);

      try {
        await StorageService.deleteComplaintFiles(complaint: c);
      } catch (e) {
        debugPrint('⚠️ file cleanup failed: $e');
      }

      if (!mounted) return;
      setState(() {
        _complaints
            .removeWhere((x) => x['id'].toString() == c['id'].toString());
        _selectedIds.remove(c['id'].toString());
        _recompute();
      });
      HapticFeedback.mediumImpact();
      _snack(tr('✅ سکاڵا سڕایەوە'), const Color(0xFF0F9D7A));
    } catch (e) {
      debugPrint('❌ delete error: $e');
      _snack(
          tr('سڕینەوە سەرنەکەوت، دووبارە هەوڵبدەوە'), const Color(0xFFDC3545));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _bulkDelete() async {
    if (_selectedIds.isEmpty || _isDeleting) return;
    final n = _selectedIds.length;
    if (!await _confirm(trf('سڕینەوەی {0} سکاڵا', [_ku(n)]),
        'ئایا دڵنیایت لە سڕینەوەی هەموو ئەم سکاڵایانە؟ ناگەڕێنەوە.', 'بەڵێ')) {
      return;
    }

    setState(() => _isDeleting = true);
    try {
      final ids = _selectedIds.toList();
      final toDelete =
          _complaints.where((c) => ids.contains(c['id'].toString())).toList();

      await Supabase.instance.client
          .from('complaints')
          .delete()
          .inFilter('id', ids);

      for (final c in toDelete) {
        try {
          await StorageService.deleteComplaintFiles(complaint: c);
        } catch (e) {
          debugPrint('⚠️ file cleanup failed: $e');
        }
      }

      if (!mounted) return;
      setState(() {
        _complaints.removeWhere((c) => ids.contains(c['id'].toString()));
        _selectMode = false;
        _selectedIds.clear();
        _recompute();
      });
      HapticFeedback.heavyImpact();
      _snack(trf('✅ {0} سکاڵا سڕانەوە', [_ku(ids.length)]),
          const Color(0xFF0F9D7A));
    } catch (e) {
      debugPrint('❌ bulk delete error: $e');
      _snack(
          tr('سڕینەوە سەرنەکەوت، دووبارە هەوڵبدەوە'), const Color(0xFFDC3545));
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📄 PDF
  // ═══════════════════════════════════════════════════════════
  Future<void> _generatePdf() async {
    if (_generatingPdf) return;
    final list = _currentList;
    if (list.isEmpty) {
      _snack(tr('هیچ سکاڵایەک نییە'), const Color(0xFFD9822B));
      return;
    }

    setState(() => _generatingPdf = true);
    try {
      await ComplaintsPdfService.generateReport(
        context: context,
        complaints: list,
        fromDate: _fromDate,
        toDate: _toDate,
      );
    } catch (e) {
      debugPrint('❌ pdf error: $e');
      _snack(tr('دروستکردنی PDF سەرنەکەوت'), const Color(0xFFDC3545));
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
  bool shouldRebuild(_SliverTabBarDelegate old) => true;
}
