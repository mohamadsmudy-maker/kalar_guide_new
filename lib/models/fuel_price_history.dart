/// 💰 مۆدێلی مێژووی نرخ
class FuelPriceHistory {
  final int? id;
  final int stationId;
  final String fuelType;
  final double price;
  final String unit;
  final String? updatedBy;
  final String? updatedByName;
  final String? notes;
  final DateTime? createdAt;

  // 🔗 زانیاری بەنزینخانە
  final String? stationNameKu;
  final String? stationNameAr;
  final String? stationNameEn;
  final String? address;
  final String? phone;
  final bool? isVerified;
  final bool? isFeatured;

  FuelPriceHistory({
    this.id,
    required this.stationId,
    required this.fuelType,
    required this.price,
    this.unit = 'لیتر',
    this.updatedBy,
    this.updatedByName,
    this.notes,
    this.createdAt,
    this.stationNameKu,
    this.stationNameAr,
    this.stationNameEn,
    this.address,
    this.phone,
    this.isVerified,
    this.isFeatured,
  });

  // ✅ Alias بۆ کاتی نوێکردنەوە
  DateTime? get updatedAt => createdAt;

  factory FuelPriceHistory.fromJson(Map<String, dynamic> json) {
    return FuelPriceHistory(
      id: json['id'],
      stationId: json['station_id'],
      fuelType: json['fuel_type'] ?? '',
      price: (json['price'] ?? 0).toDouble(),
      unit: json['unit'] ?? 'لیتر',
      updatedBy: json['updated_by'],
      updatedByName: json['updated_by_name'],
      notes: json['notes'],
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      stationNameKu: json['station_name_ku'],
      stationNameAr: json['station_name_ar'],
      stationNameEn: json['station_name_en'],
      address: json['address'],
      phone: json['phone'],
      isVerified: json['is_verified'],
      isFeatured: json['is_featured'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'station_id': stationId,
      'fuel_type': fuelType,
      'price': price,
      'unit': unit,
      'updated_by': updatedBy,
      'updated_by_name': updatedByName,
      'notes': notes,
    };
  }

  String getStationName(String lang) {
    switch (lang) {
      case 'ar':
        return (stationNameAr?.isEmpty ?? true)
            ? (stationNameKu ?? '')
            : stationNameAr!;
      case 'en':
        return (stationNameEn?.isEmpty ?? true)
            ? (stationNameKu ?? '')
            : stationNameEn!;
      default:
        return stationNameKu ?? '';
    }
  }
}