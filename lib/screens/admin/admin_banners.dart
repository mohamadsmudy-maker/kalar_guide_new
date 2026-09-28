import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../services/image_service.dart';

/// 🎨 شاشەی ڕێکخستنی سلایدەکان (Full Pro)
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
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveNewOrder() async {
    for (int i = 0; i < _banners.length; i++) {
      if (_banners[i]['is_empty'] == true) continue;
      await Supabase.instance.client
          .from('banners')
          .update({'sort_order': i}).eq('id', _banners[i]['id']);
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("ڕیزبەند نوێکرایەوە ✅"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _deleteSlot(Map<String, dynamic> banner) async {
    if (banner['is_empty'] == true) return;

    bool ok = await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            "سڕینەوەی '${banner['title']}'؟",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text("نەخێر", style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("بەڵێ"),
            ),
          ],
        ),
      ),
    ) ??
        false;

    if (!ok) return;

    await Supabase.instance.client
        .from('banners')
        .delete()
        .eq('id', banner['id']);
    _fetchBanners();
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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F5F7),
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
          title: const Text(
            "ڕێکخستنی 5 سلایدی سەرەکی",
            style: TextStyle(
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
            ? const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        )
            : Column(
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE3F2FD)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
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
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.touch_app_rounded,
                      color: Color(0xFF1976D2),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "ڕاکێشە بۆ گۆڕینی شوێن • کرتە بکە بۆ دەستکاریکردن",
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF455A64),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _banners.length,
                onReorder: (oldI, newI) {
                  setState(() {
                    if (newI > oldI) newI -= 1;
                    final it = _banners.removeAt(oldI);
                    _banners.insert(newI, it);
                  });
                  _saveNewOrder();
                },
                itemBuilder: (context, index) {
                  final banner = _banners[index];
                  final isEmpty = banner['is_empty'] == true;
                  return Container(
                    key: ValueKey(banner['id'] ?? 'slot_$index'),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isEmpty
                            ? const Color(0xFFDDDDDD)
                            : AppColors.primary.withValues(alpha: 0.25),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
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
                              color: const Color(0xFFF5F5F5),
                              child: const Icon(
                                Icons.add_photo_alternate_outlined,
                                color: Colors.grey,
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isEmpty
                                    ? Colors.grey
                                    : AppColors.primary,
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
                        isEmpty
                            ? "شوێنی بەتاڵ ${index + 1}"
                            : (banner['title'] ?? ''),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: isEmpty ? Colors.grey : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            isEmpty
                                ? "کرتە بکە بۆ زیادکردن"
                                : "نرخ: ${banner['price']} د.ع",
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!isEmpty)
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 20,
                                color: Color(0xFFEF5350),
                              ),
                              style: IconButton.styleFrom(
                                backgroundColor: const Color(0xFFFFEBEE),
                              ),
                              onPressed: () => _deleteSlot(banner),
                            ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.all(7),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F5),
                              borderRadius: BorderRadius.circular(9),
                            ),
                            child: const Icon(
                              Icons.drag_indicator_rounded,
                              size: 18,
                              color: Colors.grey,
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

// ═══════════════════════════════════════════════════════════
// 🎨 دیالۆگی دەستکاریکردنی سلاید (Full Pro - 3 Tabs)
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
  String _adType = 'store'; // store, news, custom

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
      final res =
      await Supabase.instance.client.from('dukan').select().order('name');
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
    final picked =
    await picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      setState(() {
        _pickedCustomImage = picked;
      });
    }
  }

  Future<void> _saveSlide() async {
    if (_titleCtrl.text.trim().isEmpty && _adType == 'custom') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تکایە ناونیشانی ڕیکلام پڕبکەرەوە ⚠"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      String imageUrl = _customImageCtrl.text.trim();
      String finalTitle = _titleCtrl.text.trim();

      if (_adType == 'custom') {
        if (_pickedCustomImage != null) {
          imageUrl =
          await ImageCompressionService.uploadImage(_pickedCustomImage!);
        }
      } else if (_adType == 'store' && _selectedStore != null) {
        imageUrl = _selectedStore!['image'] ?? '';
        finalTitle = _selectedStore!['name'] ?? '';
      } else if (_adType == 'news' &&
          _selectedNews != null &&
          _selectedStore != null) {
        List imgs =
        _selectedNews!['images'] is List ? _selectedNews!['images'] : [];
        if (imgs.isNotEmpty) imageUrl = imgs.first.toString();
        String newsTitle = _selectedNews!['title'] ?? '';
        String storeName = _selectedStore!['name'] ?? '';
        finalTitle = "$newsTitle • $storeName";
      }

      num parsedPrice = num.tryParse(
          _priceCtrl.text.trim().replaceAll(RegExp(r'[^0-9.]'), '')) ??
          0;

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
        await Supabase.instance.client
            .from('banners')
            .update(data)
            .eq('id', widget.currentBanner['id']);
      }

      if (mounted) {
        Navigator.pop(context, data);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("بە سەرکەوتوویی پاشەکەوتکرا ✅"),
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
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: MediaQuery.sizeOf(context).width * 0.95,
          height: MediaQuery.sizeOf(context).height * 0.85,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // 🎯 سەرەتا
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "دەستکاری سلایدی ژمارە ${widget.slotIndex + 1}",
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              // 🎯 Tabs
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
                unselectedLabelColor: Colors.grey,
                indicatorColor: AppColors.primary,
                tabs: const [
                  Tab(
                      icon: Icon(Icons.storefront_rounded, size: 18),
                      text: "شوێن"),
                  Tab(
                      icon: Icon(Icons.article_rounded, size: 18),
                      text: "هەواڵی شوێن"),
                  Tab(
                      icon: Icon(Icons.brush, size: 18),
                      text: "وێنەی خۆت"),
                ],
              ),
              const SizedBox(height: 12),

              Expanded(
                child: TabBarView(
                  controller: _tabCtrl,
                  children: [
                    // 1️⃣ تبەی شوێن (Store)
                    Column(
                      children: [
                        TextField(
                          controller: _searchStoreCtrl,
                          onChanged: (val) {
                            setState(() {
                              _filteredStores = _stores
                                  .where((s) => (s['name'] ?? '')
                                  .toLowerCase()
                                  .contains(val.toLowerCase()))
                                  .toList();
                            });
                          },
                          decoration: InputDecoration(
                            hintText: "گەڕان بەدوای شوێن...",
                            prefixIcon: const Icon(Icons.search,
                                color: AppColors.primary),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 8),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Expanded(
                          child: _filteredStores.isEmpty
                              ? const Center(
                              child: Text("هیچ شوێنێک نەدۆزرایەوە 📍",
                                  style: TextStyle(color: Colors.grey)))
                              : ListView.builder(
                            itemCount: _filteredStores.length,
                            itemBuilder: (ctx, i) {
                              var s = _filteredStores[i];
                              bool isSel =
                                  _selectedStoreId == s['id'].toString();
                              return Card(
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                      color: isSel
                                          ? AppColors.primary
                                          : Colors.grey.shade200,
                                      width: isSel ? 2 : 1),
                                ),
                                child: ListTile(
                                  leading: ClipRRect(
                                    borderRadius:
                                    BorderRadius.circular(8),
                                    child: OptimizedNetworkImage(
                                        imageUrl: s['image'] ?? '',
                                        width: 45,
                                        height: 45,
                                        fit: BoxFit.cover),
                                  ),
                                  title: Text(s['name'] ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13)),
                                  subtitle: Text(s['address'] ?? '',
                                      style: const TextStyle(
                                          fontSize: 11)),
                                  trailing: isSel
                                      ? const Icon(Icons.check_circle,
                                      color: AppColors.primary)
                                      : null,
                                  onTap: () {
                                    setState(() {
                                      _selectedStoreId =
                                          s['id'].toString();
                                      _selectedStore = s;
                                      _selectedNewsId = null;
                                      _selectedNews = null;
                                    });
                                    _fetchNewsForStore(
                                        _selectedStoreId!);
                                  },
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),

                    // 2️⃣ تبەی هەواڵی شوێن (Store News)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12)),
                          child: Row(
                            children: [
                              const Icon(Icons.store,
                                  color: AppColors.primary, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedStore != null
                                      ? "شوێنی هەڵبژێردراو: ${_selectedStore!['name']}"
                                      : "⚠️ سەرەتا لە خوارەوە شوێنێک هەڵبژێرە!",
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                      color: _selectedStore != null
                                          ? AppColors.primary
                                          : Colors.red.shade700),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (_selectedStoreId == null) ...[
                          const Text("تکایە سەرەتا شوێنێک هەڵبژێرە:",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _stores.length,
                              itemBuilder: (ctx, i) {
                                var s = _stores[i];
                                return Card(
                                  child: ListTile(
                                    dense: true,
                                    title: Text(s['name'] ?? '',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12)),
                                    trailing: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 14),
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
                        ] else ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text("هەواڵی ئەم شوێنە هەڵبژێرە:",
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold)),
                              TextButton(
                                onPressed: () => setState(() {
                                  _selectedStoreId = null;
                                  _selectedStore = null;
                                  _storeNews.clear();
                                }),
                                child: const Text("گۆڕینی شوێن 🔄",
                                    style: TextStyle(fontSize: 11)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Expanded(
                            child: _loadingNews
                                ? const Center(
                                child: CircularProgressIndicator())
                                : _storeNews.isEmpty
                                ? const Center(
                                child: Text(
                                    "ئەم شوێنە هیچ هەواڵێکی نییە 📭",
                                    style:
                                    TextStyle(color: Colors.grey)))
                                : ListView.builder(
                              itemCount: _storeNews.length,
                              itemBuilder: (ctx, i) {
                                var n = _storeNews[i];
                                bool isSel = _selectedNewsId ==
                                    n['id'].toString();
                                List imgs = n['images'] is List
                                    ? n['images']
                                    : [];
                                String img = imgs.isNotEmpty
                                    ? imgs.first.toString()
                                    : '';

                                return Card(
                                  shape: RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(12),
                                    side: BorderSide(
                                        color: isSel
                                            ? AppColors.primary
                                            : Colors.grey.shade200,
                                        width: isSel ? 2 : 1),
                                  ),
                                  child: ListTile(
                                    leading: ClipRRect(
                                      borderRadius:
                                      BorderRadius.circular(8),
                                      child: OptimizedNetworkImage(
                                          imageUrl: img,
                                          width: 40,
                                          height: 40,
                                          fit: BoxFit.cover),
                                    ),
                                    title: Text(n['title'] ?? '',
                                        style: const TextStyle(
                                            fontWeight:
                                            FontWeight.bold,
                                            fontSize: 12)),
                                    subtitle: Text(
                                        n['description'] ?? '',
                                        maxLines: 1,
                                        overflow:
                                        TextOverflow.ellipsis,
                                        style: const TextStyle(
                                            fontSize: 10)),
                                    trailing: isSel
                                        ? const Icon(
                                        Icons.check_circle,
                                        color: AppColors.primary)
                                        : null,
                                    onTap: () {
                                      setState(() {
                                        _selectedNewsId =
                                            n['id'].toString();
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
                    ),

                    // 3️⃣ تبەی وێنەی خۆت (Custom Image)
                    SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          const Text("هەڵبژاردنی وێنە بە دەست 🖼️:",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 12)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: _pickCustomImage,
                            child: Container(
                              height: 140,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.4)),
                              ),
                              child: _pickedCustomImage != null
                                  ? ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: Image.file(
                                    File(_pickedCustomImage!.path),
                                    fit: BoxFit.cover),
                              )
                                  : _customImageCtrl.text.isNotEmpty
                                  ? ClipRRect(
                                borderRadius:
                                BorderRadius.circular(14),
                                child: OptimizedNetworkImage(
                                    imageUrl:
                                    _customImageCtrl.text,
                                    fit: BoxFit.cover),
                              )
                                  : const Column(
                                mainAxisAlignment:
                                MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_a_photo,
                                      color: AppColors.primary,
                                      size: 30),
                                  SizedBox(height: 6),
                                  Text(
                                      "کرتە بکە بۆ هەڵبژاردنی وێنە لە گالەری 📸",
                                      style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _titleCtrl,
                            decoration: InputDecoration(
                              labelText: "ناونیشانی ڕیکلام *",
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _priceCtrl,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: "نرخ (اختیاری)",
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // 🎯 دوگمەکانی ژێرەوە
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text("پاشگەزبوونەوە",
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black87)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: _loading
                        ? const Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary))
                        : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _saveSlide,
                      child: Text(
                        widget.currentBanner['is_empty'] == true
                            ? "زیادکردن"
                            : "نوێکردنەوە",
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14),
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
}