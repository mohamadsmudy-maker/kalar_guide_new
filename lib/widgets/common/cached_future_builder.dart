import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../services/cache_service.dart';

/// 🗄️ FutureBuilder لەگەڵ کاش
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

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // هەوڵدان بۆ وەرگرتن لە کاش
      final cached = await CacheService.get(widget.cacheKey);

      if (cached != null) {
        if (mounted) {
          setState(() {
            _data = cached as T;
            _isLoading = false;
          });
        }
        return;
      }

      // ئەگەر نەبوو، هێنان لە سەرچاوە
      final fresh = await widget.fetcher();
      await CacheService.save(
        widget.cacheKey,
        fresh,
        duration: widget.cacheDuration,
      );

      if (mounted) {
        setState(() {
          _data = fresh;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> refresh() async {
    await CacheService.remove(widget.cacheKey);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return widget.loadingWidget ??
          const Center(
            child: CircularProgressIndicator(
              color: AppColors.primary,
            ),
          );
    }

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

    return widget.builder(context, _data as T);
  }
}