// lib/utils/pagination_helper.dart

import 'package:flutter/foundation.dart';

/// 📄 یاریدەدەر بۆ Pagination — Ultra Pro Max
class PaginationHelper<T> extends ChangeNotifier {
  final int pageSize;
  int _currentPage = 0;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  final List<T> _items = [];
  String? _lastError;

  PaginationHelper({this.pageSize = 20}) {
    if (pageSize < 1) {
      throw ArgumentError('pageSize دەبێت گەورەتر بێت لە ٠');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🔍 Getters
  // ═══════════════════════════════════════════════════════════
  List<T> get items => List.unmodifiable(_items);
  int get currentPage => _currentPage;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasMore => _hasMore;
  bool get isEmpty => _items.isEmpty;
  String? get lastError => _lastError;

  // ═══════════════════════════════════════════════════════════
  // 📥 هێنانی داتا
  // ═══════════════════════════════════════════════════════════
  Future<bool> loadFirstPage(
      Future<List<T>> Function(int from, int to) fetcher, {
        void Function(Object error)? onError,
      }) async {
    _currentPage = 0;
    _items.clear();
    _hasMore = true;
    _lastError = null;
    notifyListeners();
    return loadMore(fetcher, onError: onError);
  }

  Future<bool> loadMore(
      Future<List<T>> Function(int from, int to) fetcher, {
        void Function(Object error)? onError,
      }) async {
    if (_isLoadingMore || !_hasMore) return false;

    _isLoadingMore = true;
    _lastError = null;
    notifyListeners();

    try {
      final from = _currentPage * pageSize;
      final to = from + pageSize - 1;

      final newItems = await fetcher(from, to);

      if (newItems.length < pageSize) {
        _hasMore = false;
      }

      _items.addAll(newItems);
      _currentPage++;
      return newItems.isNotEmpty;
    } catch (e) {
      _lastError = e.toString();
      _hasMore = false;
      debugPrint('❌ Pagination error: $e');
      onError?.call(e);
      return false;
    } finally {
      _isLoadingMore = false;
      notifyListeners();
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
    _lastError = null;
    notifyListeners();
  }

  // ═══════════════════════════════════════════════════════════
  // ➕ زیادکردن / 🗑️ سڕینەوە
  // ═══════════════════════════════════════════════════════════
  void add(T item) {
    _items.insert(0, item);
    notifyListeners();
  }

  void addAll(List<T> newItems) {
    _items.addAll(newItems);
    notifyListeners();
  }

  void removeWhere(bool Function(T) test) {
    // ⚠️ چاکسازی: پێش سڕینەوە درێژی دەپشکنین
    final lengthBefore = _items.length;
    _items.removeWhere(test);
    final lengthAfter = _items.length;

    // تەنها کاتێک notify دەکەین کە بەڕاستی شتێک سڕاوەتەوە
    if (lengthBefore != lengthAfter) {
      notifyListeners();
    }
  }

  void clear() {
    _items.clear();
    _currentPage = 0;
    _hasMore = true;
    _lastError = null;
    notifyListeners();
  }

  void updateAt(int index, T newItem) {
    if (index >= 0 && index < _items.length) {
      _items[index] = newItem;
      notifyListeners();
    }
  }
}