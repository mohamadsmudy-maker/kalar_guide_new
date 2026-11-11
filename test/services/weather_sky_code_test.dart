import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/weather_service.dart';

void main() {
  group('WeatherService.skyCode', () {
    test('thin high cirrus is not "overcast"', () {
      // Open-Meteo: code 3 لەگەڵ تەنها هەوری بەرز
      expect(WeatherService.skyCode(3, low: 0, mid: 0, high: 100), 1);
      expect(WeatherService.skyCode(3, low: 0, mid: 5, high: 30), 0);
    });
    test('real low/mid clouds still count', () {
      expect(WeatherService.skyCode(0, low: 80, mid: 10, high: 0), 3);
      expect(WeatherService.skyCode(1, low: 50, mid: 0, high: 0), 2);
    });
    test('rain, fog, snow codes are kept', () {
      expect(WeatherService.skyCode(61, low: 0, mid: 0, high: 0), 61);
      expect(WeatherService.skyCode(45, low: 0, mid: 0, high: 0), 45);
    });
    test('no layer data → API code', () {
      expect(WeatherService.skyCode(2), 2);
    });
    test('strong sunshine never reads as overcast', () {
      // ١٠:٣٠ ـی کەلار: مۆدێل دەڵێت هەور، بەڵام خۆر سەر دەسووتێنێت
      expect(
        WeatherService.skyCode(3,
            low: 10, mid: 80, high: 90, sunFrac: 0.9, direct: 600),
        1,
      );
      expect(
        WeatherService.skyCode(3, low: 0, mid: 75, high: 0, direct: 400),
        1,
      );
      // خۆری ناوەند → هەوراوی (2) نەک هەوری تەواو (3)
      expect(
        WeatherService.skyCode(3, low: 90, mid: 0, high: 0, sunFrac: 0.4),
        2,
      );
    });
    test('sunshine does not override at night or real overcast', () {
      expect(
        WeatherService.skyCode(3,
            low: 90, mid: 0, high: 0, sunFrac: 0.9, isDay: false),
        3,
      );
      expect(
        WeatherService.skyCode(3,
            low: 95, mid: 60, high: 0, sunFrac: 0.05, direct: 40),
        3,
      );
      // تیشک هەور زیاد ناکات: ئاسمانی ساماڵ هەر ساماڵە
      expect(
        WeatherService.skyCode(0, low: 0, mid: 0, high: 0, sunFrac: 0.0),
        0,
      );
    });
  });
}
