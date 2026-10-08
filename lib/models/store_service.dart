/// 📋 مۆدێلی مامەڵەی شوێن (پێداویستی و تێچووی)
class StoreService {
  final String? id;
  final int storeId;
  final String titleKu;
  final String? titleAr;
  final String? titleEn;
  final String? description;
  final List<String> requirements;
  final List<String> fees;
  final String? duration;
  final String? location;
  final String? notes;
  final String icon;
  final String color;
  final int displayOrder;
  final bool isActive;

  StoreService({
    this.id,
    required this.storeId,
    required this.titleKu,
    this.titleAr,
    this.titleEn,
    this.description,
    this.requirements = const [],
    this.fees = const [],
    this.duration,
    this.location,
    this.notes,
    this.icon = 'description',
    this.color = '#1E88E5',
    this.displayOrder = 0,
    this.isActive = true,
  });

  factory StoreService.fromJson(Map<String, dynamic> json) {
    return StoreService(
      id: json['id']?.toString(),
      storeId: int.tryParse(json['store_id']?.toString() ?? '0') ?? 0,
      titleKu: json['title_ku']?.toString() ?? '',
      titleAr: json['title_ar']?.toString(),
      titleEn: json['title_en']?.toString(),
      description: json['description']?.toString(),
      requirements: _parseList(json['requirements']),
      fees: _parseList(json['fees']),
      duration: json['duration']?.toString(),
      location: json['location']?.toString(),
      notes: json['notes']?.toString(),
      icon: json['icon']?.toString() ?? 'description',
      color: json['color']?.toString() ?? '#1E88E5',
      displayOrder:
      int.tryParse(json['display_order']?.toString() ?? '0') ?? 0,
      isActive: json['is_active'] != false,
    );
  }

  static List<String> _parseList(dynamic raw) {
    if (raw == null) return [];
    if (raw is List) {
      return raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (raw is String) {
      try {
        final s = raw.replaceAll(RegExp(r'^\{|\}$'), '');
        return s
            .split(',')
            .map((e) => e.trim().replaceAll('"', ''))
            .where((e) => e.isNotEmpty)
            .toList();
      } catch (_) {
        return [];
      }
    }
    return [];
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'store_id': storeId,
      'title_ku': titleKu,
      'title_ar': titleAr,
      'title_en': titleEn,
      'description': description,
      'requirements': requirements,
      'fees': fees,
      'duration': duration,
      'location': location,
      'notes': notes,
      'icon': icon,
      'color': color,
      'display_order': displayOrder,
      'is_active': isActive,
    };
  }

  /// 📝 ناو بەپێی زمان
  String getTitle(String lang) {
    switch (lang) {
      case 'ar':
        return (titleAr?.isEmpty ?? true) ? titleKu : titleAr!;
      case 'en':
        return (titleEn?.isEmpty ?? true) ? titleKu : titleEn!;
      default:
        return titleKu;
    }
  }
}