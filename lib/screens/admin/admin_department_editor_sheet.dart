// lib/screens/admin/admin_department_editor_sheet.dart
// فۆڕمی زیادکردن/دەستکاریکردنی فەرمانگە

part of 'admin_departments.dart';

// ═══════════════════════════════════════════════════════════════
// 🎨 Editor Sheet — زیادکردن / دەستکاریکردنی فەرمانگە
// ═══════════════════════════════════════════════════════════════
class _DepartmentEditorSheet extends StatefulWidget {
  final Map<String, dynamic>? department;
  const _DepartmentEditorSheet({this.department});

  @override
  State<_DepartmentEditorSheet> createState() => _DepartmentEditorSheetState();
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
        SnackBar(
          content: Text(tr('ناوی فەرمانگە پێویستە')),
          backgroundColor: const Color(0xFFD9822B),
        ),
      );
      return;
    }

    final data = {
      'name_ku': _nameKuCtrl.text.trim(),
      'name_ar':
          _nameArCtrl.text.trim().isEmpty ? null : _nameArCtrl.text.trim(),
      'name_en':
          _nameEnCtrl.text.trim().isEmpty ? null : _nameEnCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      'address':
          _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim(),
      'website':
          _websiteCtrl.text.trim().isEmpty ? null : _websiteCtrl.text.trim(),
      'user_phone': _userPhoneCtrl.text.trim().isEmpty
          ? null
          : _userPhoneCtrl.text.trim(),
      'image': _imageCtrl.text.trim().isEmpty ? null : _imageCtrl.text.trim(),
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
      textDirection: AppLang.direction,
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
                        colors: [Color(0xFF0F9D7A), Color(0xFF0F9D7A)],
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
                      tr(isEditing
                          ? 'دەستکاریکردنی فەرمانگە'
                          : 'زیادکردنی فەرمانگە'),
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
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
                    _buildField(tr('ناوی کوردی *'), _nameKuCtrl, isDark),
                    const SizedBox(height: 10),
                    _buildField(tr('ناوی عەرەبی'), _nameArCtrl, isDark),
                    const SizedBox(height: 10),
                    _buildField(tr('ناوی ئینگلیزی'), _nameEnCtrl, isDark),
                    const SizedBox(height: 10),
                    _buildField(
                      tr('ژمارەی مۆبایل'),
                      _phoneCtrl,
                      isDark,
                      keyboard: TextInputType.phone,
                    ),
                    const SizedBox(height: 10),
                    _buildField(tr('ناونیشان'), _addressCtrl, isDark),
                    const SizedBox(height: 10),
                    _buildField(tr('ماڵپەڕ'), _websiteCtrl, isDark),
                    const SizedBox(height: 10),
                    _buildField(
                      tr('لینکی وێنە (URL)'),
                      _imageCtrl,
                      isDark,
                    ),
                    const SizedBox(height: 10),
                    _buildField(
                      tr('ژمارەی ڤێندەر (بۆ چوونەژوورەوەی فەرمانگە)'),
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
                                Color(0xFF0F9D7A),
                                Color(0xFF0F9D7A),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tr('ڕەنگی فەرمانگە'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            color:
                                isDark ? Colors.white : const Color(0xFF1A1A2E),
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
                    backgroundColor: const Color(0xFF0F9D7A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 3,
                    shadowColor: const Color(0xFF0F9D7A).withValues(alpha: 0.4),
                  ),
                  onPressed: _save,
                  icon: Icon(
                    isEditing ? Icons.save_rounded : Icons.add_circle_rounded,
                    size: 22,
                  ),
                  label: Text(
                    tr(isEditing ? 'نوێکردنەوە' : 'زیادکردن'),
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
            color: Color(0xFF0F9D7A),
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
      return const Color(0xFF0F9D7A);
    }
  }
}
