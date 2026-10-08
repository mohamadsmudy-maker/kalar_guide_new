import 'package:flutter/material.dart';
import '../../models/store_service.dart';
import '../../services/store_service_service.dart';

/// 📋 شاشەی بەڕێوەبردنی مامەڵەکانی شوێن (بۆ ئەدمین)
class AdminStoreServicesScreen extends StatefulWidget {
  final int storeId;
  final String storeName;

  const AdminStoreServicesScreen({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  State<AdminStoreServicesScreen> createState() =>
      _AdminStoreServicesScreenState();
}

class _AdminStoreServicesScreenState
    extends State<AdminStoreServicesScreen> {
  bool _loading = true;
  List<StoreService> _services = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final data = await StoreServiceService.getAllForAdmin(widget.storeId);
    if (mounted) {
      setState(() {
        _services = data;
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({StoreService? service}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ServiceEditorDialog(
        storeId: widget.storeId,
        service: service,
      ),
    );

    if (result != null) {
      if (service == null) {
        await StoreServiceService.addService(result);
      } else if (service.id != null) {
        await StoreServiceService.updateService(service.id!, result);
      }
      _loadData();
    }
  }

  Future<void> _deleteService(StoreService service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('سڕینەوەی مامەڵە'),
          content: Text('ئایا دڵنیایت لە سڕینەوەی "${service.titleKu}"؟'),
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

    if (confirm == true && service.id != null) {
      await StoreServiceService.deleteService(service.id!);
      _loadData();
    }
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
          title: Text(
            'مامەڵەکانی ${widget.storeName}',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 15,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFF1A1A2E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadData,
            ),
          ],
        ),
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF1E88E5),
          ),
        )
            : _services.isEmpty
            ? _buildEmpty(isDark)
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _services.length,
          itemBuilder: (ctx, i) =>
              _buildCard(_services[i], isDark),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          backgroundColor: const Color(0xFF1E88E5),
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

  Widget _buildCard(StoreService service, bool isDark) {
    Color color;
    try {
      String hex = service.color.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      color = Color(int.parse(hex, radix: 16));
    } catch (_) {
      color = const Color(0xFF1E88E5);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.description_rounded,
                  color: color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  service.titleKu,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
              ),
              if (!service.isActive)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'ناچالاک',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              const SizedBox(width: 6),
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
          const SizedBox(height: 8),
          Row(
            children: [
              _buildMiniInfo(
                Icons.checklist_rounded,
                '${service.requirements.length} پێداویستی',
                const Color(0xFF8B5CF6),
                isDark,
              ),
              const SizedBox(width: 10),
              _buildMiniInfo(
                Icons.attach_money_rounded,
                '${service.fees.length} تێچوو',
                const Color(0xFF10B981),
                isDark,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniInfo(
      IconData icon, String text, Color color, bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white54 : Colors.grey.shade600,
          ),
        ),
      ],
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
              color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.description_outlined,
              size: 60,
              color: Color(0xFF1E88E5),
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
          const SizedBox(height: 6),
          Text(
            'دوگمەی خوارەوە بەکاربهێنە بۆ زیادکردن',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🎨 دیالۆگی زیادکردن / دەستکاریکردن
// ═══════════════════════════════════════════════════════════
class _ServiceEditorDialog extends StatefulWidget {
  final int storeId;
  final StoreService? service;

  const _ServiceEditorDialog({
    required this.storeId,
    this.service,
  });

  @override
  State<_ServiceEditorDialog> createState() => _ServiceEditorDialogState();
}

class _ServiceEditorDialogState extends State<_ServiceEditorDialog> {
  late TextEditingController _titleKuCtrl;
  late TextEditingController _titleArCtrl;
  late TextEditingController _titleEnCtrl;
  late TextEditingController _descCtrl;
  late TextEditingController _requirementsCtrl;
  late TextEditingController _feesCtrl;
  late TextEditingController _durationCtrl;
  late TextEditingController _locationCtrl;
  late TextEditingController _notesCtrl;

  late String _icon;
  late String _selectedColor;
  bool _isActive = true;
  bool _loading = false;

  final _icons = [
    {'key': 'description', 'icon': Icons.description_rounded},
    {'key': 'car', 'icon': Icons.directions_car_rounded},
    {'key': 'home', 'icon': Icons.home_rounded},
    {'key': 'school', 'icon': Icons.school_rounded},
    {'key': 'health', 'icon': Icons.local_hospital_rounded},
    {'key': 'money', 'icon': Icons.attach_money_rounded},
    {'key': 'id_card', 'icon': Icons.badge_rounded},
  ];

  final _colors = [
    '#1E88E5',
    '#10B981',
    '#F59E0B',
    '#EF4444',
    '#8B5CF6',
    '#EC4899',
    '#14B8A6',
    '#6C5CE7',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.service;

    _titleKuCtrl = TextEditingController(text: s?.titleKu ?? '');
    _titleArCtrl = TextEditingController(text: s?.titleAr ?? '');
    _titleEnCtrl = TextEditingController(text: s?.titleEn ?? '');
    _descCtrl = TextEditingController(text: s?.description ?? '');
    _requirementsCtrl = TextEditingController(
      text: s?.requirements.join('\n') ?? '',
    );
    _feesCtrl = TextEditingController(
      text: s?.fees.join('\n') ?? '',
    );
    _durationCtrl = TextEditingController(text: s?.duration ?? '');
    _locationCtrl = TextEditingController(text: s?.location ?? '');
    _notesCtrl = TextEditingController(text: s?.notes ?? '');

    _icon = s?.icon ?? 'description';
    _selectedColor = s?.color ?? '#1E88E5';
    _isActive = s?.isActive ?? true;
  }

  @override
  void dispose() {
    _titleKuCtrl.dispose();
    _titleArCtrl.dispose();
    _titleEnCtrl.dispose();
    _descCtrl.dispose();
    _requirementsCtrl.dispose();
    _feesCtrl.dispose();
    _durationCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleKuCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ناونیشان پێویستە'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      // ✅ پارسکردنی لیستەکان لە دێرەکانەوە
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

      final Map<String, dynamic> data = {
        'store_id': widget.storeId,
        'title_ku': _titleKuCtrl.text.trim(),
        'title_ar': _titleArCtrl.text.trim().isEmpty
            ? null
            : _titleArCtrl.text.trim(),
        'title_en': _titleEnCtrl.text.trim().isEmpty
            ? null
            : _titleEnCtrl.text.trim(),
        'description': _descCtrl.text.trim().isEmpty
            ? null
            : _descCtrl.text.trim(),
        'requirements': requirements,
        'fees': fees,
        'duration': _durationCtrl.text.trim().isEmpty
            ? null
            : _durationCtrl.text.trim(),
        'location': _locationCtrl.text.trim().isEmpty
            ? null
            : _locationCtrl.text.trim(),
        'notes': _notesCtrl.text.trim().isEmpty
            ? null
            : _notesCtrl.text.trim(),
        'icon': _icon,
        'color': _selectedColor,
        'is_active': _isActive,
      };

      if (mounted) Navigator.pop(context, data);
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
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
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
                      isEditing ? 'دەستکاریکردن' : 'زیادکردنی مامەڵە',
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

                // 🎯 ئایکۆن
                const Text(
                  'ئایکۆن',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _icons.map((ic) {
                    final String key = ic['key'] as String;
                    final IconData iconData = ic['icon'] as IconData;
                    final bool isSelected = _icon == key;

                    return GestureDetector(
                      onTap: () => setState(() => _icon = key),
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF1E88E5)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF1E88E5)
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          iconData,
                          color: isSelected
                              ? Colors.white
                              : Colors.grey.shade700,
                          size: 22,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                // 🎨 ڕەنگ
                const Text(
                  'ڕەنگ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _colors.map((c) {
                    Color color;
                    try {
                      String hex = c.replaceAll('#', '');
                      if (hex.length == 6) hex = 'FF$hex';
                      color = Color(int.parse(hex, radix: 16));
                    } catch (_) {
                      color = Colors.blue;
                    }
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
                                ? Colors.black
                                : Colors.transparent,
                            width: 3,
                          ),
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
                const SizedBox(height: 16),

                _buildField('ناونیشانی کوردی *', _titleKuCtrl),
                const SizedBox(height: 10),
                _buildField('ناونیشانی عەرەبی', _titleArCtrl),
                const SizedBox(height: 10),
                _buildField('ناونیشانی ئینگلیزی', _titleEnCtrl),
                const SizedBox(height: 10),
                _buildField('وەسف', _descCtrl, maxLines: 2),
                const SizedBox(height: 10),
                _buildField(
                  '📄 پێداویستییەکان (هەر دێرێک = یەک پێداویستی)',
                  _requirementsCtrl,
                  maxLines: 5,
                ),
                const SizedBox(height: 10),
                _buildField(
                  '💰 تێچووەکان (هەر دێرێک = یەک تێچوو)',
                  _feesCtrl,
                  maxLines: 4,
                ),
                const SizedBox(height: 10),
                _buildField('⏱️ ماوە', _durationCtrl),
                const SizedBox(height: 10),
                _buildField('📍 شوێن', _locationCtrl),
                const SizedBox(height: 10),
                _buildField('📝 تێبینی', _notesCtrl, maxLines: 2),
                const SizedBox(height: 16),

                SwitchListTile(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  title: const Text(
                    'چالاک',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _loading ? null : _save,
                    child: _loading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                        : Text(
                      isEditing ? 'نوێکردنەوە' : 'زیادکردن',
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15,
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