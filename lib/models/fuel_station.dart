/// 🏢 مۆدێلی بەنزینخانە
class FuelStation {
  final int? id;
  final String nameKu;
  final String nameAr;
  final String nameEn;
  final String? address;
  final String? phone;
  final double? latitude;
  final double? longitude;
  final bool isActive;
  final bool isVerified;
  final bool isFeatured;
  final String? notes;
  final DateTime? createdAt;

  FuelStation({
    this.id,
    required this.nameKu,
    this.nameAr = '',
    this.nameEn = '',
    this.address,
    this.phone,
    this.latitude,
    this.longitude,
    this.isActive = true,
    this.isVerified = false,
    this.isFeatured = false,
    this.notes,
    this.createdAt,
  });

  factory FuelStation.fromJson(Map<String, dynamic> json) {
    return FuelStation(
      id: json['id'],
      nameKu: json['name_ku'] ?? '',
      nameAr: json['name_ar'] ?? '',
      nameEn: json['name_en'] ?? '',
      address: json['address'],
      phone: json['phone'],
      latitude: double.tryParse(json['latitude']?.toString() ?? ''),
      longitude: double.tryParse(json['longitude']?.toString() ?? ''),
      isActive: json['is_active'] ?? true,
      isVerified: json['is_verified'] ?? false,
      isFeatured: json['is_featured'] ?? false,
      notes: json['notes'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name_ku': nameKu,
      'name_ar': nameAr,
      'name_en': nameEn,
      'address': address,
      'phone': phone,
      'latitude': latitude,
      'longitude': longitude,
      'is_active': isActive,
      'is_verified': isVerified,
      'is_featured': isFeatured,
      'notes': notes,
    };
  }

  String getName(String lang) {
    switch (lang) {
      case 'ar':
        return nameAr.isEmpty ? nameKu : nameAr;
      case 'en':
        return nameEn.isEmpty ? nameKu : nameEn;
      default:
        return nameKu;
    }
  }

  FuelStation copyWith({
    int? id,
    String? nameKu,
    String? nameAr,
    String? nameEn,
    String? address,
    String? phone,
    double? latitude,
    double? longitude,
    bool? isActive,
    bool? isVerified,
    bool? isFeatured,
    String? notes,
  }) {
    return FuelStation(
      id: id ?? this.id,
      nameKu: nameKu ?? this.nameKu,
      nameAr: nameAr ?? this.nameAr,
      nameEn: nameEn ?? this.nameEn,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isActive: isActive ?? this.isActive,
      isVerified: isVerified ?? this.isVerified,
      isFeatured: isFeatured ?? this.isFeatured,
      notes: notes ?? this.notes,
      createdAt: createdAt,
    );
  }
}