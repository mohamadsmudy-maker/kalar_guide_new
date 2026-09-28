/// 📰 مۆدێلی هەواڵ
class News {
  final dynamic id;
  final String? storeId;
  final String title;
  final String description;
  final List<String> images;
  final int likes;
  final int views;
  final DateTime? createdAt;

  News({
    this.id,
    this.storeId,
    required this.title,
    required this.description,
    this.images = const [],
    this.likes = 0,
    this.views = 0,
    this.createdAt,
  });

  factory News.fromJson(Map<String, dynamic> json) {
    // وەرگرتنی وێنەکان بە شێوازی پارێزراو
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

    return News(
      id: json['id'],
      storeId: json['store_id']?.toString(),
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      images: imgList,
      likes: json['likes'] is int
          ? json['likes']
          : int.tryParse(json['likes']?.toString() ?? '0') ?? 0,
      views: json['views'] is int
          ? json['views']
          : int.tryParse(json['views']?.toString() ?? '0') ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
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
    };
  }

  /// وێنەی سەرەکی
  String? get primaryImage => images.isNotEmpty ? images.first : null;

  /// وەرگرتنی کاتی "چەند لەمەوبەر"
  String getTimeAgo() {
    if (createdAt == null) return 'کەمێک پێش ئێستا';

    final diff = DateTime.now().difference(createdAt!);

    if (diff.inSeconds < 60) {
      return 'چەند چرکەیەک پێش ئێستا';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} دەقیقە لەمەوبەر';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} سەعات لەمەوبەر';
    } else if (diff.inDays < 30) {
      return '${diff.inDays} ڕۆژ لەمەوبەر';
    } else {
      return '${(diff.inDays / 30).floor()} مانگ لەمەوبەر';
    }
  }
}