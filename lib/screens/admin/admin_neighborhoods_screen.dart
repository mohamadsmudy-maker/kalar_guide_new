import 'package:flutter/material.dart';
import '../../models/neighborhood.dart';
import '../../services/neighborhood_service.dart';

/// 🏘️ شاشەی بەڕێوەبردنی گەڕەکەکان
class AdminNeighborhoodsScreen extends StatefulWidget {
  const AdminNeighborhoodsScreen({super.key});

  @override
  State<AdminNeighborhoodsScreen> createState() =>
      _AdminNeighborhoodsScreenState();
}

class _AdminNeighborhoodsScreenState extends State<AdminNeighborhoodsScreen> {
  bool _loading = true;
  List<Neighborhood> _neighborhoods = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final data = await NeighborhoodService.getAll();
    if (mounted) {
      setState(() {
        _neighborhoods = data;
        _loading = false;
      });
    }
  }

  Future<void> _openEditor({Neighborhood? neighborhood}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _NeighborhoodEditorDialog(neighborhood: neighborhood),
    );

    if (result != null) {
      if (neighborhood == null) {
        await NeighborhoodService.addNeighborhood(result);
      } else if (neighborhood.id != null) {
        await NeighborhoodService.updateNeighborhood(
          neighborhood.id!,
          result,
        );
      }
      _loadData();
    }
  }

  Future<void> _deleteNeighborhood(Neighborhood n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text('سڕینەوەی گەڕەک'),
          content: Text('ئایا دڵنیایت لە سڕینەوەی "${n.nameKu}"؟'),
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

    if (confirm == true && n.id != null) {
      await NeighborhoodService.deleteNeighborhood(n.id!);
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
            'گەڕەکەکان 🏘️',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
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
          child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
        )
            : _neighborhoods.isEmpty
            ? _buildEmpty(isDark)
            : ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: _neighborhoods.length,
          itemBuilder: (ctx, i) => _buildCard(
            _neighborhoods[i],
            isDark,
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEditor(),
          backgroundColor: const Color(0xFF1E88E5),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: const Text(
            'زیادکردنی گەڕەک',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Neighborhood n, bool isDark) {
    Color color;
    try {
      String hex = n.color.replaceAll('#', '');
      if (hex.length == 6) hex = 'FF$hex';
      color = Color(int.parse(hex, radix: 16));
    } catch (_) {
      color = const Color(0xFF1E88E5);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
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
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.location_city_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          n.nameKu,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${n.totalStores} شوێن',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : Colors.grey.shade600,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit_rounded, color: Colors.blue, size: 22),
              onPressed: () => _openEditor(neighborhood: n),
            ),
            IconButton(
              icon: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
                size: 22,
              ),
              onPressed: () => _deleteNeighborhood(n),
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
              color: const Color(0xFF1E88E5).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.location_city_outlined,
              size: 60,
              color: Color(0xFF1E88E5),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'هیچ گەڕەکێک نییە',
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

// ═══════════════════════════════════════════════════════════
// 🎨 دیالۆگی دەستکاریکردنی گەڕەک
// ═══════════════════════════════════════════════════════════
class _NeighborhoodEditorDialog extends StatefulWidget {
  final Neighborhood? neighborhood;

  const _NeighborhoodEditorDialog({this.neighborhood});

  @override
  State<_NeighborhoodEditorDialog> createState() =>
      _NeighborhoodEditorDialogState();
}

class _NeighborhoodEditorDialogState
    extends State<_NeighborhoodEditorDialog> {
  late TextEditingController _nameKuCtrl;
  late TextEditingController _nameArCtrl;
  late TextEditingController _nameEnCtrl;
  late TextEditingController _descKuCtrl;
  late TextEditingController _latCtrl;
  late TextEditingController _lngCtrl;
  late String _selectedColor;
  bool _loading = false;

  final _colors = [
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
    final n = widget.neighborhood;
    _nameKuCtrl = TextEditingController(text: n?.nameKu ?? '');
    _nameArCtrl = TextEditingController(text: n?.nameAr ?? '');
    _nameEnCtrl = TextEditingController(text: n?.nameEn ?? '');
    _descKuCtrl = TextEditingController(text: n?.descriptionKu ?? '');
    _latCtrl = TextEditingController(
      text: n?.centerLatitude?.toString() ?? '',
    );
    _lngCtrl = TextEditingController(
      text: n?.centerLongitude?.toString() ?? '',
    );
    _selectedColor = n?.color ?? '#1E88E5';
  }

  @override
  void dispose() {
    _nameKuCtrl.dispose();
    _nameArCtrl.dispose();
    _nameEnCtrl.dispose();
    _descKuCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameKuCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ناوی گەڕەک پێویستە'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final data = {
        'name_ku': _nameKuCtrl.text.trim(),
        'name_ar': _nameArCtrl.text.trim().isEmpty
            ? null
            : _nameArCtrl.text.trim(),
        'name_en': _nameEnCtrl.text.trim().isEmpty
            ? null
            : _nameEnCtrl.text.trim(),
        'description_ku': _descKuCtrl.text.trim().isEmpty
            ? null
            : _descKuCtrl.text.trim(),
        'color': _selectedColor,
        'center_latitude': _latCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(_latCtrl.text.trim()),
        'center_longitude': _lngCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(_lngCtrl.text.trim()),
      };

      if (mounted) Navigator.pop(context, data);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.neighborhood != null;

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
                      Icons.location_city_rounded,
                      color: Color(0xFF1E88E5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isEditing ? 'دەستکاریکردن' : 'زیادکردنی گەڕەک',
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
                _buildField('وەسف', _descKuCtrl, maxLines: 3),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildField('Latitude', _latCtrl),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _buildField('Longitude', _lngCtrl),
                    ),
                  ],
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
                                ? Colors.black
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