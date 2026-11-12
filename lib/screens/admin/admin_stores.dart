import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../widgets/common/auto_translate.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../stores/add_store_screen.dart';
import 'admin_store_services_screen.dart';
import '../../l10n/tr.dart';

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
        textDirection: AppLang.direction,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(tr("سڕینەوەی شوێن 🗑")),
          content: Text(tr("ئایا دڵنیایت لە سڕینەوەی ئەم شوێنە؟")),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr("نەخێر")),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC3545),
                foregroundColor: Colors.white,
              ),
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
          .from('dukan')
          .delete()
          .eq('id', storeId);
      _fetchStores();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr("شوێنەکە سڕایەوە 🗑")),
            backgroundColor: const Color(0xFF0F9D7A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trf("هەڵە: {0}", [e])), backgroundColor: const Color(0xFFDC3545)),
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

  // 🆕 دوگمەی مامەڵەکان
  void _openStoreServices(Map<String, dynamic> store) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminStoreServicesScreen(
          storeId: int.tryParse(store['id'].toString()) ?? 0,
          storeName: store['name']?.toString() ?? '',
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<SettingsProvider>().languageId;
    final filteredStores = _filteredStores;

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F5F7),
        appBar: AppBar(
          title: Text(
            tr("بەڕێوەبردنی شوێنەکان 🏪"),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
          label: Text(
            tr("زیادکردنی شوێنی نوێ"),
            style: const TextStyle(fontWeight: FontWeight.bold),
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
                    hintText: tr("گەڕان بەدوای شوێنەکان..."),
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
                    label: trf('هەموو ({0})', [_allStores.length]),
                    value: 'all',
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: trf('بە لۆکەیشن ({0})', [_withLocationCount]),
                    value: 'with_location',
                    color: const Color(0xFF0F9D7A),
                  ),
                  const SizedBox(width: 6),
                  _buildFilterChip(
                    label: trf('بێ لۆکەیشن ({0})', [_withoutLocationCount]),
                    value: 'without_location',
                    color: const Color(0xFFD9822B),
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
                          trf("{0} شوێن", [filteredStores.length]),
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
                  ? Center(
                child: Text(
                  tr("هیچ شوێنێک نەدۆزرایەوە 📍"),
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
                  : ListView.builder(
                padding:
                const EdgeInsets.fromLTRB(16, 8, 16, 100),
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
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: OptimizedNetworkImage(
                    imageUrl: store['image'] ?? '',
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AutoTranslate(
                        text: store['name']?.toString() ?? '',
                        lang: lang,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 4),
                      AutoTranslate(
                        text: "📍 ${store['address'] ?? ''}",
                        lang: lang,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            trf('📞 {0}', [tr(store['phone'] ?? 'نییە')]),
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
                                border: Border.all(
                                  color: Colors.green.shade200,
                                ),
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
                                    tr('لۆکەیشن'),
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
                                border: Border.all(
                                  color: Colors.orange.shade200,
                                ),
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
                                    tr('بێ لۆکەیشن'),
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
              ],
            ),
            const SizedBox(height: 10),
            // ⚡ دوگمەکان
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.description_rounded,
                      label: tr('مامەڵەکان'),
                      color: const Color(0xFF4F5BD5),
                      onTap: () => _openStoreServices(store),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.grey.shade300,
                  ),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.edit_rounded,
                      label: tr('دەستکاری'),
                      color: const Color(0xFF1E88E5),
                      onTap: () => _openEditStore(store),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 30,
                    color: Colors.grey.shade300,
                  ),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.delete_outline_rounded,
                      label: tr('سڕینەوە'),
                      color: const Color(0xFFDC3545),
                      onTap: () => _deleteStore(store['id']),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              tr(label),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
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
              tr(label),
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