// lib/models/neighborhood.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// 🏘️ مۆدێلی گەڕەک — ULTRA PRO MAX
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

  List<LatLng>? _boundary;

  List<LatLng> get boundaryPoints => _boundary ?? [];
  bool get hasBoundary => _boundary != null && _boundary!.length >= 3;
  void setBoundary(List<LatLng> points) => _boundary = points;

  bool get hasCenter =>
      centerLatitude != null &&
          centerLongitude != null &&
          centerLatitude != 0 &&
          centerLongitude != 0;

  int? get idAsInt => int.tryParse(id ?? '');

  String get normalizedColor {
    final c = color.replaceAll('#', '').trim();
    return c.length == 6 ? c : '1E88E5';
  }

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

  // ── helpers ──────────────────────────────────────
  static int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? fallback;
  }

  static double _asDouble(dynamic v, {double fallback = 0.0}) {
    if (v == null) return fallback;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? fallback;
  }

  static double? _asDoubleOrNull(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  // ── fromJson ─────────────────────────────────────
  factory Neighborhood.fromJson(Map<String, dynamic> json) {
    final neighborhood = Neighborhood(
      id: json['id']?.toString(),
      nameKu: json['name_ku']?.toString() ?? '',
      nameAr: json['name_ar']?.toString(),
      nameEn: json['name_en']?.toString(),
      color: json['color']?.toString() ?? '#1E88E5',
      totalStores: _asInt(json['total_stores']),
      population: _asInt(json['population']),
      areaKm2: _asDouble(json['area_km2']),
      centerLatitude: _asDoubleOrNull(json['center_lat']),
      centerLongitude: _asDoubleOrNull(json['center_lng']),
      descriptionKu: json['description_ku']?.toString(),
      coverUrl: json['cover_url']?.toString(),
      icon: json['icon']?.toString(),
    );

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
      }
    }

    return neighborhood;
  }

  // ── toJson ───────────────────────────────────────
  Map<String, dynamic> toJson({
    bool includeId = true,
    bool includeNullables = false,
    bool includeNullBoundary = false,
  }) {
    return {
      if (includeId && id != null) 'id': id,
      'name_ku': nameKu,
      if (includeNullables || nameAr != null) 'name_ar': nameAr,
      if (includeNullables || nameEn != null) 'name_en': nameEn,
      'color': normalizedColor,
      'total_stores': totalStores,
      'population': population,
      'area_km2': areaKm2,
      'center_lat': centerLatitude,
      'center_lng': centerLongitude,
      if (includeNullables || descriptionKu != null)
        'description_ku': descriptionKu,
      if (includeNullables || coverUrl != null) 'cover_url': coverUrl,
      if (includeNullables || icon != null) 'icon': icon,
      if (_boundary != null && _boundary!.isNotEmpty)
        'boundary': _boundary!
            .map((p) => {'lat': p.latitude, 'lng': p.longitude})
            .toList(),
      if (includeNullBoundary && (_boundary == null || _boundary!.isEmpty))
        'boundary': null,
    };
  }

  Map<String, dynamic> toInsertJson() =>
      toJson(includeId: false, includeNullables: false);

  Map<String, dynamic> toUpdateJson({bool clearBoundary = false}) {
    final j = toJson(
      includeId: false,
      includeNullables: true,
      includeNullBoundary: clearBoundary,
    );
    j['updated_at'] = DateTime.now().toUtc().toIso8601String();
    return j;
  }

  // ── getName ──────────────────────────────────────
  String getName(String lang) {
    switch (lang) {
      case 'ar':
        return (nameAr?.trim().isEmpty ?? true) ? nameKu : nameAr!.trim();
      case 'en':
        return (nameEn?.trim().isEmpty ?? true) ? nameKu : nameEn!.trim();
      default:
        return nameKu;
    }
  }

  Color get displayColor {
    try {
      String hex = normalizedColor;
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFF1E88E5);
    }
  }

  LatLng? get centerLatLng {
    if (!hasCenter) return null;
    return LatLng(centerLatitude!, centerLongitude!);
  }

  // ── copyWith (nullable-safe) ──────────────────────
  Neighborhood copyWith({
    String? id,
    bool clearId = false,
    String? nameKu,
    String? nameAr,
    bool clearNameAr = false,
    String? nameEn,
    bool clearNameEn = false,
    String? color,
    int? totalStores,
    int? population,
    double? areaKm2,
    double? centerLatitude,
    bool clearCenterLatitude = false,
    double? centerLongitude,
    bool clearCenterLongitude = false,
    String? descriptionKu,
    bool clearDescriptionKu = false,
    String? coverUrl,
    bool clearCoverUrl = false,
    String? icon,
    bool clearIcon = false,
    List<LatLng>? boundary,
    bool clearBoundary = false,
  }) {
    final n = Neighborhood(
      id: clearId ? null : (id ?? this.id),
      nameKu: nameKu ?? this.nameKu,
      nameAr: clearNameAr ? null : (nameAr ?? this.nameAr),
      nameEn: clearNameEn ? null : (nameEn ?? this.nameEn),
      color: color ?? this.color,
      totalStores: totalStores ?? this.totalStores,
      population: population ?? this.population,
      areaKm2: areaKm2 ?? this.areaKm2,
      centerLatitude: clearCenterLatitude
          ? null
          : (centerLatitude ?? this.centerLatitude),
      centerLongitude: clearCenterLongitude
          ? null
          : (centerLongitude ?? this.centerLongitude),
      descriptionKu:
      clearDescriptionKu ? null : (descriptionKu ?? this.descriptionKu),
      coverUrl: clearCoverUrl ? null : (coverUrl ?? this.coverUrl),
      icon: clearIcon ? null : (icon ?? this.icon),
    );

    if (clearBoundary) {
      // هیچ boundary نەهێڵە
    } else if (boundary != null) {
      n.setBoundary(boundary);
    } else if (_boundary != null) {
      n.setBoundary(_boundary!);
    }

    return n;
  }
}