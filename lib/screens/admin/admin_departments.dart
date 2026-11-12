import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_department_place_picker.dart';
import 'admin_department_services_screen.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../l10n/tr.dart';

part 'admin_department_editor_sheet.dart';

/// 🏛️ شاشەی بەڕێوەبردنی فەرمانگەکان — ULTRA PRO V2
class AdminDepartmentsScreen extends StatefulWidget {
  const AdminDepartmentsScreen({super.key});

  @override
  State<AdminDepartmentsScreen> createState() =>
      _AdminDepartmentsScreenState();
}

class _AdminDepartmentsScreenState extends State<AdminDepartmentsScreen> {
  bool _isLoading = true;
  bool _isDeleting = false;
  List<Map<String, dynamic>> _departments = [];
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 📡 Fetch
  // ═══════════════════════════════════════════════════════════
  Future<void> _fetchDepartments() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = AuthSessionManager.currentUser;
      final role = AuthSessionManager.userRole;

      List<Map<String, dynamic>> departments;

      // ڤێندەر — تەنها فەرمانگەی خۆی
      if (role == 'department' && user != null) {
        final userPhone = user['phone']?.toString() ?? '';
        final res = await Supabase.instance.client
            .from('departments')
            .select()
            .eq('user_phone', userPhone)
            .order('name_ku');
        departments = List<Map<String, dynamic>>.from(res);
      } else {
        // ئەدمین — هەموو فەرمانگەکان
        final res = await Supabase.instance.client
            .from('departments')
            .select()
            .order('name_ku');
        departments = List<Map<String, dynamic>>.from(res);
      }

      if (mounted) {
        setState(() {
          _departments = departments;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredDepartments {
    if (_searchQuery.isEmpty) return _departments;
    return _departments.where((d) {
      final name = (d['name_ku'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // ➕ / ✏️ Editor
  // ═══════════════════════════════════════════════════════════
  Future<void> _openEditor({Map<String, dynamic>? department}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DepartmentEditorSheet(department: department),
    );

    if (result == null) return;

    try {
      if (department == null) {
        await Supabase.instance.client.from('departments').insert(result);
      } else {
        await Supabase.instance.client
            .from('departments')
            .update(result)
            .eq('id', department['id']);
      }

      await _fetchDepartments();

      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr(department == null ? '✅ زیادکرا' : '✅ نوێکرایەوە')),
            backgroundColor: const Color(0xFF0F9D7A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trf('هەڵە: {0}', [e])), backgroundColor: const Color(0xFFDC3545)),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📍 زیادکردن لە شوێنە تۆمارکراوەکان
  // ═══════════════════════════════════════════════════════════
  Future<void> _addFromPlaces() async {
    final place = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          DepartmentPlacePickerSheet(existingDepartments: _departments),
    );
    if (place == null) return;

    final row = DepartmentPlaces.rowFromPlace(place);
    final table = Supabase.instance.client.from('departments');
    try {
      Map<String, dynamic> created;
      try {
        created = await table.insert(row).select().single();
      } on PostgrestException catch (e) {
        // مایگرەیشنی place_id هێشتا جێبەجێ نەکراوە — بێ ئەو ستوونە زیاد بکە
        if (!e.message.contains('place_id')) rethrow;
        created =
            await table.insert({...row}..remove('place_id')).select().single();
      }

      await _fetchDepartments();
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('✅ فەرمانگە زیادکرا — ئێستا مامەڵەکانی زیاد بکە')),
          backgroundColor: const Color(0xFF0F9D7A),
        ),
      );
      // ڕاستەوخۆ بۆ زیادکردنی مامەڵەکانی ئەم فەرمانگەیە
      await _openServicesManager(created);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trf('هەڵە: {0}', [e])),
            backgroundColor: const Color(0xFFDC3545),
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🗑️ Delete
  // ═══════════════════════════════════════════════════════════
  Future<void> _deleteDepartment(Map<String, dynamic> department) async {
    if (_isDeleting) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFDC3545)),
              const SizedBox(width: 8),
              Text(tr('سڕینەوەی فەرمانگە')),
            ],
          ),
          content: Text(
            trf('ئایا دڵنیایت لە سڕینەوەی "{0}"؟\n\nهەموو مامەڵەکانی ئەم فەرمانگەش دەسڕدرێنەوە.', [department['name_ku']]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('نەخێر')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC3545),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr('سڕینەوە')),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    if (mounted) setState(() => _isDeleting = true);

    try {
      await Supabase.instance.client
          .from('departments')
          .delete()
          .eq('id', department['id']);

      await _fetchDepartments();

      if (mounted) {
        HapticFeedback.heavyImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('✅ فەرمانگە سڕایەوە')),
            backgroundColor: const Color(0xFF0F9D7A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(trf('هەڵە: {0}', [e])), backgroundColor: const Color(0xFFDC3545)),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 بەڕێوەبردنی مامەڵەکان
  // ═══════════════════════════════════════════════════════════
  Future<void> _openServicesManager(Map<String, dynamic> dept) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AdminDepartmentServicesScreen(department: dept),
      ),
    );
    if (mounted) _fetchDepartments();
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role = AuthSessionManager.userRole;
    final isVendor = role == 'department';

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF0F4F9),
        appBar: AppBar(
          title: Text(
            tr(isVendor ? 'فەرمانگەکەم' : 'بەڕێوەبردنی فەرمانگەکان'),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF0F9D7A),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _fetchDepartments,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
          child: CircularProgressIndicator(color: Color(0xFF0F9D7A)),
        )
            : Column(
          children: [
            // 🔍 Search
            if (!isVendor)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A1A22)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.trim()),
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      hintText: tr('گەڕان بەدوای فەرمانگەکان...'),
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF0F9D7A),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                    ),
                  ),
                ),
              ),

            // 📋 List
            Expanded(
              child: _filteredDepartments.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _filteredDepartments.length,
                itemBuilder: (context, index) =>
                    _buildDepartmentCard(
                      _filteredDepartments[index],
                      isDark,
                    ),
              ),
            ),
          ],
        ),
        floatingActionButton: isVendor
            ? null
            : FloatingActionButton.extended(
          backgroundColor: const Color(0xFF0F9D7A),
          foregroundColor: Colors.white,
          onPressed: _addFromPlaces,
          icon: const Icon(Icons.add_rounded),
          label: Text(
            tr('زیادکردنی فەرمانگە'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 Department Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildDepartmentCard(
      Map<String, dynamic> department,
      bool isDark,
      ) {
    final name = department['name_ku']?.toString() ?? '';
    final phone = department['phone']?.toString() ?? '';
    final address = department['address']?.toString() ?? '';
    final image = department['image']?.toString() ?? '';
    final color = _hexToColor(
      department['color']?.toString() ?? '#10B981',
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        children: [
          // ═══ Main Info ═══
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Image
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: image.isNotEmpty
                      ? OptimizedNetworkImage(
                    imageUrl: image,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  )
                      : Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.7)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr(name),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1A1A2E),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              size: 12,
                              color:
                              isDark ? Colors.white54 : Colors.grey,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                tr(address),
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.phone_rounded,
                              size: 12,
                              color: color,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              tr(phone),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: color,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ═══ Actions Bar ═══
          Container(
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF0F0F14)
                  : const Color(0xFFF8F9FA),
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(18),
              ),
            ),
            child: Row(
              children: [
                // 📋 مامەڵەکان
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.list_alt_rounded,
                    label: tr('مامەڵەکان'),
                    color: const Color(0xFF4F5BD5),
                    onTap: _isDeleting
                        ? null
                        : () => _openServicesManager(department),
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade300,
                ),
                // ✏️ دەستکاری
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.edit_rounded,
                    label: tr('دەستکاری'),
                    color: const Color(0xFF1E88E5),
                    onTap: _isDeleting
                        ? null
                        : () => _openEditor(department: department),
                  ),
                ),
                Container(
                  width: 1,
                  height: 30,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : Colors.grey.shade300,
                ),
                // 🗑️ سڕینەوە
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.delete_outline_rounded,
                    label: tr('سڕینەوە'),
                    color: const Color(0xFFDC3545),
                    onTap: _isDeleting
                        ? null
                        : () => _deleteDepartment(department),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 5),
            Text(
              tr(label),
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
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
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF0F9D7A).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.business_outlined,
              size: 60,
              color: Color(0xFF0F9D7A),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr('هیچ فەرمانگەیەک نییە'),
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFF0F9D7A);
    }
  }
}
