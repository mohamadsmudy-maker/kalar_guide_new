import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/data/repositories/news_repository.dart';
import 'package:kalar_guide_new/models/news.dart';
import 'package:kalar_guide_new/providers/news_providers.dart';
import 'package:kalar_guide_new/screens/news/all_news_screen.dart';

/// هەواڵی ساختە: ٢٥ هەواڵ، تەنها دوایین یەکێکیان «هۆشداری»یە (پەڕەی دووەمە)
class _FakeRepo implements NewsRepository {
  final calls = <int>[];

  News _n(int i, String type) =>
      News(id: '$i', title: 'هەواڵ $i', description: 'd', newsType: type);

  @override
  Future<List<News>> getNews({int page = 0, int pageSize = 20}) async {
    calls.add(page);
    final all = [
      for (var i = 0; i < 24; i++) _n(i, i.isEven ? 'هەواڵ' : 'ئاگاداری'),
      _n(99, 'هۆشداری'),
      _n(100, 'زانیاری'),
    ];
    final from = page * pageSize;
    if (from >= all.length) return [];
    return all.sublist(from, (from + pageSize).clamp(0, all.length));
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('فلتەری جۆر: چیپەکان، پەڕەی دواتر دێنێت، و جۆری نامۆ زیاد دەکات',
      (t) async {
    final repo = _FakeRepo();
    // پانیی ئامێرەکە فراوان تا هەموو چیپەکان دروست ببن (ListView ی ئاسۆیی تەنبا دیارەکان دروست دەکات)
    t.view.physicalSize = const Size(1800, 1200);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(ProviderScope(
      overrides: [newsRepositoryProvider.overrideWithValue(repo)],
      child: const MaterialApp(home: AllNewsScreen()),
    ));
    await t.pumpAndSettle();

    // هەموو + پێنج جۆری ئاسایی
    for (final label in [
      'هەموو', 'هەواڵ', 'ئاگاداری', 'هۆشداری', 'ڕووداو', 'خزمەتگوزاری',
    ]) {
      expect(find.text(label), findsWidgets, reason: label);
    }
    // «هۆشداری» هێشتا لە پەڕەی یەکەمدا نییە
    expect(repo.calls, [0]);

    await t.tap(find.text('هۆشداری').first);
    await t.pumpAndSettle();
    // خۆکار پەڕەی دووەم هات و هەواڵەکەی دۆزرایەوە
    expect(repo.calls, contains(1));
    expect(find.text('هەواڵ 99'), findsOneWidget);
    expect(find.text('هەواڵ 0'), findsNothing);

    // جۆری نامۆ («زانیاری») وەک چیپ زیاد بووە
    expect(find.text('زانیاری'), findsWidgets);
    await t.tap(find.text('زانیاری').first);
    await t.pumpAndSettle();
    expect(find.text('هەواڵ 100'), findsOneWidget);

    // گەڕانەوە بۆ هەموو
    await t.tap(find.text('هەموو').first);
    await t.pumpAndSettle();
    expect(find.text('هەواڵ 0'), findsOneWidget);
  });
}
