import 'package:flutter/material.dart';
import '../../models/emergency_service.dart';
import '../../services/emergency_service.dart';

/// 🚑 شاشەی بەڕێوەبردنی خزمەتگوزارییەکانی فریاکەوتن
class AdminEmergencyServicesScreen extends StatefulWidget {
  const AdminEmergencyServicesScreen({super.key});

  @override
  State<AdminEmergencyServicesScreen> createState() =>
      _AdminEmergencyServicesScreenState();
}

class _AdminEmergencyServicesScreenState
    extends State<AdminEmergencyServicesScreen> {
  bool _loading = true;
  List<EmergencyService> _services = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final data = await EmergencyServiceService.getAll();
    if (mounted) {
      setState(() {
        _services = data;
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({EmergencyService? service}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _EmergencyEditorDialog(service: service),
    );

    if (result != null) {
      if (service == null) {
        await EmergencyServiceService.addService(result);
      } else if (service.id != null) {
        await EmergencyServiceService.updateService(service.id!, result);
      }
      _loadData();
    }
  }

  Future<void> _deleteService(EmergencyService service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('سڕینەوە'),
          content: Text('ئایا دڵنیایت لە سڕینەوەی "${service.nameKu}"؟'),
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
      await EmergencyServiceService.deleteService(service.id!);
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
          title: const Text(
            'بەڕێوەبردنی فریاکەوتن 🚑',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          backgroundColor: const Color(0xFFB71C1C),
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
            color: Color(0xFFE53935),
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
          backgroundColor: const Color(0xFFE53935),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'زیادکردنی خزمەتگوزاری',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(EmergencyService service, bool isDark) {
    Color color;
    try {
      String hex = service.color.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      color = Color(int.parse(hex, radix: 16));
    } catch (_) {
      color = const Color(0xFFEF4444);
    }

    IconData icon;
    switch (service.icon) {
      case 'local_police':
        icon = Icons.local_police_rounded;
        break;
      case 'local_fire_department':
        icon = Icons.local_fire_department_rounded;
        break;
      case 'local_hospital':
        icon = Icons.local_hospital_rounded;
        break;
      case 'bolt':
        icon = Icons.bolt_rounded;
        break;
      case 'water_drop':
        icon = Icons.water_drop_rounded;
        break;
      case 'local_gas_station':
        icon = Icons.local_gas_station_rounded;
        break;
      default:
        icon = Icons.emergency_rounded;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1.5,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.7)],
            ),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        title: Text(
          service.nameKu,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service.phone,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              if (service.authorityName != null &&
                  service.authorityName!.isNotEmpty)
                Text(
                  service.authorityName!,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : Colors.grey,
                  ),
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
              onPressed: () => _openEditor(service: service),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
                size: 22,
              ),
              onPressed: () => _deleteService(service),
            ),
          ],
        ),
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
              color: const Color(0xFFE53935).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emergency_outlined,
              size: 60,
              color: Color(0xFFE53935),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'هیچ خزمەتگوزارییەک نییە',
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
              color: isDark ? Colors.white54 : Colors.grey,
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
class _EmergencyEditorDialog extends StatefulWidget {
  final EmergencyService? service;

  const _EmergencyEditorDialog({this.service});

  @override
  State<_EmergencyEditorDialog> createState() =>
      _EmergencyEditorDialogState();
}

class _EmergencyEditorDialogState extends State<_EmergencyEditorDialog> {
  late TextEditingController _nameKuCtrl;
  late TextEditingController _nameArCtrl;
  late TextEditingController _nameEnCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _phoneAltCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _authorityCtrl;
  late String _category;
  late String _icon;
  late String _selectedColor;
  bool _isImportant = false;
  bool _is24h = true;
  bool _loading = false;

  final List<Map<String, dynamic>> _categories = [
    {'key': 'police', 'label': '🚔 پۆلیس'},
    {'key': 'fire', 'label': '🔥 ئاگرکوژێنەوە'},
    {'key': 'ambulance', 'label': '🚑 ئەمبولانس'},
    {'key': 'hospital', 'label': '🏥 نەخۆشخانە'},
    {'key': 'utility', 'label': '🔧 خزمەتگوزاری'},
    {'key': 'other', 'label': '📞 تر'},
  ];

  final List<Map<String, dynamic>> _icons = [
    {'key': 'local_police', 'icon': Icons.local_police_rounded},
    {
      'key': 'local_fire_department',
      'icon': Icons.local_fire_department_rounded,
    },
    {'key': 'local_hospital', 'icon': Icons.local_hospital_rounded},
    {'key': 'bolt', 'icon': Icons.bolt_rounded},
    {'key': 'water_drop', 'icon': Icons.water_drop_rounded},
    {
      'key': 'local_gas_station',
      'icon': Icons.local_gas_station_rounded,
    },
    {'key': 'emergency', 'icon': Icons.emergency_rounded},
  ];

  final List<String> _colors = [
    '#EF4444',
    '#B71C1C',
    '#1E88E5',
    '#10B981',
    '#F59E0B',
    '#8B5CF6',
    '#00BCD4',
    '#6C5CE7',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _nameKuCtrl = TextEditingController(text: s?.nameKu ?? '');
    _nameArCtrl = TextEditingController(text: s?.nameAr ?? '');
    _nameEnCtrl = TextEditingController(text: s?.nameEn ?? '');
    _phoneCtrl = TextEditingController(text: s?.phone ?? '');
    _phoneAltCtrl = TextEditingController(text: s?.phoneAlt ?? '');
    _addressCtrl = TextEditingController(text: s?.address ?? '');
    _authorityCtrl = TextEditingController(text: s?.authorityName ?? '');
    _category = s?.category ?? 'police';
    _icon = s?.icon ?? 'emergency';
    _selectedColor = s?.color ?? '#EF4444';
    _isImportant = s?.isImportant ?? false;
    _is24h = s?.is24h ?? true;
  }

  @override
  void dispose() {
    _nameKuCtrl.dispose();
    _nameArCtrl.dispose();
    _nameEnCtrl.dispose();
    _phoneCtrl.dispose();
    _phoneAltCtrl.dispose();
    _addressCtrl.dispose();
    _authorityCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameKuCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ناو و ژمارەی پەیوەندی پێویستە'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final Map<String, dynamic> data = {
        'name_ku': _nameKuCtrl.text.trim(),
        'name_ar': _nameArCtrl.text.trim().isEmpty
            ? null
            : _nameArCtrl.text.trim(),
        'name_en': _nameEnCtrl.text.trim().isEmpty
            ? null
            : _nameEnCtrl.text.trim(),
        'category': _category,
        'phone': _phoneCtrl.text.trim(),
        'phone_alt': _phoneAltCtrl.text.trim().isEmpty
            ? null
            : _phoneAltCtrl.text.trim(),
        'address': _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        'authority_name': _authorityCtrl.text.trim().isEmpty
            ? null
            : _authorityCtrl.text.trim(),
        'icon': _icon,
        'color': _selectedColor,
        'is_important': _isImportant,
        'is_24h': _is24h,
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
                      Icons.emergency_rounded,
                      color: Color(0xFFE53935),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEditing
                          ? 'دەستکاریکردن'
                          : 'زیادکردنی خزمەتگوزاری',
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

                const Text(
                  'کەرت',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _categories.map((c) {
                    final String key = c['key'] as String;
                    final String label = c['label'] as String;
                    final bool isSelected = _category == key;

                    return GestureDetector(
                      onTap: () => setState(() => _category = key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? const LinearGradient(
                            colors: [
                              Color(0xFFE53935),
                              Color(0xFFFF7043),
                            ],
                          )
                              : null,
                          color:
                          isSelected ? null : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFE53935)
                                : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                            color: isSelected
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),

                _buildField('ناوی کوردی *', _nameKuCtrl),
                const SizedBox(height: 10),
                _buildField('ناوی عەرەبی', _nameArCtrl),
                const SizedBox(height: 10),
                _buildField('ناوی ئینگلیزی', _nameEnCtrl),
                const SizedBox(height: 10),
                _buildField(
                  'ژمارەی پەیوەندی *',
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
                _buildField('ناوی فەرمانگە', _authorityCtrl),
                const SizedBox(height: 16),

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
                              ? const Color(0xFFE53935)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFE53935)
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
                      color = Colors.red;
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

                SwitchListTile(
                  value: _isImportant,
                  onChanged: (v) =>
                      setState(() => _isImportant = v),
                  title: const Text(
                    'گرنگ (Pulse Animation)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  secondary: const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFF59E0B),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
                SwitchListTile(
                  value: _is24h,
                  onChanged: (v) => setState(() => _is24h = v),
                  title: const Text(
                    '٢٤ سەعات کار دەکات',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  secondary: const Icon(
                    Icons.access_time_rounded,
                    color: Color(0xFF10B981),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),

                const SizedBox(height: 20),

                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
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
        TextInputType? keyboard,
      }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboard,
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