import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../widgets/common/optimized_network_image.dart';
import 'department_services_screen.dart';

/// 🏛️ شاشەی بەڕێوەبردنی فەرمانگەکان
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

  Future<void> _fetchDepartments() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final user = AuthSessionManager.currentUser;
      final role = AuthSessionManager.userRole;

      List<Map<String, dynamic>> departments;

      // ✅ ڤێندەر — تەنها فەرمانگەی خۆی
      if (role == 'department' && user != null) {
        final userPhone = user['phone']?.toString() ?? '';
        final res = await Supabase.instance.client
            .from('departments')
            .select()
            .eq('user_phone', userPhone)
            .order('name_ku');
        departments = List<Map<String, dynamic>>.from(res);
      } else {
        // ✅ ئەدمین — هەموو فەرمانگەکان
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
  // ➕ زیادکردن / دەستکاریکردن — ✅ بە await
  // ═══════════════════════════════════════════════════════════
  Future<void> _openEditor({Map<String, dynamic>? department}) async {
    await showDialog(
      context: context,
      builder: (_) => DepartmentEditorDialog(department: department),
    );

    // ✅ دوای داخستنی دیالۆگ، داتا نوێ بکەرەوە
    if (mounted) await _fetchDepartments();
  }

  // ═══════════════════════════════════════════════════════════
  // 🗑️ سڕینەوە — ✅ بە mounted پشکنین
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
          title: const Text('سڕینەوەی فەرمانگە'),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role = AuthSessionManager.userRole;
    final isVendor = role == 'department';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F1421) : const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Text(
            isVendor ? 'فەرمانگەکەم' : 'بەڕێوەبردنی فەرمانگەکان',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF1A1B2E),
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
          child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
        )
            : Column(
          children: [
            // 🔍 گەڕان
            if (!isVendor)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1A1B2E)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.1)
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
                        color: Color(0xFF1E88E5),
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

            // 📋 لیست
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
          backgroundColor: const Color(0xFF1E88E5),
          foregroundColor: Colors.white,
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'زیادکردنی فەرمانگە',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentCard(
      Map<String, dynamic> department,
      bool isDark,
      ) {
    final name = department['name_ku']?.toString() ?? '';
    final phone = department['phone']?.toString() ?? '';
    final address = department['address']?.toString() ?? '';
    final image = department['image']?.toString() ?? '';
    final color = _hexToColor(
      department['color']?.toString() ?? '#1E88E5',
    );

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => DepartmentServicesScreen(
              department: department,
            ),
          ),
        ).then((_) => _fetchDepartments());
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // 🖼️ وێنە
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
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
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.business_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 14),
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
                      color:
                      isDark ? Colors.white : const Color(0xFF1A1A2E),
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
                          color: isDark ? Colors.white54 : Colors.grey,
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
                    Text(
                      '📞 $phone',
                      style: TextStyle(
                        fontSize: 11,
                        color:
                        isDark ? Colors.white54 : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // ✅ دوگمەکان
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_rounded, size: 20),
                  color: color,
                  onPressed: _isDeleting
                      ? null
                      : () => _openEditor(department: department),
                ),
                IconButton(
                  icon:
                  const Icon(Icons.delete_outline_rounded, size: 20),
                  color: Colors.red,
                  onPressed: _isDeleting
                      ? null
                      : () => _deleteDepartment(department),
                ),
              ],
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
          Icon(
            Icons.business_rounded,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey[300],
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
      return const Color(0xFF1E88E5);
    }
  }
}

// ═══════════════════════════════════════════════════════════
// 🎨 دیالۆگی زیادکردن / دەستکاریکردنی فەرمانگە
// ═══════════════════════════════════════════════════════════
class DepartmentEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? department;

  const DepartmentEditorDialog({super.key, this.department});

  @override
  State<DepartmentEditorDialog> createState() =>
      _DepartmentEditorDialogState();
}

class _DepartmentEditorDialogState extends State<DepartmentEditorDialog> {
  late TextEditingController _nameKuCtrl;
  late TextEditingController _nameArCtrl;
  late TextEditingController _nameEnCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _websiteCtrl;
  late TextEditingController _userPhoneCtrl;
  late String _selectedColor;
  bool _loading = false;

  final List<String> _colors = [
    '#1E88E5',
    '#10B981',
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
    _selectedColor = d?['color'] ?? '#1E88E5';
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
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameKuCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ناوی فەرمانگە پێویستە'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final data = {
        'name_ku': _nameKuCtrl.text.trim(),
        'name_ar': _nameArCtrl.text.trim(),
        'name_en': _nameEnCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'address': _addressCtrl.text.trim(),
        'website': _websiteCtrl.text.trim(),
        'user_phone': _userPhoneCtrl.text.trim(),
        'color': _selectedColor,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.department == null) {
        await Supabase.instance.client.from('departments').insert(data);
      } else {
        await Supabase.instance.client
            .from('departments')
            .update(data)
            .eq('id', widget.department!['id']);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ پاشەکەوتکرا'),
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.department != null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.business_rounded,
                      color: Color(0xFF1E88E5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEditing
                          ? 'دەستکاریکردنی فەرمانگە'
                          : 'زیادکردنی فەرمانگە',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _buildField('ناوی کوردی *', _nameKuCtrl),
                const SizedBox(height: 10),
                _buildField('ناوی عەرەبی', _nameArCtrl),
                const SizedBox(height: 10),
                _buildField('ناوی ئینگلیزی', _nameEnCtrl),
                const SizedBox(height: 10),
                _buildField('ژمارەی مۆبایل', _phoneCtrl),
                const SizedBox(height: 10),
                _buildField('ناونیشان', _addressCtrl),
                const SizedBox(height: 10),
                _buildField('ماڵپەڕ', _websiteCtrl),
                const SizedBox(height: 10),
                _buildField(
                  'ژمارەی ڤێندەر (بۆ چوونەژوورەوەی فەرمانگە)',
                  _userPhoneCtrl,
                ),
                const SizedBox(height: 16),

                // 🎨 ڕەنگ
                const Text(
                  'ڕەنگی فەرمانگە',
                  style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: _colors.map((c) {
                    final color = _hexToColor(c);
                    final isSelected = _selectedColor == c;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = c),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected
                                ? Colors.white
                                : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: isSelected
                              ? [
                            BoxShadow(
                              color: color.withValues(alpha: 0.5),
                              blurRadius: 10,
                            ),
                          ]
                              : null,
                        ),
                        child: isSelected
                            ? const Icon(
                          Icons.check_rounded,
                          color: Colors.white,
                          size: 18,
                        )
                            : null,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 24),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: _loading ? null : _save,
                    icon: _loading
                        ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : const Icon(Icons.save_rounded),
                    label: Text(
                      isEditing ? 'نوێکردنەوە' : 'زیادکردن',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
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
      return const Color(0xFF1E88E5);
    }
  }
}