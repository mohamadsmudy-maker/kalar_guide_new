/// 🛍️ مۆدێلی کاڵا
class Product {
  final dynamic id;
  final String? storeId;
  final String name;
  final num price;
  final String? category;
  final String? img;
  final List<String> images;
  final Map<String, dynamic> details;
  final DateTime? createdAt;

  Product({
    this.id,
    this.storeId,
    required this.name,
    required this.price,
    this.category,
    this.img,
    this.images = const [],
    this.details = const {},
    this.createdAt,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    // وەرگرتنی وێنەکان
    List<String> imgList = [];
    if (json['images'] is List) {
      imgList = List<String>.from(
        (json['images'] as List).map((e) => e.toString()),
      );
    } else if (json['img'] != null && json['img'].toString().isNotEmpty) {
      imgList = [json['img'].toString()];
    }

    // وەرگرتنی نرخ
    num parsedPrice = 0;
    if (json['price'] is num) {
      parsedPrice = json['price'];
    } else if (json['price'] != null) {
      parsedPrice = num.tryParse(
        json['price'].toString().replaceAll(RegExp(r'[^0-9.]'), ''),
      ) ??
          0;
    }

    return Product(
      id: json['id'],
      storeId: json['store_id']?.toString(),
      name: json['name']?.toString() ?? '',
      price: parsedPrice,
      category: json['category']?.toString(),
      img: json['img']?.toString(),
      images: imgList,
      details: json['details'] is Map
          ? Map<String, dynamic>.from(json['details'])
          : {},
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'store_id': storeId,
      'name': name,
      'price': price,
      'category': category,
      'img': img,
      'images': images,
      'details': details,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// ناوی بەشی سەرەکی
  String? get mainCategory => details['main_category']?.toString();

  /// وەسف
  String? get description => details['description']?.toString();

  /// نرخی فۆرماتکراو
  String get formattedPrice {
    if (price >= 1000000) {
      return '${(price / 1000000).toStringAsFixed(1)}M د.ع';
    } else if (price >= 1000) {
      return '${(price / 1000).toStringAsFixed(0)}K د.ع';
    }
    return '${price.toStringAsFixed(0)} د.ع';
  }

  /// وێنەی سەرەکی
  String? get primaryImage {
    if (images.isNotEmpty) return images.first;
    return img;
  }
}