import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/image_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/common/optimized_network_image.dart';

/// 📰 شاشەی بەڕێوەبردنی هەواڵەکان
class AdminNewsScreen extends StatefulWidget {
  const AdminNewsScreen({super.key});

  @override
  State<AdminNewsScreen> createState() => _AdminNewsScreenState();
}

class _AdminNewsScreenState extends State<AdminNewsScreen> {
  bool _isLoading = true;
  bool _isDeleting = false;
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
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = AuthSessionManager.currentUser;
      final role = AuthSessionManager.userRole;

      List<Map<String, dynamic>> newsList;

      if (role == 'vendor' && user != null) {
        final phone = user['phone']?.toString() ?? '';

        final store = await Supabase.instance.client
            .from('dukan')
            .select('id')
            .eq('phone', phone)
            .maybeSingle();

        if (store != null) {
          final storeId = store['id'];
          final res = await Supabase.instance.client
              .from('news')
              .select()
              .eq('store_id', storeId)
              .order('created_at', ascending: false);

          newsList = List<Map<String, dynamic>>.from(res as List);
        } else {
          newsList = [];
        }
      } else {
        final res = await Supabase.instance.client
            .from('news')
            .select()
            .order('created_at', ascending: false);
        newsList = List<Map<String, dynamic>>.from(res as List);
      }

      if (mounted) {
        setState(() {
          _newsList = newsList;
          _isLoading = false;
        });
      }
    } on PostgrestException catch (e) {
      debugPrint('❌ Postgrest error: ${e.message}');
      if (mounted) setState(() => _isLoading = false);
    } catch (e) {
      debugPrint('❌ $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🗑️ سڕینەوەی هەواڵ — PARANÎ (Database سەرەتا، Storage دوای)
  // ═══════════════════════════════════════════════════════════
  Future<void> _deleteNews(Map<String, dynamic> news) async {
    if (_isDeleting) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("سڕینەوەی هەواڵ"),
          content: const Text(
            "ئایا دڵنیایت لە سڕینەوەی ئەم هەواڵە؟\n\n"
                "هەموو وێنەکانی ئەم هەواڵەش دەسڕدرێنەوە.",
          ),
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
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);

    bool storageSuccess = true;
    bool dbSuccess = false;

    try {
      // ⭐ ١. سڕینەوە لە Database (سەرەتا)
      await Supabase.instance.client
          .from('news')
          .delete()
          .eq('id', news['id']);
      dbSuccess = true;
      debugPrint('✅ داتابەیس سڕایەوە');

      // ⭐ ٢. سڕینەوەی فایلەکان لە Storage (دوای)
      try {
        await StorageService.deleteNewsFiles(news: news);
        debugPrint('✅ فایلەکانی Storage سڕانەوە');
      } catch (e) {
        debugPrint('⚠️ هەڵە لە سڕینەوەی Storage: $e');
        storageSuccess = false;
      }

      // ⭐ ٣. نوێکردنەوەی لیست
      await _fetchNews();

      if (mounted) {
        if (storageSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ هەواڵ و فایلەکانی سڕایەوە"),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ هەواڵ سڕایەوە بەڵام هەندێک فایل نەسڕانەوە'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dbSuccess
                  ? '⚠️ هەواڵ سڕایەوە بەڵام کێشە لە Storage'
                  : "هەڵە: $e",
            ),
            backgroundColor: dbSuccess ? Colors.orange : Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _openAddNewsDialog() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddNewsScreen()),
    ).then((_) => _fetchNews());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role = AuthSessionManager.userRole;
    final isVendor = role == 'vendor';

    final filteredNews = _newsList.where((news) {
      if (_searchQuery.isEmpty) return true;
      final title = (news['title'] ?? '').toString().toLowerCase();
      final desc = (news['description'] ?? '').toString().toLowerCase();
      return title.contains(_searchQuery) || desc.contains(_searchQuery);
    }).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF7F5F8),
        appBar: AppBar(
          title: Text(
            isVendor ? "هەواڵەکانم 📰" : "بەڕێوەبردنی هەواڵەکان 📰",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
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
                  color: isDark ? const Color(0xFF1A1A22) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.3 : 0.04,
                      ),
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
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: "گەڕان بەدوای هەواڵەکاندا...",
                    hintStyle: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
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
                  ? _buildEmptyState(isDark, isVendor)
                  : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _fetchNews,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  itemCount: filteredNews.length,
                  itemBuilder: (context, index) {
                    return _buildNewsCard(
                      filteredNews[index],
                      isDark,
                    );
                  },
                ),
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

  Widget _buildNewsCard(Map<String, dynamic> news, bool isDark) {
    String firstImg = '';
    if (news['images'] is List && (news['images'] as List).isNotEmpty) {
      firstImg = news['images'][0].toString();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
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
            color: isDark
                ? const Color(0xFF2A2A35)
                : Colors.grey.shade100,
            child: const Icon(
              Icons.article_rounded,
              color: Colors.grey,
            ),
          ),
        ),
        title: Text(
          news['title'] ?? '',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: isDark ? Colors.white : Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            news['description'] ?? '',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.grey,
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
          onPressed: _isDeleting ? null : () => _deleteNews(news),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, bool isVendor) {
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
            child: const Icon(
              Icons.article_outlined,
              size: 60,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isVendor ? "هیچ هەواڵێکت نییە 📭" : "هیچ هەواڵێک نەدۆزرایەوە 📭",
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ➕ شاشەی زیادکردنی هەواڵی نوێ
// ═══════════════════════════════════════════════════════════
class AddNewsScreen extends StatefulWidget {
  const AddNewsScreen({super.key});

  @override
  State<AddNewsScreen> createState() => _AddNewsScreenState();
}

class _AddNewsScreenState extends State<AddNewsScreen> {
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

      final user = AuthSessionManager.currentUser;
      final role = AuthSessionManager.userRole;
      int? storeId;

      if (role == 'vendor' && user != null) {
        final phone = user['phone']?.toString() ?? '';
        final store = await Supabase.instance.client
            .from('dukan')
            .select('id')
            .eq('phone', phone)
            .maybeSingle();
        storeId = store?['id'];
      }

      await Supabase.instance.client.from('news').insert({
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'images': uploadedUrls,
        'likes': 0,
        'views': 0,
        'store_id': storeId,
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("✅ هەواڵەکە بە سەرکەوتوویی بڵاوکرایەوە"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("هەڵە: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF7F5F8),
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
                    color: isDark
                        ? const Color(0xFF1A1A22)
                        : Colors.blue.shade50,
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
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
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
                  fillColor:
                  isDark ? const Color(0xFF1A1A22) : Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descCtrl,
                maxLines: 5,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                ),
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
                  fillColor:
                  isDark ? const Color(0xFF1A1A22) : Colors.white,
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