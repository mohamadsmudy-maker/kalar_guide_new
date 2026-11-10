import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/image_service.dart';
import '../../services/storage_service.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../l10n/tr.dart';
import '../../utils/place_display.dart';

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
  /// وێنە بارکراوەکانی هەواڵێک کە دەستکاری دەکرێت (دەتوانرێت لاببرێن)
  final List<String> _existingUrls = [];
  bool _loading = false;
  bool _triedSave = false;

  static const int _maxImages = 4;
  int get _imageCount => _existingUrls.length + _newsImages.length;

  /// جۆرەکانی هەواڵ: (ناو، ئایکۆن، ڕەنگ)
  static const List<(String, IconData, Color)> _types = [
    ('هەواڵ', Icons.newspaper_rounded, AppColors.toneBlue),
    ('ئاگاداری', Icons.campaign_rounded, AppColors.toneAmber),
    ('هۆشداری', Icons.warning_amber_rounded, AppColors.toneRed),
    ('ڕووداو', Icons.event_rounded, AppColors.toneIndigo),
    ('خزمەتگوزاری', Icons.volunteer_activism_rounded, AppColors.toneTeal),
  ];

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
      final imgs = widget.newsToEdit!['images'];
      if (imgs is List) {
        _existingUrls.addAll(imgs.map((e) => '$e').where((u) => u.startsWith('http')));
      }
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
        final remainingSlots = _maxImages - _imageCount;
        _newsImages.addAll(pickedList.take(remainingSlots));
      });
    }
  }

  Future<void> _save() async {
    setState(() => _triedSave = true);
    if (_titleCtrl.text.trim().isEmpty ||
        _descCtrl.text.trim().isEmpty ||
        _selectedStoreId == null ||
        _selectedNewsType == null) {
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

      // وێنە کۆنەکان (ئەوانەی نەسڕاونەتەوە) + وێنە نوێیەکان
      uploadedUrls = [..._existingUrls, ...uploadedUrls];

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
    final card = isDark ? const Color(0xFF1A1A22) : Colors.white;
    final text = isDark ? Colors.white : AppColors.textPrimary;
    final sub = isDark ? Colors.white54 : AppColors.textSecondary;
    final line = isDark ? Colors.white12 : const Color(0xFFE6EAF0);
    final storeName = _stores
        .where((st) => st['id'].toString() == _selectedStoreId)
        .map((st) => '${st['name'] ?? ''}')
        .firstOrNull;
    final storeLocked = widget.forcedStoreId != null || _stores.length == 1;

    InputDecoration field(String hint, {String? error}) => InputDecoration(
          hintText: tr(hint),
          errorText: error,
          filled: true,
          fillColor: card,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: line)),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.toneRed),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.toneRed, width: 1.6),
          ),
        );

    Widget label(IconData icon, String t, {Widget? trailing}) => Padding(
          padding: const EdgeInsets.only(bottom: 10, top: 4),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary),
              const SizedBox(width: 6),
              Expanded(child: Text(tr(t), style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: text))),
              if (trailing != null) trailing,
            ],
          ),
        );

    Widget thumb({String? url, XFile? file, required VoidCallback onRemove}) => Container(
          width: 92,
          height: 92,
          margin: const EdgeInsetsDirectional.only(end: 10),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: url != null
                    ? Image.network(url, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: line, child: const Icon(Icons.broken_image)))
                    : Image.file(File(file!.path), fit: BoxFit.cover),
              ),
              PositionedDirectional(
                top: 4,
                end: 4,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        );

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6FA),
        appBar: AppBar(
          title: Text(
            tr(isEditing ? 'دەستکاریکردنی هەواڵ' : 'بڵاوکردنەوەی هەواڵی نوێ'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          children: [
            // ─── بڵاوکەرەوە ───
            if (_loadingStores)
              const Padding(padding: EdgeInsets.all(12), child: Center(child: CircularProgressIndicator()))
            else if (_stores.isNotEmpty) ...[
              label(Icons.storefront_rounded, 'بڵاوکەرەوە'),
              if (storeLocked)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.06),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr(storeName ?? ''),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w900, color: text, fontSize: 15),
                        ),
                      ),
                      Icon(Icons.verified_rounded, color: AppColors.primary.withValues(alpha: 0.8), size: 20),
                    ],
                  ),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _selectedStoreId,
                  isExpanded: true,
                  decoration: field('شوێنێک هەڵبژێرە',
                      error: _triedSave && _selectedStoreId == null ? tr('شوێنێک هەڵبژێرە') : null),
                  items: _stores
                      .map((store) => DropdownMenuItem<String>(
                            value: store['id'].toString(),
                            child: Text(tr(store['name'] ?? 'بێ ناو'),
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                          ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedStoreId = val),
                ),
              const SizedBox(height: 18),
            ],

            // ─── جۆر ───
            label(Icons.category_rounded, 'جۆری بڵاوکراوە'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final (name, icon, color) in _types)
                  ChoiceChip(
                    selected: _selectedNewsType == name,
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedNewsType = name);
                    },
                    showCheckmark: false,
                    avatar: Icon(icon, size: 18, color: _selectedNewsType == name ? Colors.white : color),
                    label: Text(tr(name)),
                    labelStyle: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _selectedNewsType == name ? Colors.white : color,
                    ),
                    selectedColor: color,
                    backgroundColor: color.withValues(alpha: isDark ? 0.18 : 0.08),
                    side: BorderSide(color: color.withValues(alpha: 0.35)),
                    shape: const StadiumBorder(),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  ),
              ],
            ),
            const SizedBox(height: 18),

            // ─── ناونیشان ───
            label(Icons.title_rounded, 'ناونیشان'),
            TextField(
              controller: _titleCtrl,
              maxLength: 120,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => Text(
                PlaceDisplay.digits('$currentLength / $maxLength'),
                style: TextStyle(fontSize: 11, color: sub),
              ),
              textInputAction: TextInputAction.next,
              onChanged: (_) => setState(() {}),
              style: TextStyle(fontWeight: FontWeight.w800, color: text, fontSize: 15.5),
              decoration: field('ناونیشانێکی کورت و ڕوون...',
                  error: _triedSave && _titleCtrl.text.trim().isEmpty ? tr('ناونیشان پێویستە') : null),
            ),
            const SizedBox(height: 8),

            // ─── دەق ───
            label(Icons.notes_rounded, 'دەقی هەواڵ'),
            TextField(
              controller: _descCtrl,
              minLines: 5,
              maxLines: 12,
              maxLength: 2000,
              buildCounter: (_, {required currentLength, required isFocused, maxLength}) => Text(
                PlaceDisplay.digits('$currentLength / $maxLength'),
                style: TextStyle(fontSize: 11, color: sub),
              ),
              onChanged: (_) => setState(() {}),
              style: TextStyle(color: text, height: 1.6),
              decoration: field('وردەکاری هەواڵەکە بنووسە...',
                  error: _triedSave && _descCtrl.text.trim().isEmpty ? tr('دەقی هەواڵ پێویستە') : null),
            ),
            const SizedBox(height: 8),

            // ─── وێنەکان ───
            label(
              Icons.photo_library_rounded,
              'وێنەکان',
              trailing: Text(
                '${PlaceDisplay.digits(_imageCount)} / ${PlaceDisplay.digits(_maxImages)}',
                style: TextStyle(color: sub, fontWeight: FontWeight.w800),
              ),
            ),
            SizedBox(
              height: 92,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final u in _existingUrls) thumb(url: u, onRemove: () => setState(() => _existingUrls.remove(u))),
                  for (var i = 0; i < _newsImages.length; i++)
                    thumb(file: _newsImages[i], onRemove: () => setState(() => _newsImages.removeAt(i))),
                  if (_imageCount < _maxImages)
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: _pickImages,
                      child: Container(
                        width: 92,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: isDark ? 0.12 : 0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1.4),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_a_photo_rounded, color: AppColors.primary, size: 26),
                            const SizedBox(height: 4),
                            Text(tr('زیادکردن'),
                                style: const TextStyle(color: AppColors.primary, fontSize: 11.5, fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(18, 8, 18, 12),
          child: SizedBox(
            height: 54,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _loading ? null : _save,
              icon: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(isEditing ? Icons.check_rounded : Icons.send_rounded),
              label: Text(
                tr(isEditing ? 'پاشەکەوتکردن' : 'بڵاوکردنەوە'),
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
