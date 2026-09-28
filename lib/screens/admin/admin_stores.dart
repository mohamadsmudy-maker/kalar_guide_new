import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../widgets/common/auto_translate.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../screens/stores/add_store_screen.dart';  // ✅ چالاک کرا

/// 🏪 شاشەی بەڕێوەبردنی شوێنەکان — PRO EDITION
class AdminStoresScreen extends StatefulWidget {
  const AdminStoresScreen({super.key});

  @override
  State<AdminStoresScreen> createState() => _AdminStoresScreenState();
}

class _AdminStoresScreenState extends State<AdminStoresScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allStores = [];
  String _searchQuery = '';
  String _filter = 'all';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStores();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 هێنانی شوێنەکان
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchStores() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('dukan')
          .select()
          .order('name');

      final List<dynamic> rawList = res as List;
      final stores = rawList
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

      int withLoc = 0;
      for (var s in stores) {
        final lat = double.tryParse(s['latitude']?.toString() ?? '');
        final lng = double.tryParse(s['longitude']?.toString() ?? '');
        if (lat != null && lng != null && lat != 0 && lng != 0) {
          withLoc++;
        }
      }
      debugPrint('📊 AdminStores: ${stores.length} کۆی، $withLoc بە لۆکەیشن');

      if (mounted) {
        setState(() {
          _allStores = stores;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ AdminStores fetch error: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 فلتەرکردن
  // ═══════════════════════════════════════════════════════════
  List<Map<String, dynamic>> get _filteredStores {
    return _allStores.where((store) {
      final name = (store['name'] ?? '').toString().toLowerCase();
      final address = (store['address'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      final matchesSearch = _searchQuery.isEmpty ||
          name.contains(q) ||
          address.contains(q);

      if (!matchesSearch) return false;
      if (_filter == 'all') return true;

      final lat = double.tryParse(store['latitude']?.toString() ?? '');
      final lng = double.tryParse(store['longitude']?.toString() ?? '');
      final hasLocation =
          lat != null && lng != null && lat != 0 && lng != 0;

      if (_filter == 'with_location') return hasLocation;
      if (_filter == 'without_location') return !hasLocation;

      return true;
    }).toList();
  }

  int get _withLocationCount {
    return _allStores.where((s) {
      final lat = double.tryParse(s['latitude']?.toString() ?? '');
      final lng = double.tryParse(s['longitude']?.toString() ?? '');
      return lat != null && lng != null && lat != 0 && lng != 0;
    }).length;
  }

  int get _withoutLocationCount => _allStores.length - _withLocationCount;

  // ═══════════════════════════════════════════════════════════
  // 🗑 سڕینەوە
  // ═══════════════════════════════════════════════════════════
  Future<void> _deleteStore(dynamic storeId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text("سڕینەوەی شوێن 🗑"),
          content: const Text("ئایا دڵنیایت لە سڕینەوەی ئەم شوێنە؟"),
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
      await Supabase.instance.client.from('dukan').delete().eq('id', storeId);
      _fetchStores();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("شوێنەکە سڕایەوە 🗑"),
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

  // ═══════════════════════════════════════════════════════════
  // ➕ زیادکردن / ✏️ دەستکاری
  // ═══════════════════════════════════════════════════════════
  void _openAddStore() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddStoreScreen(),
      ),
    ).then((_) => _fetchStores());
  }

  void _openEditStore(Map<String, dynamic> store) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddStoreScreen(storeToEdit: store),
      ),
    ).then((_) => _fetchStores());
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<SettingsProvider>().languageId;
    final filteredStores = _filteredStores;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F5F7),
        appBar: AppBar(
          title: const Text(
            "بەڕێوەبردنی شوێنەکان 🏪",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: _openAddStore,
          icon: const Icon(Icons.add),
          label: const Text(
            "زیادکردنی شوێنی نوێ",
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: Column(
          children: [
            // 🔍 گەڕان
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (val) =>
                      setState(() => _searchQuery = val.trim()),
                  decoration: InputDecoration(
                    hintText: "گەڕان بەدوای شوێنەکان...",
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: Colors.grey,
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

            // 🎯 فلتەرەکان
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterChip(
                    label: 'هەموو (${_allStores.length})',
                    value: 'all',
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: 'بە لۆکەیشن (${_withLocationCount})',
                    value: 'with_location',
                    color: Colors.green,
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: 'بێ لۆکەیشن (${_withoutLocationCount})',
                    value: 'without_location',
                    color: Colors.orange,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 📊 ئاماری ئەنجام
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.storefront_rounded,
                          color: AppColors.primary,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "${filteredStores.length} شوێن",
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // 📋 لیستی شوێنەکان
            Expanded(
              child: _isLoading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                ),
              )
                  : filteredStores.isEmpty
                  ? const Center(
                child: Text(
                  "هیچ شوێنێک نەدۆزرایەوە 📍",
                  style: TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                itemCount: filteredStores.length,
                itemBuilder: (context, index) {
                  return _buildStoreCard(
                    filteredStores[index],
                    lang,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 کارتی شوێن
  // ═══════════════════════════════════════════════════════════
  Widget _buildStoreCard(Map<String, dynamic> store, String lang) {
    final lat = double.tryParse(store['latitude']?.toString() ?? '');
    final lng = double.tryParse(store['longitude']?.toString() ?? '');
    final hasLocation =
        lat != null && lng != null && lat != 0 && lng != 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: OptimizedNetworkImage(
            imageUrl: store['image'] ?? '',
            width: 60,
            height: 60,
            fit: BoxFit.cover,
          ),
        ),
        title: AutoTranslate(
          text: store['name']?.toString() ?? '',
          lang: lang,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
          maxLines: 1,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AutoTranslate(
                text: "📍 ${store['address'] ?? ''}",
                lang: lang,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
                maxLines: 1,
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Text(
                    "📞 ${store['phone'] ?? 'نییە'}",
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (hasLocation)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_on_rounded,
                            size: 10,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'لۆکەیشن',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.location_off_rounded,
                            size: 10,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            'بێ لۆکەیشن',
                            style: TextStyle(
                              fontSize: 9,
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(
                Icons.edit_rounded,
                color: Colors.blue,
                size: 22,
              ),
              tooltip: "دەستکاریکردن",
              onPressed: () => _openEditStore(store),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
                size: 22,
              ),
              tooltip: "سڕینەوە",
              onPressed: () => _deleteStore(store['id']),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 فلتر Chip
  // ═══════════════════════════════════════════════════════════
  Widget _buildFilterChip({
    required String label,
    required String value,
    required Color color,
  }) {
    final isSelected = _filter == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _filter = value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? color : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }
}