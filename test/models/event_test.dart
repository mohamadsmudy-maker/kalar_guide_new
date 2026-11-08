import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/models/event.dart';

void main() {
  group('AppEvent Model', () {
    test('fromJson دەبێت دروست کار بکات', () {
      final json = {
        'id': '1',
        'title_ku': 'نەورۆز',
        'start_date': '2025-03-21T10:00:00Z',
        'category': 'national',
        'color': '#6C5CE7',
        'is_featured': true,
        'views': 100,
        'interested_count': 50,
      };

      final event = AppEvent.fromJson(json);

      expect(event.id, equals('1'));
      expect(event.titleKu, equals('نەورۆز'));
      expect(event.category, equals('national'));
      expect(event.isFeatured, isTrue);
      expect(event.views, equals(100));
      expect(event.interestedCount, equals(50));
    });

    test('isToday دەبێت دروست کار بکات', () {
      final today = AppEvent(
        titleKu: 'Test',
        startDate: DateTime.now(),
      );

      final tomorrow = AppEvent(
        titleKu: 'Test',
        startDate: DateTime.now().add(const Duration(days: 1)),
      );

      expect(today.isToday, isTrue);
      expect(tomorrow.isToday, isFalse);
    });

    test('daysUntil دەبێت دروست کار بکات', () {
      final future = AppEvent(
        titleKu: 'Test',
        startDate: DateTime.now().add(const Duration(days: 5)),
      );

      expect(future.daysUntil, equals(5));
    });

    test('daysUntil ڕۆژی سالنامەیی دەژمێرێت نەک ٢٤ کاتژمێر', () {
      final now = DateTime.now();
      final tomorrowMorning = DateTime(now.year, now.month, now.day + 1, 0, 1);
      final today = DateTime(now.year, now.month, now.day, 23, 59);
      final yesterday = DateTime(now.year, now.month, now.day - 1, 12);
      expect(AppEvent(titleKu: 'a', startDate: tomorrowMorning).daysUntil, 1);
      expect(AppEvent(titleKu: 'b', startDate: today).daysUntil, 0);
      expect(AppEvent(titleKu: 'c', startDate: yesterday).daysUntil, -1);
    });

    test('hasLocation', () {
      final withLoc = AppEvent(
        titleKu: 'T',
        startDate: DateTime.now(),
        latitude: 34.6,
        longitude: 45.3,
      );

      final withoutLoc = AppEvent(
        titleKu: 'T',
        startDate: DateTime.now(),
      );

      expect(withLoc.hasLocation, isTrue);
      expect(withoutLoc.hasLocation, isFalse);
    });
  });
}