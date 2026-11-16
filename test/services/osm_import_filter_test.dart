import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/places/osm_import_filter.dart';
import 'package:kalar_guide_new/services/places/osm_import_service.dart';

OsmImportRow row(
  String name, {
  String kind = 'cafe',
  String? category,
  String? hood,
  String? phone,
  bool gov = false,
  OsmMatch match = OsmMatch.none,
}) =>
    OsmImportRow(
      OsmPlace(
        externalId: 'osm:node/$name',
        name: name,
        lat: 34.6,
        lng: 45.3,
        kind: kind,
        isGovernment: gov,
        phone: phone,
      ),
      match,
      category,
      neighborhood: hood,
    );

void main() {
  final rows = [
    row('A&S Cafe', category: 'چێشتخانە', hood: 'شەهیدان', phone: '0770'),
    row('GYM 925', kind: 'fitness_centre', hood: 'شەهیدان'),
    row('شارەوانی', kind: 'townhall', category: 'فەرمانگەکان', gov: true),
    row('Old Cafe', category: 'چێشتخانە', match: OsmMatch.same),
  ];
  int n(OsmImportFilter f) => f.apply(rows).length;

  test('بنەڕەت: تەنها نوێکان؛ بێ ئەوە هەموو', () {
    expect(n(const OsmImportFilter()), 3);
    expect(n(const OsmImportFilter(onlyNew: false)), 4);
    expect(const OsmImportFilter().activeCount, 0);
  });

  test('بەش، بێ بەش، جۆر، گەڕەک، دەرەوەی گەڕەک', () {
    expect(n(const OsmImportFilter(category: 'چێشتخانە')), 1);
    expect(n(const OsmImportFilter(category: OsmImportFilter.none)), 1);
    expect(n(const OsmImportFilter(kind: 'townhall')), 1);
    expect(n(const OsmImportFilter(neighborhood: 'شەهیدان')), 2);
    expect(n(const OsmImportFilter(neighborhood: OsmImportFilter.none)), 1);
  });

  test('گەڕان، ژمارە، حکومی، هەڵبژێردراو و تێکەڵکردنیان', () {
    expect(n(const OsmImportFilter(query: ' cafe ')), 1);
    expect(n(const OsmImportFilter(query: 'cafe', onlyNew: false)), 2);
    expect(n(const OsmImportFilter(hasPhone: true)), 1);
    expect(n(const OsmImportFilter(governmentOnly: true)), 1);
    // بنەڕەت: ئەوانە هەڵبژێردراون کە نوێن و بەشیان هەیە
    expect(n(const OsmImportFilter(selectedOnly: true)), 2);
    expect(
      n(const OsmImportFilter(neighborhood: 'شەهیدان', hasPhone: true)),
      1,
    );
  });

  test('copyWith دەتوانێت بەها بکاتەوە null، و cleared تەنها «نوێکان» دەهێڵێتەوە', () {
    const f = OsmImportFilter(category: 'x', query: 'q', onlyNew: false);
    expect(f.activeCount, 2);
    expect(f.copyWith(category: () => null).category, isNull);
    expect(f.copyWith(hasPhone: true).category, 'x');
    final c = f.cleared();
    expect(c.activeCount, 0);
    expect(c.onlyNew, isFalse);
  });

  test('ژماردن بۆ هەڵبژێرەکان: زۆرترین لە پێشەوە، «هیچ» لە کۆتایی', () {
    final c = OsmImportFilter.counts(rows, (r) => r.neighborhood);
    expect(c.first.key, 'شەهیدان');
    expect(c.first.value, 2);
    expect(c.last.key, OsmImportFilter.none);
    expect(c.last.value, 2);
  });
}
