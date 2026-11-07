// test/models/store_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/models/store_service.dart';

void main() {
  group('StoreService.fromJson', () {
    test('لیستی Postgres ({a,b}) دەخوێنێتەوە', () {
      final s = StoreService.fromJson({
        'store_id': '5',
        'title_ku': 'پاسپۆرت',
        'requirements': '{"ناسنامە","وێنە"}',
        'fees': ['  25000 ', '', 'x'],
      });
      expect(s.storeId, 5);
      expect(s.requirements, ['ناسنامە', 'وێنە']);
      expect(s.fees, ['25000', 'x']);
    });

    test('بەهای بنەڕەتی', () {
      final s = StoreService.fromJson({'title_ku': 't', 'store_id': null});
      expect(s.storeId, 0);
      expect(s.requirements, isEmpty);
      expect(s.icon, 'description');
      expect(s.color, '#1E88E5');
      expect(s.isActive, isTrue);
    });

    test('is_active تەنها بە false ناچالاک دەبێت', () {
      expect(StoreService.fromJson({'title_ku': 't', 'is_active': false}).isActive, isFalse);
      expect(StoreService.fromJson({'title_ku': 't', 'is_active': null}).isActive, isTrue);
    });
  });

  test('getTitle بۆ زمانی بەتاڵ دەگەڕێتەوە بۆ کوردی', () {
    final s = StoreService.fromJson({'title_ku': 'ک', 'title_ar': 'ع', 'title_en': ''});
    expect(s.getTitle('ar'), 'ع');
    expect(s.getTitle('en'), 'ک');
  });

  test('toJson بەهای null ناگرێتەوە مەگەر داوا بکرێت', () {
    final s = StoreService.fromJson({'title_ku': 't', 'store_id': 1});
    expect(s.toJson().containsKey('title_ar'), isFalse);
    expect(s.toJson(includeNullables: true).containsKey('title_ar'), isTrue);
    expect(s.toUpdateJson()['updated_at'], isA<String>());
  });
}
