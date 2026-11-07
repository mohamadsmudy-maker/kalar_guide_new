import 'package:flutter/foundation.dart';
import 'gallery_category.dart';
import 'gallery_category_registry.dart';

@immutable
class GalleryImage {
  final String id;
  final String imageUrl;
  final String? imagePath;
  final String title;
  final String categoryId;
  final int views;
  final DateTime? createdAt;

  const GalleryImage({
    required this.id,
    required this.imageUrl,
    this.imagePath,
    required this.title,
    required this.categoryId,
    this.views = 0,
    this.createdAt,
  });

  GalleryCategory get category =>
      GalleryCategoryRegistry.byId(categoryId);

  factory GalleryImage.fromMap(Map<String, dynamic> m) => GalleryImage(
    id: m['id']?.toString() ?? '',
    imageUrl: m['image_url']?.toString() ?? '',
    imagePath: m['image_path']?.toString(),
    title: m['title']?.toString() ?? '',
    categoryId: (m['category']?.toString().isNotEmpty ?? false)
        ? m['category'].toString()
        : GalleryCategoryRegistry.defaultId,
    views: (m['views'] as num?)?.toInt() ?? 0,
    createdAt: m['created_at'] != null
        ? DateTime.tryParse(m['created_at'].toString())
        : null,
  );

  GalleryImage copyWith({
    String? title,
    int? views,
    String? categoryId,
  }) =>
      GalleryImage(
        id: id,
        imageUrl: imageUrl,
        imagePath: imagePath,
        title: title ?? this.title,
        categoryId: categoryId ?? this.categoryId,
        views: views ?? this.views,
        createdAt: createdAt,
      );
}