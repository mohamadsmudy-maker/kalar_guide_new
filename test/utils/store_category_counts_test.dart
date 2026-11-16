import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/utils/store_category_counts.dart';

void main() {
  final stores = <Map<String, dynamic>>[
    {'name': 'a', 'category': 'یاریگا', 'sub_category': 'تۆپی پێ'},
    {'name': 'b', 'category': 'یاریگا', 'sub_category': null},
    {'name': 'c', 'category': ' یاریگا ', 'sub_category': 'تۆپی پێ'},
    {'name': 'd', 'category': 'چێشتخانە'},
    {'name': 'e', 'category': ''},
    {'name': 'f'},
  ];

  test('ژماردن: زۆرترین لە پێشەوە، «بێ بەش» لە کۆتایی، بۆشایی لادەبرێت', () {
    final c = StoreCategoryCounts.count(stores);
    expect(c.map((e) => e.key).toList(),
        ['یاریگا', 'چێشتخانە', StoreCategoryCounts.none]);
    expect(c.map((e) => e.value).toList(), [3, 1, 2]);
  });

  test('ژماردنی ژێربەش لە ناو یەک بەشدا', () {
    final c = StoreCategoryCounts.count(
      stores.where((s) => StoreCategoryCounts.categoryOf(s) == 'یاریگا'),
      field: 'sub_category',
    );
    expect(c.first.key, 'تۆپی پێ');
    expect(c.first.value, 2);
    expect(c.last.key, StoreCategoryCounts.none);
  });

  test('گونجان: هەموو، بەش، بەش + ژێربەش، بێ بەش', () {
    int n({String? cat, String? sub}) => stores
        .where((s) =>
            StoreCategoryCounts.matches(s, category: cat, subCategory: sub))
        .length;
    expect(n(), 6);
    expect(n(cat: 'یاریگا'), 3);
    expect(n(cat: 'یاریگا', sub: 'تۆپی پێ'), 2);
    expect(n(cat: 'یاریگا', sub: StoreCategoryCounts.none), 1);
    expect(n(cat: StoreCategoryCounts.none), 2);
  });
}
