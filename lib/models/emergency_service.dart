/// 🚑 مۆدێلی خزمەتگوزاری فریاکەوتن
class EmergencyService {
  final String? id;
  final String nameKu;
  final String? nameAr;
  final String? nameEn;
  final String category;
  final String phone;
  final String? phoneAlt;
  final String? address;
  final double? latitude;
  final double? longitude;
  final String icon;
  final String color;
  final bool is24h;
  final bool isImportant;
  final int displayOrder;
  final String? notes;

  // ✅ خانەی نوێ
  final String? authorityName;

  EmergencyService({
    this.id,
    required this.nameKu,
    this.nameAr,
    this.nameEn,
    required this.category,
    required this.phone,
    this.phoneAlt,
    this.address,
    this.latitude,
    this.longitude,
    this.icon = 'emergency',
    this.color = '#EF4444',
    this.is24h = true,
    this.isImportant = false,
    this.displayOrder = 0,
    this.notes,
    this.authorityName, // ✅ زیادکرا
  });

  factory EmergencyService.fromJson(Map<String, dynamic> json) {
    return EmergencyService(
      id: json['id']?.toString(),
      nameKu: json['name_ku']?.toString() ?? '',
      nameAr: json['name_ar']?.toString(),
      nameEn: json['name_en']?.toString(),
      category: json['category']?.toString() ?? 'other',
      phone: json['phone']?.toString() ?? '',
      phoneAlt: json['phone_alt']?.toString(),
      address: json['address']?.toString(),
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      icon: json['icon']?.toString() ?? 'emergency',
      color: json['color']?.toString() ?? '#EF4444',
      is24h: json['is_24h'] != false,
      isImportant: json['is_important'] == true,
      displayOrder: int.tryParse(json['display_order']?.toString() ?? '0') ?? 0,
      notes: json['notes']?.toString(),
      authorityName: json['authority_name']?.toString(), // ✅ زیادکرا
    );
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

  bool get hasLocation =>
      latitude != null &&
          longitude != null &&
          latitude != 0 &&
          longitude != 0;
}