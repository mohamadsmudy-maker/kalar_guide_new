// lib/screens/favorites/favorites_screen.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../widgets/ultra_pro/ultra_pro_components.dart';
import '../stores/store_details_dialog.dart';
import '../news/news_details.dart';
import '../../l10n/tr.dart';
import '../../utils/place_display.dart';

part 'favorites_screen_ui.dart';

const Color _kPink = Color(0xFFC2557A);
const Color _kPurple = Color(0xFFC2557A);

enum _Kind { stores, news }

extension on _Kind {
  String get favTable => this == _Kind.stores ? 'favorite_stores' : 'news_favorites';
  String get targetCol => this == _Kind.stores ? 'store_id' : 'news_id';
  String get dataTable => this == _Kind.stores ? 'dukan' : 'news';
  Color get color => this == _Kind.stores ? _kPink : _kPurple;
  String get titleKey => this == _Kind.stores ? 'name' : 'title';
}

/// ❤️ شاشەی دڵخوازەکان — FULL ULTRA PRO MAX V2
class FavoritesScreen extends StatefulWidget {
  final VoidCallback? onMenuTap;

  const FavoritesScreen({super.key, this.onMenuTap});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final TabController _tabController;
  late final AnimationController _entryController;
  late final AnimationController _pulseController;
  late final Animation<double> _entryAnimation;
  late final Animation<double> _pulseAnimation;

  // ── Per-kind state ──────────────────────────────────────
  // Every item is normalised to: fav_id, target_raw, created_at, data
  final Map<_Kind, List<Map<String, dynamic>>> _items = {
    _Kind.stores: [],
    _Kind.news: [],
  };
  final Map<_Kind, bool> _loading = {_Kind.stores: true, _Kind.news: true};
  final Map<_Kind, bool> _error = {_Kind.stores: false, _Kind.news: false};
  final Map<_Kind, TextEditingController> _searchCtrl = {
    _Kind.stores: TextEditingController(),
    _Kind.news: TextEditingController(),
  };
  final Map<_Kind, String> _query = {_Kind.stores: '', _Kind.news: ''};
  final Map<_Kind, String> _sortBy = {
    _Kind.stores: 'recent',
    _Kind.news: 'recent',
  };
  final Map<_Kind, Set<String>> _selected = {
    _Kind.stores: <String>{},
    _Kind.news: <String>{},
  };

  bool _batchMode = false;
  bool _deleting = false;
  Timer? _searchDebounce;

  _Kind get _currentKind =>
      _tabController.index == 0 ? _Kind.stores : _Kind.news;

  String? get _userId {
    final user = AuthSessionManager.currentUser;
    if (user == null || user['id'] == null) return null;
    return user['id'].toString();
  }

  // ═══════════════════════════════════════════════════════════
  // 🔁 Lifecycle
  // ═══════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChanged);

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _entryAnimation =
        CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _initializeAndLoad();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchDebounce?.cancel();
    _tabController
      ..removeListener(_onTabChanged)
      ..dispose();
    _entryController.dispose();
    _pulseController.dispose();
    for (final c in _searchCtrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted && !_deleting) {
      _loadAll(silent: true);
    }
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    // Selection is per-tab; leaving a tab clears the other tab's picks.
    final other = _currentKind == _Kind.stores ? _Kind.news : _Kind.stores;
    if (_selected[other]!.isNotEmpty) _selected[other]!.clear();
    // The store dialog can unfavorite things, so refresh quietly on return.
    if (_currentKind == _Kind.stores && !_deleting) {
      _load(_Kind.stores, silent: true);
    }
    if (mounted) setState(() {});
  }

  Future<void> _initializeAndLoad() async {
    if (Supabase.instance.client.auth.currentUser == null) {
      try {
        await Supabase.instance.client.auth.signInAnonymously();
      } catch (e) {
        debugPrint('❌ Anonymous sign in failed: $e');
      }
    }
    await _loadAll();
  }

  // ═══════════════════════════════════════════════════════════
  // 📥 Data
  // ═══════════════════════════════════════════════════════════
  Future<void> _loadAll({bool silent = false}) async {
    await Future.wait([
      _load(_Kind.stores, silent: silent),
      _load(_Kind.news, silent: silent),
    ]);
    if (mounted && !silent) _entryController.forward(from: 0);
  }

  Future<void> _load(_Kind kind, {bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading[kind] = true;
        _error[kind] = false;
      });
    }

    try {
      final uid = _userId;
      if (uid == null) {
        if (mounted) {
          setState(() {
            _items[kind] = [];
            _loading[kind] = false;
          });
        }
        return;
      }

      final client = Supabase.instance.client;
      final favRes = await client
          .from(kind.favTable)
          .select('id, ${kind.targetCol}, created_at')
          .eq('user_id', uid)
          .order('created_at', ascending: false);

      final favList = List<Map<String, dynamic>>.from(favRes as List);
      if (favList.isEmpty) {
        if (mounted) {
          setState(() {
            _items[kind] = [];
            _loading[kind] = false;
            _error[kind] = false;
          });
        }
        return;
      }

      final ids = favList.map((f) => f[kind.targetCol].toString()).toList();
      final dataRes =
      await client.from(kind.dataTable).select('*').inFilter('id', ids);

      final byId = <String, Map<String, dynamic>>{
        for (final d in List<Map<String, dynamic>>.from(dataRes as List))
          d['id'].toString(): d,
      };

      final combined = <Map<String, dynamic>>[];
      for (final fav in favList) {
        final data = byId[fav[kind.targetCol].toString()];
        if (data == null || data.isEmpty) continue;
        combined.add({
          'fav_id': fav['id'],
          'target_raw': fav[kind.targetCol],
          'created_at': fav['created_at'],
          'data': data,
        });
      }

      if (!mounted) return;
      setState(() {
        _items[kind] = combined;
        _loading[kind] = false;
        _error[kind] = false;
        // drop selections that no longer exist
        final alive = combined.map((e) => e['fav_id'].toString()).toSet();
        _selected[kind]!.removeWhere((id) => !alive.contains(id));
      });
    } catch (e) {
      debugPrint('❌ Load ${kind.name} error: $e');
      if (!mounted) return;
      setState(() {
        _loading[kind] = false;
        // keep old data on silent refresh failures
        if (!silent) _error[kind] = true;
      });
    }
  }

  List<Map<String, dynamic>> _filtered(_Kind kind) {
    var list = List<Map<String, dynamic>>.from(_items[kind]!);
    final q = _query[kind]!.trim().toLowerCase();

    if (q.isNotEmpty) {
      list = list.where((item) {
        final d = item['data'] as Map<String, dynamic>;
        final a = (d[kind.titleKey] ?? '').toString().toLowerCase();
        final b = ((kind == _Kind.stores ? d['address'] : d['description']) ?? '')
            .toString()
            .toLowerCase();
        return a.contains(q) || b.contains(q);
      }).toList();
    }

    switch (_sortBy[kind]) {
      case 'oldest':
        list.sort((a, b) => (a['created_at'] ?? '')
            .toString()
            .compareTo((b['created_at'] ?? '').toString()));
        break;
      case 'title':
        list.sort((a, b) => ((a['data'] as Map)[kind.titleKey] ?? '')
            .toString()
            .toLowerCase()
            .compareTo(((b['data'] as Map)[kind.titleKey] ?? '')
            .toString()
            .toLowerCase()));
        break;
      default:
        break; // already newest-first from the query
    }
    return list;
  }

  // ═══════════════════════════════════════════════════════════
  // 🗑 Delete (single with undo, batch with confirm)
  // ═══════════════════════════════════════════════════════════
  Future<void> _removeOne(_Kind kind, Map<String, dynamic> item) async {
    final list = _items[kind]!;
    final index = list.indexOf(item);
    if (index < 0) return;

    setState(() {
      list.removeAt(index);
      _selected[kind]!.remove(item['fav_id'].toString());
    });
    HapticFeedback.mediumImpact();

    try {
      await Supabase.instance.client
          .from(kind.favTable)
          .delete()
          .eq('id', item['fav_id']);
    } catch (e) {
      debugPrint('❌ Delete error: $e');
      if (!mounted) return;
      setState(() => list.insert(index > list.length ? list.length : index, item));
      _showSnack(tr('سڕینەوە سەرنەکەوت، دووبارە هەوڵبدەوە'), const Color(0xFFDC3545));
      return;
    }

    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(tr('لە دڵخوازەکان لابرا'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
          behavior: SnackBarBehavior.floating,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: tr('گەڕاندنەوە'),
            textColor: const Color(0xFFD9822B),
            onPressed: () => _undoRemove(kind, item),
          ),
        ),
      );
  }

  Future<void> _undoRemove(_Kind kind, Map<String, dynamic> item) async {
    final uid = _userId;
    if (uid == null) return;
    try {
      await Supabase.instance.client.from(kind.favTable).insert({
        'user_id': uid,
        kind.targetCol: item['target_raw'],
      });
      HapticFeedback.lightImpact();
      await _load(kind, silent: true);
    } catch (e) {
      debugPrint('❌ Undo error: $e');
      _showSnack(tr('گەڕاندنەوە سەرنەکەوت'), const Color(0xFFDC3545));
    }
  }

  Future<bool> _confirmDelete(int count) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(tr('سڕینەوە'),
              style: const TextStyle(fontWeight: FontWeight.w900)),
          content: Text(trf('دڵنیایت لە سڕینەوەی {0} دڵخواز؟', [_ku(count)])),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('نەخێر')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: const Color(0xFFDC3545)),
              child: Text(tr('سڕینەوە')),
            ),
          ],
        ),
      ),
    );
    return ok ?? false;
  }

  Future<void> _deleteBatch(_Kind kind) async {
    final ids = _selected[kind]!.toList();
    if (ids.isEmpty || _deleting) return;
    if (!await _confirmDelete(ids.length)) return;

    setState(() => _deleting = true);
    try {
      await Supabase.instance.client
          .from(kind.favTable)
          .delete()
          .inFilter('id', ids);
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      setState(() {
        _selected[kind]!.clear();
        _batchMode = false;
      });
      await _load(kind, silent: true);
      _showSnack(trf('{0} دڵخواز سڕایەوە', [_ku(ids.length)]), const Color(0xFF0F9D7A));
    } catch (e) {
      debugPrint('❌ Batch delete error: $e');
      _showSnack(tr('سڕینەوە سەرنەکەوت، دووبارە هەوڵبدەوە'), const Color(0xFFDC3545));
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  void _exitBatch() {
    setState(() {
      _batchMode = false;
      for (final s in _selected.values) {
        s.clear();
      }
    });
  }

  void _toggleSelect(_Kind kind, String id) {
    HapticFeedback.selectionClick();
    setState(() {
      final s = _selected[kind]!;
      if (!s.remove(id)) s.add(id);
    });
  }

  void _enterBatchWith(_Kind kind, String id) {
    if (_batchMode) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _batchMode = true;
      _selected[kind]!.add(id);
    });
  }

  // ═══════════════════════════════════════════════════════════
  // 🧰 Helpers
  // ═══════════════════════════════════════════════════════════
  String _ku(num n) => n.toString().replaceAllMapped(
    RegExp(r'\d'),
        (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)],
  );

  String _ago(dynamic raw) {
    final d = DateTime.tryParse(raw?.toString() ?? '')?.toLocal();
    if (d == null) return '';
    final diff = DateTime.now().difference(d);
    if (diff.inMinutes < 1) return 'ئێستا';
    if (diff.inMinutes < 60) return trf('{0} خولەک لەمەوبەر', [_ku(diff.inMinutes)]);
    if (diff.inHours < 24) return trf('{0} کاتژمێر لەمەوبەر', [_ku(diff.inHours)]);
    if (diff.inDays < 30) return trf('{0} ڕۆژ لەمەوبەر', [_ku(diff.inDays)]);
    return '${_ku(d.year)}/${_ku(d.month)}/${_ku(d.day)}';
  }

  void _showSnack(String msg, Color color) {
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
          duration: const Duration(seconds: 2),
        ),
      );
  }

  String _extractFirstImage(dynamic rawImages) {
    if (rawImages == null) return '';
    if (rawImages is List) {
      return rawImages.isEmpty ? '' : rawImages.first.toString().trim();
    }
    if (rawImages is String) {
      var s = rawImages.trim();
      if (s.isEmpty) return '';
      s = s.replaceAll(RegExp(r'^\[|\]$'), '');
      s = s.replaceAll('"', '').replaceAll("'", '');
      if (s.contains(',')) s = s.split(',').first;
      return s.trim();
    }
    return rawImages.toString().trim();
  }

  Color _bg(bool isDark) =>
      isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9);
  Color _card(bool isDark) => isDark ? const Color(0xFF1A1A22) : Colors.white;
  Color _title(bool isDark) => isDark ? Colors.white : const Color(0xFF1A1A2E);
  Color _sub(bool isDark) => isDark ? Colors.white54 : Colors.grey.shade600;

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_userId == null) return _buildLoggedOut(isDark);

    final kind = _currentKind;
    final selectedCount = _selected[kind]!.length;

    return PopScope(
      canPop: !_batchMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _batchMode) _exitBatch();
      },
      child: Directionality(
        textDirection: AppLang.direction,
        child: Scaffold(
          backgroundColor: _bg(isDark),
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(isDark),
              SliverToBoxAdapter(child: _buildTabBar(isDark)),
              SliverFillRemaining(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTab(_Kind.stores, isDark),
                    _buildTab(_Kind.news, isDark),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: _batchMode
              ? FloatingActionButton.extended(
            onPressed: () {
              HapticFeedback.mediumImpact();
              _exitBatch();
            },
            backgroundColor: selectedCount > 0 ? Colors.grey : const Color(0xFFDC3545),
            foregroundColor: Colors.white,
            icon: const Icon(Icons.close_rounded),
            label: Text(tr('هەڵوەشاندنەوە'),
                style: const TextStyle(fontWeight: FontWeight.w900)),
          )
              : null,
        ),
      ),
    );
  }

  Widget _buildLoggedOut(bool isDark) {
    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: _bg(isDark),
        appBar: AppBar(
          title: Text(tr('دڵخوازەکان'),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          backgroundColor: _card(isDark),
          foregroundColor: isDark ? Colors.white : AppColors.primary,
          centerTitle: true,
          elevation: 0,
        ),
        body: ProEmptyState(
          icon: Icons.favorite_rounded,
          title: tr('پێویستە بچیتە ژوورەوە'),
          subtitle: tr('بۆ بینینی دڵخوازەکانت سەرەتا بچۆ ژوورەوە'),
          color: const Color(0xFFC2557A),
          isDark: isDark,
          actionLabel: tr('چوونەژوورەوە'),
          actionIcon: Icons.login_rounded,
          onAction: () {
            Navigator.pushNamed(context, '/auth').then((_) {
              if (mounted) {
                setState(() {});
                _initializeAndLoad();
              }
            });
          },
        ),
      ),
    );
  }

  Widget _buildAppBar(bool isDark) {
    final total = _items[_Kind.stores]!.length + _items[_Kind.news]!.length;
    final iconColor = isDark ? Colors.white : AppColors.primary;

    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: _card(isDark),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: widget.onMenuTap != null
          ? IconButton(
        icon: Icon(Icons.menu_rounded, color: iconColor),
        onPressed: widget.onMenuTap,
      )
          : null,
      actions: [
        IconButton(
          icon: Icon(Icons.refresh_rounded, color: iconColor),
          tooltip: tr('نوێکردنەوە'),
          onPressed: () async {
            HapticFeedback.lightImpact();
            await _loadAll(silent: true);
            _showSnack(tr('داتاکان نوێکرانەوە ✅'), const Color(0xFF0F9D7A));
          },
        ),
        IconButton(
          icon: Icon(
            _batchMode ? Icons.close_rounded : Icons.checklist_rounded,
            color: iconColor,
          ),
          tooltip: _batchMode ? tr('هەڵوەشاندنەوە') : tr('هەڵبژاردنی چەند'),
          onPressed: () {
            HapticFeedback.selectionClick();
            if (_batchMode) {
              _exitBatch();
            } else {
              setState(() => _batchMode = true);
            }
          },
        ),
        const SizedBox(width: 8),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF1A1A22), const Color(0xFF252530)]
                  : [Colors.white, _kPink.withValues(alpha: 0.05)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -50,
                right: -50,
                child: AnimatedBuilder(
                  animation: _pulseAnimation,
                  builder: (_, __) => Transform.scale(
                    scale: _pulseAnimation.value,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _kPink.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 70, 20, 12),
                  child: Row(
                    children: [
                      AnimatedBuilder(
                        animation: _pulseAnimation,
                        builder: (_, __) => Transform.scale(
                          scale: 1.0 + (_pulseAnimation.value - 1.0) * 0.4,
                          child: Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                  colors: [_kPink, _kPurple]),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: _kPink.withValues(alpha: 0.5),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                  spreadRadius: -4,
                                ),
                              ],
                            ),
                            child: const Icon(Icons.favorite_rounded,
                                color: Colors.white, size: 30),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tr('دڵخوازەکان'),
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: _title(isDark),
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _kPink.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.favorite_rounded,
                                      color: _kPink, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    trf('{0} دڵخواز', [_ku(total)]),
                                    style: const TextStyle(
                                        color: _kPink,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w900),
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
  // 📑 Generic tab (stores + news share everything but the card)
  // ═══════════════════════════════════════════════════════════
  Widget _buildTab(_Kind kind, bool isDark) {
    final color = kind.color;
    final isStores = kind == _Kind.stores;

    if (_loading[kind]!) {
      return Center(child: CircularProgressIndicator(color: color));
    }

    if (_error[kind]!) {
      return _scrollableCenter(
        kind,
        ProEmptyState(
          icon: Icons.wifi_off_rounded,
          title: tr('نەتوانرا بارببێت'),
          subtitle: tr('ئینتەرنێتەکەت بپشکنە و دووبارە هەوڵبدەوە'),
          color: color,
          isDark: isDark,
          actionLabel: tr('دووبارە هەوڵبدەرەوە'),
          onAction: () => _load(kind),
        ),
      );
    }

    if (_items[kind]!.isEmpty) {
      return _scrollableCenter(
        kind,
        _buildEmptyState(
          isDark: isDark,
          icon: isStores ? Icons.place_outlined : Icons.article_outlined,
          title: isStores
              ? tr('هیچ شوێنێکی دڵخوازت نییە')
              : tr('هیچ هەواڵێکی دڵخوازت نییە'),
          subtitle: isStores
              ? tr('شوێنەکان بپشکنە و ئەوانەی حەزت لێیە\nزیاد بکە بۆ دڵخوازەکان')
              : tr('هەواڵەکان بپشکنە و ئەوانەی حەزت لێیە\nزیاد بکە بۆ دڵخوازەکان'),
          color: color,
        ),
      );
    }

    final list = _filtered(kind);
    final selected = _selected[kind]!;

    return Column(
      children: [
        _buildSearchBar(kind, isDark),
        _buildSortBar(kind, isDark),
        if (_batchMode)
          _buildBatchBar(
            isDark: isDark,
            color: color,
            selectedCount: selected.length,
            totalCount: list.length,
            onSelectAll: () => setState(() {
              final all = list.map((e) => e['fav_id'].toString()).toSet();
              if (selected.length == all.length && selected.containsAll(all)) {
                selected.clear();
              } else {
                selected
                  ..clear()
                  ..addAll(all);
              }
            }),
            onDelete: () => _deleteBatch(kind),
          ),
        Expanded(
          child: RefreshIndicator(
            color: color,
            onRefresh: () => _load(kind, silent: true),
            child: list.isEmpty
                ? _scrollableCenter(
              kind,
              _buildEmptyState(
                isDark: isDark,
                icon: Icons.search_off_rounded,
                title: tr('هیچ ئەنجامێک نەدۆزرایەوە'),
                subtitle: tr('گەڕانەکەت هیچ ئەنجامێکی نەبوو'),
                color: color,
              ),
            )
                : ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final item = list[index];
                final id = item['fav_id'].toString();
                final isSel = selected.contains(id);

                Widget card = isStores
                    ? _buildStoreCard(item, isDark, isSel)
                    : _buildNewsCard(item, isDark, isSel);

                if (!_batchMode) {
                  card = Dismissible(
                    key: ValueKey('${kind.name}_$id'),
                    direction: DismissDirection.horizontal,
                    background: _dismissBg(Alignment.centerRight),
                    secondaryBackground: _dismissBg(Alignment.centerLeft),
                    onDismissed: (_) => _removeOne(kind, item),
                    child: card,
                  );
                }

                return _entry(index, card);
              },
            ),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔎 Search / sort / batch bars
  // ═══════════════════════════════════════════════════════════
  Widget _buildSearchBar(_Kind kind, bool isDark) {
    final color = kind.color;
    final ctrl = _searchCtrl[kind]!;
    final hasText = _query[kind]!.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: _card(isDark),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: hasText ? color.withValues(alpha: 0.5) : Colors.transparent,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            const SizedBox(width: 12),
            Icon(Icons.search_rounded, color: color, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: ctrl,
                textInputAction: TextInputAction.search,
                onChanged: (v) {
                  _searchDebounce?.cancel();
                  _searchDebounce = Timer(const Duration(milliseconds: 250), () {
                    if (mounted) setState(() => _query[kind] = v);
                  });
                  // keep the clear button in sync immediately
                  if ((v.isEmpty) != !hasText) setState(() {});
                },
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: kind == _Kind.stores
                      ? tr('گەڕان بەدوای شوێنەکان...')
                      : tr('گەڕان بەدوای هەواڵەکان...'),
                  hintStyle: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.grey),
                  border: InputBorder.none,
                ),
              ),
            ),
            if (hasText || ctrl.text.isNotEmpty)
              IconButton(
                icon: Icon(Icons.close_rounded,
                    size: 18, color: isDark ? Colors.white54 : Colors.grey),
                onPressed: () {
                  ctrl.clear();
                  _searchDebounce?.cancel();
                  setState(() => _query[kind] = '');
                },
              ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  Widget _buildSortBar(_Kind kind, bool isDark) {
    final color = kind.color;
    final current = _sortBy[kind]!;
    final options = [
      ('recent', 'نوێترین', Icons.schedule_rounded),
      ('oldest', 'کۆنترین', Icons.history_rounded),
      (
      'title',
      kind == _Kind.stores ? 'ناو' : 'ناونیشان',
      Icons.sort_by_alpha_rounded
      ),
    ];
    final shown = _filtered(kind).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.sort_rounded,
              size: 14, color: isDark ? Colors.white54 : Colors.grey),
          const SizedBox(width: 8),
          for (final opt in options)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _sortBy[kind] = opt.$1);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: current == opt.$1
                        ? color.withValues(alpha: 0.15)
                        : _card(isDark),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: current == opt.$1 ? color : Colors.transparent),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(opt.$3,
                          size: 11,
                          color: current == opt.$1
                              ? color
                              : (isDark ? Colors.white54 : Colors.grey)),
                      const SizedBox(width: 4),
                      Text(
                        tr(opt.$2),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: current == opt.$1
                              ? color
                              : (isDark ? Colors.white54 : Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const Spacer(),
          Text(trf('{0} ئەنجام', [_ku(shown)]),
              style: TextStyle(
                  fontSize: 10, color: isDark ? Colors.white38 : Colors.grey)),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration(Color color, bool isDark, bool selected) =>
      BoxDecoration(
        color: selected ? color.withValues(alpha: isDark ? 0.12 : 0.05) : _card(isDark),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? color : color.withValues(alpha: 0.15),
          width: selected ? 2 : 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      );

}