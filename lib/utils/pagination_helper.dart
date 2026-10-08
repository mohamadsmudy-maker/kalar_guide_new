import 'package:flutter/foundation.dart';

/// 📄 یاریدەدەر بۆ Pagination
class PaginationHelper<T> {
  final int pageSize;
  int _currentPage = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final List<T> _items = [];

  PaginationHelper({this.pageSize = 20});

  // ═══════════════════════════════════════════════════════════
  // 🔍 Getters
  // ═══════════════════════════════════════════════════════════
  List<T> get items => _items;
  int get currentPage => _currentPage;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get isEmpty => _items.isEmpty;

  // ═══════════════════════════════════════════════════════════
  // 📥 هێنانی داتا
  // ═══════════════════════════════════════════════════════════
  Future<void> loadFirstPage(
      Future<List<T>> Function(int from, int to) fetcher,
      ) async {
    _currentPage = 0;
    _items.clear();
    _hasMore = true;
    await loadMore(fetcher);
  }

  Future<void> loadMore(
      Future<List<T>> Function(int from, int to) fetcher,
      ) async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;

    try {
      final from = _currentPage * pageSize;
      final to = from + pageSize - 1;

      final newItems = await fetcher(from, to);

      if (newItems.length < pageSize) {
        _hasMore = false;
      }

      _items.addAll(newItems);
      _currentPage++;
    } catch (e) {
      debugPrint('❌ Pagination error: $e');
      _hasMore = false;
    } finally {
      _isLoadingMore = false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔄 گەڕاندنەوە
  // ═══════════════════════════════════════════════════════════
  void reset() {
    _currentPage = 0;
    _items.clear();
    _hasMore = true;
    _isLoadingMore = false;
  }

  // ═══════════════════════════════════════════════════════════
  // ➕ زیادکردن / 🗑️ سڕینەوە
  // ═══════════════════════════════════════════════════════════
  void add(T item) => _items.insert(0, item);

  void removeWhere(bool Function(T) test) {
    _items.removeWhere(test);
  }
}