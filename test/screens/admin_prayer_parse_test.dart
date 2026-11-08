// test/screens/admin_prayer_parse_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/screens/admin/admin_prayer_times.dart';

void main() {
  test('پەیستکردنی دێڕەکان وەک ئامۆژگاری', () {
    final r = parseMonth('''
7 05:05 06:30 11:47 02:37 05:04 06:15
٨  ٠٥:٠٦  ٠٦:٣١  ١١:٤٧  ٠٢:٣٧  ٠٥:٠٣  ٠٦:١٥
''', 11, 2028);
    expect(r.error, isNull);
    expect(r.days['07-11'], {
      'fajr': '05:05', 'sunrise': '06:30', 'dhuhr': '11:47',
      'asr': '14:37', 'maghrib': '17:04', 'isha': '18:15',
    });
    expect(r.days['08-11']!['maghrib'], '17:03');
  });

  test('هەڵەکان بە ژمارەی دێڕ', () {
    expect(parseMonth('7 05:05 06:30', 11, 2028).error, contains('دێڕی 1'));
    expect(parseMonth('31 05:05 06:30 11:47 02:37 05:04 06:15', 11, 2028).error, contains('ڕۆژی هەڵە'));
    expect(parseMonth('7 06:40 06:30 11:47 02:37 05:04 06:15', 11, 2028).error, contains('ڕیز'));
    expect(parseMonth('', 11, 2028).error, isNotNull);
  });

  test('٢٩ی شوبات', () {
    expect(parseMonth('29 05:30 06:50 12:00 03:10 05:45 07:00', 2, 2028).error, isNull);
  });
}
