import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositories/news_repository.dart';
import '../models/news.dart';
import 'providers.dart';

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
class NewsState {
  final List<News> news;
  final bool isLoading;
  final bool hasMore;
  final String? error;
  final int page;

  const NewsState({
    this.news = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.error,
    this.page = 0,
  });

  NewsState copyWith({
    List<News>? news,
    bool? isLoading,
    bool? hasMore,
    String? error,
    int? page,
  }) {
    return NewsState(
      news: news ?? this.news,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      error: error,
      page: page ?? this.page,
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🎯 Notifier
// ═══════════════════════════════════════════════════════════
class NewsNotifier extends StateNotifier<NewsState> {
  final NewsRepository _repo;
  static const int _pageSize = 20;

  NewsNotifier(this._repo) : super(const NewsState()) {
    loadInitial();
  }

  Future<void> loadInitial() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);

    try {
      final news = await _repo.getNews(page: 0, pageSize: _pageSize);
      state = NewsState(
        news: news,
        isLoading: false,
        hasMore: news.length >= _pageSize,
        page: 1,
      );
    } catch (e) {
      debugPrint('❌ NewsNotifier.loadInitial: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || !state.hasMore) return;
    state = state.copyWith(isLoading: true);

    try {
      final more = await _repo.getNews(
        page: state.page,
        pageSize: _pageSize,
      );
      state = state.copyWith(
        news: [...state.news, ...more],
        isLoading: false,
        hasMore: more.length >= _pageSize,
        page: state.page + 1,
      );
    } catch (e) {
      debugPrint('❌ NewsNotifier.loadMore: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh() async {
    state = const NewsState();
    await loadInitial();
  }

  Future<void> incrementViews(String newsId) async {
    final idx = state.news.indexWhere((n) => n.id == newsId);
    if (idx == -1) return;

    final news = state.news[idx];
    final updated = news.copyWith(views: news.views + 1);

    final newList = [...state.news];
    newList[idx] = updated;
    state = state.copyWith(news: newList);

    await _repo.incrementViews(newsId, news.views);
  }
}

// ═══════════════════════════════════════════════════════════
// 🎯 Providers
// ═══════════════════════════════════════════════════════════
final newsProvider =
StateNotifierProvider<NewsNotifier, NewsState>((ref) {
  final repo = ref.watch(newsRepositoryProvider);
  return NewsNotifier(repo);
});

final storeNewsProvider =
FutureProvider.family<List<News>, int>((ref, storeId) async {
  final repo = ref.watch(newsRepositoryProvider);
  return await repo.getNewsByStore(storeId);
});