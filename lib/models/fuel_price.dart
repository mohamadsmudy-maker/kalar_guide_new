/// 🛢️ مۆدێلی جۆری سووتەمەنی
class FuelPrice {
  final int? id;
  final String fuelType;
  final String nameKu;
  final String nameAr;
  final String nameEn;
  final double price;
  final String unit;
  final String icon;
  final String color;
  final bool isAvailable;
  final bool isImportant;
  final String? notes;
  final int displayOrder;
  final DateTime? updatedAt;

  FuelPrice({
    this.id,
    required this.fuelType,
    required this.nameKu,
    this.nameAr = '',
    this.nameEn = '',
    this.price = 0,
    this.unit = 'لیتر',
    this.icon = 'local_gas_station',
    this.color = '#1E88E5',
    this.isAvailable = true,
    this.isImportant = false,
    this.notes,
    this.displayOrder = 0,
    this.updatedAt,
  });

  factory FuelPrice.fromJson(Map<String, dynamic> json) {
    return FuelPrice(
      id: json['id'],
      fuelType: json['fuel_type'] ?? '',
      nameKu: json['name_ku'] ?? '',
      nameAr: json['name_ar'] ?? '',
      nameEn: json['name_en'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      unit: json['unit'] ?? 'لیتر',
      icon: json['icon'] ?? 'local_gas_station',
      color: json['color'] ?? '#1E88E5',
      isAvailable: json['is_available'] ?? true,
      isImportant: json['is_important'] ?? false,
      notes: json['notes'],
      displayOrder: json['display_order'] ?? 0,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'fuel_type': fuelType,
      'name_ku': nameKu,
      'name_ar': nameAr,
      'name_en': nameEn,
      'price': price,
      'unit': unit,
      'icon': icon,
      'color': color,
      'is_available': isAvailable,
      'is_important': isImportant,
      'notes': notes,
      'display_order': displayOrder,
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
}