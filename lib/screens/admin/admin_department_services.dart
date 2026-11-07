// lib/screens/admin/admin_department_services.dart
// بەڕێوەبردنی خزمەتگوزارییەکانی فەرمانگەیەک

part of 'admin_departments.dart';


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
