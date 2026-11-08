// test/models/neighborhood_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/models/neighborhood.dart';

void main() {
  group('Neighborhood.fromJson', () {
    test('ژمارەکان لە string و num دەخوێنێتەوە', () {
      final n = Neighborhood.fromJson({
        'id': 7,
        'name_ku': 'شەهیدان',
        'total_stores': '12',
        'population': 3400.0,
        'area_km2': '1.5',
        'center_lat': '34.63',
        'center_lng': 45.32,
      });
      expect(n.id, '7');
      expect(n.totalStores, 12);
      expect(n.population, 3400);
      expect(n.areaKm2, 1.5);
      expect(n.centerLatitude, 34.63);
      expect(n.centerLongitude, 45.32);
    });

    test('بەهای هەڵە دەبێتە fallback نەک exception', () {
      final n = Neighborhood.fromJson({
        'name_ku': 'x',
        'total_stores': 'abc',
        'area_km2': null,
        'center_lat': 'bad',
      });
      expect(n.totalStores, 0);
      expect(n.areaKm2, 0.0);
      expect(n.centerLatitude, isNull);
    });

    test('سنوور: خاڵی 0 و هەڵە لادەبرێن، کەمتر لە ٣ خاڵ = بێ سنوور', () {
      final few = Neighborhood.fromJson({
        'name_ku': 'x',
        'boundary': [
          {'lat': 34.6, 'lng': 45.3},
          {'lat': 0, 'lng': 0},
          {'lat': 'bad', 'lng': 45.3},
          {'lat': 34.7, 'lng': 45.4},
        ],
      });
      expect(few.hasBoundary, isFalse);

      final ok = Neighborhood.fromJson({
        'name_ku': 'x',
        'boundary': [
          {'lat': 34.6, 'lng': 45.3},
          {'lat': '34.7', 'lng': '45.4'},
          {'lat': 34.8, 'lng': 45.2},
        ],
      });
      expect(ok.hasBoundary, isTrue);
      expect(ok.boundaryPoints.length, 3);
      expect(ok.toJson()['boundary'], hasLength(3));
    });
  });

  group('Neighborhood.getName', () {
    final n = Neighborhood.fromJson({
      'name_ku': 'گەڕەک',
      'name_ar': '  حي  ',
      'name_en': '   ',
    });

    test('عەرەبی trim دەکرێت', () => expect(n.getName('ar'), 'حي'));
    test('ئینگلیزی بەتاڵ → کوردی', () => expect(n.getName('en'), 'گەڕەک'));
    test('زمانی نەناسراو → کوردی', () => expect(n.getName('fr'), 'گەڕەک'));
  });

  group('Neighborhood JSON بۆ داتابەیس', () {
    test('toInsertJson ئایدی ناگرێتەوە', () {
      final n = Neighborhood.fromJson({'id': 1, 'name_ku': 'x'});
      expect(n.toInsertJson().containsKey('id'), isFalse);
    });

    test('toUpdateJson(clearBoundary) سنوور دەکاتە null', () {
      final n = Neighborhood.fromJson({'name_ku': 'x'});
      final j = n.toUpdateJson(clearBoundary: true);
      expect(j.containsKey('boundary'), isTrue);
      expect(j['boundary'], isNull);
      expect(j['updated_at'], isA<String>());
    });
  });
}
