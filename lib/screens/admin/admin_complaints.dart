// lib/screens/admin/admin_complaints.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

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

  static const List<Color> _neighborhoodColors = [
    Color(0xFF2196F3), Color(0xFF4CAF50), Color(0xFFFF9800),
    Color(0xFF9C27B0), Color(0xFFF44336), Color(0xFF009688),
    Color(0xFFE91E63), Color(0xFF3F51B5), Color(0xFFFFC107),
    Color(0xFF00BCD4), Color(0xFF8BC34A), Color(0xFFFF5722),
  ];

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
  // 📡 Realtime (auto refresh when anything changes)
  // ═══════════════════════════════════════════════════════════
  void _subscribeRealtime() {
    try {
      _channel = Supabase.instance.client
          .channel('admin-complaints-live')
          .onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'complaints',
        callback: (_) {
          _realtimeDebounce?.cancel();
          _realtimeDebounce = Timer(const Duration(milliseconds: 1500), () {
            if (mounted && !_loading) _fetchComplaints(showLoader: false);
          });
        },
      )
          .subscribe();
    } catch (e) {
      debugPrint('⚠️ realtime unavailable: $e');
    }
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
        _snack(tr('نوێکردنەوە سەرنەکەوت — ئینتەرنێت بپشکنە'), Colors.orange);
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🟢 WhatsApp Sharing with All Details
  // ═══════════════════════════════════════════════════════════
  Future<void> _shareComplaintToWhatsApp(Map<String, dynamic> c) async {
    final title = c['title'] ?? 'بێ ناونیشان';
    final desc = c['description'] ?? 'بێ وەسف';
    final authority = c['responsible_authority'] ?? 'نەزانراو';
    final neighborhood = c['neighborhood_name'] ?? 'نەزانراو';

    // 📍 لۆکەیشن
    final lat = c['latitude'];
    final lng = c['longitude'];
    String locationText = 'شوێن تۆمار نەکراوە';
    if (lat != null && lng != null) {
      locationText = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    }

    // 🎙️ ڤۆیس
    final voiceUrl = c['voice_url']?.toString() ?? '';
    String voiceText = voiceUrl.isNotEmpty ? voiceUrl : 'دەنگی بۆ نەنێردراوە';

    // 🖼️ وێنەکان
    final List images = c['images'] is List
        ? c['images'] as List
        : (c['images'] is String && (c['images'] as String).isNotEmpty ? [c['images']] : []);

    String imagesText = '';
    if (images.isNotEmpty) {
      for (int i = 0; i < images.length; i++) {
        imagesText += trf('🖼️ وێنەی {0}: {1}\n', [i + 1, images[i]]);
      }
    } else {
      imagesText = 'هیچ وێنەیەک نییە\n';
    }

    // ✍️ دروستکردنی پەیامەکە بە شێوەیەکی جوان
    final message = '''
🔔 *سکاڵا* 🔔

📌 *ناونیشان:* $title
📝 *وەسف:* $desc
🏢 *لایەنی پەیوەندیدار:* $authority
📍 *گەڕەک:* $neighborhood

🗺️ *لینکی شوێن:*
$locationText

🎙️ *لینکی دەنگ:*
$voiceText

$imagesText
''';

    // ✅ چاککردنی لینک بۆ ئەوەی لە هەموو ئامێرەکان کار بکات
    final Uri whatsappUri = Uri.parse(
        "https://wa.me/?text=${Uri.encodeComponent(message)}"
    );

    try {
      if (!await launchUrl(whatsappUri, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch WhatsApp';
      }
    } catch (e) {
      _snack(tr('⚠️ نەتوانرا واتسئاپ بکرێتەوە. دڵنیابە واتسئاپ دامەزراوە.'), Colors.red);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 Filtering / sorting (pure, cached per tab)
  // ═══════════════════════════════════════════════════════════
  DateTime? _created(Map<String, dynamic> c) =>
      DateTime.tryParse(c['created_at']?.toString() ?? '')?.toLocal();

  int _priorityScore(Map<String, dynamic> c) {
    var score = 0;
    final s = c['status']?.toString();
    if (s == 'pending') score += 100;
    if (s == 'in_progress') score += 60;

    final created = _created(c);
    if (created != null) {
      final hours = DateTime.now().difference(created).inHours;
      if (hours < 6) {
        score += 50;
      } else if (hours < 24) {
        score += 30;
      } else if (hours < 72) {
        score += 15;
      }
    }
    if ((c['voice_url']?.toString() ?? '').isNotEmpty) score += 20;
    if (c['images'] is List && (c['images'] as List).isNotEmpty) score += 10;
    return score;
  }

  bool _isOverdue(Map<String, dynamic> c) {
    if (c['status'] != 'pending') return false;
    final created = _created(c);
    return created != null &&
        DateTime.now().difference(created) > _overdueAfter;
  }

  bool _matchesTab(Map<String, dynamic> c, String key) {
    final s = c['status']?.toString();
    switch (key) {
      case 'all':
        return true;
      case 'approved':
        return s == 'approved' || s == 'in_progress';
      default:
        return s == key;
    }
  }

  bool _matchesCommon(Map<String, dynamic> c) {
    if (_filterStatuses.isNotEmpty && !_filterStatuses.contains(c['status'])) {
      return false;
    }
    if (_filterAuthority != null &&
        c['responsible_authority'] != _filterAuthority) {
      return false;
    }
    if (_filterNeighborhood != null &&
        c['neighborhood_name'] != _filterNeighborhood) {
      return false;
    }
    if (_onlyWithVoice && (c['voice_url']?.toString() ?? '').isEmpty) {
      return false;
    }
    if (_onlyWithImages) {
      final imgs = c['images'];
      if (!(imgs is List && imgs.isNotEmpty)) return false;
    }
    if (_dateFilterActive) {
      final d = _created(c);
      if (d == null) return false;
      final from = DateTime(_fromDate.year, _fromDate.month, _fromDate.day);
      final to =
      DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);
      if (d.isBefore(from) || d.isAfter(to)) return false;
    }
    if (_q.isNotEmpty) {
      final text =
      "${c['title']} ${c['description']} ${c['responsible_authority']} ${c['neighborhood_name']}"
          .toLowerCase();
      if (!text.contains(_q)) return false;
    }
    return true;
  }

  int _cmpDate(Map<String, dynamic> a, Map<String, dynamic> b) {
    final da = _created(a);
    final db = _created(b);
    if (da == null || db == null) return 0;
    return da.compareTo(db);
  }

  /// Rebuilds every cached value. Call inside setState.
  void _recompute() {
    _allCount = _complaints.length;
    _pendingCount = 0;
    _approvedCount = 0;
    _completedCount = 0;
    _rejectedCount = 0;
    _overdueCount = 0;
    _nbCounts.clear();
    _scores.clear();

    for (final c in _complaints) {
      switch (c['status']) {
        case 'pending':
          _pendingCount++;
          break;
        case 'approved':
        case 'in_progress':
          _approvedCount++;
          break;
        case 'completed':
          _completedCount++;
          break;
        case 'rejected':
          _rejectedCount++;
          break;
      }
      if (_isOverdue(c)) _overdueCount++;
      final nb = c['neighborhood_name']?.toString();
      if (nb != null && nb.isNotEmpty) {
        _nbCounts[nb] = (_nbCounts[nb] ?? 0) + 1;
      }
      _scores[c['id'].toString()] = _priorityScore(c);
    }

    final common = _complaints.where(_matchesCommon).toList();

    int cmp(Map<String, dynamic> a, Map<String, dynamic> b) {
      switch (_sortBy) {
        case 'oldest':
          return _cmpDate(a, b);
        case 'priority':
          final pa = _scores[a['id'].toString()] ?? 0;
          final pb = _scores[b['id'].toString()] ?? 0;
          if (pa != pb) return pb.compareTo(pa);
          return _cmpDate(b, a);
        default:
          return _cmpDate(b, a);
      }
    }

    for (final key in _tabKeys) {
      _tabLists[key] = common.where((c) => _matchesTab(c, key)).toList()
        ..sort(cmp);
    }
  }

  void _refilter() {
    if (!mounted) return;
    setState(_recompute);
  }

  double get _completionRate =>
      _allCount == 0 ? 0 : (_completedCount / _allCount) * 100;

  // ═══════════════════════════════════════════════════════════
  // 🎨 Helpers
  // ═══════════════════════════════════════════════════════════
  String _ku(Object n) => n.toString().replaceAllMapped(
    RegExp(r'\d'),
        (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)],
  );

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

  Color _neighborhoodColor(String? name) {
    if (name == null) return Colors.grey;
    final idx = _neighborhoods.indexOf(name);
    if (idx < 0) return Colors.grey;
    return _neighborhoodColors[idx % _neighborhoodColors.length];
  }

  String _timeAgo(String? dateStr) {
    if (dateStr == null) return '';
    final date = DateTime.tryParse(dateStr)?.toLocal();
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'ئێستا';
    if (diff.inMinutes < 60) return trf('{0} خولەک لەمەوبەر', [_ku(diff.inMinutes)]);
    if (diff.inHours < 24) return trf('{0} کاتژمێر لەمەوبەر', [_ku(diff.inHours)]);
    if (diff.inDays < 7) return trf('{0} ڕۆژ لەمەوبەر', [_ku(diff.inDays)]);
    if (diff.inDays < 30) {
      return trf('{0} هەفتە لەمەوبەر', [_ku((diff.inDays / 7).floor())]);
    }
    if (diff.inDays < 365) {
      return trf('{0} مانگ لەمەوبەر', [_ku((diff.inDays / 30).floor())]);
    }
    return trf('{0} ساڵ لەمەوبەر', [_ku((diff.inDays / 365).floor())]);
  }

  void _snack(String msg, Color color, {SnackBarAction? action}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content:
          Text(tr(msg), style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: Duration(seconds: action == null ? 2 : 5),
          action: action,
        ),
      );
  }

  Color _bg(bool isDark) =>
      isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF4F6F9);
  Color _surface(bool isDark) =>
      isDark ? const Color(0xFF1A1A22) : Colors.white;

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
    final allSelected =
        list.isNotEmpty && list.every((c) => _selectedIds.contains('${c['id']}'));

    return SliverAppBar(
      expandedHeight: 140,
      pinned: true,
      backgroundColor: const Color(0xFF0A0A0F),
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
                          color: const Color(0xFFE91E63).withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
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
                                    color: Color(0xFF4CAF50),
                                    shape: BoxShape.circle),
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(tr('ڕاستەوخۆ • گەڕەک • WHATSAPP'),
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF4CAF50),
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1)),
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

  PopupMenuItem<String> _popupItem(String value, String label, IconData icon) {
    return PopupMenuItem(
      value: value,
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(tr(label),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
      ]),
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
          Text(tr(label)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(tr(_ku(count)),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary)),
          ),
        ],
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
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.filter_alt_off_rounded,
                        size: 12, color: Colors.red),
                    const SizedBox(width: 4),
                    Text(tr('سڕینەوەی فلتەر'),
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.red)),
                  ]),
                ),
              ),
          ]),
        ]),
      ),
    );
  }

  void _clearAllFilters() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    _q = '';
    _sortBy = _defaultSort;
    _filterAuthority = null;
    _filterNeighborhood = null;
    _filterStatuses = {};
    _onlyWithVoice = false;
    _onlyWithImages = false;
    _dateFilterActive = false;
    _fromDate = _defaultFrom;
    _toDate = DateTime.now();
    _refilter();
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
    final nbColor = _neighborhoodColor(nbName);

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
              color: (overdue ? Colors.red : color)
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
          if (isPending)
            Container(
              height: 4,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  (overdue ? Colors.red : color).withValues(alpha: 0.3),
                  overdue ? Colors.red : color,
                  (overdue ? Colors.red : color).withValues(alpha: 0.3),
                ]),
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
              ),
            ),
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
                      color: isSelected ? AppColors.primary : Colors.transparent,
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
                                color: Colors.red.withValues(alpha: 0.5),
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
                _chip('دواکەوتوو', Icons.warning_amber_rounded, Colors.red),
              ],
              if (nbName != null && nbName.isNotEmpty) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: _chip(nbName, Icons.place_rounded, nbColor,
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
                              color:
                              isDark ? Colors.white : const Color(0xFF1A1A2E),
                              height: 1.3),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Wrap(spacing: 6, runSpacing: 4, children: [
                        if (hasVoice)
                          _buildTag('دەنگ', Icons.mic_rounded,
                              const Color(0xFF1E88E5)),
                        if (hasPhone)
                          _buildTag(userPhone, Icons.phone_rounded,
                              const Color(0xFF25D366)),
                        if (c['responsible_authority'] != null)
                          _buildTag(c['responsible_authority'].toString(),
                              Icons.account_balance_rounded, Colors.indigo),
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
                      color: const Color(0xFF2ECC71),
                      onTap: () => _quickUpdate(c, 'in_progress'),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildAction(
                      icon: Icons.cancel_rounded,
                      label: tr('ڕەتکردنەوە'),
                      color: const Color(0xFFE74C3C),
                      onTap: () => _quickUpdate(c, 'rejected'),
                    ),
                  ),
                  const SizedBox(width: 6),
                ] else if (isInProgress) ...[
                  Expanded(
                    child: _buildAction(
                      icon: Icons.check_circle_rounded,
                      label: tr('تەواوکردن'),
                      color: const Color(0xFF3498DB),
                      onTap: () => _quickUpdate(c, 'completed'),
                    ),
                  ),
                  const SizedBox(width: 6),
                ] else
                  const Spacer(),

                // ✅ دوگمەی شێرکردن (Share) هەمیشە بەردەستە
                _buildIconBtn(
                    Icons.share_rounded,
                    const Color(0xFF25D366),
                        () => _shareComplaintToWhatsApp(c)
                ),
                const SizedBox(width: 6),

                // ✅ دوگمەی چات (تەنها ئەگەر ژمارەی مۆبایل هەبوو)
                if (hasPhone) ...[
                  _buildIconBtn(Icons.chat_rounded, const Color(0xFF25D366),
                          () => _sendWhatsApp(c)),
                  const SizedBox(width: 6),
                ],

                _buildIconBtn(Icons.visibility_rounded, AppColors.primary,
                        () => _showDetails(c)),
                const SizedBox(width: 6),
                _buildIconBtn(Icons.delete_rounded, Colors.red,
                    _isDeleting ? null : () => _delete(c)),
              ]),
            ),
        ]),
      ),
    );
  }

  void _showFilterSheet() {
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
          bool sameDay(DateTime a, DateTime b) =>
              a.year == b.year && a.month == b.month && a.day == b.day;
          _sortBy = result.sortBy;
          _fromDate = result.fromDate;
          _toDate = result.toDate;
          _filterAuthority = result.authority;
          _filterStatuses = result.statuses;
          _onlyWithVoice = result.onlyWithVoice;
          _onlyWithImages = result.onlyWithImages;
          // the date range only filters the list once the admin changed it
          _dateFilterActive = !sameDay(result.fromDate, _defaultFrom) ||
              !sameDay(result.toDate, DateTime.now());
          _refilter();
        },
      ),
    );
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

  Future<void> _sendWhatsApp(Map<String, dynamic> c) async {
    HapticFeedback.mediumImpact();
    await WhatsAppComplaintService.sendComplaint(
      context: context,
      complaint: c,
      showPreview: true,
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
      _snack(tr('گۆڕینی دۆخ سەرنەکەوت، دووبارە هەوڵبدەوە'), Colors.red);
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
      _snack(tr('گەڕاندنەوە سەرنەکەوت'), Colors.red);
    }
  }

  Future<void> _showBulkActions() async {
    if (_selectedIds.isEmpty) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Widget tile(String key, String label, IconData icon, Color color) =>
        ListTile(
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          title: Text(tr(label),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          onTap: () => Navigator.pop(context, key),
        );

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _surface(isDark),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Directionality(
        textDirection: AppLang.direction,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                    trf('کار لەسەر {0} سکاڵا', [_ku(_selectedIds.length)]),
                    style: const TextStyle(
                        fontWeight: FontWeight.w900, fontSize: 16)),
              ),
              tile('in_progress', 'پەسەندکردن', Icons.verified_rounded,
                  const Color(0xFF2ECC71)),
              tile('completed', 'جێبەجێکردن (تەواو)',
                  Icons.check_circle_rounded, const Color(0xFF3498DB)),
              tile('rejected', 'ڕەتکردنەوە', Icons.cancel_rounded,
                  const Color(0xFFE74C3C)),
              const Divider(),
              tile('delete', 'سڕینەوە', Icons.delete_sweep_rounded, Colors.red),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (!mounted || choice == null) return;
    if (choice == 'delete') {
      await _bulkDelete();
    } else {
      await _bulkSetStatus(choice);
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
      _snack(tr('گۆڕین سەرنەکەوت، دووبارە هەوڵبدەوە'), Colors.red);
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
            _snack(tr('گەڕاندنەوە سەرنەکەوت'), Colors.red);
          }
        },
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🗑 Delete
  // ═══════════════════════════════════════════════════════════
  Future<bool> _confirm(String title, String body, String yes) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(tr(title))),
          ]),
          content: Text(tr(body)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('نەخێر')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr(yes)),
            ),
          ],
        ),
      ),
    );
    return ok ?? false;
  }

  Future<void> _delete(Map<String, dynamic> c) async {
    if (_isDeleting) return;
    if (!await _confirm('سڕینەوەی سکاڵا',
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
        _complaints.removeWhere((x) => x['id'].toString() == c['id'].toString());
        _selectedIds.remove(c['id'].toString());
        _recompute();
      });
      HapticFeedback.mediumImpact();
      _snack(tr('✅ سکاڵا سڕایەوە'), Colors.green);
    } catch (e) {
      debugPrint('❌ delete error: $e');
      _snack(tr('سڕینەوە سەرنەکەوت، دووبارە هەوڵبدەوە'), Colors.red);
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
      final toDelete = _complaints
          .where((c) => ids.contains(c['id'].toString()))
          .toList();

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
      _snack(trf('✅ {0} سکاڵا سڕانەوە', [_ku(ids.length)]), Colors.green);
    } catch (e) {
      debugPrint('❌ bulk delete error: $e');
      _snack(tr('سڕینەوە سەرنەکەوت، دووبارە هەوڵبدەوە'), Colors.red);
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
      _snack(tr('هیچ سکاڵایەک نییە'), Colors.orange);
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
      _snack(tr('دروستکردنی PDF سەرنەکەوت'), Colors.red);
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