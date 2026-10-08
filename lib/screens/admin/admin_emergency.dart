import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../models/emergency_service.dart';         // ✅ Model
import '../../services/emergency_service.dart';       // ✅ Service

/// 🚨 بەڕێوەبردنی فریاکەوتن (ئەدمین)
class AdminEmergencyScreen extends StatefulWidget {
  const AdminEmergencyScreen({super.key});

  @override
  State<AdminEmergencyScreen> createState() => _AdminEmergencyScreenState();
}

class _AdminEmergencyScreenState extends State<AdminEmergencyScreen> {
  bool _loading = true;
  List<EmergencyService> _contacts = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await EmergencyServiceService.getAll();
    if (mounted) {
      setState(() {
        _contacts = list;
        _loading = false;
      });
    }
  }

  Future<void> _delete(String id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('سڕینەوە'),
          content: const Text('ئایا دڵنیایت؟'),
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

    if (ok != true) return;

    try {
      await Supabase.instance.client
          .from('emergency_services')
          .delete()
          .eq('id', id);
      _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('هەڵە: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openEditor({EmergencyService? contact}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _EmergencyEditorDialog(contact: contact),
    ).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: const Text(
            'بەڕێوەبردنی فریاکەوتن 🚨',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFFDC2626),
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _load,
            ),
          ],
        ),
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(color: Color(0xFFDC2626)),
        )
            : _contacts.isEmpty
            ? _buildEmpty(isDark)
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _contacts.length,
          itemBuilder: (ctx, i) => _buildCard(_contacts[i], isDark),
        ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: const Color(0xFFDC2626),
          foregroundColor: Colors.white,
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'زیادکردنی نوێ',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(EmergencyService c, bool isDark) {
    final color = _hexToColor(c.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getIcon(c.icon),
              color: color,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.nameKu,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  c.phone,
                  style: TextStyle(
                    fontSize: 13,
                    color: color,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_rounded, color: Colors.blue),
            onPressed: () => _openEditor(contact: c),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            onPressed: () => _delete(c.id!),
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
          const Icon(
            Icons.phone_disabled_rounded,
            size: 80,
            color: Colors.grey,
          ),
          const SizedBox(height: 16),
          Text(
            'هیچ پەیوەندییەک نییە',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white54 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIcon(String name) {
    switch (name) {
      case 'local_police':
        return Icons.local_police_rounded;
      case 'local_fire_department':
        return Icons.local_fire_department_rounded;
      case 'local_hospital':
        return Icons.local_hospital_rounded;
      case 'electric_bolt':
        return Icons.electric_bolt_rounded;
      case 'water_drop':
        return Icons.water_drop_rounded;
      default:
        return Icons.phone_rounded;
    }
  }

  Color _hexToColor(String hex) {
    try {
      hex = hex.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      return Color(int.parse(hex, radix: 16));
    } catch (_) {
      return const Color(0xFFDC2626);
    }
  }
}

// ═══════════════════════════════════════════════════════════
// 📝 Dialog ی زیادکردن / دەستکاریکردن
// ═══════════════════════════════════════════════════════════
class _EmergencyEditorDialog extends StatefulWidget {
  final EmergencyService? contact;
  const _EmergencyEditorDialog({this.contact});

  @override
  State<_EmergencyEditorDialog> createState() =>
      _EmergencyEditorDialogState();
}

class _EmergencyEditorDialogState extends State<_EmergencyEditorDialog> {
  final _nameCtrl = TextEditingController();
  final _nameArCtrl = TextEditingController();
  final _nameEnCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _phoneAltCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  String _category = 'other';
  bool _isImportant = true;
  bool _is24h = true;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    if (c != null) {
      _nameCtrl.text = c.nameKu;
      _nameArCtrl.text = c.nameAr ?? '';
      _nameEnCtrl.text = c.nameEn ?? '';
      _phoneCtrl.text = c.phone;
      _phoneAltCtrl.text = c.phoneAlt ?? '';
      _addressCtrl.text = c.address ?? '';
      _notesCtrl.text = c.notes ?? '';
      _category = c.category;
      _isImportant = c.isImportant;
      _is24h = c.is24h;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _nameArCtrl.dispose();
    _nameEnCtrl.dispose();
    _phoneCtrl.dispose();
    _phoneAltCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ناو و ژمارە پێویستن'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // 🎨 ڕەنگ و ئایکۆن بەپێی جۆر
      final config = _getCategoryConfig(_category);

      final data = {
        'category': _category,
        'name_ku': _nameCtrl.text.trim(),
        'name_ar': _nameArCtrl.text.trim().isEmpty
            ? null
            : _nameArCtrl.text.trim(),
        'name_en': _nameEnCtrl.text.trim().isEmpty
            ? null
            : _nameEnCtrl.text.trim(),
        'phone': _phoneCtrl.text.trim(),
        'phone_alt': _phoneAltCtrl.text.trim().isEmpty
            ? null
            : _phoneAltCtrl.text.trim(),
        'address': _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
        'is_important': _isImportant,
        'is_24h': _is24h,
        'icon': config['icon'],
        'color': config['color'],
        'display_order': 0,
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (widget.contact == null) {
        await Supabase.instance.client
            .from('emergency_services')
            .insert(data);
      } else {
        await Supabase.instance.client
            .from('emergency_services')
            .update(data)
            .eq('id', widget.contact!.id!);
      }

      if (mounted) Navigator.pop(context);
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

  Map<String, String> _getCategoryConfig(String category) {
    switch (category) {
      case 'police':
        return {'icon': 'local_police', 'color': '#1E88E5'};
      case 'fire':
        return {'icon': 'local_fire_department', 'color': '#EF4444'};
      case 'ambulance':
        return {'icon': 'local_hospital', 'color': '#DC2626'};
      case 'hospital':
        return {'icon': 'local_hospital', 'color': '#E91E63'};
      case 'utility':
        return {'icon': 'electric_bolt', 'color': '#F59E0B'};
      default:
        return {'icon': 'phone', 'color': '#8B5CF6'};
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.contact != null;

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
                      Icons.emergency_rounded,
                      color: Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEditing ? 'دەستکاریکردن' : 'زیادکردنی نوێ',
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

                // 🎯 جۆر
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: InputDecoration(
                    labelText: 'جۆر',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'police', child: Text('پۆلیس')),
                    DropdownMenuItem(
                      value: 'fire',
                      child: Text('ئاگرکوژێنەوە'),
                    ),
                    DropdownMenuItem(
                      value: 'ambulance',
                      child: Text('ئەمبولانس'),
                    ),
                    DropdownMenuItem(
                      value: 'hospital',
                      child: Text('نەخۆشخانە'),
                    ),
                    DropdownMenuItem(
                      value: 'utility',
                      child: Text('خزمەتگوزاری'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('تر')),
                  ],
                  onChanged: (v) => setState(() => _category = v!),
                ),
                const SizedBox(height: 10),

                _buildField('ناوی کوردی *', _nameCtrl),
                const SizedBox(height: 10),
                _buildField('ناوی عەرەبی', _nameArCtrl),
                const SizedBox(height: 10),
                _buildField('ناوی ئینگلیزی', _nameEnCtrl),
                const SizedBox(height: 10),
                _buildField(
                  'ژمارەی مۆبایل *',
                  _phoneCtrl,
                  keyboard: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                _buildField(
                  'ژمارەی یەدەگ',
                  _phoneAltCtrl,
                  keyboard: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                _buildField('ناونیشان', _addressCtrl),
                const SizedBox(height: 10),
                _buildField('تێبینی', _notesCtrl, maxLines: 2),

                const SizedBox(height: 12),
                SwitchListTile(
                  value: _isImportant,
                  onChanged: (v) => setState(() => _isImportant = v),
                  title: const Text(
                    'فریاکەوتنی گرنگ',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: const Text(
                    'لە خوارەوەی شاشەی سەرەکی پیشان بدرێت',
                    style: TextStyle(fontSize: 10),
                  ),
                  activeThumbColor: const Color(0xFFDC2626),
                ),
                SwitchListTile(
                  value: _is24h,
                  onChanged: (v) => setState(() => _is24h = v),
                  title: const Text(
                    '٢٤ سەعات کاردەکات',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  activeThumbColor: const Color(0xFFDC2626),
                ),

                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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
        TextInputType? keyboard,
        int maxLines = 1,
      }) {
    return TextField(
      controller: ctrl,
      keyboardType: keyboard,
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