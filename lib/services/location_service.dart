import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 📍 خزمەتگوزاری شوێن و دووری
class LocationService {
  /// وەرگرتنی شوێنی ئێستای بەکارهێنەر
  static Future<Position?> getCurrentPosition() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      if (permission == LocationPermission.deniedForever) return null;

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {
      return null;
    }
  }

  /// حسابکردنی دووری لە نێوان دوو خاڵ (بە کیلۆمەتر)
  static double calculateDistance(
      double startLat,
      double startLng,
      double endLat,
      double endLng,
      ) {
    double straightLineKm = Geolocator.distanceBetween(
      startLat,
      startLng,
      endLat,
      endLng,
    ) /
        1000;

    // زیادکردنی ڕێژەی ڕێگای ڕاستەقینە (1.3 = فاکتەری ڕێگا)
    return straightLineKm * 1.3;
  }

  /// فۆرماتکردنی دووری بۆ دەقی خوونەوە
  static String formatDistance(double distanceKm) {
    if (distanceKm < 1.0) {
      return '${(distanceKm * 1000).toStringAsFixed(0)} مەتر';
    } else {
      return '${distanceKm.toStringAsFixed(1)} کم';
    }
  }
}

/// 🛑 پشکنینی سنووری شاری کەلار
class KalarBoundaryChecker {
  /// 📍 سنووری ڕاستەقینەی شاری کەلار
  ///
  /// ✅ چارەسەرکرا — ٦ خاڵ بۆ دروستی زیاتر
  static const List<LatLng> _kalarPolygon = [
    // ═══════════════════════════════════════════════════════
    // 🗺️ سنووری شاری کەلار — ٦ خاڵ
    // ═══════════════════════════════════════════════════════
    LatLng(34.6550, 45.3450), // NE
    LatLng(34.6480, 45.3550), // E
    LatLng(34.6050, 45.3350), // SE
    LatLng(34.5950, 45.3050), // SW
    LatLng(34.6050, 45.2850), // W
    LatLng(34.6350, 45.2850), // NW
  ];

  /// پشکنین ئەگەر خاڵێک لە ناو سنووری کەلار بێت
  static bool isWithinKalar(LatLng point) {
    int intersectCount = 0;
    int j = _kalarPolygon.length - 1;

    for (int i = 0; i < _kalarPolygon.length; i++) {
      if ((_kalarPolygon[i].latitude > point.latitude) !=
          (_kalarPolygon[j].latitude > point.latitude) &&
          (point.longitude <
              (_kalarPolygon[j].longitude - _kalarPolygon[i].longitude) *
                  (point.latitude - _kalarPolygon[i].latitude) /
                  (_kalarPolygon[j].latitude - _kalarPolygon[i].latitude) +
                  _kalarPolygon[i].longitude)) {
        intersectCount++;
      }
      j = i;
    }
    return (intersectCount % 2) == 1;
  }

  /// ✅ پشکنینی نزیکەیی — ٥ کم لە ناوەندی کەلار
  static bool isWithinKalarWithBuffer(LatLng point) {
    if (isWithinKalar(point)) return true;

    const centerLat = 34.6189;
    const centerLng = 45.3156;

    final distance = Geolocator.distanceBetween(
      point.latitude,
      point.longitude,
      centerLat,
      centerLng,
    ) /
        1000;

    return distance <= 5.0;
  }
}