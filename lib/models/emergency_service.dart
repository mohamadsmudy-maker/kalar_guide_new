// 📁 models/emergency_service.dart
import 'package:flutter/material.dart'; // ✅ پێویستە بۆ Color و Icons
import 'package:flutter/foundation.dart';

import 'emergency_categories.dart'; // ✅ پێویستە بۆ EmergencyCategories

/// 🚑 مۆدێلی خزمەتگوزاری فریاکەوتن — ULTRA PRO MAX
@immutable
class EmergencyService {
  /// ✅ Stable id from DB. `null` only for "not yet saved".
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
  final String color; // hex like `#EF4444`
  final bool is24h;
  final bool isImportant;
  final bool isActive;
  final int displayOrder;
  final String? notes;
  final String? authorityName;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const EmergencyService({
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

  // ───────────────────────────────────────────────────────
  // 📥 fromJson — tolerant of strings, ints, and nulls
  // ───────────────────────────────────────────────────────
  factory EmergencyService.fromJson(Map<String, dynamic> json) {
    return EmergencyService(
      id: _asString(json['id']),
      nameKu: _asString(json['name_ku']) ?? '',
      nameAr: _asString(json['name_ar']),
      nameEn: _asString(json['name_en']),
      category: _asString(json['category']) ?? 'other',
      phone: _asString(json['phone']) ?? '',
      phoneAlt: _asString(json['phone_alt']),
      address: _asString(json['address']),
      latitude: _asDouble(json['latitude']),
      longitude: _asDouble(json['longitude']),
      icon: _asString(json['icon']) ?? 'emergency',
      color: _asString(json['color']) ?? '#EF4444',
      is24h: _asBool(json['is_24h'], fallback: true),
      isImportant: _asBool(json['is_important'], fallback: false),
      isActive: _asBool(json['is_active'], fallback: true),
      displayOrder: _asInt(json['display_order']) ?? 0,
      notes: _asString(json['notes']),
      authorityName: _asString(json['authority_name']),
      createdAt: _asDateTime(json['created_at']),
      updatedAt: _asDateTime(json['updated_at']),
    );
  }

  // ───────────────────────────────────────────────────────
  // 📤 toJson — strips nulls so Postgres defaults win
  // ───────────────────────────────────────────────────────
  Map<String, dynamic> toJson({bool includeId = true}) {
    return {
      if (includeId && id != null) 'id': id,
      'name_ku': nameKu,
      if (nameAr != null) 'name_ar': nameAr,
      if (nameEn != null) 'name_en': nameEn,
      'category': category,
      'phone': phone,
      if (phoneAlt != null) 'phone_alt': phoneAlt,
      if (address != null) 'address': address,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'icon': icon,
      'color': color,
      'is_24h': is24h,
      'is_important': isImportant,
      'is_active': isActive,
      'display_order': displayOrder,
      if (notes != null) 'notes': notes,
      if (authorityName != null) 'authority_name': authorityName,
    };
  }

  /// For an "insert" (no id, no timestamps).
  Map<String, dynamic> toInsertJson() => toJson(includeId: false);

  // ───────────────────────────────────────────────────────
  // 🎯 Localization
  // ───────────────────────────────────────────────────────
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

  // ───────────────────────────────────────────────────────
  // 📍 Location
  // ───────────────────────────────────────────────────────
  bool get hasLocation =>
      latitude != null &&
          longitude != null &&
          !(latitude == 0.0 && longitude == 0.0);

  // ───────────────────────────────────────────────────────
  // 🔄 copyWith — with explicit clear flags for nullable fields
  // ───────────────────────────────────────────────────────
  EmergencyService copyWith({
    String? id,
    bool clearId = false,
    String? nameKu,
    String? nameAr,
    bool clearNameAr = false,
    String? nameEn,
    bool clearNameEn = false,
    String? category,
    String? phone,
    String? phoneAlt,
    bool clearPhoneAlt = false,
    String? address,
    bool clearAddress = false,
    double? latitude,
    bool clearLatitude = false,
    double? longitude,
    bool clearLongitude = false,
    String? icon,
    String? color,
    bool? is24h,
    bool? isImportant,
    bool? isActive,
    int? displayOrder,
    String? notes,
    bool clearNotes = false,
    String? authorityName,
    bool clearAuthorityName = false,
    DateTime? createdAt,
    bool clearCreatedAt = false,
    DateTime? updatedAt,
    bool clearUpdatedAt = false,
  }) {
    return EmergencyService(
      id: clearId ? null : (id ?? this.id),
      nameKu: nameKu ?? this.nameKu,
      nameAr: clearNameAr ? null : (nameAr ?? this.nameAr),
      nameEn: clearNameEn ? null : (nameEn ?? this.nameEn),
      category: category ?? this.category,
      phone: phone ?? this.phone,
      phoneAlt: clearPhoneAlt ? null : (phoneAlt ?? this.phoneAlt),
      address: clearAddress ? null : (address ?? this.address),
      latitude: clearLatitude ? null : (latitude ?? this.latitude),
      longitude: clearLongitude ? null : (longitude ?? this.longitude),
      icon: icon ?? this.icon,
      color: color ?? this.color,
      is24h: is24h ?? this.is24h,
      isImportant: isImportant ?? this.isImportant,
      isActive: isActive ?? this.isActive,
      displayOrder: displayOrder ?? this.displayOrder,
      notes: clearNotes ? null : (notes ?? this.notes),
      authorityName:
      clearAuthorityName ? null : (authorityName ?? this.authorityName),
      createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
    );
  }

  // ───────────────────────────────────────────────────────
  // ⚖️ Equality
  // ───────────────────────────────────────────────────────
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is EmergencyService &&
              runtimeType == other.runtimeType &&
              id == other.id &&
              nameKu == other.nameKu &&
              nameAr == other.nameAr &&
              nameEn == other.nameEn &&
              category == other.category &&
              phone == other.phone &&
              phoneAlt == other.phoneAlt &&
              address == other.address &&
              latitude == other.latitude &&
              longitude == other.longitude &&
              icon == other.icon &&
              color == other.color &&
              is24h == other.is24h &&
              isImportant == other.isImportant &&
              isActive == other.isActive &&
              displayOrder == other.displayOrder &&
              notes == other.notes &&
              authorityName == other.authorityName &&
              createdAt == other.createdAt &&
              updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hashAll([
    id,
    nameKu,
    nameAr,
    nameEn,
    category,
    phone,
    phoneAlt,
    address,
    latitude,
    longitude,
    icon,
    color,
    is24h,
    isImportant,
    isActive,
    displayOrder,
    notes,
    authorityName,
    createdAt,
    updatedAt,
  ]);

  @override
  String toString() =>
      'EmergencyService(id: $id, nameKu: $nameKu, category: $category, '
          'phone: $phone, active: $isActive)';
}

// ═══════════════════════════════════════════════════════════
// 🧰 Safe JSON coercion helpers
// ═══════════════════════════════════════════════════════════
String? _asString(Object? v) {
  if (v == null) return null;
  final s = v.toString().trim();
  return s.isEmpty ? null : s;
}

int? _asInt(Object? v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

double? _asDouble(Object? v) {
  if (v == null) return null;
  if (v is double) return v;
  if (v is num) return v.toDouble();
  return double.tryParse(v.toString());
}

bool _asBool(Object? v, {required bool fallback}) {
  if (v == null) return fallback;
  if (v is bool) return v;
  if (v is num) return v != 0;
  final s = v.toString().toLowerCase();
  if (s == 'true' || s == '1' || s == 'yes') return true;
  if (s == 'false' || s == '0' || s == 'no') return false;
  return fallback;
}

DateTime? _asDateTime(Object? v) {
  if (v == null) return null;
  if (v is DateTime) return v;
  return DateTime.tryParse(v.toString());
}

// ═══════════════════════════════════════════════════════════
// 🎨 Extensions (چارەسەری کێشەی ڕەنگ و ئایکۆن)
// ═══════════════════════════════════════════════════════════
extension EmergencyServiceX on EmergencyService {
  /// 🎨 پارسکردنی ڕەنگ لە هێکسی وەک `#EF4444` بۆ `Color`
  Color get displayColor {
    final hex = color.replaceFirst('#', '');
    try {
      if (hex.length == 6) return Color(int.parse('FF$hex', radix: 16));
      if (hex.length == 8) return Color(int.parse(hex, radix: 16));
    } catch (_) {}
    return EmergencyCategories.getOrOther(category).color;
  }

  /// 🏷️ وەرگرتنی زانیاری کاتێگۆری (ئایکۆن و ڕەنگ)
  EmergencyCategory get categoryInfo => EmergencyCategories.getOrOther(category);
}