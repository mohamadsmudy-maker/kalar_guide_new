import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../services/cache_service.dart';

/// 🗄️ FutureBuilder لەگەڵ کاش — ULTRA PRO v2
///
/// چاکسازییە گرنگەکان:
///  • **کاشی بێ `fromCache` بۆ جۆرە گشتییەکان کار نەدەکرد**: ئەگەر کاشەکە JSON بێت،
///    `List<dynamic>` دەگەڕێتەوە و `cached is List<Map<String, dynamic>>` هەمیشە false
///    بوو — کەواتە هەموو جارێک داتا لە سەرچاوە دەهێنرا و کاش بێ سوود بوو.
///    پارامەتری نوێی `fromCache` ئەو گۆڕانکارییە دەکات.
///  • Race condition: ئەگەر `cacheKey` بگۆڕێت (یان refresh دووبارە بێت)، وەڵامی
///    داواکاری کۆن دەستکاری ناکات.
///  • شکستی پاشەکەوتکردن (save) ئیتر ئەنجامە سەرکەوتووەکە ناشارێتەوە.
///  • هەڵەی خاو ئیتر بە بەکارهێنەر ناپیشاندرێت (تەنها لە debug log).
///  • `refresh()` داتای کۆن لەسەر شاشە دەهێڵێتەوە (بێ skeleton/loading)،
///    و ئەگەر شکستی هێنا هەر داتای کۆن دەمێنێتەوە.
///  • ئەگەر چەند widget هەمان `cacheKey` بخوازن، تەنها یەک fetch دەکرێت.
///  • State ئێستا public ە: `GlobalKey<CachedFutureBuilderState<T>>` → `.currentState?.refresh()`
///  • `_data == null` وەک «هیچ داتایەک نییە» نەماوە (جۆری nullable دروست کار دەکات)
///  • `revalidate: true` = یەکسەر کاش نیشان بدە، پاشان لە پشتەوە نوێی بکەرەوە
class CachedFutureBuilder<T> extends StatefulWidget {
  final String cacheKey;
  final Future<T> Function() fetcher;
  final Widget Function(BuildContext context, T data) builder;
  final Duration? cacheDuration;
  final Widget? loadingWidget;
  final Widget Function(Object error)? errorBuilder;

  /// گۆڕینی کاشی خوێندراو (زۆرجار JSON) بۆ جۆری `T`.
  /// نموونە: `fromCache: (raw) => (raw as List).cast<Map<String, dynamic>>()`
  /// ئەگەر فڕێ بدات، کاشەکە وەک نەگونجاو دەژمێردرێت و داتا نوێ دەهێنرێت.
  final T Function(dynamic raw)? fromCache;

  /// true = کاش یەکسەر نیشان بدە و دواتر لە پشتەوە داتای تازە بهێنە
  final bool revalidate;

  const CachedFutureBuilder({
    super.key,
    required this.cacheKey,
    required this.fetcher,
    required this.builder,
    this.cacheDuration,
    this.loadingWidget,
    this.errorBuilder,
    this.fromCache,
    this.revalidate = false,
  });

  @override
  State<CachedFutureBuilder<T>> createState() =>
      CachedFutureBuilderState<T>();
}

class CachedFutureBuilderState<T> extends State<CachedFutureBuilder<T>> {
  T? _data;
  bool _hasData = false;
  Object? _error;
  bool _isLoading = true;
  bool _refreshing = false;
  int _run = 0;

  /// fetch ی هاوبەش بۆ هەمان کلیل
  static final Map<String, Future<dynamic>> _inFlight = {};

  static const Map<String, Map<String, String>> _tr = {
    'error': {
      'ku': 'نەتوانرا داتا بهێنرێت',
      'ar': 'تعذر تحميل البيانات',
      'en': 'Could not load data'
    },
    'hint': {
      'ku': 'ئینتەرنێتەکەت بپشکنە و دووبارە هەوڵبدەرەوە',
      'ar': 'تحقق من اتصالك وحاول مجدداً',
      'en': 'Check your connection and try again'
    },
    'retry': {'ku': 'دووبارە هەوڵبدە', 'ar': 'إعادة المحاولة', 'en': 'Try again'},
    'empty': {'ku': 'هیچ داتایەک نییە', 'ar': 'لا توجد بيانات', 'en': 'No data'},
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(CachedFutureBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ ئەگەر cacheKey گۆڕا، داتای کۆن فڕێ بدە و نوێ بهێنە
    if (oldWidget.cacheKey != widget.cacheKey) {
      _data = null;
      _hasData = false;
      _error = null;
      _isLoading = true;
      _refreshing = false;
      _load();
    }
  }

  @override
  void dispose() {
    _run++; // وەڵامی درەنگ پشتگوێ دەخرێت
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 Public API
  // ═══════════════════════════════════════════════════════════
  /// 🔄 دووبارە هێنانەوە (کاش دەسڕێتەوە). داتای کۆن لەسەر شاشە دەمێنێت.
  Future<void> refresh() => _load(force: true);

  // ═══════════════════════════════════════════════════════════
  // 📥 Loading
  // ═══════════════════════════════════════════════════════════
  (bool, T?) _decodeCache(dynamic raw) {
    if (raw == null) return (false, null);

    final decode = widget.fromCache;
    if (decode != null) {
      try {
        return (true, decode(raw));
      } catch (e) {
        debugPrint('⚠️ fromCache failed for "${widget.cacheKey}": $e');
        return (false, null);
      }
    }

    if (raw is T) return (true, raw);
    return (false, null);
  }

  Future<T> _fetch() {
    final key = widget.cacheKey;
    final existing = _inFlight[key];
    if (existing != null) return existing.then((v) => v as T);

    final future = widget.fetcher();
    _inFlight[key] = future;
    future.then(
          (_) => _inFlight.remove(key),
      onError: (Object _) => _inFlight.remove(key),
    );
    return future;
  }

  Future<void> _load({bool force = false}) async {
    final run = ++_run;
    final key = widget.cacheKey;

    if (mounted) {
      if (_hasData) {
        // refresh: داتای کۆن دەمێنێتەوە
        if (!_refreshing) setState(() => _refreshing = true);
      } else if (!_isLoading || _error != null) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }
    }

    try {
      if (force) {
        await CacheService.remove(key);
        if (!mounted || run != _run) return;
      } else {
        // ⭐ ١. کاش
        final cached = await CacheService.get(key);
        if (!mounted || run != _run) return;

        final (found, value) = _decodeCache(cached);
        if (found) {
          setState(() {
            _data = value;
            _hasData = true;
            _isLoading = false;
            _error = null;
            _refreshing = widget.revalidate;
          });
          debugPrint('✅ CachedFutureBuilder: "$key" لە کاش هێنرا');
          if (!widget.revalidate) return;
        } else if (cached != null) {
          debugPrint(
            '⚠️ Cache mismatch for "$key": expected $T, got ${cached.runtimeType}',
          );
          await CacheService.remove(key);
          if (!mounted || run != _run) return;
        }
      }

      // ⭐ ٢. سەرچاوە
      final fresh = await _fetch();
      if (!mounted || run != _run) return;

      setState(() {
        _data = fresh;
        _hasData = true;
        _isLoading = false;
        _error = null;
        _refreshing = false;
      });

      // پاشەکەوت لە دوای نیشاندان؛ شکستی save ئەنجامەکە نابڕێت
      try {
        await CacheService.save(key, fresh, duration: widget.cacheDuration);
      } catch (e) {
        debugPrint('⚠️ CachedFutureBuilder save failed for "$key": $e');
      }
    } catch (e) {
      debugPrint('❌ CachedFutureBuilder error ("$key"): $e');
      if (!mounted || run != _run) return;

      setState(() {
        _refreshing = false;
        _isLoading = false;
        // ئەگەر داتای کۆن هەیە، هەر نیشان بدرێت؛ تەنها بێ داتا هەڵە پیشان دەدرێت
        if (!_hasData) _error = e;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final lang = context.select<SettingsProvider, String>((s) => s.languageId);
    String t(String k) => _tr[k]?[lang] ?? _tr[k]?['en'] ?? k;

    // ✅ داتا هەیە (تەنانەت ئەگەر refresh بەردەوام بێت)
    if (_hasData) return widget.builder(context, _data as T);

    // ⏳ Loading
    if (_isLoading) {
      return widget.loadingWidget ??
          const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
    }

    // ❌ Error
    if (_error != null) {
      if (widget.errorBuilder != null) return widget.errorBuilder!(_error!);

      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 56, color: Color(0xFFDC3545)),
              const SizedBox(height: 12),
              Text(
                t('error'),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 15,
                  color: Color(0xFFDC3545),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                t('hint'),
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(t('retry')),
              ),
            ],
          ),
        ),
      );
    }

    return Center(
      child: Text(t('empty'), style: const TextStyle(color: Colors.grey)),
    );
  }
}