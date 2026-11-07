// lib/models/review.dart

/// ⭐ مۆدێلی هەڵسەنگاندن
class Review {
  final String? id;
  final int storeId;
  final String? userId;
  final String userName;
  final String? userPhone;
  final int rating;
  final String? comment;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isApproved;

  Review({
    this.id,
    required this.storeId,
    this.userId,
    required this.userName,
    this.userPhone,
    required this.rating,
    this.comment,
    this.createdAt,
    this.updatedAt,
    this.isApproved = true,
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    return Review(
      id: json['id']?.toString(),
      storeId: int.tryParse(json['store_id']?.toString() ?? '0') ?? 0,
      userId: json['user_id']?.toString(),
      userName: json['user_name']?.toString() ?? 'بەکارهێنەر',
      userPhone: json['user_phone']?.toString(),
      rating: int.tryParse(json['rating']?.toString() ?? '5') ?? 5,
      comment: json['comment']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'].toString())
          : null,
      isApproved: json['is_approved'] != false,
    );
  }

  Map<String, dynamic> toJson({bool includeNullables = false}) {
    return {
      if (id != null) 'id': id,
      'store_id': storeId,
      if (includeNullables || userId != null) 'user_id': userId,
      'user_name': userName,
      if (includeNullables || userPhone != null) 'user_phone': userPhone,
      'rating': rating,
      if (includeNullables || comment != null) 'comment': comment,
      'is_approved': isApproved,
    };
  }

  Map<String, dynamic> toUpdateJson() {
    final json = toJson(includeNullables: true);
    json['updated_at'] = DateTime.now().toUtc().toIso8601String();
    return json;
  }

  String getTimeAgo() {
    if (createdAt == null) return '';
    final diff = DateTime.now().difference(createdAt!);

    if (diff.inMinutes < 1) return 'ئێستا';
    if (diff.inMinutes < 60) return '${diff.inMinutes} خولەک لەمەوبەر';
    if (diff.inHours < 24) return '${diff.inHours} کاتژمێر لەمەوبەر';
    if (diff.inDays < 7) return '${diff.inDays} ڕۆژ لەمەوبەر';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()} هەفتە لەمەوبەر';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()} مانگ لەمەوبەر';
    return '${(diff.inDays / 365).floor()} ساڵ لەمەوبەر';
  }

  Review copyWith({
    String? id, bool clearId = false,
    int? storeId,
    String? userId, bool clearUserId = false,
    String? userName,
    String? userPhone, bool clearUserPhone = false,
    int? rating,
    String? comment, bool clearComment = false,
    DateTime? createdAt, bool clearCreatedAt = false,
    DateTime? updatedAt, bool clearUpdatedAt = false,
    bool? isApproved,
  }) {
    return Review(
      id: clearId ? null : (id ?? this.id),
      storeId: storeId ?? this.storeId,
      userId: clearUserId ? null : (userId ?? this.userId),
      userName: userName ?? this.userName,
      userPhone: clearUserPhone ? null : (userPhone ?? this.userPhone),
      rating: rating ?? this.rating,
      comment: clearComment ? null : (comment ?? this.comment),
      createdAt: clearCreatedAt ? null : (createdAt ?? this.createdAt),
      updatedAt: clearUpdatedAt ? null : (updatedAt ?? this.updatedAt),
      isApproved: isApproved ?? this.isApproved,
    );
  }
}

/// 📊 ئاماری هەڵسەنگاندنی شوێن (وەک خۆی مایەوە، کێشەی نییە)
class StoreRating {
  final int storeId;
  final int totalReviews;
  final double averageRating;
  final int count5;
  final int count4;
  final int count3;
  final int count2;
  final int count1;

  StoreRating({
    required this.storeId,
    required this.totalReviews,
    required this.averageRating,
    required this.count5,
    required this.count4,
    required this.count3,
    required this.count2,
    required this.count1,
  });

  factory StoreRating.fromJson(Map<String, dynamic> json) {
    return StoreRating(
      storeId: int.tryParse(json['store_id']?.toString() ?? '0') ?? 0,
      totalReviews: int.tryParse(json['total_reviews']?.toString() ?? '0') ?? 0,
      averageRating: double.tryParse(json['average_rating']?.toString() ?? '0') ?? 0.0,
      count5: int.tryParse(json['count_5']?.toString() ?? '0') ?? 0,
      count4: int.tryParse(json['count_4']?.toString() ?? '0') ?? 0,
      count3: int.tryParse(json['count_3']?.toString() ?? '0') ?? 0,
      count2: int.tryParse(json['count_2']?.toString() ?? '0') ?? 0,
      count1: int.tryParse(json['count_1']?.toString() ?? '0') ?? 0,
    );
  }

  double percentFor(int stars) {
    if (totalReviews == 0) return 0;
    int count = 0;
    switch (stars) {
      case 5: count = count5; break;
      case 4: count = count4; break;
      case 3: count = count3; break;
      case 2: count = count2; break;
      case 1: count = count1; break;
    }
    return (count / totalReviews) * 100;
  }
}