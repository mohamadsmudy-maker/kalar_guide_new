import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/qibla/qibla_math.dart';

void main() {
  // سەرچاوە: geographiclib (WGS‑84) و pygeomag (WMM‑2025 ی NOAA)
  group('qiblaBearing (WGS‑84)', () {
    const cases = [
      (34.6178, 45.3325, 201.6775), // کەلار
      (34.662, 45.268, 201.3781),
      (36.19, 44.01, 195.0703), // هەولێر
      (51.5, -0.12, 118.8701), // لەندەن
      (-33.9, 151.2, 277.3062), // سیدنی
      (40.7, -74.0, 58.4006), // نیویۆرک
    ];
    for (final (lat, lng, want) in cases) {
      test('$lat,$lng', () {
        expect(QiblaMath.qiblaBearing(lat, lng), closeTo(want, 0.001));
      });
    }
  });

  group('magneticDeclination (WMM‑2025)', () {
    double year(double y) => y;
    DateTime at(double y) {
      final whole = y.floor();
      final start = DateTime.utc(whole);
      final len = DateTime.utc(whole + 1).difference(start).inSeconds;
      return start.add(Duration(seconds: ((y - whole) * len).round()));
    }

    const cases = [
      (34.6178, 45.3325, 2026.86, 5.0396),
      (34.662, 45.268, 2028.5, 5.062),
      (36.19, 44.01, 2026.86, 5.4674),
      (51.5, -0.12, 2028.5, 1.506),
      (-33.9, 151.2, 2026.86, 12.8381),
      (40.7, -74.0, 2028.5, -12.3959),
      (21.42, 39.83, 2026.86, 3.5005),
    ];
    for (final (lat, lng, y, want) in cases) {
      test('$lat,$lng @ ${year(y)}', () {
        expect(QiblaMath.magneticDeclination(lat, lng, at: at(y)), closeTo(want, 0.01));
      });
    }
  });
}
