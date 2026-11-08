import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/image_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../l10n/tr.dart';

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
      final role = AuthSessionManager.userRole;
      final storeId = AuthSessionManager.storeId;

      List<Map<String, dynamic>> newsList;

      if (role == 'vendor') {
        if (storeId != null) {
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
    } catch (e) {
      debugPrint('❌ Postgrest error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteNews(Map<String, dynamic> news) async {
    if (_isDeleting) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(tr("سڕینەوەی هەواڵ")),
          content: Text(tr("ئایا دڵنیایت لە سڕینەوەی ئەم هەواڵە؟")),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr("نەخێر"))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC3545), foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr("سڕینەوە")),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;
    setState(() => _isDeleting = true);

    try {
      await Supabase.instance.client.from('news').delete().eq('id', news['id']);
      try {
        await StorageService.deleteNewsFiles(news: news);
      } catch (e) {
        debugPrint('⚠️ deleteNewsFiles: $e'); // هەواڵەکە سڕایەوە، تەنها فایلەکان نەسڕانەوە
      }
      await _fetchNews();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr("✅ هەواڵەکە سڕایەوە")), backgroundColor: const Color(0xFF0F9D7A)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trf("هەڵە: {0}", [e])), backgroundColor: const Color(0xFFDC3545)),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _openAddNewsDialog({Map<String, dynamic>? newsToEdit}) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => AddNewsScreen(newsToEdit: newsToEdit)),
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
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F0F14) : const Color(0xFFF7F5F8),
        appBar: AppBar(
          title: Text(
            tr(isVendor ? "هەواڵەکانم 📰" : "بەڕێوەبردنی هەواڵەکان 📰"),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                  decoration: InputDecoration(
                    hintText: tr("گەڕان..."),
                    hintStyle: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.grey),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppColors.primary, size: 20),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : filteredNews.isEmpty
                  ? _buildEmptyState(isDark, isVendor)
                  : RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _fetchNews,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredNews.length,
                  itemBuilder: (context, index) {
                    return _buildNewsCard(filteredNews[index], isDark);
                  },
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: () => _openAddNewsDialog(),
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
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: firstImg.isNotEmpty
              ? OptimizedNetworkImage(imageUrl: firstImg, width: 60, height: 60, fit: BoxFit.cover)
              : Container(width: 60, height: 60, color: Colors.grey.shade100, child: const Icon(Icons.article_rounded, color: Colors.grey)),
        ),
        title: Text(
          tr(news['title'] ?? ''),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: isDark ? Colors.white : Colors.black87),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          tr(news['description'] ?? ''),
          style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit, color: Color(0xFF1E88E5), size: 20),
              onPressed: () => _openAddNewsDialog(newsToEdit: news),
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Color(0xFFDC3545), size: 20),
              onPressed: _isDeleting ? null : () => _deleteNews(news),
            ),
          ],
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
            decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.article_outlined, size: 60, color: AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            tr(isVendor ? "هیچ هەواڵێکت نییە 📭" : "هیچ هەواڵێک نەدۆزرایەوە 📭"),
            style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ➕ شاشەی زیادکردن / دەستکاریکردنی هەواڵ
// ═══════════════════════════════════════════════════════════
class AddNewsScreen extends StatefulWidget {
  final Map<String, dynamic>? newsToEdit;
  final String? forcedStoreId; // ✅ پارامەتری نوێ بۆ ناچارکردنی شوێن

  const AddNewsScreen({super.key, this.newsToEdit, this.forcedStoreId});

  @override
  State<AddNewsScreen> createState() => _AddNewsScreenState();
}

class _AddNewsScreenState extends State<AddNewsScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final List<XFile> _newsImages = [];
  bool _loading = false;

  List<Map<String, dynamic>> _stores = [];
  String? _selectedStoreId;
  String? _selectedNewsType;
  bool _loadingStores = true;

  bool get isEditing => widget.newsToEdit != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _titleCtrl.text = widget.newsToEdit!['title'] ?? '';
      _descCtrl.text = widget.newsToEdit!['description'] ?? '';
      _selectedStoreId = widget.newsToEdit!['store_id']?.toString();
      _selectedNewsType = widget.newsToEdit!['news_type']?.toString() ?? 'هەواڵ';
    } else {
      _selectedNewsType = 'هەواڵ';
    }
    _fetchStores();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStores() async {
    try {
      // ✅ ئەگەر forcedStoreId هەبوو (واتە لە شاشەی شوێنەکەوە هاتووە)
      if (widget.forcedStoreId != null) {
        final res = await Supabase.instance.client
            .from('dukan')
            .select('id, name')
            .eq('id', widget.forcedStoreId!)
            .maybeSingle();

        if (res != null && mounted) {
          setState(() {
            _stores = [res];
            _selectedStoreId = res['id'].toString();
          });
        }
        if (mounted) setState(() => _loadingStores = false);
        return;
      }

      final role = AuthSessionManager.userRole;

      if (role == 'vendor') {
        final storeId = AuthSessionManager.storeId;
        if (storeId != null) {
          final res = await Supabase.instance.client
              .from('dukan')
              .select('id, name')
              .eq('id', storeId)
              .maybeSingle();

          if (res != null) {
            setState(() {
              _stores = [res];
              _selectedStoreId = res['id'].toString();
            });
          }
        }
      } else {
        final res = await Supabase.instance.client.from('dukan').select('id, name').order('name');
        setState(() {
          _stores = List<Map<String, dynamic>>.from(res as List);
        });
      }
    } catch (e) {
      debugPrint('❌ Error fetching stores: $e');
    } finally {
      if (mounted) setState(() => _loadingStores = false);
    }
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
    if (_titleCtrl.text.trim().isEmpty || _selectedStoreId == null || _selectedNewsType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr("تکایە هەموو خانەکان پڕ بکەرەوە ⚠")), backgroundColor: const Color(0xFFD9822B)),
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

      if (isEditing && uploadedUrls.isEmpty) {
        uploadedUrls = List<String>.from(widget.newsToEdit!['images'] ?? []);
      }

      if (isEditing) {
        await Supabase.instance.client.from('news').update({
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'images': uploadedUrls,
          'store_id': _selectedStoreId,
          'news_type': _selectedNewsType,
        }).eq('id', widget.newsToEdit!['id']);
      } else {
        await Supabase.instance.client.from('news').insert({
          'title': _titleCtrl.text.trim(),
          'description': _descCtrl.text.trim(),
          'images': uploadedUrls,
          'likes': 0,
          'views': 0,
          'store_id': _selectedStoreId,
          'news_type': _selectedNewsType,
          'created_at': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr(isEditing ? "✅ دەستکاری کرا" : "✅ بڵاوکرایەوە")), backgroundColor: const Color(0xFF0F9D7A)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trf("هەڵە: {0}", [e])), backgroundColor: const Color(0xFFDC3545)),
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
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F0F14) : const Color(0xFFF7F5F8),
        appBar: AppBar(
          title: Text(tr(isEditing ? "دەستکاریکردنی هەواڵ ✏️" : "بڵاوکردنەوەی هەواڵی نوێ 📢")),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _newsImages.length < 4 ? _pickImages : null,
                child: Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A22) : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.4), width: 1.5),
                  ),
                  child: _newsImages.isEmpty
                      ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_a_photo_rounded, size: 36, color: AppColors.primary),
                      const SizedBox(height: 6),
                      Text(tr("وێنەکان (تا 4 وێنە) 📸"), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  )
                      : ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(8),
                    itemCount: _newsImages.length,
                    itemBuilder: (ctx, i) => Container(
                      width: 90,
                      margin: const EdgeInsets.only(right: 8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.file(File(_newsImages[i].path), fit: BoxFit.cover)),
                          Positioned(
                            top: 4, right: 4,
                            child: GestureDetector(
                              onTap: () => setState(() => _newsImages.removeAt(i)),
                              child: Container(
                                decoration: const BoxDecoration(color: Color(0xFFDC3545), shape: BoxShape.circle),
                                padding: const EdgeInsets.all(4),
                                child: const Icon(Icons.close, size: 12, color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              if (_loadingStores)
                const Center(child: CircularProgressIndicator())
              else if (_stores.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1A1A22) : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedStoreId,
                      isExpanded: true,
                      icon: const Icon(Icons.storefront_rounded, color: AppColors.primary),
                      items: _stores.map((store) {
                        return DropdownMenuItem<String>(
                          value: store['id'].toString(),
                          child: Text(
                            tr(store['name'] ?? 'بێ ناو'),
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setState(() => _selectedStoreId = val);
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _selectedNewsType,
                decoration: InputDecoration(
                  labelText: tr("جۆری هەواڵ *"),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
                items: ['هەواڵ', 'ئاگاداری', 'هۆشداری', 'ڕووداو', 'خزمەتگوزاری'].map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(tr(type)),
                )).toList(),
                onChanged: (val) => setState(() => _selectedNewsType = val),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: tr("ناونیشانی هەواڵ *"),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
                ),
              ),
              const SizedBox(height: 16),

              TextField(
                controller: _descCtrl,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: tr("وەسف *"),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
                ),
              ),
              const SizedBox(height: 30),

              _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                  : SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: _save,
                  child: Text(
                    tr(isEditing ? "پاشەکەوتکردن ✅" : "بڵاوکردنەوە ✅"),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
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