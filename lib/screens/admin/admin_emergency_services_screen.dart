import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../models/emergency_service.dart';
import '../../services/emergency_service.dart';

/// 🚑 پانێڵی بەڕێوەبردنی فریاکەوتن — ULTRA PRO
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
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (mounted) setState(() => _loading = true);
    final data = await EmergencyServiceRepository.getAll();
    if (mounted) {
      setState(() {
        _services = data;
        _loading = false;
      });
    }
  }

  List<EmergencyService> get _filtered {
    if (_searchQuery.isEmpty) return _services;
    final q = _searchQuery.toLowerCase();
    return _services.where((s) {
      return s.nameKu.toLowerCase().contains(q) ||
          s.phone.toLowerCase().contains(q) ||
          s.category.toLowerCase().contains(q);
    }).toList();
  }

  Future<void> _openEditor({EmergencyService? service}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EmergencyEditorSheet(service: service),
    );

    if (result == null) return;

    try {
      if (service == null) {
        await EmergencyServiceRepository.addService(result);
      } else if (service.id != null) {
        await EmergencyServiceRepository.updateService(service.id!, result);
      }
      if (mounted) {
        HapticFeedback.mediumImpact();
        _loadData();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(service == null ? '✅ زیادکرا' : '✅ نوێکرایەوە'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('هەڵە: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteService(EmergencyService service) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red),
              SizedBox(width: 8),
              Text('سڕینەوە', style: TextStyle(fontWeight: FontWeight.w900)),
            ],
          ),
          content: Text('ئایا دڵنیایت لە سڕینەوەی "${service.nameKu}"؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('نەخێر'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              icon: const Icon(Icons.delete_rounded, size: 18),
              label: const Text('بەڵێ، بیسڕەوە'),
            ),
          ],
        ),
      ),
    );

    if (confirm != true || service.id == null) return;

    try {
      await EmergencyServiceRepository.deleteService(service.id!);
      HapticFeedback.heavyImpact();
      _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ سڕایەوە'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('هەڵە: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0A0A0F) : const Color(0xFFF0F4F9),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFFDC2626),
          foregroundColor: Colors.white,
          centerTitle: true,
          title: const Text(
            'بەڕێوەبردنی فریاکەوتن',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadData,
            ),
          ],
        ),
        body: Column(
          children: [
            // ═══ Stats ═══
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFDC2626), Color(0xFF7F1D1D)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.emergency_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'کۆی ژمارەکان',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${_services.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                            height: 1.0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ═══ Search ═══
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 52,
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1A1A22) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.06)
                        : Colors.grey.shade200,
                  ),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'گەڕان...',
                    hintStyle: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white38 : Colors.grey,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: Color(0xFFDC2626),
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _searchQuery = '');
                      },
                    )
                        : null,
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ═══ List ═══
            Expanded(
              child: _loading
                  ? const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFFDC2626),
                ),
              )
                  : _filtered.isEmpty
                  ? _buildEmptyState(isDark)
                  : ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                itemCount: _filtered.length,
                itemBuilder: (context, i) =>
                    _buildServiceTile(_filtered[i], isDark),
              ),
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          backgroundColor: const Color(0xFFDC2626),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'زیادکردنی نوێ',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }

  Widget _buildServiceTile(EmergencyService service, bool isDark) {
    final color = _hexToColor(service.color);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1.2,
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.7)],
            ),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            _getIconData(service.icon),
            color: Colors.white,
            size: 22,
          ),
        ),
        title: Text(
          service.nameKu,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 14,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.phone_rounded, size: 12, color: color),
              const SizedBox(width: 4),
              Text(
                service.phone,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: color,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  service.category,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
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
              color: const Color(0xFFDC2626).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emergency_outlined,
              size: 60,
              color: Color(0xFFDC2626),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'هیچ ژمارەیەک نییە',
            style: TextStyle(
              fontSize: 16,
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

  IconData _getIconData(String icon) {
    switch (icon) {
      case 'local_police':
        return Icons.local_police_rounded;
      case 'local_fire_department':
        return Icons.local_fire_department_rounded;
      case 'local_hospital':
        return Icons.local_hospital_rounded;
      case 'bolt':
        return Icons.electric_bolt_rounded;
      case 'water_drop':
        return Icons.water_drop_rounded;
      case 'local_gas_station':
        return Icons.local_gas_station_rounded;
      default:
        return Icons.emergency_rounded;
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

// ═══════════════════════════════════════════════════════════════
// 📝 Editor Sheet — ULTRA PRO
// ═══════════════════════════════════════════════════════════════
class _EmergencyEditorSheet extends StatefulWidget {
  final EmergencyService? service;
  const _EmergencyEditorSheet({this.service});

  @override
  State<_EmergencyEditorSheet> createState() => _EmergencyEditorSheetState();
}

class _EmergencyEditorSheetState extends State<_EmergencyEditorSheet> {
  // ═══ Controllers ═══
  late TextEditingController _nameKuCtrl;
  late TextEditingController _nameArCtrl;
  late TextEditingController _nameEnCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _phoneAltCtrl;
  late TextEditingController _addressCtrl;
  late TextEditingController _authorityCtrl;
  late TextEditingController _notesCtrl;

  // ═══ State ═══
  String _category = 'police';
  String _icon = 'emergency';
  String _selectedColor = '#EF4444';
  bool _isImportant = false;
  bool _is24h = true;
  bool _isActive = true;

  // ═══ Data ═══
  final List<Map<String, String>> _categories = [
    {'key': 'police', 'label': '🚔 پۆلیس'},
    {'key': 'fire', 'label': '🔥 ئاگرکوژێنەوە'},
    {'key': 'ambulance', 'label': '🚑 ئەمبولانس'},
    {'key': 'hospital', 'label': '🏥 نەخۆشخانە'},
    {'key': 'power', 'label': '⚡ کارەبا'},
    {'key': 'water', 'label': '💧 ئاو'},
    {'key': 'utility', 'label': '🔧 خزمەتگوزاری'},
    {'key': 'other', 'label': '📞 تر'},
  ];

  final List<Map<String, dynamic>> _icons = [
    {'key': 'local_police', 'icon': Icons.local_police_rounded},
    {'key': 'local_fire_department', 'icon': Icons.local_fire_department_rounded},
    {'key': 'local_hospital', 'icon': Icons.local_hospital_rounded},
    {'key': 'bolt', 'icon': Icons.electric_bolt_rounded},
    {'key': 'water_drop', 'icon': Icons.water_drop_rounded},
    {'key': 'local_gas_station', 'icon': Icons.local_gas_station_rounded},
    {'key': 'emergency', 'icon': Icons.emergency_rounded},
  ];

  final List<String> _colors = [
    '#EF4444',
    '#DC2626',
    '#1E88E5',
    '#10B981',
    '#F59E0B',
    '#8B5CF6',
    '#EC4899',
    '#14B8A6',
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
    _notesCtrl = TextEditingController(text: s?.notes ?? '');
    _category = s?.category ?? 'police';
    _icon = s?.icon ?? 'emergency';
    _selectedColor = s?.color ?? '#EF4444';
    _isImportant = s?.isImportant ?? false;
    _is24h = s?.is24h ?? true;
    _isActive = s?.isActive ?? true;
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
    _notesCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (_nameKuCtrl.text.trim().isEmpty ||
        _phoneCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ناو و ژمارە پێویستن'),
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
      'notes': _notesCtrl.text.trim().isEmpty
          ? null
          : _notesCtrl.text.trim(),
      'icon': _icon,
      'color': _selectedColor,
      'is_important': _isImportant,
      'is_24h': _is24h,
      'is_active': _isActive,
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
            // ═══ Handle ═══
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

            // ═══ Header ═══
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFDC2626), Color(0xFFFF7043)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.emergency_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isEditing ? 'دەستکاریکردن' : 'زیادکردنی نوێ',
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

            // ═══ Form ═══
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ═══ Category ═══
                    _buildSectionTitle('کاتێگۆری', isDark),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categories.map((cat) {
                        final isSelected = _category == cat['key'];
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _category = cat['key']!);
                          },
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
                                  Color(0xFFDC2626),
                                  Color(0xFFFF7043),
                                ],
                              )
                                  : null,
                              color: isSelected
                                  ? null
                                  : (isDark
                                  ? const Color(0xFF0F0F14)
                                  : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : (isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.grey.shade300),
                              ),
                            ),
                            child: Text(
                              cat['label']!,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                color: isSelected
                                    ? Colors.white
                                    : (isDark
                                    ? Colors.white70
                                    : Colors.grey.shade700),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // ═══ Fields ═══
                    _buildField('ناوی کوردی *', _nameKuCtrl, isDark),
                    const SizedBox(height: 10),
                    _buildField('ناوی عەرەبی', _nameArCtrl, isDark),
                    const SizedBox(height: 10),
                    _buildField('ناوی ئینگلیزی', _nameEnCtrl, isDark),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildField(
                            'ژمارەی سەرەکی *',
                            _phoneCtrl,
                            isDark,
                            keyboard: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _buildField(
                            'ژمارەی یەدەگ',
                            _phoneAltCtrl,
                            isDark,
                            keyboard: TextInputType.phone,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _buildField('ناونیشان', _addressCtrl, isDark),
                    const SizedBox(height: 10),
                    _buildField(
                      'ناوی فەرمانگە',
                      _authorityCtrl,
                      isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildField(
                      'تێبینی',
                      _notesCtrl,
                      isDark,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 20),

                    // ═══ Icon ═══
                    _buildSectionTitle('ئایکۆن', isDark),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _icons.map((ic) {
                        final isSelected = _icon == ic['key'];
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() => _icon = ic['key'] as String);
                          },
                          child: Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                colors: [
                                  Color(0xFFDC2626),
                                  Color(0xFFFF7043),
                                ],
                              )
                                  : null,
                              color: isSelected
                                  ? null
                                  : (isDark
                                  ? const Color(0xFF0F0F14)
                                  : Colors.grey.shade100),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? Colors.transparent
                                    : (isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.grey.shade300),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              ic['icon'] as IconData,
                              color: isSelected
                                  ? Colors.white
                                  : (isDark
                                  ? Colors.white70
                                  : Colors.grey.shade700),
                              size: 22,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),

                    // ═══ Color ═══
                    _buildSectionTitle('ڕەنگ', isDark),
                    const SizedBox(height: 8),
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

                    // ═══ Switches ═══
                    _buildSwitch(
                      'ژمارەی گرنگ',
                      'لە سەرەوەی لیست پیشان بدرێت',
                      Icons.star_rounded,
                      const Color(0xFFF59E0B),
                      _isImportant,
                          (v) => setState(() => _isImportant = v),
                      isDark,
                    ),
                    _buildSwitch(
                      '٢٤ سەعات کاردەکات',
                      null,
                      Icons.access_time_filled_rounded,
                      const Color(0xFF10B981),
                      _is24h,
                          (v) => setState(() => _is24h = v),
                      isDark,
                    ),
                    _buildSwitch(
                      'چالاک',
                      'لە شاشەی بەکارهێنەر دەردەکەوێت',
                      Icons.visibility_rounded,
                      AppColors.primary,
                      _isActive,
                          (v) => setState(() => _isActive = v),
                      isDark,
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ═══ Save Button ═══
            Container(
              padding: EdgeInsets.fromLTRB(
                20,
                12,
                20,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F0F14) : Colors.grey.shade50,
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
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                    shadowColor: const Color(0xFFDC2626).withValues(alpha: 0.4),
                  ),
                  onPressed: _save,
                  icon: Icon(
                    isEditing ? Icons.save_rounded : Icons.add_circle_rounded,
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

  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFDC2626), Color(0xFFFF7043)],
            ),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
      ],
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
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.shade300,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
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

  Widget _buildSwitch(
      String title,
      String? subtitle,
      IconData icon,
      Color color,
      bool value,
      ValueChanged<bool> onChanged,
      bool isDark,
      ) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F14) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 10,
                      color: isDark ? Colors.white54 : Colors.grey,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: color,
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
      return const Color(0xFFDC2626);
    }
  }
}