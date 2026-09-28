import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/image_service.dart';
import '../../widgets/common/optimized_network_image.dart';

/// 📰 شاشەی بەڕێوەبردنی هەواڵەکان
class AdminNewsScreen extends StatefulWidget {
  const AdminNewsScreen({super.key});

  @override
  State<AdminNewsScreen> createState() => _AdminNewsScreenState();
}

class _AdminNewsScreenState extends State<AdminNewsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _newsList = [];
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchNews() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('news')
          .select()
          .order('created_at', ascending: false);
      if (mounted) {
        setState(() {
          _newsList = List<Map<String, dynamic>>.from(res as List);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteNews(dynamic newsId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text("سڕینەوەی هەواڵ"),
          content: const Text("ئایا دڵنیایت لە سڕینەوەی ئەم هەواڵە؟"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("نەخێر"),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("سڕینەوە"),
            ),
          ],
        ),
      ),
    ) ??
        false;

    if (!confirm) return;

    try {
      await Supabase.instance.client.from('news').delete().eq('id', newsId);
      _fetchNews();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("هەواڵەکە بە سەرکەوتوویی سڕایەوە 🗑"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("هەڵە: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openAddNewsDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const _AddNewsScreen()),
    ).then((_) => _fetchNews());
  }

  @override
  Widget build(BuildContext context) {
    var filteredNews = _newsList.where((news) {
      if (_searchQuery.isEmpty) return true;
      final title = (news['title'] ?? '').toString().toLowerCase();
      final desc = (news['description'] ?? '').toString().toLowerCase();
      return title.contains(_searchQuery) || desc.contains(_searchQuery);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F5F8),
        appBar: AppBar(
          title: const Text(
            "بەڕێوەبردنی هەواڵەکان 📰",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(
                        () => _searchQuery = val.trim().toLowerCase(),
                  ),
                  decoration: const InputDecoration(
                    hintText: "گەڕان بەدوای هەواڵەکاندا...",
                    hintStyle:
                    TextStyle(fontSize: 12, color: Colors.grey),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              )
                  : filteredNews.isEmpty
                  ? const Center(
                child: Text(
                  "هیچ هەواڵێک نەدۆزرایەوە 📭",
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                itemCount: filteredNews.length,
                itemBuilder: (context, index) {
                  var news = filteredNews[index];
                  String firstImg = '';
                  if (news['images'] is List &&
                      (news['images'] as List).isNotEmpty) {
                    firstImg = news['images'][0].toString();
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(12),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: firstImg.isNotEmpty
                            ? OptimizedNetworkImage(
                          imageUrl: firstImg,
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        )
                            : Container(
                          width: 60,
                          height: 60,
                          color: Colors.grey.shade100,
                          child: const Icon(
                            Icons.article_rounded,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                      title: Text(
                        news['title'] ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          news['description'] ?? '',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline_rounded,
                          color: Colors.red,
                          size: 20,
                        ),
                        onPressed: () => _deleteNews(news['id']),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: _openAddNewsDialog,
          child: const Icon(Icons.add, size: 28),
        ),
      ),
    );
  }
}

/// ➕ شاشەی زیادکردنی هەواڵی نوێ
class _AddNewsScreen extends StatefulWidget {
  const _AddNewsScreen();

  @override
  State<_AddNewsScreen> createState() => _AddNewsScreenState();
}

class _AddNewsScreenState extends State<_AddNewsScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final List<XFile> _newsImages = [];
  bool _loading = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedList = await picker.pickMultiImage(imageQuality: 70);
    if (pickedList.isNotEmpty) {
      setState(() {
        int remainingSlots = 4 - _newsImages.length;
        _newsImages.addAll(pickedList.take(remainingSlots));
      });
    }
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _newsImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تکایە ناونیشان و وێنەیەک هەڵبژێرە ⚠"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      List<String> uploadedUrls = [];
      for (var img in _newsImages) {
        String url = await ImageCompressionService.uploadImage(img);
        uploadedUrls.add(url);
      }

      await Supabase.instance.client.from('news').insert({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'images': uploadedUrls,
        'likes': 0,
        'views': 0,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("هەواڵەکە بە سەرکەوتوویی بڵاوکرایەوە ✅"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("هەڵە: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F5F8),
        appBar: AppBar(
          title: const Text(
            "بڵاوکردنەوەی هەواڵی نوێ 📢",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _newsImages.length < 4 ? _pickImages : null,
                child: Container(
                  height: 130,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: _newsImages.isEmpty
                      ? const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_rounded,
                        size: 36,
                        color: AppColors.primary,
                      ),
                      SizedBox(height: 6),
                      Text(
                        "وێنەکانی هەواڵ (تا 4 وێنە) 📸",
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  )
                      : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(8),
                    itemCount: _newsImages.length +
                        (_newsImages.length < 4 ? 1 : 0),
                    itemBuilder: (ctx, i) {
                      if (i == _newsImages.length) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.add_circle,
                                size: 38,
                                color: AppColors.primary,
                              ),
                              onPressed: _pickImages,
                            ),
                          ),
                        );
                      }
                      return Container(
                        width: 95,
                        margin: const EdgeInsets.only(right: 8),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                File(_newsImages[i].path),
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 4,
                              right: 4,
                              child: GestureDetector(
                                onTap: () => setState(
                                      () => _newsImages.removeAt(i),
                                ),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  padding: const EdgeInsets.all(4),
                                  child: const Icon(
                                    Icons.close,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: "ناونیشانی هەواڵ *",
                  prefixIcon: const Icon(
                    Icons.title_rounded,
                    color: AppColors.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: "وەسف و وردەکاری هەواڵ *",
                  alignLabelWithHint: true,
                  prefixIcon: const Icon(
                    Icons.description_rounded,
                    color: AppColors.primary,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 30),
              _loading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              )
                  : SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _save,
                  child: const Text(
                    "بڵاوکردنەوە ✅",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
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