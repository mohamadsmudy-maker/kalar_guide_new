import '../l10n/tr.dart';
// lib/models/news.dart

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
  final String? newsType;
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
    this.newsType,
    this.storeName,
    this.storeLogo,
    this.storeImage,
  });

  factory News.fromJson(Map<String, dynamic> json) {
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

    String? storeName;
    String? storeLogo;
    String? storeImage;

    final storeData = json['dukan'];
    if (storeData is Map) {
      storeName = storeData['name']?.toString();
      storeLogo = storeData['logo']?.toString();
      storeImage = storeData['image']?.toString();
    }

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
      newsType: json['news_type']?.toString(),
      storeName: storeName,
      storeLogo: storeLogo,
      storeImage: storeImage,
    );
  }

  Map<String, dynamic> toJson({bool includeNullables = false}) {
    return {
      if (id != null) 'id': id,
      if (includeNullables || storeId != null) 'store_id': storeId,
      'title': title,
      'description': description,
      'images': images,
      'likes': likes,
      'views': views,
      if (includeNullables || newsType != null) 'news_type': newsType,
      // زانیاری شوێن تەنها بۆ نیشاندانە، بۆ داتابەیس نا
    };
  }

  Map<String, dynamic> toUpdateJson() {
    final json = toJson(includeNullables: true);
    json['updated_at'] = DateTime.now().toUtc().toIso8601String();
    return json;
  }

  String? get primaryImage => images.isNotEmpty ? images.first : null;

  bool get hasImage => primaryImage != null && primaryImage!.isNotEmpty;

  bool get hasStore => storeName != null && storeName!.isNotEmpty;

  String? get storeAvatar {
    if (storeLogo != null && storeLogo!.isNotEmpty) return storeLogo;
    if (storeImage != null && storeImage!.isNotEmpty) return storeImage;
    return null;
  }

  String getTimeAgo() {
    if (createdAt == null) return 'کەمێک پێش ئێستا';

    final diff = DateTime.now().difference(createdAt!);

    if (diff.inSeconds < 60) return 'چەند چرکەیەک پێش ئێستا';
    if (diff.inMinutes < 60) return trf('{0} دەقیقە لەمەوبەر', [diff.inMinutes]);
    if (diff.inHours < 24) return trf('{0} سەعات لەمەوبەر', [diff.inHours]);
    if (diff.inDays < 30) return trf('{0} ڕۆژ لەمەوبەر', [diff.inDays]);
    return trf('{0} مانگ لەمەوبەر', [(diff.inDays / 30).floor()]);
  }

  News copyWith({
    String? id,
    bool clearId = false,
    String? storeId,
    bool clearStoreId = false,
    String? title,
    String? description,
    List<String>? images,
    int? likes,
    int? views,
    DateTime? createdAt,
    String? newsType,
    bool clearNewsType = false,
    String? storeName,
    bool clearStoreName = false,
    String? storeLogo,
    bool clearStoreLogo = false,
    String? storeImage,
    bool clearStoreImage = false,
  }) {
    return News(
      id: clearId ? null : (id ?? this.id),
      storeId: clearStoreId ? null : (storeId ?? this.storeId),
      title: title ?? this.title,
      description: description ?? this.description,
      images: images ?? this.images,
      likes: likes ?? this.likes,
      views: views ?? this.views,
      createdAt: createdAt ?? this.createdAt,
      newsType: clearNewsType ? null : (newsType ?? this.newsType),
      storeName: clearStoreName ? null : (storeName ?? this.storeName),
      storeLogo: clearStoreLogo ? null : (storeLogo ?? this.storeLogo),
      storeImage: clearStoreImage ? null : (storeImage ?? this.storeImage),
    );
  }
}