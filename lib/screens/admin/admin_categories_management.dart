import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/image_service.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../l10n/tr.dart';

/// 🗂️ شاشەی بەڕێوەبردنی بەشە سەرەکییەکان (Ultra Pro Max)
class AdminCategoriesManagementScreen extends StatefulWidget {
  const AdminCategoriesManagementScreen({super.key});

  @override
  State<AdminCategoriesManagementScreen> createState() =>
      _AdminCategoriesManagementScreenState();
}

class _AdminCategoriesManagementScreenState
    extends State<AdminCategoriesManagementScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _mainCategories = [];
  List<Map<String, dynamic>> _subCategories = [];
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('main_categories')
            .select()
            .order('sort_order', ascending: true),
        Supabase.instance.client.from('sub_categories').select(),
      ]);

      if (mounted) {
        setState(() {
          _mainCategories = _deduplicateCategories(
              List<Map<String, dynamic>>.from(results[0] as List));
          _subCategories = List<Map<String, dynamic>>.from(results[1] as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar(trf("هەڵە لە هێنانی داتا: {0}", [e]), isError: true);
      }
    }
  }

  List<Map<String, dynamic>> _deduplicateCategories(
      List<Map<String, dynamic>> rawList) {
    return rawList
        .fold<Map<String, Map<String, dynamic>>>({}, (map, item) {
          map[item['name']] = item;
          return map;
        })
        .values
        .toList();
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(tr(msg), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor:
            isError ? const Color(0xFFDC3545) : const Color(0xFF0F9D7A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _deleteMainCategory(dynamic catId, String catName) async {
    bool confirm = await showDialog(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: AppLang.direction,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24)),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50, shape: BoxShape.circle),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: Color(0xFFDC3545), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(tr("سڕینەوەی بەش"),
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 16)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr("ئایا دڵنیایت لە سڕینەوەی:"),
                      style:
                          const TextStyle(color: Colors.black54, fontSize: 13)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Text(tr(catName),
                        style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Color(0xFFDC3545),
                            fontSize: 14)),
                  ),
                  const SizedBox(height: 10),
                  Text(tr("تێبینی: بە سڕینەوەی ئەم بەشە، هەموو ژێربەشەکانیشی دەسڕێنەوە."),
                      style:
                          TextStyle(fontSize: 11, color: Colors.red.shade700)),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(tr("نەخێر"),
                      style: const TextStyle(
                          color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC3545),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.delete_rounded, size: 18),
                  label: Text(tr("سڕینەوە"),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await Supabase.instance.client
          .from('main_categories')
          .delete()
          .eq('id', catId);
      _fetchData();
      _showSnackBar(tr("بەشەکە بە سەرکەوتوویی سڕایەوە 🗑"));
    } catch (e) {
      _showSnackBar(trf("هەڵە: {0}", [e]), isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    var filteredCats = _mainCategories.where((cat) {
      final name = (cat['name'] ?? '').toString().toLowerCase();
      return _searchQuery.isEmpty || name.contains(_searchQuery);
    }).toList();

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : const Color(0xFFF4F6F9),
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 160,
              pinned: true,
              backgroundColor: const Color(0xFF1E1B2E),
              foregroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E1B2E), Color(0xFF2D2A45)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 60, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color:
                                      AppColors.primary.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.category_rounded,
                                    color: AppColors.primary, size: 24),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  tr("بەشە سەرەکی و لاوەکییەکان"),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildStatChip(
                                  "${_mainCategories.length}",
                                  "بەشی سەرەکی",
                                  Icons.apps_rounded,
                                  AppColors.primary),
                              const SizedBox(width: 8),
                              _buildStatChip(
                                  "${_subCategories.length}",
                                  "ژێربەش",
                                  Icons.subdirectory_arrow_right_rounded,
                                  const Color(0xFF0F9D7A)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkCard : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color:
                            Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (val) =>
                        setState(() => _searchQuery = val.trim().toLowerCase()),
                    style: TextStyle(
                        color: isDark ? Colors.white : Colors.black87),
                    decoration: InputDecoration(
                      hintText: tr("گەڕان بەدوای بەشەکان..."),
                      hintStyle: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.grey),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.primary, size: 22),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(Icons.close_rounded,
                                  size: 18,
                                  color: isDark ? Colors.white54 : Colors.grey),
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 16),
                    ),
                  ),
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(
                child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary)),
              )
            else if (filteredCats.isEmpty)
              SliverFillRemaining(child: _buildEmptyState(isDark))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      var mainCat = filteredCats[index];
                      String mainName = mainCat['name'] ?? '';
                      var relatedSubs = _subCategories
                          .where((sub) =>
                              sub['parent']?.toString().trim() ==
                              mainName.trim())
                          .toList();

                      return _buildMainCategoryCard(
                          mainCat, mainName, relatedSubs.length, isDark);
                    },
                    childCount: filteredCats.length,
                  ),
                ),
              ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: () {
            showDialog(
              context: context,
              builder: (_) => const AddOrEditMainCategoryDialog(),
            ).then((_) => _fetchData());
          },
          icon: const Icon(Icons.add_rounded, size: 24),
          label: Text(tr("زیادکردنی بەش"),
              style:
                  const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
        ),
      ),
    );
  }

  Widget _buildStatChip(
      String value, String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 6),
          Text(tr(value),
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w900, fontSize: 14)),
          const SizedBox(width: 4),
          Text(tr(label),
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMainCategoryCard(Map<String, dynamic> mainCat, String mainName,
      int subCount, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBackground
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: isDark
                            ? AppColors.darkBorder
                            : Colors.grey.shade200),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: mainCat['image'] != null &&
                            mainCat['image'].toString().isNotEmpty
                        ? OptimizedNetworkImage(
                            imageUrl: mainCat['image'], fit: BoxFit.cover)
                        : Icon(Icons.category_rounded,
                            color: isDark ? Colors.white54 : Colors.grey,
                            size: 24),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr(mainName),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A2E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.subdirectory_arrow_right_rounded,
                                size: 11, color: AppColors.primary),
                            const SizedBox(width: 3),
                            Text(
                              trf("{0} ژێربەش", [subCount]),
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBackground : Colors.grey.shade50,
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.edit_rounded,
                    label: tr("دەستکاری"),
                    color: const Color(0xFF1E88E5),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) =>
                            AddOrEditMainCategoryDialog(category: mainCat),
                      ).then((_) => _fetchData());
                    },
                  ),
                ),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.list_alt_rounded,
                    label: tr("ژێربەشەکان"),
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AdminSubCategoriesScreen(
                              mainCategoryName: mainName),
                        ),
                      ).then((_) => _fetchData());
                    },
                  ),
                ),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: tr("سڕینەوە"),
                    color: const Color(0xFFDC3545),
                    onTap: () => _deleteMainCategory(mainCat['id'], mainName),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
      {required IconData icon,
      required String label,
      required Color color,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(tr(label),
                style: TextStyle(
                    color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.category_outlined,
                size: 60, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            tr("هیچ بەشێک نەدۆزرایەوە 📭"),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: isDark ? Colors.white70 : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr("دەتوانیت بەشێکی نوێ زیاد بکەیت"),
            style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white54 : Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => const AddOrEditMainCategoryDialog(),
              ).then((_) => _fetchData());
            },
            icon: const Icon(Icons.add_rounded, size: 20),
            label: Text(tr("زیادکردنی بەشی نوێ"),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🎨 دیالۆگی زیادکردن / دەستکاریکردنی بەشی سەرەکی
// ═══════════════════════════════════════════════════════════
class AddOrEditMainCategoryDialog extends StatefulWidget {
  final Map<String, dynamic>? category;
  const AddOrEditMainCategoryDialog({super.key, this.category});

  @override
  State<AddOrEditMainCategoryDialog> createState() =>
      _AddOrEditMainCategoryDialogState();
}

class _AddOrEditMainCategoryDialogState
    extends State<AddOrEditMainCategoryDialog> {
  late final TextEditingController _titleCtrl;
  XFile? _pickedImage;
  String? _existingImageUrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.category?['name'] ?? '');
    _existingImageUrl = widget.category?['image'];
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    super.dispose();
  }

  String _getAiGeneratedImage(String categoryName) {
    final name = categoryName.trim().toLowerCase();
    if (name.contains('تەندروستی') ||
        name.contains('نەخۆشخانە') ||
        name.contains('پزیشک')) {
      return 'https://images.unsplash.com/photo-1538108149393-fbbd81895907?w=500&auto=format&fit=crop&q=60';
    } else if (name.contains('پەروەردە') ||
        name.contains('قوتابخانە') ||
        name.contains('فێرکاری')) {
      return 'https://images.unsplash.com/photo-1503676260728-1c00da094a0b?w=500&auto=format&fit=crop&q=60';
    } else if (name.contains('خواردن') ||
        name.contains('رێستۆرانت') ||
        name.contains('شیرینی')) {
      return 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?w=500&auto=format&fit=crop&q=60';
    } else if (name.contains('بازاڕ') ||
        name.contains('جلوبەرگ') ||
        name.contains('دوکان')) {
      return 'https://images.unsplash.com/photo-1441986300917-64674bd600d8?w=500&auto=format&fit=crop&q=60';
    } else {
      return 'https://images.unsplash.com/photo-1555529771-835f59fc5efe?w=500&auto=format&fit=crop&q=60';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.category != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: AppLang.direction,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.category_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        tr(isEditing
                            ? "دەستکاریکردنی بەش"
                            : "زیادکردنی بەشی نوێ"),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: isDark ? Colors.white70 : Colors.grey),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _titleCtrl,
                  style:
                      TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    labelText: tr("ناوی بەش *"),
                    labelStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.grey.shade700,
                        fontWeight: FontWeight.bold),
                    prefixIcon: const Icon(Icons.title_rounded,
                        color: AppColors.primary),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : Colors.grey.shade300)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                            color: isDark
                                ? AppColors.darkBorder
                                : Colors.grey.shade300)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                            color: AppColors.primary, width: 1.5)),
                    filled: true,
                    fillColor:
                        isDark ? AppColors.darkBackground : Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  tr("وێنەی بەش"),
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await ImagePicker()
                        .pickImage(source: ImageSource.gallery);
                    if (picked != null) setState(() => _pickedImage = picked);
                  },
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.darkBackground
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          width: 2),
                    ),
                    child: _pickedImage != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(File(_pickedImage!.path),
                                fit: BoxFit.cover),
                          )
                        : _existingImageUrl != null &&
                                _existingImageUrl!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: OptimizedNetworkImage(
                                    imageUrl: _existingImageUrl!,
                                    fit: BoxFit.cover),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.add_a_photo_rounded,
                                      size: 36, color: AppColors.primary),
                                  const SizedBox(height: 8),
                                  Text(
                                    tr("کرتە بکە بۆ هەڵبژاردنی وێنە 📸"),
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: isDark
                                            ? Colors.white54
                                            : Colors.grey,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    tr("ئەگەر وێنەت هەڵنەبژارد، AI خۆی بۆی دادەنێت 🤖"),
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: isDark
                                            ? Colors.white38
                                            : Colors.blueGrey),
                                  ),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary))
                      : ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14)),
                            elevation: 3,
                          ),
                          onPressed: () async {
                            if (_titleCtrl.text.trim().isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content:
                                        Text(tr("تکایە ناوی بەش بنووسە ⚠")),
                                    backgroundColor: const Color(0xFFD9822B)),
                              );
                              return;
                            }
                            setState(() => _loading = true);
                            try {
                              String imageUrl = _existingImageUrl ?? '';
                              if (_pickedImage != null) {
                                imageUrl =
                                    await ImageCompressionService.uploadImage(
                                        _pickedImage!);
                              } else if (imageUrl.isEmpty) {
                                imageUrl = _getAiGeneratedImage(
                                    _titleCtrl.text.trim());
                              }

                              if (isEditing) {
                                await Supabase.instance.client
                                    .from('main_categories')
                                    .update({
                                  'name': _titleCtrl.text.trim(),
                                  'image': imageUrl,
                                }).eq('id', widget.category!['id']);
                              } else {
                                await Supabase.instance.client
                                    .from('main_categories')
                                    .insert({
                                  'name': _titleCtrl.text.trim(),
                                  'image': imageUrl,
                                });
                              }

                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text(
                                          tr("بە سەرکەوتوویی پاشەکەوت کرا ✅")),
                                      backgroundColor: const Color(0xFF0F9D7A)),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content:
                                          Text(trf("هەڵە ڕووی دا: {0}", [e])),
                                      backgroundColor: const Color(0xFFDC3545)),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => _loading = false);
                            }
                          },
                          icon: const Icon(Icons.save_rounded, size: 20),
                          label: Text(
                            tr(isEditing ? "نوێکردنەوە ✅" : "پاشەکەوتکردن ✅"),
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 15),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🗂️ شاشەی ژێربەشەکان
// ═══════════════════════════════════════════════════════════
class AdminSubCategoriesScreen extends StatefulWidget {
  final String mainCategoryName;

  const AdminSubCategoriesScreen({super.key, required this.mainCategoryName});

  @override
  State<AdminSubCategoriesScreen> createState() =>
      _AdminSubCategoriesScreenState();
}

class _AdminSubCategoriesScreenState extends State<AdminSubCategoriesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _subCategories = [];
  final TextEditingController _subNameCtrl = TextEditingController();
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _fetchSubCategories();
  }

  @override
  void dispose() {
    _subNameCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchSubCategories() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('sub_categories')
          .select()
          .eq('parent', widget.mainCategoryName);

      if (mounted) {
        setState(() {
          _subCategories = List<Map<String, dynamic>>.from(res as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showSnackBar(trf("هەڵە لە هێنانی داتا: {0}", [e]), isError: true);
      }
    }
  }

  Future<void> _addSubCategory() async {
    String name = _subNameCtrl.text.trim();
    if (name.isEmpty) return;

    setState(() => _isAdding = true);
    try {
      await Supabase.instance.client.from('sub_categories').insert({
        'name': name,
        'parent': widget.mainCategoryName,
      });

      _subNameCtrl.clear();
      _fetchSubCategories();
      _showSnackBar(tr("ژێربەشەکە بە سەرکەوتوویی زیادکرا ✅"));
    } catch (e) {
      _showSnackBar(trf("هەڵە: {0}", [e]), isError: true);
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  Future<void> _deleteSubCategory(dynamic subId, String subName) async {
    bool confirm = await showDialog(
          context: context,
          builder: (ctx) => Directionality(
            textDirection: AppLang.direction,
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20)),
              title: Text(tr("سڕینەوەی ژێربەش")),
              content: Text(trf("ئایا دڵنیایت لە سڕینەوەی '{0}'؟", [subName])),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(tr("نەخێر")),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC3545),
                      foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(tr("سڕینەوە")),
                ),
              ],
            ),
          ),
        ) ??
        false;

    if (!confirm) return;

    try {
      await Supabase.instance.client
          .from('sub_categories')
          .delete()
          .eq('id', subId);
      _fetchSubCategories();
      _showSnackBar(tr("بە سەرکەوتوویی سڕایەوە 🗑"));
    } catch (e) {
      _showSnackBar(trf("هەڵە: {0}", [e]), isError: true);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(tr(msg), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor:
            isError ? const Color(0xFFDC3545) : const Color(0xFF0F9D7A),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: Text(
            trf("ژێربەشەکانی: {0}", [widget.mainCategoryName]),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
          backgroundColor: const Color(0xFF1E1B2E),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkCard : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _subNameCtrl,
                      style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87),
                      decoration: InputDecoration(
                        hintText: tr("ناوی ژێربەشی نوێ..."),
                        hintStyle: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white54 : Colors.grey),
                        prefixIcon: const Icon(
                            Icons.subdirectory_arrow_right_rounded,
                            color: AppColors.primary,
                            size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AppColors.primary, width: 1.5),
                        ),
                        filled: true,
                        fillColor: isDark
                            ? AppColors.darkBackground
                            : Colors.grey.shade50,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                      onPressed: _isAdding ? null : _addSubCategory,
                      icon: _isAdding
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.add_rounded, size: 20),
                      label: Text(tr("زیادکردن"),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary))
                  : _subCategories.isEmpty
                      ? Center(
                          child: Text(
                            tr("هیچ ژێربەشێک نییە 📭"),
                            style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.grey,
                                fontWeight: FontWeight.bold),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _subCategories.length,
                          itemBuilder: (context, index) {
                            var sub = _subCategories[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              decoration: BoxDecoration(
                                color:
                                    isDark ? AppColors.darkCard : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: isDark ? 0.2 : 0.03),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 8),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                          Icons
                                              .subdirectory_arrow_right_rounded,
                                          color: AppColors.primary,
                                          size: 18),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        tr(sub['name'] ?? ''),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 14,
                                          color: isDark
                                              ? Colors.white
                                              : const Color(0xFF1A1A2E),
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    GestureDetector(
                                      onTap: () => _deleteSubCategory(
                                          sub['id'], sub['name']),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? const Color(0xFFDC3545)
                                                  .withValues(alpha: 0.15)
                                              : const Color(0xFFDC3545)
                                                  .withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                            Icons.delete_outline_rounded,
                                            color: Color(0xFFDC3545),
                                            size: 18),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
