import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/data/repositories/news_repository.dart';
import 'package:kalar_guide_new/models/news.dart';
import 'package:kalar_guide_new/providers/news_providers.dart';

/// هەواڵێک کە جۆرەکەی لە داتابەیسدا دەگۆڕدرێت
class _Repo implements NewsRepository {
  String type = 'هەواڵ';
  int calls = 0;

  @override
  Future<List<News>> getNews({int page = 0, int pageSize = 20}) async {
    calls++;
    return [News(id: '1', title: 'نوێکردنەوە', description: 'd', newsType: type)];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('refreshNewsFeed: دوای دەستکاری، سلایدەر جۆری نوێ وەردەگرێت',
      (t) async {
    final repo = _Repo();
    late BuildContext ctx;
    late WidgetRef ref;
    await t.pumpWidget(ProviderScope(
      overrides: [newsRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        home: Consumer(builder: (context, r, _) {
          ctx = context;
          ref = r;
          return Text(r.watch(newsProvider).news.map((n) => n.newsType).join(','));
        }),
      ),
    ));
    await t.pumpAndSettle();
    expect(find.text('هەواڵ'), findsOneWidget);

    // ئەدمین لە داتابەیس دەیگۆڕێت، بەڵام ئەپ هێشتا کۆنەکە پیشان دەدات
    repo.type = 'خزمەتگوزاری';
    expect(ref.read(newsProvider).news.first.newsType, 'هەواڵ');

    refreshNewsFeed(ctx);
    await t.pumpAndSettle();
    expect(find.text('خزمەتگوزاری'), findsOneWidget);
    expect(repo.calls, 2);
  });

  testWidgets('refreshNewsFeed: بێ ProviderScope هەڵە نادات', (t) async {
    late BuildContext ctx;
    await t.pumpWidget(MaterialApp(home: Builder(builder: (c) {
      ctx = c;
      return const SizedBox();
    })));
    expect(() => refreshNewsFeed(ctx), returnsNormally);
  });
}
