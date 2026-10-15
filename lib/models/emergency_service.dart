/// 🚑 مۆدێلی خزمەتگوزاری فریاکەوتن — ULTRA PRO
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
  final bool isActive;
  final int displayOrder;
  final String? notes;
  final String? authorityName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

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
    this.isActive = true,
    this.displayOrder = 0,
    this.notes,
    this.authorityName,
    this.createdAt,
    this.updatedAt,
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
      isActive: json['is_active'] != false,
      displayOrder:
      int.tryParse(json['display_order']?.toString() ?? '0') ?? 0,
      notes: json['notes']?.toString(),
      authorityName: json['authority_name']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name_ku': nameKu,
      'name_ar': nameAr,
      'name_en': nameEn,
      'category': category,
      'phone': phone,
      'phone_alt': phoneAlt,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'icon': icon,
      'color': color,
      'is_24h': is24h,
      'is_important': isImportant,
      'is_active': isActive,
      'display_order': displayOrder,
      'notes': notes,
      'authority_name': authorityName,
    };
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

  EmergencyService copyWith({
    String? id,
    String? nameKu,
    String? nameAr,
    String? nameEn,
    String? category,
    String? phone,
    String? phoneAlt,
    String? address,
    double? latitude,
    double? longitude,
    String? icon,
    String? color,
    bool? is24h,
    bool? isImportant,
    bool? isActive,
    int? displayOrder,
    String? notes,
    String? authorityName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmergencyService(
      id: id ?? this.id,
      nameKu: nameKu ?? this.nameKu,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      category: category ?? this.category,
      phone: phone ?? this.phone,
      phoneAlt: phoneAlt ?? this.phoneAlt,
      address: address ?? this.address,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      is24h: is24h ?? this.is24h,
      isImportant: isImportant ?? this.isImportant,
      isActive: isActive ?? this.isActive,
      displayOrder: displayOrder ?? this.displayOrder,
      notes: notes ?? this.notes,
      authorityName: authorityName ?? this.authorityName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
