/// 🏪 مۆدێلی فرۆشگا/شوێن
class Store {
  final dynamic id;
  final String name;
  final String? phone;
  final String? address;
  final String? description;
  final String? category;
  final String? subCategory;
  final String? type; // حکومی، ناحکومی
  final double? latitude;
  final double? longitude;
  final String? image;
  final String? logo;
  final String? vendorCode;
  final DateTime? createdAt;

  Store({
    this.id,
    required this.name,
    this.phone,
    this.address,
    this.description,
    this.category,
    this.subCategory,
    this.type,
    this.latitude,
    this.longitude,
    this.image,
    this.logo,
    this.vendorCode,
    this.createdAt,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    double? lat;
    double? lng;

    if (json['latitude'] != null) {
      lat = double.tryParse(json['latitude'].toString());
    }
    if (json['longitude'] != null) {
      lng = double.tryParse(json['longitude'].toString());
    }

    return Store(
      id: json['id'],
      name: json['name']?.toString() ?? json['naw']?.toString() ?? '',
      phone: json['phone']?.toString(),
      address: json['address']?.toString(),
      description: json['description']?.toString(),
      category: json['category']?.toString() ?? json['main_category']?.toString(),
      subCategory:
      json['sub_category']?.toString() ?? json['sub']?.toString(),
      type: json['type']?.toString(),
      latitude: lat,
      longitude: lng,
      image: json['image']?.toString(),
      logo: json['logo']?.toString(),
      vendorCode: json['vendor_code']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'description': description,
      'category': category,
      'sub_category': subCategory,
      'type': type,
      'latitude': latitude,
      'longitude': longitude,
      'image': image,
      'logo': logo,
      'vendor_code': vendorCode,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// ئایا شوێنەکە لۆکەیشنی هەیە؟
  bool get hasLocation =>
      latitude != null &&
          longitude != null &&
          latitude != 0.0 &&
          longitude != 0.0;

  /// ئایا حکومییە؟
  bool get isGovernment => type == 'حکومی';

  /// ناوی پاککراو
  String get cleanName {
    String n = name.trim();
    if (n.startsWith("فرۆشگای")) {
      n = n.replaceFirst("فرۆشگای", "").trim();
    } else if (n.startsWith("فرۆشگا")) {
      n = n.replaceFirst("فرۆشگا", "").trim();
    }
    return n;
  }
}