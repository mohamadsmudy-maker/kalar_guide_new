import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/news_repository.dart';
import '../models/news.dart';
import 'providers.dart';

// ═══════════════════════════════════════════════════════════
// 📰 Constants
// ═══════════════════════════════════════════════════════════
const int kNewsPageSize = 20;
const Duration kNewsRequestTimeout = Duration(seconds: 15);

// ═══════════════════════════════════════════════════════════
// 📰 Repository
// ═══════════════════════════════════════════════════════════
final newsRepositoryProvider = Provider<NewsRepository>((ref) {
  final client = ref.watch(supabaseProvider);
  return NewsRepository(client);
});

// ═══════════════════════════════════════════════════════════
// 📰 State
// ═══════════════════════════════════════════════════════════
@immutable
class NewsState {
  final List<News> news;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int page;
  final String? query; // 🔍 search filter
  final String? categoryFilter;
  final DateTime? lastUpdated;

  const NewsState({
    this.news = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.page = 0,
    this.query,
    this.categoryFilter,
    this.lastUpdated,
  });

  bool get isEmpty => news.isEmpty && !isLoading;
  bool get isFiltering =>
      (query != null && query!.isNotEmpty) ||
          (categoryFilter != null && categoryFilter!.isNotEmpty);

  NewsState copyWith({
    List<News>? news,
    bool? isLoading,
    bool? hasMore,
    String? error,
    bool clearError = false,
    int? page,
    String? query,
    bool clearQuery = false,
    String? categoryFilter,
    bool clearCategoryFilter = false,
    DateTime? lastUpdated,
  }) {
    return NewsState(
      news: news ?? this.news,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
      query: clearQuery ? null : (query ?? this.query),
      categoryFilter:
      clearCategoryFilter ? null : (categoryFilter ?? this.categoryFilter),
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is NewsState &&
              runtimeType == other.runtimeType &&
              listEquals(news, other.news) &&
              isLoading == other.isLoading &&
              hasMore == other.hasMore &&
              error == other.error &&
              page == other.page &&
              query == other.query &&
              categoryFilter == other.categoryFilter &&
              lastUpdated == other.lastUpdated;

  @override
  int get hashCode => Object.hash(
    Object.hashAll(news),
    isLoading,
    hasMore,
    error,
    page,
    query,
    categoryFilter,
    lastUpdated,
  );
}

// ═══════════════════════════════════════════════════════════
// 🎯 Notifier
// ═══════════════════════════════════════════════════════════
class NewsNotifier extends StateNotifier<NewsState> {
  final NewsRepository _repo;
  final Ref _ref;
  bool _disposed = false;
  int _requestId = 0; // 🔒 cancels stale requests

  NewsNotifier(this._repo, this._ref) : super(const NewsState()) {
    unawaited(loadInitial());
  }

  void _safeSet(NewsState s) {
    if (_disposed) return;
    state = s;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ───────────────────────────────────────────────────────
  // 📥 Initial load
  // ───────────────────────────────────────────────────────
  Future<void> loadInitial() async {
    if (state.isLoading) return;
    final myId = ++_requestId;

    _safeSet(state.copyWith(isLoading: true, clearError: true));

    try {
      final news = await _repo
          .getNews(page: 0, pageSize: kNewsPageSize)
          .timeout(kNewsRequestTimeout);

      if (myId != _requestId) return; // stale

      _safeSet(NewsState(
        news: news,
        isLoading: false,
        hasMore: news.length >= kNewsPageSize,
        page: 1,
        query: state.query,
        categoryFilter: state.categoryFilter,
        lastUpdated: DateTime.now(),
      ));
    } catch (e, st) {
      if (myId != _requestId) return;
      _ref.read(appLoggerProvider).e('NewsNotifier', 'loadInitial', e, st);
      _safeSet(state.copyWith(isLoading: false, error: _friendlyError(e)));
    }
  }

  // ───────────────────────────────────────────────────────
  // 📥 Load more (pagination)
  // ───────────────────────────────────────────────────────
  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    final myId = ++_requestId;

    _safeSet(state.copyWith(isLoading: true, clearError: true));

    try {
      final more = await _repo
          .getNews(page: state.page, pageSize: kNewsPageSize)
          .timeout(kNewsRequestTimeout);

      if (myId != _requestId) return;

      final existingIds = state.news.map((n) => n.id).toSet();
      final fresh = more.where((n) => !existingIds.contains(n.id)).toList();

      _safeSet(state.copyWith(
        news: [...state.news, ...fresh],
        isLoading: false,
        hasMore: more.length >= kNewsPageSize,
        page: state.page + 1,
        lastUpdated: DateTime.now(),
      ));
    } catch (e, st) {
      if (myId != _requestId) return;
      _ref.read(appLoggerProvider).e('NewsNotifier', 'loadMore', e, st);
      _safeSet(state.copyWith(isLoading: false, error: _friendlyError(e)));
    }
  }

  // ───────────────────────────────────────────────────────
  // 🔄 Refresh
  // ───────────────────────────────────────────────────────
  Future<void> refresh() async {
    _requestId++;
    _safeSet(NewsState(
      query: state.query,
      categoryFilter: state.categoryFilter,
    ));
    await loadInitial();
  }

  // ───────────────────────────────────────────────────────
  // 🔍 Search (client-side filter for now)
  // ───────────────────────────────────────────────────────
  void setQuery(String? query) {
    final q = (query == null || query.trim().isEmpty) ? null : query.trim();
    if (q == state.query) return;
    _safeSet(state.copyWith(
      query: q,
      clearQuery: q == null,
    ));
  }

  // ───────────────────────────────────────────────────────
  // 🏷 Category filter
  // ───────────────────────────────────────────────────────
  void setCategoryFilter(String? category) {
    if (category == state.categoryFilter) return;
    _safeSet(state.copyWith(
      categoryFilter: category,
      clearCategoryFilter: category == null,
    ));
  }

  // ───────────────────────────────────────────────────────
  // 🧮 Derived list (filtered by query + category)
  // ───────────────────────────────────────────────────────
  List<News> get filteredNews {
    final q = state.query?.toLowerCase();
    final cat = state.categoryFilter;
    if (q == null && cat == null) return state.news;

    return state.news.where((n) {
      // ✅ چارەسەری ئاگادارکردنەوەی null (هێڵی ٢٤٢)
      final matchQuery = q == null ||
          n.title.toLowerCase().contains(q) ||
          n.description.toLowerCase().contains(q);

      // ✅ بەکارهێنانی newsType لە جیاتی category چونکە لە مۆدێلەکەدا هەیە
      final matchCategory = cat == null || n.newsType == cat;

      return matchQuery && matchCategory;
    }).toList();
  }

  // ───────────────────────────────────────────────────────
  // 👁 Increment views (optimistic + safe)
  // ───────────────────────────────────────────────────────
  Future<void> incrementViews(String newsId) async {
    final idx = state.news.indexWhere((n) => n.id == newsId);
    if (idx == -1) return;

    final current = state.news[idx];

    // ✅ Optimistic update
    final newList = [...state.news];
    newList[idx] = current.copyWith(views: current.views + 1);
    _safeSet(state.copyWith(news: newList));

    try {
      await _repo
          .incrementViews(newsId, current.views)
          .timeout(const Duration(seconds: 8));
    } catch (e, st) {
      _ref
          .read(appLoggerProvider)
          .w('NewsNotifier', 'incrementViews($newsId)', e, st);
      if (_disposed) return;
      final rollbackIdx = state.news.indexWhere((n) => n.id == newsId);
      if (rollbackIdx != -1) {
        final rb = [...state.news];
        rb[rollbackIdx] =
            rb[rollbackIdx].copyWith(views: rb[rollbackIdx].views - 1);
        _safeSet(state.copyWith(news: rb));
      }
    }
  }

  // ───────────────────────────────────────────────────────
  // 🧹 Helpers
  // ───────────────────────────────────────────────────────
  String _friendlyError(Object e) {
    final s = e.toString();
    if (s.contains('SocketException') || s.contains('timeout')) {
      return 'کێشەی ئینتەرنێت. تکایە دووبارە هەوڵ بدە';
    }
    return s;
  }
}

// ═══════════════════════════════════════════════════════════
// 🎯 Providers
// ═══════════════════════════════════════════════════════════
final newsProvider =
StateNotifierProvider<NewsNotifier, NewsState>((ref) {
  final repo = ref.watch(newsRepositoryProvider);
  return NewsNotifier(repo, ref);
});

// 📰 News by store (auto-refreshable)
final storeNewsProvider =
FutureProvider.autoDispose.family<List<News>, int>((ref, storeId) async {
  final repo = ref.watch(newsRepositoryProvider);
  return repo.getNewsByStore(storeId).timeout(kNewsRequestTimeout);
});

// 🔎 Selectors
final newsListProvider = Provider<List<News>>(
      (ref) => ref.watch(newsProvider.select((s) => s.news)),
);

final filteredNewsProvider = Provider<List<News>>(
      (ref) => ref.watch(newsProvider.notifier).filteredNews,
);

final newsLoadingProvider = Provider<bool>(
      (ref) => ref.watch(newsProvider.select((s) => s.isLoading)),
);

final newsErrorProvider = Provider<String?>(
      (ref) => ref.watch(newsProvider.select((s) => s.error)),
);

final newsHasMoreProvider = Provider<bool>(
      (ref) => ref.watch(newsProvider.select((s) => s.hasMore)),
);

final newsQueryProvider = Provider<String?>(
      (ref) => ref.watch(newsProvider.select((s) => s.query)),
);

final newsCategoryFilterProvider = Provider<String?>(
      (ref) => ref.watch(newsProvider.select((s) => s.categoryFilter)),
);