import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/cache_service.dart';

/// 🗄️ FutureBuilder لەگەڵ کاش — ULTRA PRO
///
/// ✅ چاکسازی کراوە بۆ:
/// - پشکنینی جۆر پێش Cast (`cached is T` نەک `cached as T`)
/// - پشکنینی `fresh is T` پێش پاشەکەوت
/// - پشکنینی `_data == null` پێش بەکارهێنان
/// - سڕینەوەی کاشی هەڵە ئەگەر جۆر نەگونجاو
/// - `mounted` پشکنین لە هەموو شوێنێک
class CachedFutureBuilder<T> extends StatefulWidget {
  final String cacheKey;
  final Future<T> Function() fetcher;
  final Widget Function(BuildContext context, T data) builder;
  final Duration? cacheDuration;
  final Widget? loadingWidget;
  final Widget Function(Object error)? errorBuilder;

  const CachedFutureBuilder({
    super.key,
    required this.cacheKey,
    required this.fetcher,
    required this.builder,
    this.cacheDuration,
    this.loadingWidget,
    this.errorBuilder,
  });

  @override
  State<CachedFutureBuilder<T>> createState() =>
      _CachedFutureBuilderState<T>();
}

class _CachedFutureBuilderState<T> extends State<CachedFutureBuilder<T>> {
  T? _data;
  Object? _error;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(CachedFutureBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ ئەگەر cacheKey گۆڕا، داتا نوێ بکەرەوە
    if (oldWidget.cacheKey != widget.cacheKey) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // ⭐ ١. هەوڵدان بۆ وەرگرتن لە کاش
      final cached = await CacheService.get(widget.cacheKey);

      if (!mounted) return;

      if (cached != null) {
        // ✅ پشکنینی جۆر بە پارێزراوی
        if (cached is T) {
          setState(() {
            _data = cached;
            _isLoading = false;
          });
          debugPrint('✅ CachedFutureBuilder: لە کاش هێنرا');
          return;
        } else {
          // ⚠️ جۆری کاش هەڵەیە — بیسڕەوە و Fresh بهێنە
          debugPrint(
            '⚠️ Cache type mismatch: expected $T, got ${cached.runtimeType}',
          );
          await CacheService.remove(widget.cacheKey);
        }
      }

      // ⭐ ٢. ئەگەر نەبوو، هێنان لە سەرچاوە
      final fresh = await widget.fetcher();

      if (!mounted) return;

      // ✅ پشکنینی جۆر پێش پاشەکەوت
      if (fresh is T) {
        await CacheService.save(
          widget.cacheKey,
          fresh,
          duration: widget.cacheDuration,
        );
      }

      setState(() {
        _data = fresh;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ CachedFutureBuilder error: $e');
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
      });
    }
  }

  /// 🔄 دووبارە هێنانەوە (بە سڕینەوەی کاش)
  Future<void> refresh() async {
    await CacheService.remove(widget.cacheKey);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    // ⏳ Loading
    if (_isLoading) {
      return widget.loadingWidget ??
          const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          );
    }

    // ❌ Error
    if (_error != null) {
      if (widget.errorBuilder != null) {
        return widget.errorBuilder!(_error!);
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 60,
                color: Colors.red,
              ),
              const SizedBox(height: 12),
              Text(
                "هەڵە: $_error",
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: refresh,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("دووبارە هەوڵبدە"),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ پشکنینی `_data == null` پێش بەکارهێنان
    if (_data == null) {
      return const Center(
        child: Text(
          "هیچ داتایەک نییە",
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // ⭐ جۆر پشکنراوە پێشتر — `_data as T` پارێزراوە
    // چونکە:
    // ١. `_data` تەنها لە `_loadData` دا دیاری دەکرێت
    // ٢. لە `cached is T` یان `fresh is T` دوای پشکنینی جۆر
    // ٣. `if (_data == null)` پێشتر پشکنراوە
    return widget.builder(context, _data as T);
  }
}