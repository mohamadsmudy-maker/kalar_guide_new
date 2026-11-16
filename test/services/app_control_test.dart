// ignore_for_file: prefer_const_literals_to_create_immutables
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/admin_stats.dart';
import 'package:kalar_guide_new/services/app_control.dart';

void main() {
  group('AppControlState', () {
    test('بێ هیچ ڕیزێک هەموو شتێک کراوەیە', () {
      final s = AppControlState.fromRows(const []);
      expect(s.maintenance, isFalse);
      expect(s.hasAnnouncement, isFalse);
      expect(s.needsUpdate('1.0.0'), isFalse);
      for (final k in AppControlState.featureKeys) {
        expect(s.feature(k), isTrue, reason: k);
      }
    });

    test('خوێندنەوەی هەموو کلیلەکان', () {
      final s = AppControlState.fromRows([
        {'key': 'maintenance', 'value': {'enabled': true, 'message': ' کاتێک '}},
        {'key': 'announcement', 'value': {'enabled': true, 'text': 'سڵاو', 'level': 'warning'}, 'updated_at': 'x'},
        {'key': 'min_version', 'value': {'version': '1.2.0', 'message': 'm', 'url': 'https://p'}},
        {'key': 'features', 'value': {'gallery': false, 'videos': true}},
        {'key': 'place_suggestions_enabled', 'value': false},
      ]);
      expect(s.maintenance, isTrue);
      expect(s.maintenanceMessage, 'کاتێک');
      expect(s.hasAnnouncement, isTrue);
      expect(s.announcementLevel, AnnounceLevel.warning);
      expect(s.minVersion, '1.2.0');
      expect(s.updateUrl, 'https://p');
      expect(s.feature('gallery'), isFalse);
      expect(s.feature('videos'), isTrue);
      expect(s.feature('events'), isTrue); // نەنووسراو = کراوە
      expect(s.feature('suggest_place'), isFalse); // لە کلیلە کۆنەکەوە
    });

    test('ڕاگەیاندنی بێ دەق نیشان نادرێت، و ناسنامەکەی دەگۆڕێت بە دەق', () {
      final a = AppControlState.fromRows([
        {'key': 'announcement', 'value': {'enabled': true, 'text': ''}},
      ]);
      expect(a.hasAnnouncement, isFalse);
      final b = AppControlState.fromRows([
        {'key': 'announcement', 'value': {'enabled': true, 'text': 'یەک'}},
      ]);
      final c = AppControlState.fromRows([
        {'key': 'announcement', 'value': {'enabled': true, 'text': 'دوو'}},
      ]);
      expect(b.announcementId, isNot(c.announcementId));
    });

    test('بەراوردی وەشان', () {
      expect(AppControlState.compareVersions('1.2.0', '1.10.0'), -1);
      expect(AppControlState.compareVersions('1.10.0', '1.2.0'), 1);
      expect(AppControlState.compareVersions('1.1.0+2', '1.1.0'), 0);
      expect(AppControlState.compareVersions('2', '1.9.9'), 1);
      final s = AppControlState.fromRows([
        {'key': 'min_version', 'value': {'version': '1.2.0'}},
      ]);
      expect(s.needsUpdate('1.1.0'), isTrue);
      expect(s.needsUpdate('1.2.0'), isFalse);
      expect(s.needsUpdate('2.0.0'), isFalse);
    });
  });

  group('AdminStats', () {
    final json = {
      'days': 7,
      'totals': {'places': 141, 'users': 30},
      'complaints': {
        'now': 6, 'prev': 4, 'pending': 3, 'resolved': 2,
        'daily': [
          {'d': '2026-11-10', 'n': 1},
          {'d': '2026-11-11', 'n': 5},
        ],
        'by_status': {'pending': 3, 'completed': 2},
        'top_neighborhoods': [
          {'name': 'ئازادی', 'n': 4}
        ],
        'avg_resolution_hours': 30.5,
      },
      'users': {'now': 0, 'prev': 3, 'online': 2, 'daily': [], 'by_role': {'customer': 5}},
      'places': null,
      'search': {
        'now': 9, 'prev': 0,
        'no_results': [
          {'name': 'کباب', 'n': 3}
        ],
      },
    };

    test('parse', () {
      final s = AdminStats.fromJson(Map<String, dynamic>.from(json));
      expect(s.days, 7);
      expect(s.totals!['places'], 141);
      expect(s.complaints!.now, 6);
      expect(s.complaintsDaily.length, 2);
      expect(s.complaintsDaily.last.n, 5);
      expect(s.topNeighborhoods.single.name, 'ئازادی');
      expect(s.avgResolutionHours, 30.5);
      expect(s.online, 2);
      expect(s.places, isNull); // بەشی نەبوو
      expect(s.noResults.single.name, 'کباب');
      expect(s.resolvedRate, closeTo(33.3, 0.1));
    });

    test('ڕێژەی گۆڕان', () {
      expect(const StatPair(6, 4).deltaPct, 50);
      expect(const StatPair(0, 3).deltaPct, -100);
      expect(const StatPair(0, 0).deltaPct, 0);
      expect(const StatPair(5, 0).deltaPct, isNull);
    });

    test('پوختەی شەیرکردن گەڕانی بێ ئەنجام لەخۆ دەگرێت', () {
      final s = AdminStats.fromJson(Map<String, dynamic>.from(json));
      final text = s.summary((x) => x);
      expect(text, contains('کباب'));
      expect(text, contains('6'));
    });

    test('داتای خراپ هەڵە نادات', () {
      final s = AdminStats.fromJson({'days': 'x', 'complaints': 5, 'users': {'daily': 'z'}});
      expect(s.days, 0);
      expect(s.complaints, isNull);
      expect(s.usersDaily, isEmpty);
    });
  });
}
