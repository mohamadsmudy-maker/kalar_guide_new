import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../models/gallery/gallery_image.dart';

enum AdminAction { editTitle, editCategory, delete }

class GalleryAdminOptionsSheet extends StatelessWidget {
  final GalleryImage image;
  final bool isDark;
  const GalleryAdminOptionsSheet({
    super.key,
    required this.image,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 50,
              height: 5,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey[400],
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.edit_rounded,
                  color: AppColors.primary),
              title: const Text('دەستکاری ناونیشان',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              onTap: () =>
                  Navigator.pop(context, AdminAction.editTitle),
            ),
            ListTile(
              leading: const Icon(Icons.category_rounded,
                  color: AppColors.primary),
              title: const Text('گۆڕینی جۆر',
                  style: TextStyle(fontWeight: FontWeight.w800)),
              onTap: () =>
                  Navigator.pop(context, AdminAction.editCategory),
            ),
            ListTile(
              leading: const Icon(Icons.delete_rounded,
                  color: AppColors.red),
              title: const Text('سڕینەوە',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.red)),
              onTap: () => Navigator.pop(context, AdminAction.delete),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}