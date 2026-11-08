// lib/screens/admin/admin_neighborhoods_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../models/neighborhood.dart';
import '../../services/neighborhood_service.dart';
import '../../l10n/tr.dart';

/// 🏘️ شاشەی بەڕێوەبردنی گەڕەکەکان — ULTRA PRO
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
    if (mounted) setState(() => _loading = true);
    final data = await NeighborhoodService.getAll();
    if (mounted) {
      setState(() {
        _neighborhoods = data;
        _loading = false;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ➕ / ✏️ Editor
  // ═══════════════════════════════════════════════════════════
  Future<void> _openEditor({Neighborhood? neighborhood}) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _NeighborhoodEditorDialog(neighborhood: neighborhood),
    );

    if (result == null) return;

    try {
      if (neighborhood == null) {
        await NeighborhoodService.addNeighborhood(result);
      } else if (neighborhood.id != null && neighborhood.id!.isNotEmpty) {
        await NeighborhoodService.updateNeighborhood(
          neighborhood.id!,
          result,
        );
      }
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              tr(neighborhood == null ? '✅ زیادکرا' : '✅ نوێکرایەوە'),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ _openEditor error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trf('هەڵە: {0}', [e])),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🗑️ Delete
  // ═══════════════════════════════════════════════════════════
  Future<void> _deleteNeighborhood(Neighborhood n) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(tr('سڕینەوەی گەڕەک')),
          content: Text(
            trf('ئایا دڵنیایت لە سڕینەوەی "{0}"؟', [n.nameKu]),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr('نەخێر')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
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
    if (n.id == null || n.id!.isEmpty) return;

    try {
      await NeighborhoodService.deleteNeighborhood(n.id!);
      await _loadData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('✅ گەڕەک سڕایەوە')),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ _deleteNeighborhood error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trf('هەڵە: {0}', [e])),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: Text(
            trf('گەڕەکەکان 🏘️ ({0})', [_neighborhoods.length]),
            style: const TextStyle(
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
          label: Text(
            tr('زیادکردنی گەڕەک'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }

  Widget _buildCard(Neighborhood n, bool isDark) {
    final color = n.displayColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
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
          tr(n.nameKu),
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
                tr(n.hasBoundary
                    ? trf('{0} خاڵی سنوور', [n.boundaryPoints.length])
                    : 'بێ سنوور'),
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : Colors.grey.shade600,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (n.hasCenter) ...[
                const SizedBox(height: 2),
                Text(
                  '${n.centerLatitude!.toStringAsFixed(4)}, '
                      '${n.centerLongitude!.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : Colors.grey.shade500,
                  ),
                ),
              ],
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
            tr('هیچ گەڕەکێک نییە'),
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
  late TextEditingController _nameEnCtrl;
  late TextEditingController _latCtrl;
  late TextEditingController _lngCtrl;
  late TextEditingController _boundaryCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final n = widget.neighborhood;

    _nameKuCtrl = TextEditingController(text: n?.nameKu ?? '');
    _nameEnCtrl = TextEditingController(text: n?.nameEn ?? '');
    _latCtrl = TextEditingController(
      text: (n?.centerLatitude != null && n!.centerLatitude != 0)
          ? n.centerLatitude.toString()
          : '',
    );
    _lngCtrl = TextEditingController(
      text: (n?.centerLongitude != null && n!.centerLongitude != 0)
          ? n.centerLongitude.toString()
          : '',
    );
    _boundaryCtrl = TextEditingController(
      text: (n != null && n.hasBoundary)
          ? _boundaryToString(n.boundaryPoints)
          : '',
    );
  }

  @override
  void dispose() {
    _nameKuCtrl.dispose();
    _nameEnCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _boundaryCtrl.dispose();
    super.dispose();
  }

  // ⭐ گۆڕینی لیستی خاڵەکان بۆ تێکست
  String _boundaryToString(List<LatLng> boundary) {
    return boundary
        .map((p) => '${p.latitude},${p.longitude}')
        .join(';');
  }

  // ⭐ گۆڕینی تێکست بۆ لیستی خاڵەکان
  List<Map<String, double>> _parseBoundary(String text) {
    if (text.trim().isEmpty) return [];

    final points = <Map<String, double>>[];
    final parts = text.split(';');

    for (var part in parts) {
      part = part.trim();
      if (part.isEmpty) continue;

      final coords = part.split(',');
      if (coords.length == 2) {
        final lat = double.tryParse(coords[0].trim());
        final lng = double.tryParse(coords[1].trim());
        if (lat != null && lng != null) {
          points.add({'lat': lat, 'lng': lng});
        }
      }
    }

    return points;
  }

  Future<void> _save() async {
    if (_nameKuCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('ناوی گەڕەک پێویستە')),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final boundaryPoints = _parseBoundary(_boundaryCtrl.text);

      // ⚠️ پشکنین: ئەگەر boundary هەیە، دەبێت لانیکەم 3 خاڵ بێت
      if (boundaryPoints.isNotEmpty && boundaryPoints.length < 3) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              trf('⚠️ سنوور دەبێت لانیکەم ٣ خاڵ بێت (ئێستا: {0})', [boundaryPoints.length]),
            ),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final data = <String, dynamic>{
        'name_ku': _nameKuCtrl.text.trim(),
        'name_en': _nameEnCtrl.text.trim().isEmpty
            ? null
            : _nameEnCtrl.text.trim(),
        // ✅ ناوی دروست — center_latitude / center_longitude
        'center_latitude': _latCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(_latCtrl.text.trim()),
        'center_longitude': _lngCtrl.text.trim().isEmpty
            ? null
            : double.tryParse(_lngCtrl.text.trim()),
        'boundary': boundaryPoints.isEmpty ? null : boundaryPoints,
      };

      if (mounted) Navigator.pop(context, data);
    } catch (e) {
      debugPrint('❌ _save error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.neighborhood != null;

    return Directionality(
      textDirection: AppLang.direction,
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
                      tr(isEditing ? 'دەستکاریکردن' : 'زیادکردنی گەڕەک'),
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
                _buildField(tr('ناوی کوردی *'), _nameKuCtrl),
                const SizedBox(height: 10),
                _buildField(tr('ناوی ئینگلیزی'), _nameEnCtrl),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: _buildField('Latitude', _latCtrl)),
                    const SizedBox(width: 8),
                    Expanded(child: _buildField('Longitude', _lngCtrl)),
                  ],
                ),
                const SizedBox(height: 10),
                _buildField(
                  tr('سنوور (lat,lng;lat,lng;...)'),
                  _boundaryCtrl,
                  maxLines: 5,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.blue.shade700,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          tr('خاڵەکانی سنوور بەم شێوەیە بنووسە:\n34.6189,45.3156;34.6195,45.3162;...\n⚠️ پێویستە لانیکەم ٣ خاڵ بێت'),
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.blue.shade900,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
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
                      tr(isEditing ? 'نوێکردنەوە' : 'زیادکردن'),
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