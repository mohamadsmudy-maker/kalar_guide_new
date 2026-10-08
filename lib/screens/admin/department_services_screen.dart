import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import 'package:provider/provider.dart';

/// 🏛️ شاشەی مامەڵەکانی فەرمانگە
class DepartmentServicesScreen extends StatefulWidget {
  final Map<String, dynamic> department;

  const DepartmentServicesScreen({
    super.key,
    required this.department,
  });

  @override
  State<DepartmentServicesScreen> createState() =>
      _DepartmentServicesScreenState();
}

class _DepartmentServicesScreenState extends State<DepartmentServicesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _services = [];

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('department_services')
          .select()
          .eq('department_id', widget.department['id'])
          .order('display_order');

      if (mounted) {
        setState(() {
          _services = List<Map<String, dynamic>>.from(res);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ➕ زیادکردن / دەستکاریکردن
  // ═══════════════════════════════════════════════════════════
  void _openEditor({Map<String, dynamic>? service}) {
    showDialog(
      context: context,
      builder: (_) => ServiceEditorDialog(
        departmentId: widget.department['id'],
        service: service,
      ),
    ).then((_) => _fetchServices());
  }

  // ═══════════════════════════════════════════════════════════
  // 🗑️ سڕینەوە
  // ═══════════════════════════════════════════════════════════
  Future<void> _deleteService(Map<String, dynamic> service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('سڕینەوەی مامەڵە'),
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

      await _fetchServices();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ مامەڵە سڕایەوە'),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = widget.department['name_ku']?.toString() ?? 'فەرمانگە';
    final color = _hexToColor(
      widget.department['color']?.toString() ?? '#1E88E5',
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F1421) : const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Text(
            'مامەڵەکانی $name',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
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
              onPressed: _fetchServices,
            ),
          ],
        ),
        body: _isLoading
            ? Center(
          child: CircularProgressIndicator(color: color),
        )
            : _services.isEmpty
            ? _buildEmptyState(isDark, color)
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _services.length,
          itemBuilder: (context, index) => _buildServiceCard(
            _services[index],
            isDark,
            color,
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: color,
          foregroundColor: Colors.white,
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'زیادکردنی مامەڵە',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceCard(
      Map<String, dynamic> service,
      bool isDark,
      Color color,
      ) {
    final title = service['title_ku']?.toString() ?? '';
    final description = service['description']?.toString() ?? '';
    final duration = service['duration']?.toString() ?? '';
    final fees = service['fees'];
    final documents = service['documents'];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, color.withValues(alpha: 0.7)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.description_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 20),
                color: color,
                onPressed: () => _openEditor(service: service),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                color: Colors.red,
                onPressed: () => _deleteService(service),
              ),
            ],
          ),

          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              description,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ],

          if (duration.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 14, color: Colors.blue),
                const SizedBox(width: 6),
                Text(
                  'ماوە: $duration',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
              ],
            ),
          ],

          if (documents is List && documents.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.description_outlined, size: 14, color: Colors.green),
                SizedBox(width: 6),
                Text(
                  'بەڵگەنامە پێویستەکان:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...documents.map((doc) => Padding(
              padding: const EdgeInsets.only(right: 20, bottom: 3),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 5, color: Colors.green),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      doc.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],

          if (fees is List && fees.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.attach_money_rounded, size: 14, color: Colors.orange),
                SizedBox(width: 6),
                Text(
                  'نرخ:',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...fees.map((fee) => Padding(
              padding: const EdgeInsets.only(right: 20, bottom: 3),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 5, color: Colors.orange),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      fee.toString(),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? Colors.white70 : Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.description_outlined,
            size: 80,
            color: isDark ? Colors.white24 : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'هیچ مامەڵەیەک نییە',
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'کرتە لە دوگمەی خوارەوە بکە بۆ زیادکردن',
            style: TextStyle(
              color: isDark ? Colors.white38 : Colors.grey.shade500,
              fontSize: 12,
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
// 🎨 دیالۆگی زیادکردن / دەستکاریکردنی مامەڵە
// ═══════════════════════════════════════════════════════════
class ServiceEditorDialog extends StatefulWidget {
  final dynamic departmentId;
  final Map<String, dynamic>? service;

  const ServiceEditorDialog({
    super.key,
    required this.departmentId,
    this.service,
  });

  @override
  State<ServiceEditorDialog> createState() => _ServiceEditorDialogState();
}

class _ServiceEditorDialogState extends State<ServiceEditorDialog> {
  late TextEditingController _titleKuCtrl;
  late TextEditingController _titleArCtrl;
  late TextEditingController _titleEnCtrl;
  late TextEditingController _descriptionCtrl;
  late TextEditingController _durationCtrl;
  late TextEditingController _documentsCtrl;
  late TextEditingController _feesCtrl;
  late TextEditingController _notesCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _titleKuCtrl = TextEditingController(text: s?['title_ku'] ?? '');
    _titleArCtrl = TextEditingController(text: s?['title_ar'] ?? '');
    _titleEnCtrl = TextEditingController(text: s?['title_en'] ?? '');
    _descriptionCtrl = TextEditingController(text: s?['description'] ?? '');
    _durationCtrl = TextEditingController(text: s?['duration'] ?? '');
    _notesCtrl = TextEditingController(text: s?['notes'] ?? '');

    // بەڵگەنامەکان وەک لیست
    final docs = s?['documents'];
    if (docs is List) {
      _documentsCtrl = TextEditingController(text: docs.join('\n'));
    } else {
      _documentsCtrl = TextEditingController();
    }

    // نرخەکان وەک لیست
    final fees = s?['fees'];
    if (fees is List) {
      _feesCtrl = TextEditingController(text: fees.join('\n'));
    } else {
      _feesCtrl = TextEditingController();
    }
  }

  @override
  void dispose() {
    _titleKuCtrl.dispose();
    _titleArCtrl.dispose();
    _titleEnCtrl.dispose();
    _descriptionCtrl.dispose();
    _durationCtrl.dispose();
    _documentsCtrl.dispose();
    _feesCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleKuCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ناوی مامەڵە پێویستە'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      // بەڵگەنامەکان
      final documents = _documentsCtrl.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // نرخەکان
      final fees = _feesCtrl.text
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      final data = {
        'department_id': widget.departmentId,
        'title_ku': _titleKuCtrl.text.trim(),
        'title_ar': _titleArCtrl.text.trim(),
        'title_en': _titleEnCtrl.text.trim(),
        'description': _descriptionCtrl.text.trim(),
        'duration': _durationCtrl.text.trim(),
        'documents': documents,
        'fees': fees,
        'notes': _notesCtrl.text.trim(),
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.service == null) {
        await Supabase.instance.client
            .from('department_services')
            .insert(data);
      } else {
        await Supabase.instance.client
            .from('department_services')
            .update(data)
            .eq('id', widget.service!['id']);
      }

      if (mounted) {
        Navigator.pop(context);
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
    final isEditing = widget.service != null;

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
                      Icons.description_rounded,
                      color: Color(0xFF1E88E5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEditing
                          ? 'دەستکاریکردنی مامەڵە'
                          : 'زیادکردنی مامەڵەی نوێ',
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

                _buildField('ناوی کوردی *', _titleKuCtrl),
                const SizedBox(height: 10),
                _buildField('ناوی عەرەبی', _titleArCtrl),
                const SizedBox(height: 10),
                _buildField('ناوی ئینگلیزی', _titleEnCtrl),
                const SizedBox(height: 10),
                _buildField('وەسف', _descriptionCtrl, maxLines: 3),
                const SizedBox(height: 10),
                _buildField(
                  'ماوە (بۆ نموونە: ٣٠-٦٠ خولەک)',
                  _durationCtrl,
                ),
                const SizedBox(height: 10),
                _buildField(
                  'بەڵگەنامەکان (هەر دێرێک = یەک بەڵگەنامە)',
                  _documentsCtrl,
                  maxLines: 5,
                ),
                const SizedBox(height: 10),
                _buildField(
                  'نرخەکان (هەر دێرێک = یەک نرخ)',
                  _feesCtrl,
                  maxLines: 4,
                ),
                const SizedBox(height: 10),
                _buildField('تێبینی', _notesCtrl, maxLines: 2),

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

  Widget _buildField(
      String label,
      TextEditingController ctrl, {
        int maxLines = 1,
      }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
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
}