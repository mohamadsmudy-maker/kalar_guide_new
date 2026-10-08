/// 🏘️ مۆدێلی گەڕەک
class Neighborhood {
  final String? id;
  final String nameKu;
  final String? nameAr;
  final String? nameEn;
  final String? descriptionKu;
  final String? descriptionAr;
  final String? descriptionEn;
  final String? imageUrl;
  final String? coverUrl;
  final String color;
  final String icon;
  final List<Map<String, double>> boundaryPoints;
  final double? centerLatitude;
  final double? centerLongitude;
  final int population;
  final double areaKm2;
  final int totalStores;
  final bool isMain;
  final int displayOrder;
  final bool isActive;

  Neighborhood({
    this.id,
    required this.nameKu,
    this.nameAr,
    this.nameEn,
    this.descriptionKu,
    this.descriptionAr,
    this.descriptionEn,
    this.imageUrl,
    this.coverUrl,
    this.color = '#1E88E5',
    this.icon = 'location_city',
    this.boundaryPoints = const [],
    this.centerLatitude,
    this.centerLongitude,
    this.population = 0,
    this.areaKm2 = 0,
    this.totalStores = 0,
    this.isMain = true,
    this.displayOrder = 0,
    this.isActive = true,
  });

  factory Neighborhood.fromJson(Map<String, dynamic> json) {
    return Neighborhood(
      id: json['id']?.toString(),
      nameKu: json['name_ku']?.toString() ?? '',
      nameAr: json['name_ar']?.toString(),
      nameEn: json['name_en']?.toString(),
      descriptionKu: json['description_ku']?.toString(),
      descriptionAr: json['description_ar']?.toString(),
      descriptionEn: json['description_en']?.toString(),
      imageUrl: json['image_url']?.toString(),
      coverUrl: json['cover_url']?.toString(),
      color: json['color']?.toString() ?? '#1E88E5',
      icon: json['icon']?.toString() ?? 'location_city',
      boundaryPoints: _parseBoundary(json['boundary_points']),
      centerLatitude: double.tryParse(json['center_latitude']?.toString() ?? ''),
      centerLongitude: double.tryParse(json['center_longitude']?.toString() ?? ''),
      population: int.tryParse(json['population']?.toString() ?? '0') ?? 0,
      areaKm2: double.tryParse(json['area_km2']?.toString() ?? '0') ?? 0,
      totalStores: int.tryParse(json['total_stores']?.toString() ?? '0') ?? 0,
      isMain: json['is_main'] != false,
      displayOrder: int.tryParse(json['display_order']?.toString() ?? '0') ?? 0,
      isActive: json['is_active'] != false,
    );
  }

  static List<Map<String, double>> _parseBoundary(dynamic raw) {
    if (raw == null || raw is! List) return [];
    try {
      return raw
          .map((e) => {
        'lat': double.tryParse(e['lat']?.toString() ?? '0') ?? 0,
        'lng': double.tryParse(e['lng']?.toString() ?? '0') ?? 0,
      })
          .toList();
    } catch (_) {
      return [];
    }
  }

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

  String getDescription(String lang) {
    switch (lang) {
      case 'ar':
        return (descriptionAr?.isEmpty ?? true)
            ? (descriptionKu ?? '')
            : descriptionAr!;
      case 'en':
        return (descriptionEn?.isEmpty ?? true)
            ? (descriptionKu ?? '')
            : descriptionEn!;
      default:
        return descriptionKu ?? '';
    }
  }

  bool get hasCenter =>
      centerLatitude != null && centerLongitude != null;

  bool get hasBoundary => boundaryPoints.isNotEmpty;
}