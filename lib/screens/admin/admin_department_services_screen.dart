import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../l10n/tr.dart';
import 'admin_department_service_editor.dart';

/// 🏛️ شاشەی مامەڵەکانی فەرمانگە
class AdminDepartmentServicesScreen extends StatefulWidget {
  final Map<String, dynamic> department;

  const AdminDepartmentServicesScreen({
    super.key,
    required this.department,
  });

  @override
  State<AdminDepartmentServicesScreen> createState() =>
      _AdminDepartmentServicesScreenState();
}

class _AdminDepartmentServicesScreenState extends State<AdminDepartmentServicesScreen> {
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
  Future<void> _openEditor({Map<String, dynamic>? service}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ServiceEditorSheet(
        departmentId: widget.department['id'],
        service: service,
        color: _hexToColor(
          widget.department['color']?.toString() ?? '#10B981',
        ),
      ),
    );
    if (saved != true) return;
    await _fetchServices();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('✅ پاشەکەوتکرا')),
          backgroundColor: const Color(0xFF0F9D7A),
        ),
      );
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🗑️ سڕینەوە
  // ═══════════════════════════════════════════════════════════
  Future<void> _deleteService(Map<String, dynamic> service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(tr('سڕینەوەی مامەڵە')),
          content: Text(
            'ئایا دڵنیایت لە سڕینەوەی "${service['title_ku']}"؟',
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

    try {
      await Supabase.instance.client
          .from('department_services')
          .delete()
          .eq('id', service['id']);

      await _fetchServices();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('✅ مامەڵە سڕایەوە')),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = widget.department['name_ku']?.toString() ?? 'فەرمانگە';
    final color = _hexToColor(
      widget.department['color']?.toString() ?? '#1E88E5',
    );

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F1421) : const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Text(
            trf('مامەڵەکانی {0}', [name]),
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
          label: Text(
            tr('زیادکردنی مامەڵە'),
            style: const TextStyle(fontWeight: FontWeight.bold),
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
    final documents = serviceRequirementsOf(service);

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
                  tr(title),
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
                color: const Color(0xFFDC3545),
                onPressed: () => _deleteService(service),
              ),
            ],
          ),

          if (description.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              tr(description),
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
                const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF1E88E5)),
                const SizedBox(width: 6),
                Text(
                  trf('ماوە: {0}', [duration]),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E88E5),
                  ),
                ),
              ],
            ),
          ],

          if (documents.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.description_outlined, size: 14, color: Color(0xFF0F9D7A)),
                const SizedBox(width: 6),
                Text(
                  tr('پێداویستییەکان:'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F9D7A),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...documents.map((doc) => Padding(
              padding: const EdgeInsets.only(right: 20, bottom: 3),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 5, color: Color(0xFF0F9D7A)),
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
            Row(
              children: [
                const Icon(Icons.attach_money_rounded, size: 14, color: Color(0xFFD9822B)),
                const SizedBox(width: 6),
                Text(
                  tr('نرخ:'),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFD9822B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ...fees.map((fee) => Padding(
              padding: const EdgeInsets.only(right: 20, bottom: 3),
              child: Row(
                children: [
                  const Icon(Icons.circle, size: 5, color: Color(0xFFD9822B)),
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
            tr('هیچ مامەڵەیەک نییە'),
            style: TextStyle(
              color: isDark ? Colors.white54 : Colors.grey,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('کرتە لە دوگمەی خوارەوە بکە بۆ زیادکردن'),
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
