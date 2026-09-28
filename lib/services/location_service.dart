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
        desiredAccuracy: LocationAccuracy.high,
      );
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

  /// فۆرماتکردنی دووری بۆ دەقی خوێندنەوە
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
  // 📍 ٤ گۆشەی سنووری کەلار
  static final List<LatLng> _kalarPolygon = [
    const LatLng(34.69050, 45.44992),
    const LatLng(34.72392, 45.43050),
    const LatLng(34.59240, 45.31278),
    const LatLng(34.64018, 45.26110),
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
}