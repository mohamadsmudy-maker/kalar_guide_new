/// 📰 مۆدێلی هەواڵ
class News {
  final String? id;
  final String? storeId;
  final String title;
  final String description;
  final List<String> images;
  final int likes;
  final int views;
  final DateTime? createdAt;

  // ⭐ خانەی نوێ — زانیاری شوێن
  final String? storeName;
  final String? storeLogo;
  final String? storeImage;

  News({
    this.id,
    this.storeId,
    required this.title,
    required this.description,
    this.images = const [],
    this.likes = 0,
    this.views = 0,
    this.createdAt,
    this.storeName,
    this.storeLogo,
    this.storeImage,
  });

  factory News.fromJson(Map<String, dynamic> json) {
    // وێنەکان
    List<String> imgList = [];
    final raw = json['images'] ?? json['img'];
    if (raw is List) {
      imgList = raw
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (raw is String && raw.trim().isNotEmpty) {
      String s = raw.trim();
      s = s.replaceAll(RegExp(r'^\[|\]$'), '');
      if (s.contains(',')) {
        imgList = s
            .split(',')
            .map((e) => e.replaceAll('"', '').replaceAll("'", '').trim())
            .where((e) => e.isNotEmpty)
            .toList();
      } else {
        imgList = [s.replaceAll('"', '').replaceAll("'", '').trim()];
      }
    }

    // ⭐ پارسکردنی زانیاری شوێن
    String? storeName;
    String? storeLogo;
    String? storeImage;

    final storeData = json['dukan'];
    if (storeData is Map) {
      storeName = storeData['name']?.toString();
      storeLogo = storeData['logo']?.toString();
      storeImage = storeData['image']?.toString();
    }

    // پشکنین: ئەگەر store_name ڕاستەوخۆ هەبوو (لە cache یان join ی تر)
    storeName ??= json['store_name']?.toString();
    storeLogo ??= json['store_logo']?.toString();
    storeImage ??= json['store_image']?.toString();

    return News(
      id: json['id']?.toString(),
      storeId: json['store_id']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      images: imgList,
      likes: int.tryParse(json['likes']?.toString() ?? '0') ?? 0,
      views: int.tryParse(json['views']?.toString() ?? '0') ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      storeName: storeName,
      storeLogo: storeLogo,
      storeImage: storeImage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'store_id': storeId,
      'title': title,
      'description': description,
      'images': images,
      'likes': likes,
      'views': views,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      // ⭐ زانیاری شوێن
      if (storeName != null) 'store_name': storeName,
      if (storeLogo != null) 'store_logo': storeLogo,
      if (storeImage != null) 'store_image': storeImage,
    };
  }

  /// وێنەی سەرەکی
  String? get primaryImage => images.isNotEmpty ? images.first : null;

  /// ئایا وێنەی هەیە؟
  bool get hasImage => primaryImage != null && primaryImage!.isNotEmpty;

  /// ⭐ ئایا شوێن هەیە؟
  bool get hasStore => storeName != null && storeName!.isNotEmpty;

  /// ⭐ لۆگۆ یان وێنەی شوێن
  String? get storeAvatar {
    if (storeLogo != null && storeLogo!.isNotEmpty) return storeLogo;
    if (storeImage != null && storeImage!.isNotEmpty) return storeImage;
    return null;
  }

  /// کاتی "چەند لەمەوبەر"
  String getTimeAgo() {
    if (createdAt == null) return 'کەمێک پێش ئێستا';

    final diff = DateTime.now().difference(createdAt!);

    if (diff.inSeconds < 60) return 'چەند چرکەیەک پێش ئێستا';
    if (diff.inMinutes < 60) return '${diff.inMinutes} دەقیقە لەمەوبەر';
    if (diff.inHours < 24) return '${diff.inHours} سەعات لەمەوبەر';
    if (diff.inDays < 30) return '${diff.inDays} ڕۆژ لەمەوبەر';
    return '${(diff.inDays / 30).floor()} مانگ لەمەوبەر';
  }

  News copyWith({
    String? id,
    String? storeId,
    String? title,
    String? description,
    List<String>? images,
    int? likes,
    int? views,
    DateTime? createdAt,
    String? storeName,
    String? storeLogo,
    String? storeImage,
  }) {
    return News(
      id: id ?? this.id,
      storeId: storeId ?? this.storeId,
      title: title ?? this.title,
      description: description ?? this.description,
      images: images ?? this.images,
      likes: likes ?? this.likes,
      views: views ?? this.views,
      createdAt: createdAt ?? this.createdAt,
      storeName: storeName ?? this.storeName,
      storeLogo: storeLogo ?? this.storeLogo,
      storeImage: storeImage ?? this.storeImage,
    );
  }
}