import 'package:flutter/material.dart';
import '../../config/app_colors.dart';
import '../../models/gallery/gallery_category.dart';
import '../../models/gallery/gallery_category_registry.dart';
import '../../l10n/tr.dart';

class GalleryUploadResult {
  final String title;
  final String categoryId;
  const GalleryUploadResult({required this.title, required this.categoryId});
}

/// 📤 شیت بۆ هەڵبژاردنی ناونیشان + جۆر
class GalleryUploadSheet extends StatefulWidget {
  final bool isDark;
  const GalleryUploadSheet({super.key, required this.isDark});

  @override
  State<GalleryUploadSheet> createState() => _GalleryUploadSheetState();
}

class _GalleryUploadSheetState extends State<GalleryUploadSheet> {
  final _controller = TextEditingController();
  late GalleryCategory _selected;

  @override
  void initState() {
    super.initState();
    _selected = GalleryCategoryRegistry.all.last; // general
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLang.direction,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16, 16, 16,
          MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tr('زانیارییەکانی وێنە'),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),

              // ناونیشان
              TextField(
                controller: _controller,
                maxLength: 120,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: tr('ناونیشان'),
                  hintText: tr('بۆ نموونە: چیاى گۆیژە'),
                  filled: true,
                  fillColor: widget.isDark
                      ? AppColors.darkBorder
                      : AppColors.backgroundGrey,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // جۆر
              Text(tr('جۆر'),
                  style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: GalleryCategoryRegistry.all.map((c) {
                  final selected = _selected.id == c.id;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = c),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? c.color
                            : (widget.isDark
                            ? AppColors.darkCard
                            : AppColors.surface),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? c.color
                              : (widget.isDark
                              ? AppColors.darkBorder
                              : Colors.grey.shade300),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(c.icon,
                              size: 16,
                              color: selected ? Colors.white : c.color),
                          const SizedBox(width: 6),
                          Text(
                            tr(c.label),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? Colors.white
                                  : (widget.isDark
                                  ? Colors.white70
                                  : AppColors.textPrimary),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final title = _controller.text.trim();
                    if (title.isEmpty) return;
                    Navigator.pop(
                      context,
                      GalleryUploadResult(
                        title: title,
                        categoryId: _selected.id,
                      ),
                    );
                  },
                  icon: const Icon(Icons.check_rounded),
                  label: Text(tr('پاشەکەوتکردن')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}