// lib/services/qibla/qibla_math.dart
import 'dart:math' as math;

import 'wmm2025_coefficients.dart';

/// 🧭 ژمێریاری وردی قیبلە
///
/// - [qiblaBearing]: ئاراستەی قیبلە لە باکووری ڕاستەقینەوە، لەسەر ئێلیپسۆیدی
///   WGS‑84 (Vincenty) — وردتر لە فۆرمولی گۆی ساکار.
/// - [magneticDeclination]: جیاوازی باکووری موگناتیسی و ڕاستەقینە بە مۆدێلی
///   WMM‑2025 ی NOAA. کۆمپاسی ئەندرۆید باکووری موگناتیسی دەدات، بۆیە بەبێ ئەم
///   ڕاستکردنەوەیە لە کەلار نزیکەی ٥° هەڵە دەبێت.
class QiblaMath {
  QiblaMath._();

  /// ناوەندی کەعبەی پیرۆز
  static const double kaabaLat = 21.422487;
  static const double kaabaLng = 39.826206;

  static double _rad(double d) => d * math.pi / 180;
  static double _deg(double r) => r * 180 / math.pi;
  static double norm360(double a) => ((a % 360) + 360) % 360;

  // ═══════════════════════════════════════════════════════════
  // 📐 Vincenty inverse — ئاراستەی سەرەتایی لەسەر WGS‑84
  // ═══════════════════════════════════════════════════════════
  static double qiblaBearing(double lat, double lng) =>
      _vincentyBearing(lat, lng, kaabaLat, kaabaLng) ?? greatCircleBearing(lat, lng);

  /// فۆرمولی گۆی (بۆ بەراورد / ئەگەر Vincenty یەکنەگرتەوە)
  static double greatCircleBearing(double lat, double lng) {
    final p1 = _rad(lat), p2 = _rad(kaabaLat);
    final dl = _rad(kaabaLng - lng);
    final y = math.sin(dl) * math.cos(p2);
    final x = math.cos(p1) * math.sin(p2) - math.sin(p1) * math.cos(p2) * math.cos(dl);
    return norm360(_deg(math.atan2(y, x)));
  }

  static double? _vincentyBearing(double lat1, double lon1, double lat2, double lon2) {
    const f = 1 / 298.257223563;
    final l = _rad(lon2 - lon1);
    final u1 = math.atan((1 - f) * math.tan(_rad(lat1)));
    final u2 = math.atan((1 - f) * math.tan(_rad(lat2)));
    final sinU1 = math.sin(u1), cosU1 = math.cos(u1);
    final sinU2 = math.sin(u2), cosU2 = math.cos(u2);

    var lambda = l;
    double sinLambda = 0, cosLambda = 0;
    for (var i = 0; i < 200; i++) {
      sinLambda = math.sin(lambda);
      cosLambda = math.cos(lambda);
      final t1 = cosU2 * sinLambda;
      final t2 = cosU1 * sinU2 - sinU1 * cosU2 * cosLambda;
      final sinSigma = math.sqrt(t1 * t1 + t2 * t2);
      if (sinSigma == 0) return 0; // هەمان شوێن
      final cosSigma = sinU1 * sinU2 + cosU1 * cosU2 * cosLambda;
      final sigma = math.atan2(sinSigma, cosSigma);
      final sinAlpha = cosU1 * cosU2 * sinLambda / sinSigma;
      final cos2Alpha = 1 - sinAlpha * sinAlpha;
      final cos2SigmaM = cos2Alpha == 0 ? 0.0 : cosSigma - 2 * sinU1 * sinU2 / cos2Alpha;
      final c = f / 16 * cos2Alpha * (4 + f * (4 - 3 * cos2Alpha));
      final prev = lambda;
      lambda = l +
          (1 - c) *
              f *
              sinAlpha *
              (sigma +
                  c * sinSigma * (cos2SigmaM + c * cosSigma * (-1 + 2 * cos2SigmaM * cos2SigmaM)));
      if ((lambda - prev).abs() < 1e-12) {
        final y = cosU2 * math.sin(lambda);
        final x = cosU1 * sinU2 - sinU1 * cosU2 * math.cos(lambda);
        return norm360(_deg(math.atan2(y, x)));
      }
    }
    return null; // یەکنەگرتەوە (تەنها بۆ خاڵی دژبەری کەعبە)
  }

  // ═══════════════════════════════════════════════════════════
  // 🧲 WMM‑2025 — لادانی موگناتیسی (declination)
  // ═══════════════════════════════════════════════════════════
  static const int _maxOrd = 12;
  static const int _size = 13;
  static List<List<double>>? _c, _cd, _k;
  static List<double>? _snorm;

  static void _load() {
    if (_c != null) return;
    final c = List.generate(_size, (_) => List.filled(_size, 0.0));
    final cd = List.generate(_size, (_) => List.filled(_size, 0.0));
    final k = List.generate(_size, (_) => List.filled(_size, 0.0));
    final snorm = List.filled(_size * _size, 0.0);

    for (final row in wmmCoefficients) {
      final n = row[0].toInt(), m = row[1].toInt();
      c[m][n] = row[2];
      cd[m][n] = row[4];
      if (m != 0) {
        c[n][m - 1] = row[3];
        cd[n][m - 1] = row[5];
      }
    }

    // Schmidt → unnormalized
    snorm[0] = 1.0;
    for (var n = 1; n <= _maxOrd; n++) {
      snorm[n] = snorm[n - 1] * (2 * n - 1) / n;
      var j = 2;
      for (var m = 0; m <= n; m++) {
        k[m][n] = ((n - 1) * (n - 1) - m * m) / ((2 * n - 1) * (2 * n - 3));
        if (m > 0) {
          final flnmj = ((n - m + 1) * j) / (n + m);
          snorm[n + m * _size] = snorm[n + (m - 1) * _size] * math.sqrt(flnmj);
          j = 1;
          c[n][m - 1] = snorm[n + m * _size] * c[n][m - 1];
          cd[n][m - 1] = snorm[n + m * _size] * cd[n][m - 1];
        }
        c[m][n] = snorm[n + m * _size] * c[m][n];
        cd[m][n] = snorm[n + m * _size] * cd[m][n];
      }
    }
    k[1][1] = 0.0;
    _c = c;
    _cd = cd;
    _k = k;
    _snorm = snorm;
  }

  /// ساڵی دەیی (بۆ نموونە 2026.86)
  static double decimalYear(DateTime t) {
    final start = DateTime.utc(t.year);
    final end = DateTime.utc(t.year + 1);
    return t.year + t.toUtc().difference(start).inSeconds / end.difference(start).inSeconds;
  }

  /// لادانی موگناتیسی بە پلە (+ = ڕۆژهەڵات). [altKm] بەرزی لە ئاستی دەریا.
  static double magneticDeclination(double lat, double lng, {DateTime? at, double altKm = 0}) {
    _load();
    final c = _c!, cd = _cd!, k = _k!;
    final p = List<double>.from(_snorm!);
    final fn = [for (var n = 0; n < _size; n++) n + 1.0];
    final fm = [for (var m = 0; m < _size; m++) m.toDouble()];

    final tc = List.generate(_size, (_) => List.filled(_size, 0.0));
    final dp = List.generate(_size, (_) => List.filled(_size, 0.0));
    final sp = List.filled(_size, 0.0);
    final cp = List.filled(_size, 0.0);
    final pp = List.filled(_size, 0.0);
    cp[0] = pp[0] = 1.0;

    const a = 6378.137, b = 6356.7523142, re = 6371.2;
    const a2 = a * a, b2 = b * b, c2 = a2 - b2;
    const a4 = a2 * a2, b4 = b2 * b2, c4 = a4 - b4;

    // دەرەوەی ماوەی مۆدێل: نزیکترین ساڵی دروست بەکاردێت
    final dt = (decimalYear(at ?? DateTime.now()) - wmmEpoch).clamp(0.0, 5.0);

    final rlon = _rad(lng), rlat = _rad(lat);
    final srlon = math.sin(rlon), srlat = math.sin(rlat);
    final crlon = math.cos(rlon), crlat = math.cos(rlat);
    final srlat2 = srlat * srlat, crlat2 = crlat * crlat;
    sp[1] = srlon;
    cp[1] = crlon;

    final q = math.sqrt(a2 - c2 * srlat2);
    final q1 = altKm * q;
    final q2 = ((q1 + a2) / (q1 + b2)) * ((q1 + a2) / (q1 + b2));
    final ct = srlat / math.sqrt(q2 * crlat2 + srlat2);
    final st = math.sqrt(1.0 - ct * ct);
    final r2 = altKm * altKm + 2.0 * q1 + (a4 - c4 * srlat2) / (q * q);
    final r = math.sqrt(r2);
    final d = math.sqrt(a2 * crlat2 + b2 * srlat2);
    final ca = (altKm + d) / r;
    final sa = c2 * crlat * srlat / (r * d);

    for (var m = 2; m <= _maxOrd; m++) {
      sp[m] = sp[1] * cp[m - 1] + cp[1] * sp[m - 1];
      cp[m] = cp[1] * cp[m - 1] - sp[1] * sp[m - 1];
    }

    final aor = re / r;
    var ar = aor * aor;
    double br = 0, bt = 0, bp = 0, bpp = 0;

    for (var n = 1; n <= _maxOrd; n++) {
      ar *= aor;
      for (var m = 0; m <= n; m++) {
        if (n == m) {
          p[n + m * _size] = st * p[n - 1 + (m - 1) * _size];
          dp[m][n] = st * dp[m - 1][n - 1] + ct * p[n - 1 + (m - 1) * _size];
        } else if (n == 1 && m == 0) {
          p[n + m * _size] = ct * p[n - 1 + m * _size];
          dp[m][n] = ct * dp[m][n - 1] - st * p[n - 1 + m * _size];
        } else if (n > 1 && n != m) {
          if (m > n - 2) {
            p[n - 2 + m * _size] = 0.0;
            dp[m][n - 2] = 0.0;
          }
          p[n + m * _size] = ct * p[n - 1 + m * _size] - k[m][n] * p[n - 2 + m * _size];
          dp[m][n] = ct * dp[m][n - 1] - st * p[n - 1 + m * _size] - k[m][n] * dp[m][n - 2];
        }

        tc[m][n] = c[m][n] + dt * cd[m][n];
        if (m != 0) tc[n][m - 1] = c[n][m - 1] + dt * cd[n][m - 1];

        final par = ar * p[n + m * _size];
        double temp1, temp2;
        if (m == 0) {
          temp1 = tc[m][n] * cp[m];
          temp2 = tc[m][n] * sp[m];
        } else {
          temp1 = tc[m][n] * cp[m] + tc[n][m - 1] * sp[m];
          temp2 = tc[m][n] * sp[m] - tc[n][m - 1] * cp[m];
        }
        bt -= ar * temp1 * dp[m][n];
        bp += fm[m] * temp2 * par;
        br += fn[n] * temp1 * par;

        if (st == 0.0 && m == 1) {
          pp[n] = n == 1 ? pp[n - 1] : ct * pp[n - 1] - k[m][n] * pp[n - 2];
          bpp += fm[m] * temp2 * ar * pp[n];
        }
      }
    }
    bp = st == 0.0 ? bpp : bp / st;

    final bx = -bt * ca - br * sa;
    final by = bp;
    return _deg(math.atan2(by, bx));
  }
}
