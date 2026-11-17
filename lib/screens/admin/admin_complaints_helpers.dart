// lib/screens/admin/admin_complaints_helpers.dart
// بەشێک لە ڕووکاری _AdminComplaintsProScreenState — لە admin_complaints.dart جیاکراوەتەوە

part of 'admin_complaints.dart';

extension _AdminComplaintsProScreenStateHelpers
    on _AdminComplaintsProScreenState {
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
  // 🟢 WhatsApp Sharing with All Details
  // ═══════════════════════════════════════════════════════════
  Future<void> _shareComplaintToWhatsApp(Map<String, dynamic> c) =>
      WhatsAppComplaintService.shareToWhatsApp(context, c);

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
        DateTime.now().difference(created) >
            _AdminComplaintsProScreenState._overdueAfter;
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
      final to = DateTime(_toDate.year, _toDate.month, _toDate.day, 23, 59, 59);
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

    for (final key in _AdminComplaintsProScreenState._tabKeys) {
      _tabLists[key] = common.where((c) => _matchesTab(c, key)).toList()
        ..sort(cmp);
    }
  }

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
        return const Color(0xFFD9822B);
      case 'approved':
      case 'in_progress':
        return const Color(0xFF0F9D7A);
      case 'rejected':
        return const Color(0xFFDC3545);
      case 'completed':
        return const Color(0xFF1E88E5);
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
    final date = DateTime.tryParse(dateStr)?.toLocal();
    if (date == null) return '';
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 1) return 'ئێستا';
    if (diff.inMinutes < 60)
      return trf('{0} خولەک لەمەوبەر', [_ku(diff.inMinutes)]);
    if (diff.inHours < 24)
      return trf('{0} کاتژمێر لەمەوبەر', [_ku(diff.inHours)]);
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
          content: Text(tr(msg),
              style: const TextStyle(fontWeight: FontWeight.bold)),
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

  void _clearAllFilters() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    _q = '';
    _sortBy = _AdminComplaintsProScreenState._defaultSort;
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

  /// مێنیوی کارتی سکاڵا: هاوبەشکردن، چات، وردەکاری، سڕینەوە (پێشتر چوار دوگمەی جیا بوون)
  Widget _buildCardMenu(Map<String, dynamic> c, bool hasPhone) {
    return PopupMenuButton<String>(
      tooltip: tr('زیاتر'),
      icon: Icon(Icons.more_horiz_rounded, color: Colors.grey.shade600),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (v) {
        switch (v) {
          case 'details':
            _showDetails(c);
            break;
          case 'share':
            _shareComplaintToWhatsApp(c);
            break;
          case 'chat':
            _sendWhatsApp(c);
            break;
          case 'delete':
            if (!_isDeleting) _delete(c);
            break;
        }
      },
      itemBuilder: (_) => [
        _popupItem('details', 'وردەکاری', Icons.visibility_rounded),
        _popupItem('share', 'هاوبەشکردن', Icons.share_rounded),
        if (hasPhone) _popupItem('chat', 'چات', Icons.chat_rounded),
        PopupMenuItem(
          value: 'delete',
          child: Row(children: [
            const Icon(Icons.delete_rounded,
                size: 18, color: Color(0xFFDC3545)),
            const SizedBox(width: 10),
            Text(tr('سڕینەوە'),
                style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFFDC3545))),
          ]),
        ),
      ],
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
              style:
                  const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
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
                  const Color(0xFF0F9D7A)),
              tile('completed', 'جێبەجێکردن (تەواو)',
                  Icons.check_circle_rounded, const Color(0xFF1E88E5)),
              tile('rejected', 'ڕەتکردنەوە', Icons.cancel_rounded,
                  const Color(0xFFDC3545)),
              const Divider(),
              tile('delete', 'سڕینەوە', Icons.delete_sweep_rounded,
                  const Color(0xFFDC3545)),
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
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC3545)),
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
                  backgroundColor: const Color(0xFFDC3545),
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr(yes)),
            ),
          ],
        ),
      ),
    );
    return ok ?? false;
  }
}
