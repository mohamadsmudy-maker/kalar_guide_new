import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../services/image_service.dart';
import '../../l10n/tr.dart';

// ═══════════════════════════════════════════════════════════
// ⚙️ Constants
// ═══════════════════════════════════════════════════════════
const String _kTable = 'complaint_instructions';
const int _kMaxInstructions = 20;
const int _kTitleMax = 80;
const int _kDescMax = 600;
const Color _kAppBarColor = Color(0xFF1E1B2E);

// ═══════════════════════════════════════════════════════════
// 🛠️ Shared UI Helpers
// ═══════════════════════════════════════════════════════════
void _toast(ScaffoldMessengerState messenger, String msg,
    {bool isError = false}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content:
            Text(tr(msg), style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor:
            isError ? const Color(0xFFDC3545) : const Color(0xFF0F9D7A),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
}

Future<bool> _confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = "نەخێر",
  IconData icon = Icons.warning_amber_rounded,
  Color color = const Color(0xFFDC3545),
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => Directionality(
      textDirection: AppLang.direction,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(tr(title),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Text(tr(message), style: const TextStyle(fontSize: 13)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(tr(cancelLabel),
                style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(tr(confirmLabel)),
          ),
        ],
      ),
    ),
  );
  return res ?? false;
}

void _showImagePreview(BuildContext context, String url) {
  showDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: OptimizedNetworkImage(imageUrl: url, fit: BoxFit.contain),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SectionCard extends StatelessWidget {
  final bool isDark;
  final Widget child;
  const _SectionCard({required this.isDark, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

enum _StatusFilter { all, active, inactive }

// ═══════════════════════════════════════════════════════════
// 1. 📢 لیستی بەڕێوەبردنی ڕێنماییەکانی سکاڵا
// ═══════════════════════════════════════════════════════════
class AdminComplaintInstructionsListScreen extends StatefulWidget {
  const AdminComplaintInstructionsListScreen({super.key});

  @override
  State<AdminComplaintInstructionsListScreen> createState() =>
      _AdminComplaintInstructionsListScreenState();
}

class _AdminComplaintInstructionsListScreenState
    extends State<AdminComplaintInstructionsListScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _instructions = [];

  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';
  _StatusFilter _filter = _StatusFilter.all;
  final Set<dynamic> _togglingIds = {};

  bool get _limitReached => _instructions.length >= _kMaxInstructions;
  int get _activeCount =>
      _instructions.where((e) => (e['is_active'] ?? true) == true).length;

  @override
  void initState() {
    super.initState();
    _fetchInstructions();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchInstructions({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final res = await Supabase.instance.client
          .from(_kTable)
          .select()
          .order('id', ascending: true);

      if (!mounted) return;
      setState(() {
        _instructions = List<Map<String, dynamic>>.from(res as List);
        _loading = false;
        _error = null;
      });
    } on PostgrestException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _toggleActive(Map<String, dynamic> item, bool value) async {
    final id = item['id'];
    final messenger = ScaffoldMessenger.of(context);
    final old = item['is_active'] ?? true;

    setState(() {
      item['is_active'] = value;
      _togglingIds.add(id);
    });

    try {
      await Supabase.instance.client
          .from(_kTable)
          .update({'is_active': value}).eq('id', id);
    } catch (e) {
      if (!mounted) return;
      setState(() => item['is_active'] = old);
      _toast(messenger, trf("هەڵە: {0}", [e]), isError: true);
    } finally {
      if (mounted) setState(() => _togglingIds.remove(id));
    }
  }

  Future<void> _deleteInstruction(dynamic id) async {
    final messenger = ScaffoldMessenger.of(context);
    final confirm = await _confirmDialog(
      context,
      title: tr("سڕینەوەی ڕێنمایی"),
      message: tr("ئایا دڵنیایت لە سڕینەوەی ئەم سلایدە؟"),
      confirmLabel: tr("سڕینەوە"),
    );
    if (!confirm) return;

    try {
      await Supabase.instance.client.from(_kTable).delete().eq('id', id);
      await _fetchInstructions(silent: true);
      _toast(messenger, tr("بە سەرکەوتوویی سڕایەوە 🗑️"));
    } catch (e) {
      _toast(messenger, trf("هەڵە: {0}", [e]), isError: true);
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? item}) async {
    if (item == null && _limitReached) {
      _toast(ScaffoldMessenger.of(context),
          trf("گەیشتیتە سنووری {0} سلاید ⚠", [_kMaxInstructions]),
          isError: true);
      return;
    }
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AdminEditComplaintInstructionScreen(itemToEdit: item),
      ),
    );
    if (changed == true) _fetchInstructions(silent: true);
  }

  List<MapEntry<int, Map<String, dynamic>>> get _visible {
    final q = _query.trim().toLowerCase();
    final out = <MapEntry<int, Map<String, dynamic>>>[];
    for (var i = 0; i < _instructions.length; i++) {
      final it = _instructions[i];
      final active = (it['is_active'] ?? true) == true;
      if (_filter == _StatusFilter.active && !active) continue;
      if (_filter == _StatusFilter.inactive && active) continue;
      if (q.isNotEmpty) {
        final t = (it['title'] ?? '').toString().toLowerCase();
        final d = (it['description'] ?? '').toString().toLowerCase();
        if (!t.contains(q) && !d.contains(q)) continue;
      }
      out.add(MapEntry(i, it));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor:
            isDark ? AppColors.darkBackground : const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: Text(
            tr("ڕێنماییەکانی سکاڵا 📢"),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          backgroundColor: _kAppBarColor,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
          actions: [
            IconButton(
              tooltip: tr("نوێکردنەوە"),
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loading ? null : () => _fetchInstructions(),
            ),
          ],
        ),
        body: _buildBody(isDark),
        floatingActionButton: (_loading || _error != null || _limitReached)
            ? null
            : FloatingActionButton.extended(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                onPressed: () => _openEditor(),
                icon: const Icon(Icons.add_rounded),
                label: Text(tr("زیادکردنی نوێ"),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
      ),
    );
  }

  Widget _buildBody(bool isDark) {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return _buildScrollableCenter(_buildErrorState(isDark));
    }
    if (_instructions.isEmpty) {
      return _buildScrollableCenter(_buildEmptyState(isDark));
    }

    final items = _visible;

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _fetchInstructions(silent: true),
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: items.isEmpty ? 2 : items.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) return _buildHeader(isDark);
          if (items.isEmpty) return _buildNoResults(isDark);
          final entry = items[i - 1];
          return _buildInstructionCard(entry.value, entry.key, isDark);
        },
      ),
    );
  }

  Widget _buildScrollableCenter(Widget child) {
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _fetchInstructions(silent: true),
      child: LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark) {
    final total = _instructions.length;
    final active = _activeCount;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _statChip(isDark, Icons.layers_rounded,
                  "$total / $_kMaxInstructions", "کۆی گشتی", AppColors.primary),
              const SizedBox(width: 8),
              _statChip(isDark, Icons.visibility_rounded, "$active", "چالاک",
                  const Color(0xFF0F9D7A)),
              const SizedBox(width: 8),
              _statChip(isDark, Icons.visibility_off_rounded,
                  "${total - active}", "ناچالاک", Colors.grey),
            ],
          ),
          if (_limitReached) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFD9822B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: const Color(0xFFD9822B).withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: Color(0xFFD9822B), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      trf("گەیشتیتە زۆرترین ژمارەی سلاید ({0}). بۆ زیادکردنی نوێ، یەکێک بسڕەوە.",
                          [_kMaxInstructions]),
                      style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.white70 : Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black87, fontSize: 13),
            decoration: InputDecoration(
              hintText: tr("گەڕان بەپێی ناونیشان یان دەق..."),
              hintStyle: TextStyle(
                  color: isDark ? Colors.white54 : Colors.grey, fontSize: 12),
              prefixIcon:
                  const Icon(Icons.search_rounded, color: AppColors.primary),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: Icon(Icons.close_rounded,
                          color: isDark ? Colors.white54 : Colors.grey),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
              filled: true,
              fillColor: isDark ? AppColors.darkCard : Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              _filterChip(isDark, "هەمووی", _StatusFilter.all),
              _filterChip(isDark, "چالاک", _StatusFilter.active),
              _filterChip(isDark, "ناچالاک", _StatusFilter.inactive),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statChip(
      bool isDark, IconData icon, String value, String label, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              tr(value),
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 14,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              tr(label),
              style: TextStyle(
                  fontSize: 10, color: isDark ? Colors.white54 : Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(bool isDark, String label, _StatusFilter value) {
    final selected = _filter == value;
    return ChoiceChip(
      label: Text(
        tr(label),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: selected
              ? Colors.white
              : (isDark ? Colors.white70 : Colors.black87),
        ),
      ),
      selected: selected,
      showCheckmark: false,
      selectedColor: AppColors.primary,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      side: BorderSide(
        color: selected
            ? AppColors.primary
            : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      onSelected: (_) => setState(() => _filter = value),
    );
  }

  Widget _buildInstructionCard(
      Map<String, dynamic> item, int index, bool isDark) {
    final bool isActive = (item['is_active'] ?? true) == true;
    final String imageUrl = (item['image_url'] ?? '').toString();
    final String title = (item['title'] ?? 'بێ ناونیشان').toString();
    final String desc = (item['description'] ?? '').toString();
    final bool toggling = _togglingIds.contains(item['id']);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isActive
              ? const Color(0xFF0F9D7A).withValues(alpha: 0.3)
              : (isDark ? Colors.white12 : Colors.grey.shade200),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: imageUrl.isEmpty
                ? null
                : () => _showImagePreview(context, imageUrl),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(18)),
                  child: imageUrl.isNotEmpty
                      ? OptimizedNetworkImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          height: 160,
                          fit: BoxFit.cover,
                        )
                      : Container(
                          width: double.infinity,
                          height: 160,
                          color: isDark
                              ? AppColors.darkBackground
                              : Colors.grey.shade100,
                          child: const Icon(Icons.image_not_supported_rounded,
                              color: Colors.grey, size: 40),
                        ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.7),
                            Colors.transparent
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: _badge(
                      trf("سلاید {0}", [index + 1]), AppColors.primary,
                      fontSize: 12),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  child: _badge(
                    isActive ? "چالاک" : "ناچالاک",
                    isActive ? const Color(0xFF0F9D7A) : Colors.grey,
                    icon: isActive
                        ? Icons.visibility_rounded
                        : Icons.visibility_off_rounded,
                  ),
                ),
                if (imageUrl.isNotEmpty)
                  Positioned(
                    bottom: 10,
                    left: 12,
                    child: Icon(Icons.zoom_out_map_rounded,
                        color: Colors.white.withValues(alpha: 0.85), size: 18),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr(title),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    toggling
                        ? const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 14),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppColors.primary),
                            ),
                          )
                        : Switch(
                            value: isActive,
                            activeThumbColor: const Color(0xFF0F9D7A),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            onChanged: (v) => _toggleActive(item, v),
                          ),
                  ],
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    tr(desc),
                    style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white60 : Colors.grey.shade600,
                        height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => _openEditor(item: item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.edit_rounded,
                                  color: AppColors.primary, size: 16),
                              const SizedBox(width: 6),
                              Text(tr("دەستکاری"),
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _deleteInstruction(item['id']),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFFDC3545).withValues(alpha: 0.15)
                              : Colors.red.shade50,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.delete_rounded,
                            color: Color(0xFFDC3545), size: 18),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color,
      {IconData? icon, double fontSize = 10}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 6)
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, color: Colors.white, size: 12),
            const SizedBox(width: 4),
          ],
          Text(
            tr(text),
            style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 50),
      child: Column(
        children: [
          Icon(Icons.search_off_rounded,
              size: 52, color: isDark ? Colors.white54 : Colors.grey),
          const SizedBox(height: 10),
          Text(
            tr("هیچ ئەنجامێک نەدۆزرایەوە"),
            style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isDark ? Colors.white54 : Colors.grey),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              _searchCtrl.clear();
              setState(() {
                _query = '';
                _filter = _StatusFilter.all;
              });
            },
            child: Text(tr("سڕینەوەی فلتەرەکان")),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle),
          child: const Icon(Icons.announcement_outlined,
              size: 60, color: AppColors.primary),
        ),
        const SizedBox(height: 16),
        Text(
          tr("هیچ ڕێنماییەک نییە 📭"),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 15,
            color: isDark ? Colors.white54 : const Color(0xFF1A1A2E),
          ),
        ),
        const SizedBox(height: 6),
        Text(tr("دەتوانیت ڕێنمایی نوێ زیاد بکەیت"),
            style: TextStyle(
                fontSize: 12, color: isDark ? Colors.white54 : Colors.grey)),
        const SizedBox(height: 20),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          ),
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: Text(tr("زیادکردنی ڕێنمایی نوێ"),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildErrorState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
                color: const Color(0xFFDC3545).withValues(alpha: 0.1),
                shape: BoxShape.circle),
            child: const Icon(Icons.wifi_off_rounded,
                size: 52, color: Color(0xFFDC3545)),
          ),
          const SizedBox(height: 16),
          Text(
            tr("هەڵەیەک ڕووی دا"),
            style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: isDark ? Colors.white : Colors.black87),
          ),
          const SizedBox(height: 6),
          Text(
            tr(_error ?? ''),
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11, color: isDark ? Colors.white54 : Colors.grey),
          ),
          const SizedBox(height: 18),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: () => _fetchInstructions(),
            icon: const Icon(Icons.refresh_rounded, size: 20),
            label: Text(tr("دووبارە هەوڵبدەرەوە"),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 2. ✏️ پەڕەی زیادکردن و دەستکاری سلایدی تاکەکەسی
// ═══════════════════════════════════════════════════════════
class AdminEditComplaintInstructionScreen extends StatefulWidget {
  final Map<String, dynamic>? itemToEdit;

  const AdminEditComplaintInstructionScreen({super.key, this.itemToEdit});

  @override
  State<AdminEditComplaintInstructionScreen> createState() =>
      _AdminEditComplaintInstructionScreenState();
}

class _AdminEditComplaintInstructionScreenState
    extends State<AdminEditComplaintInstructionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _picker = ImagePicker();

  XFile? _pickedImage;
  String? _existingImageUrl;
  bool _removedExisting = false;
  bool _isActive = true;
  bool _loading = false;
  bool _saved = false;
  bool _imageError = false;

  String _initTitle = '';
  String _initDesc = '';
  bool _initActive = true;

  bool get isEditing => widget.itemToEdit != null;

  bool get _hasImage =>
      _pickedImage != null ||
      (!_removedExisting && (_existingImageUrl ?? '').isNotEmpty);

  bool get _isDirty =>
      _titleCtrl.text.trim() != _initTitle ||
      _descCtrl.text.trim() != _initDesc ||
      _isActive != _initActive ||
      _pickedImage != null ||
      _removedExisting;

  @override
  void initState() {
    super.initState();
    final item = widget.itemToEdit;
    if (item != null) {
      _titleCtrl.text = (item['title'] ?? '').toString();
      _descCtrl.text = (item['description'] ?? '').toString();
      _existingImageUrl = item['image_url']?.toString();
      _isActive = (item['is_active'] ?? true) == true;
    }
    _initTitle = _titleCtrl.text.trim();
    _initDesc = _descCtrl.text.trim();
    _initActive = _isActive;

    _titleCtrl.addListener(_onChanged);
    _descCtrl.addListener(_onChanged);
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _titleCtrl.removeListener(_onChanged);
    _descCtrl.removeListener(_onChanged);
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    try {
      final picked = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 70, maxWidth: 1600);
      if (picked != null && mounted) {
        setState(() {
          _pickedImage = picked;
          _imageError = false;
        });
      }
    } catch (e) {
      _toast(messenger, trf("نەتوانرا وێنە هەڵبژێردرێت: {0}", [e]),
          isError: true);
    }
  }

  void _removeImage() {
    setState(() {
      _pickedImage = null;
      if ((_existingImageUrl ?? '').isNotEmpty) _removedExisting = true;
    });
  }

  Future<void> _save() async {
    if (_loading) return;
    FocusScope.of(context).unfocus();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final formOk = _formKey.currentState?.validate() ?? false;
    if (!_hasImage) setState(() => _imageError = true);
    if (!formOk || !_hasImage) {
      _toast(messenger, tr("تکایە زانیارییە پێویستەکان پڕبکەرەوە ⚠"),
          isError: true);
      return;
    }

    setState(() => _loading = true);
    try {
      String imageUrl = _removedExisting ? '' : (_existingImageUrl ?? '');
      if (_pickedImage != null) {
        imageUrl = await ImageCompressionService.uploadImage(_pickedImage!);
      }

      final data = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'image_url': imageUrl,
        'is_active': _isActive,
      };

      final table = Supabase.instance.client.from(_kTable);
      if (!isEditing) {
        await table.insert(data);
      } else {
        await table.update(data).eq('id', widget.itemToEdit!['id']);
      }

      if (!mounted) return;
      setState(() => _saved = true);
      navigator.pop(true);
      _toast(messenger, tr("بە سەرکەوتوویی پاشەکەوت کرا ✅"));
    } catch (e) {
      _toast(messenger, trf("هەڵە ڕووی دا: {0}", [e]), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _decoration(bool isDark,
      {required String label, required IconData icon, bool multiline = false}) {
    OutlineInputBorder border(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: c, width: w),
        );

    final fieldBorderColor =
        isDark ? AppColors.darkBorder : Colors.grey.shade300;

    return InputDecoration(
      labelText: label,
      alignLabelWithHint: multiline,
      labelStyle:
          TextStyle(fontSize: 13, color: isDark ? Colors.white54 : Colors.grey),
      prefixIcon: multiline
          ? Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: Icon(icon, color: AppColors.primary),
            )
          : Icon(icon, color: AppColors.primary),
      border: border(fieldBorderColor),
      enabledBorder: border(fieldBorderColor),
      focusedBorder: border(AppColors.primary, 1.5),
      errorBorder: border(const Color(0xFFDC3545)),
      focusedErrorBorder: border(const Color(0xFFDC3545), 1.5),
      filled: true,
      fillColor: isDark ? AppColors.darkBackground : Colors.grey.shade50,
      counterStyle:
          TextStyle(fontSize: 10, color: isDark ? Colors.white54 : Colors.grey),
      contentPadding:
          EdgeInsets.symmetric(horizontal: 16, vertical: multiline ? 16 : 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: AppLang.direction,
      child: PopScope(
        canPop: _saved || !_isDirty,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          final navigator = Navigator.of(context);
          final leave = await _confirmDialog(
            context,
            title: tr("گۆڕانکاریەکان پاشەکەوت نەکراون"),
            message: tr("ئەگەر دەرچیت، گۆڕانکارییەکانت لەدەست دەچن. دڵنیایت؟"),
            confirmLabel: tr("دەرچوون"),
            cancelLabel: tr("مانەوە"),
            icon: Icons.edit_off_rounded,
            color: const Color(0xFFD9822B),
          );
          if (leave) navigator.pop(false);
        },
        child: Scaffold(
          backgroundColor:
              isDark ? AppColors.darkBackground : const Color(0xFFF4F6F9),
          appBar: AppBar(
            title: Text(
              tr(isEditing
                  ? "دەستکاریکردنی ڕێنمایی ✏️"
                  : "زیادکردنی ڕێنمایی نوێ 📢"),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
            backgroundColor: _kAppBarColor,
            foregroundColor: Colors.white,
            centerTitle: true,
            elevation: 0,
          ),
          body: Stack(
            children: [
              GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildImageSection(isDark),
                        const SizedBox(height: 16),
                        _buildFieldsSection(isDark),
                        const SizedBox(height: 28),
                        _buildSaveButton(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
              if (_loading)
                Positioned.fill(
                  child: AbsorbPointer(
                    child:
                        Container(color: Colors.black.withValues(alpha: 0.15)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection(bool isDark) {
    final hasImage = _hasImage;

    Widget content;
    if (_pickedImage != null) {
      content = Image.file(File(_pickedImage!.path), fit: BoxFit.cover);
    } else if (!_removedExisting && (_existingImageUrl ?? '').isNotEmpty) {
      content = OptimizedNetworkImage(
          imageUrl: _existingImageUrl!, fit: BoxFit.cover);
    } else {
      content = Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.add_a_photo_rounded,
              size: 40, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            tr("کرتە بکە بۆ هەڵبژاردنی وێنە 📸"),
            style: const TextStyle(
                fontSize: 13, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ],
      );
    }

    return _SectionCard(
      isDark: isDark,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.photo_library_rounded,
                  color: AppColors.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                tr("وێنەی سلاید *"),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickImage,
            child: Container(
              height: 200,
              width: double.infinity,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _imageError
                      ? const Color(0xFFDC3545)
                      : AppColors.primary.withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    content,
                    if (hasImage)
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Row(
                          children: [
                            _roundBtn(Icons.edit_rounded, _pickImage),
                            const SizedBox(width: 6),
                            _roundBtn(
                                Icons.delete_outline_rounded, _removeImage,
                                color: const Color(0xFFDC3545)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_imageError)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 4),
              child: Text(tr("تکایا وێنەیەک هەڵبژێرە"),
                  style:
                      const TextStyle(color: Color(0xFFDC3545), fontSize: 11)),
            ),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap, {Color? color}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: (color ?? Colors.black).withValues(alpha: 0.65),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }

  Widget _buildFieldsSection(bool isDark) {
    return _SectionCard(
      isDark: isDark,
      child: Column(
        children: [
          TextFormField(
            controller: _titleCtrl,
            enabled: !_loading,
            maxLength: _kTitleMax,
            textInputAction: TextInputAction.next,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: _decoration(isDark,
                label: tr("ناونیشانی ڕێنمایی *"), icon: Icons.title_rounded),
            validator: (v) => (v == null || v.trim().isEmpty)
                ? "تکایا ناونیشان پڕبکەرەوە"
                : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _descCtrl,
            enabled: !_loading,
            maxLines: 5,
            maxLength: _kDescMax,
            keyboardType: TextInputType.multiline,
            style: TextStyle(color: isDark ? Colors.white : Colors.black87),
            decoration: _decoration(isDark,
                label: tr("دەق و ڕوونکردنەوەی ڕێنماییەکە"),
                icon: Icons.description_rounded,
                multiline: true),
          ),
          const SizedBox(height: 10),
          _buildActiveToggle(isDark),
        ],
      ),
    );
  }

  Widget _buildActiveToggle(bool isDark) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _isActive
            ? (isDark
                ? const Color(0xFF0F9D7A).withValues(alpha: 0.15)
                : Colors.green.shade50)
            : (isDark ? AppColors.darkBackground : Colors.grey.shade100),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isActive
              ? Colors.green.shade200
              : (isDark ? AppColors.darkBorder : Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isActive ? Icons.visibility_rounded : Icons.visibility_off_rounded,
            color: _isActive ? const Color(0xFF0F9D7A) : Colors.grey,
            size: 22,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(_isActive ? "چالاکە" : "ناچالاکە"),
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    color: _isActive
                        ? Colors.green.shade800
                        : (isDark ? Colors.white70 : Colors.grey.shade700),
                  ),
                ),
                Text(
                  tr(_isActive
                      ? "بەکارهێنەران دەتوانن بیبینن"
                      : "بەکارهێنەران ناتوانن بیبینن"),
                  style: TextStyle(
                    fontSize: 10,
                    color: _isActive
                        ? Colors.green.shade600
                        : (isDark ? Colors.white54 : Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isActive,
            activeThumbColor: const Color(0xFF0F9D7A),
            onChanged:
                _loading ? null : (val) => setState(() => _isActive = val),
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
          disabledForegroundColor: Colors.white,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 3,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
        ),
        onPressed: _loading
            ? null
            : () {
                HapticFeedback.lightImpact();
                _save();
              },
        icon: _loading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.5, color: Colors.white),
              )
            : const Icon(Icons.save_rounded, size: 22),
        label: Text(
          tr(_loading
              ? "تکایە چاوەڕێبە..."
              : (isEditing ? "نوێکردنەوە ✅" : "پاشەکەوتکردن ✅")),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
        ),
      ),
    );
  }
}
