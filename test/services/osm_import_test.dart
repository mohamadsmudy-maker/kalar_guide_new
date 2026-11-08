import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/places/osm_import_service.dart';

const _sample = '''
{"elements":[
 {"type":"node","id":1,"lat":34.62,"lon":45.33,"tags":{"amenity":"pharmacy","name":"Pharmacy A","name:ckb":"دەرمانخانەی ئەلف","phone":"0770"}},
 {"type":"way","id":2,"center":{"lat":34.61,"lon":45.34},"tags":{"amenity":"townhall","name":"شارەوانی کەلار"}},
 {"type":"node","id":3,"lat":34.6,"lon":45.3,"tags":{"shop":"supermarket","name":"مارکێتی ڕۆژ"}},
 {"type":"node","id":4,"lat":34.6,"lon":45.3,"tags":{"amenity":"bench"}},
 {"type":"node","id":1,"lat":34.62,"lon":45.33,"tags":{"amenity":"pharmacy","name:ckb":"دەرمانخانەی ئەلف"}}
]}''';

void main() {
  test('parses Overpass JSON: names, centres, kinds, duplicates', () {
    final list = OsmImportService.parse(_sample);
    expect(list.length, 3, reason: 'unnamed bench and duplicate id dropped');
    final ph = list.firstWhere((p) => p.externalId == 'osm:node/1');
    expect(ph.name, 'دەرمانخانەی ئەلف', reason: 'Kurdish name preferred');
    expect(ph.kind, 'pharmacy');
    final th = list.firstWhere((p) => p.externalId == 'osm:way/2');
    expect(th.lat, 34.61);
    expect(th.isGovernment, isTrue);
    expect(list.firstWhere((p) => p.externalId == 'osm:node/3').kind, 'shop:supermarket');
  });

  test('suggests one of the existing categories', () {
    const cats = ['تەندروستی', 'فەرمانگەکان', 'بازاڕ و دوکانەکان', 'چێشتخانە و مێوانخانەکان'];
    expect(OsmImportService.suggestCategory('pharmacy', cats), 'تەندروستی');
    expect(OsmImportService.suggestCategory('townhall', cats), 'فەرمانگەکان');
    expect(OsmImportService.suggestCategory('shop:bakery', cats), 'بازاڕ و دوکانەکان');
    expect(OsmImportService.suggestCategory('cafe', cats), 'چێشتخانە و مێوانخانەکان');
    expect(OsmImportService.suggestCategory('bench', cats), isNull);
  });

  test('finds places that are already in the app', () {
    final p = OsmImportService.parse(_sample).firstWhere((p) => p.externalId == 'osm:way/2');
    expect(OsmImportService.match(p, [{'external_id': 'osm:way/2'}]), OsmMatch.same);
    expect(
      OsmImportService.match(p, [
        {'name': 'شارەوانی  كەلار', 'latitude': 34.6105, 'longitude': 45.3401},
      ]),
      OsmMatch.likely,
    );
    expect(
      OsmImportService.match(p, [
        {'name': 'شارەوانی کەلار', 'latitude': 34.70, 'longitude': 45.40},
      ]),
      OsmMatch.none,
      reason: 'same name far away is another place',
    );
  });
}
