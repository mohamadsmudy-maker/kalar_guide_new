import 'package:flutter/material.dart';  // ⭐ Color + debugPrint
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 🏘️ مۆدێلی گەڕەک — ULTRA PRO
class Neighborhood {
  final String? id;
  final String nameKu;
  final String? nameAr;
  final String? nameEn;
  final String color;
  final int totalStores;
  final int population;
  final double areaKm2;
  final double? centerLatitude;
  final double? centerLongitude;
  final String? descriptionKu;
  final String? coverUrl;
  final String? icon;

  // ═══════════════════════════════════════════════════════════
  // 🗺️ سنووری پۆلیگۆن (لە GeoJSON)
  // ═══════════════════════════════════════════════════════════
  List<LatLng>? _boundary;

  List<LatLng> get boundaryPoints => _boundary ?? [];

  bool get hasBoundary => _boundary != null && _boundary!.length >= 3;

  void setBoundary(List<LatLng> points) {
    _boundary = points;
  }

  bool get hasCenter =>
      centerLatitude != null &&
          centerLongitude != null &&
          centerLatitude != 0 &&
          centerLongitude != 0;

  Neighborhood({
    this.id,
    required this.nameKu,
    this.nameAr,
    this.nameEn,
    this.color = '#1E88E5',
    this.totalStores = 0,
    this.population = 0,
    this.areaKm2 = 0,
    this.centerLatitude,
    this.centerLongitude,
    this.descriptionKu,
    this.coverUrl,
    this.icon,
  });

  // ═══════════════════════════════════════════════════════════
  // 📥 fromJson
  // ═══════════════════════════════════════════════════════════
  factory Neighborhood.fromJson(Map<String, dynamic> json) {
    final neighborhood = Neighborhood(
      id: json['id']?.toString(),
      nameKu: json['name_ku'] as String? ?? '',
      nameAr: json['name_ar'] as String?,
      nameEn: json['name_en'] as String?,
      color: json['color'] as String? ?? '#1E88E5',
      totalStores:
      int.tryParse(json['total_stores']?.toString() ?? '0') ?? 0,
      population:
      int.tryParse(json['population']?.toString() ?? '0') ?? 0,
      areaKm2:
      double.tryParse(json['area_km2']?.toString() ?? '0') ?? 0,
      centerLatitude: json['center_latitude'] != null
          ? double.tryParse(json['center_latitude'].toString())
          : null,
      centerLongitude: json['center_longitude'] != null
          ? double.tryParse(json['center_longitude'].toString())
          : null,
      descriptionKu: json['description_ku'] as String?,
      coverUrl: json['cover_url'] as String?,
      icon: json['icon'] as String?,
    );

    // ✅ پارسکردنی boundary
    final boundaryData = json['boundary'];
    if (boundaryData is List && boundaryData.isNotEmpty) {
      final points = <LatLng>[];

      for (final item in boundaryData) {
        if (item is Map) {
          final lat = double.tryParse(item['lat']?.toString() ?? '');
          final lng = double.tryParse(item['lng']?.toString() ?? '');
          if (lat != null && lng != null && lat != 0 && lng != 0) {
            points.add(LatLng(lat, lng));
          }
        }
      }

      if (points.length >= 3) {
        neighborhood.setBoundary(points);
      } else if (points.isNotEmpty) {
        debugPrint(
          '⚠️ Neighborhood ${neighborhood.nameKu}: boundary تەنها ${points.length} خاڵی هەیە',
        );
      }
    }

    return neighborhood;
  }

  // ═══════════════════════════════════════════════════════════
  // 📤 toJson
  // ═══════════════════════════════════════════════════════════
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name_ku': nameKu,
      'name_ar': nameAr,
      'name_en': nameEn,
      'color': color,
      'total_stores': totalStores,
      'population': population,
      'area_km2': areaKm2,
      'center_latitude': centerLatitude,
      'center_longitude': centerLongitude,
      'description_ku': descriptionKu,
      'cover_url': coverUrl,
      'icon': icon,
      if (_boundary != null && _boundary!.isNotEmpty)
        'boundary': _boundary!
            .map((p) => {
          'lat': p.latitude,
          'lng': p.longitude,
        })
            .toList(),
    };
  }

  /// 🎯 ناوی گونجاو بەپێی زمان
  String getName(String lang) {
    switch (lang) {
      case 'ar':
        return (nameAr?.isEmpty ?? true) ? nameKu : nameAr!;
      case 'en':
        return (nameEn?.isEmpty ?? true) ? nameKu : nameEn!;
      default:
        return nameKu;
    }
  }

  /// 🎨 ڕەنگ وەک Color
  Color get displayColor {
    try {
      String hex = color.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFF1E88E5);
    }
  }

  /// 🗺️ ناوەندی گەڕەک وەک LatLng
  LatLng? get centerLatLng {
    if (!hasCenter) return null;
    return LatLng(centerLatitude!, centerLongitude!);
  }

  /// 🗺️ ناوەندی پۆلیگۆن (ئەگەر center نەبوو)
  LatLng? get computedCenter {
    if (hasCenter) return centerLatLng;
    if (!hasBoundary) return null;

    double sumLat = 0;
    double sumLng = 0;
    for (final p in _boundary!) {
      sumLat += p.latitude;
      sumLng += p.longitude;
    }
    return LatLng(
      sumLat / _boundary!.length,
      sumLng / _boundary!.length,
    );
  }

  Neighborhood copyWith({
    String? id,
    String? nameKu,
    String? nameAr,
    String? nameEn,
    String? color,
    int? totalStores,
    int? population,
    double? areaKm2,
    double? centerLatitude,
    double? centerLongitude,
    String? descriptionKu,
    String? coverUrl,
    String? icon,
  }) {
    final n = Neighborhood(
      id: id ?? this.id,
      nameKu: nameKu ?? this.nameKu,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      color: color ?? this.color,
      totalStores: totalStores ?? this.totalStores,
      population: population ?? this.population,
      areaKm2: areaKm2 ?? this.areaKm2,
      centerLatitude: centerLatitude ?? this.centerLatitude,
      centerLongitude: centerLongitude ?? this.centerLongitude,
      descriptionKu: descriptionKu ?? this.descriptionKu,
      coverUrl: coverUrl ?? this.coverUrl,
      icon: icon ?? this.icon,
    );
    if (_boundary != null) n.setBoundary(_boundary!);
    return n;
  }
}