/// 📦 مۆدێلی ئۆردەر
class Order {
  final dynamic id;
  final String? userId;
  final String customerName;
  final String customerPhone;
  final String? storeId;
  final String? storeName;
  final num totalPrice;
  final List<OrderItem> items;
  final String status; // pending, approved, delivered, completed, rejected
  final DateTime? createdAt;

  Order({
    this.id,
    this.userId,
    required this.customerName,
    required this.customerPhone,
    this.storeId,
    this.storeName,
    required this.totalPrice,
    this.items = const [],
    this.status = 'pending',
    this.createdAt,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    List<OrderItem> parsedItems = [];
    if (json['items'] is List) {
      parsedItems = (json['items'] as List)
          .map((e) => OrderItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    return Order(
      id: json['id'],
      userId: json['user_id']?.toString(),
      customerName: json['customer_name']?.toString() ?? '',
      customerPhone: json['customer_phone']?.toString() ?? '',
      storeId: json['store_id']?.toString(),
      storeName: json['store_name']?.toString(),
      totalPrice: json['total_price'] is num
          ? json['total_price']
          : num.tryParse(json['total_price']?.toString() ?? '0') ?? 0,
      items: parsedItems,
      status: json['status']?.toString() ?? 'pending',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'customer_name': customerName,
      'customer_phone': customerPhone,
      'store_id': storeId,
      'store_name': storeName,
      'total_price': totalPrice,
      'items': items.map((e) => e.toJson()).toList(),
      'status': status,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// وەرگێڕانی دۆخ بۆ کوردی
  String get statusKurdish {
    switch (status) {
      case 'pending':
        return 'چاوەڕێ';
      case 'approved':
        return 'پەسەندکراو';
      case 'delivered':
        return 'ڕێگادایە';
      case 'completed':
        return 'تەواو';
      case 'rejected':
        return 'ڕەتکراو';
      default:
        return status;
    }
  }
}

/// 🛒 ئایتمی ئۆردەر
class OrderItem {
  final dynamic productId;
  final String name;
  final num price;
  final int qty;
  final String? img;

  OrderItem({
    this.productId,
    required this.name,
    required this.price,
    required this.qty,
    this.img,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      productId: json['product_id'],
      name: json['name']?.toString() ?? '',
      price: json['price'] is num
          ? json['price']
          : num.tryParse(json['price']?.toString() ?? '0') ?? 0,
      qty: json['qty'] is int
          ? json['qty']
          : int.tryParse(json['qty']?.toString() ?? '1') ?? 1,
      img: json['img']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'name': name,
      'price': price,
      'qty': qty,
      'img': img,
    };
  }

  /// کۆی ئەم ئایتمە
  num get total => price * qty;
}