/// 🚨 مۆدێلی خزمەتگوزاری فریاکەوتن
class EmergencyContact {
  final int? id;
  final String category;
  final String nameKu;
  final String? nameAr;
  final String? nameEn;
  final String phone;
  final String? phoneAlt;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String workingHours;
  final bool isEmergency;
  final bool isActive;
  final String icon;
  final String color;
  final int displayOrder;
  final String? notes;

  EmergencyContact({
    this.id,
    required this.category,
    required this.nameKu,
    this.nameAr,
    this.nameEn,
    required this.phone,
    this.phoneAlt,
    this.address,
    this.latitude,
    this.longitude,
    this.workingHours = '24/7',
    this.isEmergency = true,
    this.isActive = true,
    this.icon = 'emergency',
    this.color = '#EF4444',
    this.displayOrder = 0,
    this.notes,
  });

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'],
      category: json['category']?.toString() ?? 'other',
      nameKu: json['name_ku']?.toString() ?? '',
      nameAr: json['name_ar']?.toString(),
      nameEn: json['name_en']?.toString(),
      phone: json['phone']?.toString() ?? '',
      phoneAlt: json['phone_alt']?.toString(),
      address: json['address']?.toString(),
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      workingHours: json['working_hours']?.toString() ?? '24/7',
      isEmergency: json['is_emergency'] == true,
      isActive: json['is_active'] != false,
      icon: json['icon']?.toString() ?? 'emergency',
      color: json['color']?.toString() ?? '#EF4444',
      displayOrder: int.tryParse(json['display_order']?.toString() ?? '0') ?? 0,
      notes: json['notes']?.toString(),
    );
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
  String get displayColor => color;

  /// 📞 ژمارەی پەیوەندی
  bool get hasLocation =>
      latitude != null &&
          longitude != null &&
          latitude != 0 &&
          longitude != 0;
}

