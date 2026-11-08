import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../services/image_service.dart';
import '../../l10n/tr.dart';

/// 🎨 شاشەی ڕێکخستنی سلایدەکان (Ultra Pro Max)
class AdminReorderBannersScreen extends StatefulWidget {
  const AdminReorderBannersScreen({super.key});

  @override
  State<AdminReorderBannersScreen> createState() =>
      _AdminReorderBannersScreenState();
}

class _AdminReorderBannersScreenState extends State<AdminReorderBannersScreen> {
  List<Map<String, dynamic>> _banners = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBanners();
  }

  Future<void> _fetchBanners() async {
    setState(() => _isLoading = true);
    try {
      final response = await Supabase.instance.client
          .from('banners')
          .select()
          .order('sort_order', ascending: true)
          .limit(5);

      List<Map<String, dynamic>> fetched =
      List<Map<String, dynamic>>.from(response);

      List<Map<String, dynamic>> slots = List.generate(5, (i) {
        if (i < fetched.length) {
          return {...fetched[i], 'slot_index': i};
        }
        return {
          'id': 'empty_$i',
          'is_empty': true,
          'slot_index': i,
          'sort_order': i,
          'title': '',
          'price': '',
          'image': '',
        };
      });

      if (mounted) {
        setState(() {
          _banners = slots;
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

  Future<void> _saveNewOrder() async {
    try {
      for (int i = 0; i < _banners.length; i++) {
        if (_banners[i]['is_empty'] == true) continue;
        await Supabase.instance.client
            .from('banners')
            .update({'sort_order': i}).eq('id', _banners[i]['id']);
      }
      if (mounted) {
        HapticFeedback.lightImpact();
        _showSnackBar(tr("ڕیزبەند نوێکرایەوە ✅"));
      }
    } catch (e) {
      _showSnackBar(trf("هەڵە لە پاشەکەوتکردنی ڕیزبەند: {0}", [e]), isError: true);
    }
  }

  Future<void> _deleteSlot(Map<String, dynamic> banner) async {
    if (banner['is_empty'] == true) return;

    bool ok = await _showConfirmDialog(
      title: trf("سڕینەوەی '{0}'؟", [banner['title']]),
      message: tr("ئایا دڵنیایت لە سڕینەوەی ئەم سلایدە؟"),
    );
    if (!ok) return;

    try {
      await Supabase.instance.client
          .from('banners')
          .delete()
          .eq('id', banner['id']);
      _fetchBanners();
    } catch (e) {
      _showSnackBar(trf("هەڵە لە سڕینەوە: {0}", [e]), isError: true);
    }
  }

  void _openEditDialog(int slotIndex) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditSlideProDialog(
        slotIndex: slotIndex,
        currentBanner: _banners[slotIndex],
      ),
    ).then((_) => _fetchBanners());
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(tr(msg), style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: isError ? Colors.red : Colors.green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
  }

  Future<bool> _showConfirmDialog({
    required String title,
    required String message,
  }) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(tr(title), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          content: Text(tr(message), style: const TextStyle(fontSize: 13)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr("نەخێر"), style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr("بەڵێ")),
            ),
          ],
        ),
      ),
    ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : const Color(0xFFF6F5F7);

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE91E63), Color(0xFFAD1457)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          title: Text(
            tr("ڕێکخستنی 5 سلایدی سەرەکی"),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          foregroundColor: Colors.white,
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _fetchBanners,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Column(
          children: [
            _buildHeaderInfo(isDark),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _banners.length,
                onReorderItem: (oldI, newI) {
                  setState(() {
                    final it = _banners.removeAt(oldI);
                    _banners.insert(newI, it);
                  });
                  _saveNewOrder();
                },
                itemBuilder: (context, index) {
                  return _buildBannerItem(index, isDark);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(bool isDark) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : const Color(0xFFE3F2FD),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isDark ? Colors.blue.withValues(alpha: 0.2) : const Color(0xFFE3F2FD),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.touch_app_rounded,
              color: Color(0xFF1976D2),
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              tr("ڕاکێشە بۆ گۆڕینی شوێن • کرتە بکە بۆ دەستکاریکردن"),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white70 : const Color(0xFF455A64),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBannerItem(int index, bool isDark) {
    final banner = _banners[index];
    final isEmpty = banner['is_empty'] == true;

    return Container(
      key: ValueKey(banner['id'] ?? 'slot_$index'),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isEmpty
              ? (isDark ? AppColors.darkBorder : const Color(0xFFDDDDDD))
              : AppColors.primary.withValues(alpha: 0.25),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        onTap: () => _openEditDialog(index),
        leading: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: isEmpty
                  ? Container(
                width: 68,
                height: 68,
                color: isDark ? AppColors.darkBackground : const Color(0xFFF5F5F5),
                child: Icon(
                  Icons.add_photo_alternate_outlined,
                  color: isDark ? Colors.white54 : Colors.grey,
                ),
              )
                  : OptimizedNetworkImage(
                imageUrl: banner['image'] ?? '',
                width: 68,
                height: 68,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 2,
              left: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isEmpty ? Colors.grey : AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "${index + 1}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          ],
        ),
        title: Text(
          tr(isEmpty ? trf("شوێنی بەتاڵ {0}", [index + 1]) : (banner['title'] ?? '')),
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: isEmpty
                ? (isDark ? Colors.white54 : Colors.grey)
                : (isDark ? Colors.white : Colors.black87),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              tr(isEmpty ? "کرتە بکە بۆ زیادکردن" : "نرخ: ${banner['price']} د.ع"),
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.white60 : Colors.grey,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20, color: Color(0xFFEF5350)),
                style: IconButton.styleFrom(
                  backgroundColor: isDark ? Colors.red.withValues(alpha: 0.15) : const Color(0xFFFFEBEE),
                ),
                onPressed: () => _deleteSlot(banner),
              ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                Icons.drag_indicator_rounded,
                size: 18,
                color: isDark ? Colors.white54 : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🎨 دیالۆگی دەستکاریکردنی سلاید
// ═══════════════════════════════════════════════════════════
class EditSlideProDialog extends StatefulWidget {
  final int slotIndex;
  final Map<String, dynamic> currentBanner;

  const EditSlideProDialog({
    super.key,
    required this.slotIndex,
    required this.currentBanner,
  });

  @override
  State<EditSlideProDialog> createState() => EditSlideProDialogState();
}

class EditSlideProDialogState extends State<EditSlideProDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  String _adType = 'store';

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _priceCtrl = TextEditingController();
  final TextEditingController _customImageCtrl = TextEditingController();
  final TextEditingController _searchStoreCtrl = TextEditingController();

  String? _selectedStoreId;
  Map<String, dynamic>? _selectedStore;

  String? _selectedNewsId;
  Map<String, dynamic>? _selectedNews;

  bool _loading = false;
  bool _loadingNews = false;
  List<Map<String, dynamic>> _stores = [];
  List<Map<String, dynamic>> _filteredStores = [];
  List<Map<String, dynamic>> _storeNews = [];
  XFile? _pickedCustomImage;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    final b = widget.currentBanner;

    if (b['is_empty'] != true) {
      _titleCtrl.text = b['title'] ?? '';
      _priceCtrl.text = b['price']?.toString() ?? '0';
      _customImageCtrl.text = b['image'] ?? '';
      _adType = b['type'] ?? 'store';
      _selectedStoreId = b['store_id']?.toString();
      _selectedNewsId = b['news_id']?.toString();

      if (_adType == 'store') {
        _tabCtrl.index = 0;
      } else if (_adType == 'news') {
        _tabCtrl.index = 1;
      } else {
        _tabCtrl.index = 2;
      }
    }

    _fetchStores();
    if (_selectedStoreId != null) {
      _fetchNewsForStore(_selectedStoreId!);
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _priceCtrl.dispose();
    _customImageCtrl.dispose();
    _searchStoreCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStores() async {
    try {
      final res = await Supabase.instance.client.from('dukan').select().order('name');
      if (mounted) {
        setState(() {
          _stores = List<Map<String, dynamic>>.from(res);
          _filteredStores = _stores;
          if (_selectedStoreId != null) {
            _selectedStore = _stores.firstWhere(
                  (s) => s['id'].toString() == _selectedStoreId,
              orElse: () => {},
            );
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchNewsForStore(String storeId) async {
    setState(() => _loadingNews = true);
    try {
      final res = await Supabase.instance.client
          .from('news')
          .select()
          .eq('store_id', storeId)
          .order('id', ascending: false);
      if (mounted) {
        setState(() {
          _storeNews = List<Map<String, dynamic>>.from(res);
          _loadingNews = false;
          if (_selectedNewsId != null) {
            _selectedNews = _storeNews.firstWhere(
                  (n) => n['id'].toString() == _selectedNewsId,
              orElse: () => {},
            );
          }
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingNews = false);
    }
  }

  Future<void> _pickCustomImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      setState(() => _pickedCustomImage = picked);
    }
  }

  Future<void> _saveSlide() async {
    if (_titleCtrl.text.trim().isEmpty && _adType == 'custom') {
      _showSnackBar(tr("تکایە ناونیشانی ڕیکلام پڕبکەرەوە ⚠"), isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      String imageUrl = _customImageCtrl.text.trim();
      String finalTitle = _titleCtrl.text.trim();

      if (_adType == 'custom') {
        if (_pickedCustomImage != null) {
          imageUrl = await ImageCompressionService.uploadImage(_pickedCustomImage!);
        }
      } else if (_adType == 'store' && _selectedStore != null) {
        imageUrl = _selectedStore!['image'] ?? '';
        finalTitle = _selectedStore!['name'] ?? '';
      } else if (_adType == 'news' && _selectedNews != null && _selectedStore != null) {
        List imgs = _selectedNews!['images'] is List ? _selectedNews!['images'] : [];
        if (imgs.isNotEmpty) imageUrl = imgs.first.toString();
        String newsTitle = _selectedNews!['title'] ?? '';
        String storeName = _selectedStore!['name'] ?? '';
        finalTitle = "$newsTitle • $storeName";
      }

      num parsedPrice = num.tryParse(_priceCtrl.text.trim().replaceAll(RegExp(r'[^0-9.]'), '')) ?? 0;

      final data = {
        'title': finalTitle,
        'price': parsedPrice,
        'image': imageUrl,
        'store_id': _adType == 'store' || _adType == 'news'
            ? (_selectedStoreId != null ? int.tryParse(_selectedStoreId!) : null)
            : null,
        'news_id': _adType == 'news'
            ? (_selectedNewsId != null ? int.tryParse(_selectedNewsId!) : null)
            : null,
        'sort_order': widget.slotIndex,
        'type': _adType,
      };

      if (widget.currentBanner['is_empty'] == true) {
        await Supabase.instance.client.from('banners').insert(data);
      } else {
        await Supabase.instance.client.from('banners').update(data).eq('id', widget.currentBanner['id']);
      }

      if (mounted) {
        Navigator.pop(context, data);
        _showSnackBar(tr("بە سەرکەوتوویی پاشەکەوتکرا ✅"));
      }
    } catch (e) {
      if (mounted) _showSnackBar(trf("هەڵە: {0}", [e]), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSnackBar(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr(msg), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: isError ? Colors.orange : Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: AppLang.direction,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.sizeOf(context).width * 0.95,
          height: MediaQuery.sizeOf(context).height * 0.85,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    trf("دەستکاری سلایدی ژمارە {0}", [widget.slotIndex + 1]),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white70 : Colors.grey),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              TabBar(
                controller: _tabCtrl,
                onTap: (i) {
                  setState(() {
                    if (i == 0) _adType = 'store';
                    else if (i == 1) _adType = 'news';
                    else _adType = 'custom';
                  });
                },
                labelColor: AppColors.primary,
                unselectedLabelColor: isDark ? Colors.white54 : Colors.grey,
                indicatorColor: AppColors.primary,
                tabs: [
                  Tab(icon: const Icon(Icons.storefront_rounded, size: 18), text: tr("شوێن")),
                  Tab(icon: const Icon(Icons.article_rounded, size: 18), text: tr("هەواڵی شوێن")),
                  Tab(icon: const Icon(Icons.brush, size: 18), text: tr("وێنەی خۆت")),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildStoreTab(isDark),
                    _buildNewsTab(isDark),
                    _buildCustomTab(isDark),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: isDark ? AppColors.darkBorder : Colors.grey.shade400),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        tr("پاشگەزبوونەوە"),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _loading
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                        : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _saveSlide,
                      child: Text(
                        tr(widget.currentBanner['is_empty'] == true ? "زیادکردن" : "نوێکردنەوە"),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStoreTab(bool isDark) {
    return Column(
      children: [
        TextField(
          controller: _searchStoreCtrl,
          onChanged: (val) {
            setState(() {
              _filteredStores = _stores
                  .where((s) => (s['name'] ?? '').toLowerCase().contains(val.toLowerCase()))
                  .toList();
            });
          },
          decoration: InputDecoration(
            hintText: tr("گەڕان بەدوای شوێن..."),
            prefixIcon: const Icon(Icons.search, color: AppColors.primary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            filled: true,
            fillColor: isDark ? AppColors.darkBackground : Colors.grey.shade50,
          ),
          style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: _filteredStores.isEmpty
              ? Center(
            child: Text(
              tr("هیچ شوێنێک نەدۆزرایەوە 📍"),
              style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
            ),
          )
              : ListView.builder(
            itemCount: _filteredStores.length,
            itemBuilder: (ctx, i) {
              var s = _filteredStores[i];
              bool isSel = _selectedStoreId == s['id'].toString();
              return Card(
                color: isDark ? AppColors.darkCard : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSel ? AppColors.primary : (isDark ? AppColors.darkBorder : Colors.grey.shade200),
                    width: isSel ? 2 : 1,
                  ),
                ),
                child: ListTile(
                  leading: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: OptimizedNetworkImage(
                      imageUrl: s['image'] ?? '',
                      width: 45,
                      height: 45,
                      fit: BoxFit.cover,
                    ),
                  ),
                  title: Text(
                    tr(s['name'] ?? ''),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    tr(s['address'] ?? ''),
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.grey),
                  ),
                  trailing: isSel ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                  onTap: () {
                    setState(() {
                      _selectedStoreId = s['id'].toString();
                      _selectedStore = s;
                      _selectedNewsId = null;
                      _selectedNews = null;
                    });
                    _fetchNewsForStore(_selectedStoreId!);
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildNewsTab(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? Colors.blue.withValues(alpha: 0.15) : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.store, color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tr(_selectedStore != null
                      ? trf("شوێنی هەڵبژێردراو: {0}", [_selectedStore!['name']])
                      : "⚠️ سەرەتا لە خوارەوە شوێنێک هەڵبژێرە!"),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: _selectedStore != null ? AppColors.primary : Colors.red.shade700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (_selectedStoreId == null)
          Expanded(
            child: ListView.builder(
              itemCount: _stores.length,
              itemBuilder: (ctx, i) {
                var s = _stores[i];
                return Card(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  child: ListTile(
                    dense: true,
                    title: Text(
                      tr(s['name'] ?? ''),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () {
                      setState(() {
                        _selectedStoreId = s['id'].toString();
                        _selectedStore = s;
                        _selectedNewsId = null;
                        _selectedNews = null;
                      });
                      _fetchNewsForStore(_selectedStoreId!);
                    },
                  ),
                );
              },
            ),
          )
        else ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                tr("هەواڵی ئەم شوێنە هەڵبژێرە:"),
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  _selectedStoreId = null;
                  _selectedStore = null;
                  _storeNews.clear();
                }),
                child: Text(tr("گۆڕینی شوێن 🔄"), style: const TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Expanded(
            child: _loadingNews
                ? const Center(child: CircularProgressIndicator())
                : _storeNews.isEmpty
                ? Center(
              child: Text(
                tr("ئەم شوێنە هیچ هەواڵێکی نییە 📭"),
                style: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: _storeNews.length,
              itemBuilder: (ctx, i) {
                var n = _storeNews[i];
                bool isSel = _selectedNewsId == n['id'].toString();
                List imgs = n['images'] is List ? n['images'] : [];
                String img = imgs.isNotEmpty ? imgs.first.toString() : '';

                return Card(
                  color: isDark ? AppColors.darkCard : Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSel ? AppColors.primary : (isDark ? AppColors.darkBorder : Colors.grey.shade200),
                      width: isSel ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: OptimizedNetworkImage(
                        imageUrl: img,
                        width: 40,
                        height: 40,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(
                      tr(n['title'] ?? ''),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      tr(n['description'] ?? ''),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey),
                    ),
                    trailing: isSel ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                    onTap: () {
                      setState(() {
                        _selectedNewsId = n['id'].toString();
                        _selectedNews = n;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildCustomTab(bool isDark) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 6),
          Text(
            tr("هەڵبژاردنی وێنە بە دەست 🖼️:"),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: _pickCustomImage,
            child: Container(
              height: 140,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
              ),
              child: _pickedCustomImage != null
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(File(_pickedCustomImage!.path), fit: BoxFit.cover),
              )
                  : _customImageCtrl.text.isNotEmpty
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: OptimizedNetworkImage(imageUrl: _customImageCtrl.text, fit: BoxFit.cover),
              )
                  : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_a_photo, color: AppColors.primary, size: 30),
                  const SizedBox(height: 6),
                  Text(
                    tr("کرتە بکە بۆ هەڵبژاردنی وێنە لە گالەری 📸"),
                    style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _titleCtrl,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: tr("ناونیشانی ڕیکلام *"),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.white,
              labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _priceCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: InputDecoration(
              labelText: tr("نرخ (اختیاری)"),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.white,
              labelStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
            ),
          ),
        ],
      ),
    );
  }
}