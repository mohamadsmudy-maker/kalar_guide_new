import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import '../../widgets/full_screen_image_viewer.dart'; // ✅ ئەمە زیادکرا

import '../../config/app_colors.dart';
import '../../models/gallery/gallery_category_registry.dart';
import '../../models/gallery/gallery_image.dart';
import '../../services/gallery/gallery_service.dart';
import '../../widgets/gallery/gallery_admin_options_sheet.dart';
import '../../widgets/gallery/gallery_category_chips.dart';
import '../../widgets/gallery/gallery_empty_state.dart';
import '../../widgets/gallery/gallery_error_state.dart';
import '../../widgets/gallery/gallery_image_card.dart';
import '../../widgets/gallery/gallery_shimmer_grid.dart';
import '../../widgets/gallery/gallery_upload_sheet.dart';
import '../../l10n/tr.dart';

class AdminGallery extends StatefulWidget {
  const AdminGallery({super.key});

  @override
  State<AdminGallery> createState() => _AdminGalleryState();
}

class _AdminGalleryState extends State<AdminGallery> {
  final _service = GalleryService();
  final _picker = ImagePicker();
  final _search = TextEditingController();

  List<GalleryImage> _all = [];
  Map<String, int> _counts = {};
  String? _selectedCategory;
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _service.fetchAll();
      final counts = await _service.countByCategory();
      if (!mounted) return;
      setState(() {
        _all = list;
        _counts = counts;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'هەڵە لە هێنانی داتا';
      });
    }
  }

  List<GalleryImage> get _filtered {
    final q = _search.text.trim().toLowerCase();
    return _all.where((img) {
      final cat =
          _selectedCategory == null || img.categoryId == _selectedCategory;
      final matchTitle = q.isEmpty || img.title.toLowerCase().contains(q);
      return cat && matchTitle;
    }).toList();
  }

  Future<void> _upload() async {
    final XFile? picked;
    try {
      picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
    } catch (e) {
      _snack(tr('نەتوانرا وێنە هەڵبژێردرێت'), error: true);
      return;
    }
    if (picked == null) return;

    if (!mounted) return;
    final result = await showModalBottomSheet<GalleryUploadResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.darkCard
          : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => GalleryUploadSheet(
        isDark: Theme.of(context).brightness == Brightness.dark,
      ),
    );
    if (result == null) return;

    setState(() => _uploading = true);
    try {
      await _service.upload(
        file: File(picked.path),
        title: result.title,
        categoryId: result.categoryId,
      );
      _snack(tr('وێنە زیادکرا'));
      await _load();
    } catch (e) {
      _snack(
          '${tr('هەڵە لە ئەپلۆدکردن')}\n${GalleryService.uploadErrorText(e)}',
          error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _onLongPress(GalleryImage img) async {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final action = await showModalBottomSheet<AdminAction>(
      context: context,
      backgroundColor: isDark ? AppColors.darkCard : AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (_) => GalleryAdminOptionsSheet(image: img, isDark: isDark),
    );
    if (action == null) return;
    switch (action) {
      case AdminAction.editTitle:
        await _editTitle(img);
        break;
      case AdminAction.editCategory:
        await _editCategory(img);
        break;
      case AdminAction.delete:
        await _delete(img);
        break;
    }
  }

  Future<void> _editTitle(GalleryImage img) async {
    final c = TextEditingController(text: img.title);
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          title: Text(tr('دەستکاری ناونیشان')),
          content: TextField(
            controller: c,
            autofocus: true,
            maxLength: 120,
            decoration: InputDecoration(hintText: tr('ناونیشان')),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('پاشگەزبوونەوە'))),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, c.text.trim()),
                child: Text(tr('پاشەکەوتکردن'))),
          ],
        ),
      ),
    );
    c.dispose();
    if (title == null || title.isEmpty) return;
    try {
      await _service.updateTitle(img.id, title);
      await _load();
    } catch (_) {
      _snack(tr('هەڵە لە دەستکاریکردن'), error: true);
    }
  }

  Future<void> _editCategory(GalleryImage img) async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: GalleryCategoryRegistry.all
                .map((c) => ListTile(
                      leading: Icon(c.icon, color: c.color),
                      title: Text(tr(c.label)),
                      trailing: img.categoryId == c.id
                          ? const Icon(Icons.check_rounded)
                          : null,
                      onTap: () => Navigator.pop(ctx, c.id),
                    ))
                .toList(),
          ),
        ),
      ),
    );
    if (selected == null || selected == img.categoryId) return;
    try {
      await _service.updateCategory(img.id, selected);
      await _load();
    } catch (_) {
      _snack(tr('هەڵە لە گۆڕین'), error: true);
    }
  }

  Future<void> _delete(GalleryImage img) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          title: Text(tr('سڕینەوە')),
          content: Text(trf('ئایا دڵنیایت لە سڕینەوەی "{0}"؟', [img.title])),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tr('نەخێر'))),
            ElevatedButton(
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.red,
                    foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(tr('بەڵێ'))),
          ],
        ),
      ),
    );
    if (ok != true) return;
    try {
      await _service.delete(img);
      setState(() => _all.removeWhere((e) => e.id == img.id));
      _snack(tr('سڕایەوە'));
    } catch (_) {
      _snack(tr('هەڵە لە سڕینەوە'), error: true);
    }
  }

  void _snack(String m, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content:
            Text(tr(m), style: const TextStyle(fontWeight: FontWeight.w700)),
        backgroundColor: error ? AppColors.red : AppColors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : AppColors.background;
    final items = _filtered;

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          title: Text(tr('بەڕێوەبردنی گەلەری'),
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          centerTitle: true,
          backgroundColor: isDark ? AppColors.darkCard : AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: tr('گەڕان بەپێی ناونیشان...'),
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _search.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? AppColors.darkCard : AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            GalleryCategoryChips(
              isDark: isDark,
              selectedId: _selectedCategory,
              counts: _counts,
              onSelected: (id) => setState(() => _selectedCategory = id),
            ),
            if (_uploading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: LinearProgressIndicator(minHeight: 3),
              ),
            const SizedBox(height: 4),
            Expanded(child: _buildBody(isDark, items)),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _uploading ? null : _upload,
          backgroundColor: AppColors.primary,
          icon: const Icon(Icons.add_photo_alternate_rounded,
              color: Colors.white),
          label: Text(
            tr(_uploading ? 'چاوەڕوان بە...' : 'وێنەی نوێ'),
            style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(bool isDark, List<GalleryImage> items) {
    if (_loading) return GalleryShimmerGrid(isDark: isDark, count: 4);
    if (_error != null) {
      return GalleryErrorState(
        isDark: isDark,
        message: _error!,
        onRetry: _load,
      );
    }
    if (items.isEmpty) {
      return GalleryEmptyState(
        isDark: isDark,
        message: _search.text.isNotEmpty
            ? tr('هیچ ئەنجامێک نەدۆزرایەوە')
            : tr('گەلەری بەتاڵە'),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: GridView.builder(
        // ignore: deprecated_member_use — scrollCacheExtent needs a newer Flutter
        cacheExtent: 800,
        padding: const EdgeInsets.all(12).copyWith(bottom: 100),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.78,
        ),
        itemCount: items.length,
        itemBuilder: (_, i) => GalleryImageCard(
          image: items[i],
          isDark: isDark,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => FullScreenImageViewer(
                imageUrl: items[i].imageUrl,
                imageTitle: items[i].title,
                category:
                    GalleryCategoryRegistry.byId(items[i].categoryId).label,
                categoryIcon:
                    GalleryCategoryRegistry.byId(items[i].categoryId).icon,
                views: items[i].views,
                date: items[i].createdAt,
              ),
            ),
          ),
          onLongPress: () => _onLongPress(items[i]),
        ),
      ),
    );
  }
}
