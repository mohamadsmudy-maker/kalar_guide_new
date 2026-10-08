/// 💰 مۆدێلی مێژووی نرخ
class FuelPriceHistory {
  final int? id;

  // ✅ required → int? (چونکە لە fromJson دا دەتوانێت null بێت)
  final int? stationId;

  final String fuelType;

  // ✅ num → double بۆ پارە
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
    this.stationId,
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

  /// ✅ ناوی بەنزینخانە بەپێی زمان
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

  /// ✅ نرخی فۆرماتکراو
  String get formattedPrice {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M د.ع';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K د.ع';
    }
    return '${price.toStringAsFixed(0)} د.ع';
  }

  /// ✅ نرخی فۆرماتکراو (تەواو)
  String get formattedPriceFull {
    return '${price.toStringAsFixed(0)} د.ع';
  }

  factory FuelPriceHistory.fromJson(Map<String, dynamic> json) {
    // ✅ پارسکردنی نرخ
    double parsedPrice = 0;
    final rawPrice = json['price'];
    if (rawPrice is num) {
      parsedPrice = rawPrice.toDouble();
    } else if (rawPrice != null) {
      parsedPrice =
          double.tryParse(rawPrice.toString().replaceAll(',', '')) ?? 0;
    }

    // ✅ پارسکردنی stationId
    int? parsedStationId;
    if (json['station_id'] != null) {
      if (json['station_id'] is int) {
        parsedStationId = json['station_id'];
      } else {
        parsedStationId = int.tryParse(json['station_id'].toString());
      }
    }

    // ✅ پارسکردنی id
    int? parsedId;
    if (json['id'] != null) {
      if (json['id'] is int) {
        parsedId = json['id'];
      } else {
        parsedId = int.tryParse(json['id'].toString());
      }
    }

    return FuelPriceHistory(
      id: parsedId,
      stationId: parsedStationId,
      fuelType: json['fuel_type']?.toString() ?? '',
      price: parsedPrice,
      unit: json['unit']?.toString() ?? 'لیتر',
      updatedBy: json['updated_by']?.toString(),
      updatedByName: json['updated_by_name']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      stationNameKu: json['station_name_ku']?.toString(),
      stationNameAr: json['station_name_ar']?.toString(),
      stationNameEn: json['station_name_en']?.toString(),
      address: json['address']?.toString(),
      phone: json['phone']?.toString(),
      isVerified: json['is_verified'] as bool?,
      isFeatured: json['is_featured'] as bool?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      if (stationId != null) 'station_id': stationId,
      'fuel_type': fuelType,
      'price': price,
      'unit': unit,
      'updated_by': updatedBy,
      'updated_by_name': updatedByName,
      'notes': notes,
    };
  }

  /// ✅ کۆپی لەگەڵ گۆڕانکاری
  FuelPriceHistory copyWith({
    int? id,
    int? stationId,
    String? fuelType,
    double? price,
    String? unit,
    String? updatedBy,
    String? updatedByName,
    String? notes,
    DateTime? createdAt,
    String? stationNameKu,
    String? stationNameAr,
    String? stationNameEn,
    String? address,
    String? phone,
    bool? isVerified,
    bool? isFeatured,
  }) {
    return FuelPriceHistory(
      id: id ?? this.id,
      stationId: stationId ?? this.stationId,
      fuelType: fuelType ?? this.fuelType,
      price: price ?? this.price,
      unit: unit ?? this.unit,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedByName: updatedByName ?? this.updatedByName,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      stationNameKu: stationNameKu ?? this.stationNameKu,
      stationNameAr: stationNameAr ?? this.stationNameAr,
      stationNameEn: stationNameEn ?? this.stationNameEn,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      isVerified: isVerified ?? this.isVerified,
      isFeatured: isFeatured ?? this.isFeatured,
    );
  }
}