import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_department_services_screen.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/optimized_network_image.dart';

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
            content: Text(department == null ? '✅ زیادکرا' : '✅ نوێکرایەوە'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('هەڵە: $e'), backgroundColor: Colors.red),
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
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('سڕینەوەی فەرمانگە'),
            ],
          ),
          content: Text(
            'ئایا دڵنیایت لە سڕینەوەی "${department['name_ku']}"؟\n\n'
                'هەموو مامەڵەکانی ئەم فەرمانگەش دەسڕدرێنەوە.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('نەخێر'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('سڕینەوە'),
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
          const SnackBar(
            content: Text('✅ فەرمانگە سڕایەوە'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('هەڵە: $e'), backgroundColor: Colors.red),
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
    Navigator.push(
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
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF0F4F9),
        appBar: AppBar(
          title: Text(
            isVendor ? 'فەرمانگەکەم' : 'بەڕێوەبردنی فەرمانگەکان',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF10B981),
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
          child: CircularProgressIndicator(color: Color(0xFF10B981)),
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
                      hintText: 'گەڕان بەدوای فەرمانگەکان...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.white54 : Colors.grey,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF10B981),
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
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'زیادکردنی فەرمانگە',
            style: TextStyle(fontWeight: FontWeight.w900),
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
                        name,
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
                                address,
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
                              phone,
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
                    label: 'مامەڵەکان',
                    color: const Color(0xFF8B5CF6),
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
                    label: 'دەستکاری',
                    color: Colors.blue,
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
                    label: 'سڕینەوە',
                    color: Colors.red,
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
              label,
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
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.business_outlined,
              size: 60,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'هیچ فەرمانگەیەک نییە',
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
      return const Color(0xFF10B981);
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// 🎨 Editor Sheet — زیادکردن / دەستکاریکردنی فەرمانگە
// ═══════════════════════════════════════════════════════════════
class _DepartmentEditorSheet extends StatefulWidget {
  final Map<String, dynamic>? department;
  const _DepartmentEditorSheet({this.department});

  @override
  State<_DepartmentEditorSheet> createState() =>
      _DepartmentEditorSheetState();
}

class _DepartmentEditorSheetState extends State<_DepartmentEditorSheet> {
  late TextEditingController _nameKuCtrl;
  late TextEditingController _nameArCtrl;
  late TextEditingController _nameEnCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _websiteCtrl;
  late TextEditingController _userPhoneCtrl;
  late TextEditingController _imageCtrl;
  late String _selectedColor;

  final List<String> _colors = [
    '#10B981',
    '#1E88E5',
    '#EF4444',
    '#F59E0B',
    '#8B5CF6',
    '#EC4899',
    '#14B8A6',
    '#6C5CE7',
  ];

  @override
  void initState() {
    super.initState();
    final d = widget.department;
    _nameKuCtrl = TextEditingController(text: d?['name_ku'] ?? '');
    _nameArCtrl = TextEditingController(text: d?['name_ar'] ?? '');
    _nameEnCtrl = TextEditingController(text: d?['name_en'] ?? '');
    _phoneCtrl = TextEditingController(text: d?['phone'] ?? '');
    _addressCtrl = TextEditingController(text: d?['address'] ?? '');
    _websiteCtrl = TextEditingController(text: d?['website'] ?? '');
    _userPhoneCtrl = TextEditingController(text: d?['user_phone'] ?? '');
    _imageCtrl = TextEditingController(text: d?['image'] ?? '');
    _selectedColor = d?['color'] ?? '#10B981';
  }

  @override
  void dispose() {
    _nameKuCtrl.dispose();
    _nameArCtrl.dispose();
    _nameEnCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _websiteCtrl.dispose();
    _userPhoneCtrl.dispose();
    _imageCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameKuCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ناوی فەرمانگە پێویستە'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final data = {
      'name_ku': _nameKuCtrl.text.trim(),
      'name_ar': _nameArCtrl.text.trim().isEmpty
          ? null
          : _nameArCtrl.text.trim(),
      'name_en': _nameEnCtrl.text.trim().isEmpty
          ? null
          : _nameEnCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim().isEmpty
          ? null
          : _phoneCtrl.text.trim(),
      'address': _addressCtrl.text.trim().isEmpty
          ? null
          : _addressCtrl.text.trim(),
      'website': _websiteCtrl.text.trim().isEmpty
          ? null
          : _websiteCtrl.text.trim(),
      'user_phone': _userPhoneCtrl.text.trim().isEmpty
          ? null
          : _userPhoneCtrl.text.trim(),
      'image': _imageCtrl.text.trim().isEmpty
          ? null
          : _imageCtrl.text.trim(),
      'color': _selectedColor,
      'updated_at': DateTime.now().toIso8601String(),
    };

    Navigator.pop(context, data);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.department != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            const SizedBox(height: 10),
            Container(
              width: 45,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.business_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing
                          ? 'دەستکاریکردنی فەرمانگە'
                          : 'زیادکردنی فەرمانگە',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Form
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildField('ناوی کوردی *', _nameKuCtrl, isDark),
                    const SizedBox(height: 10),
                    _buildField('ناوی عەرەبی', _nameArCtrl, isDark),
                    const SizedBox(height: 10),
                    _buildField('ناوی ئینگلیزی', _nameEnCtrl, isDark),
                    const SizedBox(height: 10),
                    _buildField(
                      'ژمارەی مۆبایل',
                      _phoneCtrl,
                      isDark,
                      keyboard: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),
                    _buildField('ناونیشان', _addressCtrl, isDark),
                    const SizedBox(height: 10),
                    _buildField('ماڵپەڕ', _websiteCtrl, isDark),
                    const SizedBox(height: 10),
                    _buildField(
                      'لینکی وێنە (URL)',
                      _imageCtrl,
                      isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildField(
                      'ژمارەی ڤێندەر (بۆ چوونەژوورەوەی فەرمانگە)',
                      _userPhoneCtrl,
                      isDark,
                      keyboard: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),

                    // Color Picker
                    Row(
                      children: [
                        Container(
                          width: 4,
                          height: 16,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                Color(0xFF10B981),
                                Color(0xFF059669),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'ڕەنگی فەرمانگە',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A2E),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: _colors.map((c) {
                        final color = _hexToColor(c);
                        final isSelected = _selectedColor == c;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _selectedColor = c);
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 3,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: color.withValues(
                                    alpha: isSelected ? 0.6 : 0.3,
                                  ),
                                  blurRadius: isSelected ? 14 : 6,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: isSelected
                                ? const Icon(
                              Icons.check_rounded,
                              color: Colors.white,
                              size: 20,
                            )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // Save Button
            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F0F14)
                    : Colors.grey.shade50,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade200,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                    shadowColor:
                    const Color(0xFF10B981).withValues(alpha: 0.4),
                  ),
                  onPressed: _save,
                  icon: Icon(
                    isEditing
                        ? Icons.save_rounded
                        : Icons.add_circle_rounded,
                    size: 22,
                  ),
                  label: Text(
                    isEditing ? 'نوێکردنەوە' : 'زیادکردن',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
      String label,
      TextEditingController ctrl,
      bool isDark, {
        TextInputType? keyboard,
        int maxLines = 1,
      }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
      maxLines: maxLines,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white54 : Colors.grey.shade700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF10B981),
            width: 1.5,
          ),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F0F14) : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }

  Color _hexToColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFF10B981);
    }
  }
}

// ═══════════════════════════════════════════════════════════════
// 📋 بەڕێوەبردنی مامەڵەکانی فەرمانگە — ULTRA PRO
// ═══════════════════════════════════════════════════════════════
class DepartmentServicesAdminScreen extends StatefulWidget {
  final Map<String, dynamic> department;
  const DepartmentServicesAdminScreen({super.key, required this.department});

  @override
  State<DepartmentServicesAdminScreen> createState() =>
      _DepartmentServicesAdminScreenState();
}

class _DepartmentServicesAdminScreenState
    extends State<DepartmentServicesAdminScreen> {
  bool _loading = true;
  List<Map<String, dynamic>> _services = [];

  @override
  void initState() {
    super.initState();
    _loadServices();
  }

  Future<void> _loadServices() async {
    if (mounted) setState(() => _loading = true);
    try {
      final res = await Supabase.instance.client
          .from('department_services')
          .select()
          .eq('department_id', widget.department['id'])
          .order('display_order');

      if (mounted) {
        setState(() {
          _services = List<Map<String, dynamic>>.from(res);
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Services error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? service}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ServiceEditorSheet(
        departmentId: widget.department['id'],
        service: service,
      ),
    );

    if (result == null) return;

    try {
      if (service == null) {
        await Supabase.instance.client
            .from('department_services')
            .insert(result);
      } else {
        await Supabase.instance.client
            .from('department_services')
            .update(result)
            .eq('id', service['id']);
      }
      _loadServices();
      if (mounted) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
            Text(service == null ? '✅ زیادکرا' : '✅ نوێکرایەوە'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('هەڵە: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteService(Map<String, dynamic> service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('سڕینەوەی مامەڵە'),
            ],
          ),
          content: Text(
            'ئایا دڵنیایت لە سڕینەوەی "${service['title_ku']}"؟',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('نەخێر'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('سڕینەوە'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;

    try {
      await Supabase.instance.client
          .from('department_services')
          .delete()
          .eq('id', service['id']);
      HapticFeedback.heavyImpact();
      _loadServices();
    } catch (e) {
      debugPrint('❌ $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = widget.department['name_ku']?.toString() ?? 'فەرمانگە';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF0F4F9),
        appBar: AppBar(
          title: Text(
            'مامەڵەکانی $name',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
            ),
          ),
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF10B981),
          ),
        )
            : _services.isEmpty
            ? _buildEmpty(isDark)
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _services.length,
          itemBuilder: (context, i) =>
              _buildServiceTile(_services[i], isDark),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          backgroundColor: const Color(0xFF10B981),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'زیادکردنی مامەڵە',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceTile(Map<String, dynamic> service, bool isDark) {
    final title = service['title_ku']?.toString() ?? '';
    final requirements = service['requirements'];
    final fees = service['fees'];
    final reqCount = requirements is List ? requirements.length : 0;
    final feeCount = fees is List ? fees.length : 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.2),
          width: 1.2,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (reqCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$reqCount پێداویستی',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF8B5CF6),
                          ),
                        ),
                      ),
                    if (reqCount > 0 && feeCount > 0)
                      const SizedBox(width: 6),
                    if (feeCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981)
                              .withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$feeCount تێچوو',
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(
              Icons.edit_rounded,
              color: Colors.blue,
              size: 20,
            ),
            onPressed: () => _openEditor(service: service),
          ),
          IconButton(
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: Colors.red,
              size: 20,
            ),
            onPressed: () => _deleteService(service),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 60,
              color: Color(0xFF10B981),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'هیچ مامەڵەیەک نییە',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 📝 Editor Sheet — زیادکردنی مامەڵە
// ═══════════════════════════════════════════════════════════════
class _ServiceEditorSheet extends StatefulWidget {
  final dynamic departmentId;
  final Map<String, dynamic>? service;

  const _ServiceEditorSheet({
    required this.departmentId,
    this.service,
  });

  @override
  State<_ServiceEditorSheet> createState() => _ServiceEditorSheetState();
}

class _ServiceEditorSheetState extends State<_ServiceEditorSheet> {
  late TextEditingController _titleCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _durationCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _notesCtrl;
  late TextEditingController _requirementsCtrl;
  late TextEditingController _feesCtrl;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _titleCtrl = TextEditingController(text: s?['title_ku'] ?? '');
    _descCtrl = TextEditingController(text: s?['description'] ?? '');
    _durationCtrl = TextEditingController(text: s?['duration'] ?? '');
    _locationCtrl = TextEditingController(text: s?['location'] ?? '');
    _notesCtrl = TextEditingController(text: s?['notes'] ?? '');

    final reqs = s?['requirements'];
    _requirementsCtrl = TextEditingController(
      text: reqs is List ? reqs.join('\n') : '',
    );

    final fees = s?['fees'];
    _feesCtrl = TextEditingController(
      text: fees is List ? fees.join('\n') : '',
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _durationCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    _requirementsCtrl.dispose();
    _feesCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ناونیشان پێویستە'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final requirements = _requirementsCtrl.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final fees = _feesCtrl.text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final data = {
      'department_id': widget.departmentId,
      'title_ku': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim(),
      'duration': _durationCtrl.text.trim().isEmpty
          ? null
          : _durationCtrl.text.trim(),
      'location': _locationCtrl.text.trim().isEmpty
          ? null
          : _locationCtrl.text.trim(),
      'notes': _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
      'requirements': requirements,
      'fees': fees,
      'icon': 'description',
      'color': '#10B981',
      'is_active': true,
      'display_order': 0,
      'updated_at': DateTime.now().toIso8601String(),
    };

    Navigator.pop(context, data);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.service != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 45,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF10B981), Color(0xFF059669)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.description_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing
                          ? 'دەستکاریکردنی مامەڵە'
                          : 'زیادکردنی مامەڵە',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? Colors.white
                            : const Color(0xFF1A1A2E),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildField('ناونیشان *', _titleCtrl, isDark),
                    const SizedBox(height: 10),
                    _buildField('وەسف', _descCtrl, isDark, maxLines: 2),
                    const SizedBox(height: 10),
                    _buildField(
                      'ماوە (بۆ نموونە: ٣٠-٦٠ خولەک)',
                      _durationCtrl,
                      isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildField('شوێن', _locationCtrl, isDark),
                    const SizedBox(height: 10),
                    _buildField(
                      'پێداویستییەکان (هەر دێرێک = یەک پێداویستی)',
                      _requirementsCtrl,
                      isDark,
                      maxLines: 6,
                    ),
                    const SizedBox(height: 10),
                    _buildField(
                      'تێچووەکان (هەر دێرێک = یەک تێچوو)',
                      _feesCtrl,
                      isDark,
                      maxLines: 5,
                    ),
                    const SizedBox(height: 10),
                    _buildField(
                      'تێبینی',
                      _notesCtrl,
                      isDark,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F0F14)
                    : Colors.grey.shade50,
                border: Border(
                  top: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.grey.shade200,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _save,
                  icon: Icon(
                    isEditing
                        ? Icons.save_rounded
                        : Icons.add_circle_rounded,
                  ),
                  label: Text(
                    isEditing ? 'نوێکردنەوە' : 'زیادکردن',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(
      String label,
      TextEditingController ctrl,
      bool isDark, {
        int maxLines = 1,
      }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      style: TextStyle(
        color: isDark ? Colors.white : Colors.black87,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: isDark ? Colors.white54 : Colors.grey.shade700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(0xFF10B981),
            width: 1.5,
          ),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F0F14) : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
    );
  }
}