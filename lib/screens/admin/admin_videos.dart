import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../l10n/tr.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../videos/user_videos.dart' show youtubeThumb;

/// 🎬 شاشەی بەڕێوەبردنی ڤیدیۆکان
class AdminVideosScreen extends StatefulWidget {
  const AdminVideosScreen({super.key});

  @override
  State<AdminVideosScreen> createState() => _AdminVideosScreenState();
}

class _AdminVideosScreenState extends State<AdminVideosScreen> {
  bool _isLoading = true;
  bool _isDeleting = false;
  String? _error;
  List<Map<String, dynamic>> _videosList = [];

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final res = await Supabase.instance.client
          .from('videos')
          .select()
          .order('id', ascending: false);

      if (mounted) {
        setState(() {
          _videosList = List<Map<String, dynamic>>.from(res as List);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Fetch videos error: $e');
      if (mounted) {
        setState(() {
          _error = '$e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteVideo(dynamic id) async {
    if (_isDeleting) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(tr("سڕینەوەی ڤیدیۆ")),
          content: Text(tr("ئایا دڵنیایت لە سڕینەوەی ئەم ڤیدیۆیە؟")),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tr("نەخێر")),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC3545),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tr("سڕینەوە")),
            ),
          ],
        ),
      ),
    );

    if (confirm != true) return;
    if (mounted) setState(() => _isDeleting = true);

    try {
      await Supabase.instance.client.from('videos').delete().eq('id', id);
      await _fetchVideos();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr("ڤیدیۆکە سڕایەوە")),
            backgroundColor: const Color(0xFF0F9D7A),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Delete video error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trf("هەڵە: {0}", [e])),
            backgroundColor: const Color(0xFFDC3545),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _openEditor({Map<String, dynamic>? videoToEdit}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VideoEditorSheet(videoToEdit: videoToEdit),
    );
    if (saved != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr("✅ پاشەکەوتکرا")),
        backgroundColor: const Color(0xFF0F9D7A),
      ),
    );
    await _fetchVideos();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6FA),
        appBar: AppBar(
          title: Text(
            tr("بەڕێوەبردنی ڤیدیۆکان"),
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          backgroundColor: isDark ? const Color(0xFF1A1B2E) : AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _fetchVideos,
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _videosList.isEmpty
                ? _buildEmpty(isDark)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                    itemCount: _videosList.length,
                    itemBuilder: (context, i) =>
                        _buildCard(_videosList[i], isDark),
                  ),
        floatingActionButton: FloatingActionButton.extended(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: _isDeleting ? null : () => _openEditor(),
          icon: const Icon(Icons.add_rounded),
          label: Text(
            tr('زیادکردنی ڤیدیۆ'),
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty(bool isDark) {
    final sub = isDark ? Colors.white54 : const Color(0xFF8A90A0);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                _error != null
                    ? Icons.cloud_off_rounded
                    : Icons.video_library_rounded,
                size: 52,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _error != null
                  ? tr('ڤیدیۆکان نەهێنران')
                  : tr('هیچ ڤیدیۆیەک زیاد نەکراوە'),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _error ?? tr('بە دوگمەی خوارەوە لینکی ڤیدیۆیەکی یوتیووب زیاد بکە'),
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12.5, color: sub),
            ),
            if (_error != null)
              TextButton.icon(
                onPressed: _fetchVideos,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(tr('دووبارە هەوڵبدەوە')),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> vid, bool isDark) {
    final title = '${vid['title'] ?? ''}';
    final desc = '${vid['description'] ?? ''}'.trim();
    final thumb = youtubeThumb('${vid['video_url'] ?? ''}');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsetsDirectional.fromSTEB(10, 10, 2, 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 96,
              height: 60,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (thumb != null)
                    OptimizedNetworkImage(imageUrl: thumb, fit: BoxFit.cover)
                  else
                    ColoredBox(
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.black45,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(title),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                  ),
                ),
                if (desc.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    tr(desc),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : const Color(0xFF8A90A0),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: tr('دەستکاری'),
            icon: const Icon(Icons.edit_rounded,
                color: AppColors.primary, size: 20),
            onPressed:
                _isDeleting ? null : () => _openEditor(videoToEdit: vid),
          ),
          IconButton(
            tooltip: tr('سڕینەوە'),
            icon: const Icon(Icons.delete_outline_rounded,
                color: Color(0xFFDC3545), size: 20),
            onPressed: _isDeleting ? null : () => _deleteVideo(vid['id']),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ➕ شیتی زیادکردن / دەستکاریکردنی ڤیدیۆ — true ئەگەر پاشەکەوت کرا
// ═══════════════════════════════════════════════════════════
class _VideoEditorSheet extends StatefulWidget {
  final Map<String, dynamic>? videoToEdit;
  const _VideoEditorSheet({this.videoToEdit});

  @override
  State<_VideoEditorSheet> createState() => _VideoEditorSheetState();
}

class _VideoEditorSheetState extends State<_VideoEditorSheet> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _descCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final v = widget.videoToEdit;
    _titleCtrl = TextEditingController(text: '${v?['title'] ?? ''}');
    _urlCtrl = TextEditingController(text: '${v?['video_url'] ?? ''}');
    _descCtrl = TextEditingController(text: '${v?['description'] ?? ''}');
    _urlCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _warn(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFD9822B),
      ),
    );
  }

  Future<void> _save() async {
    final url = _urlCtrl.text.trim();
    if (_titleCtrl.text.trim().isEmpty || url.isEmpty) {
      _warn(tr("تکایە ناونیشان و لینکی ڤیدیۆ پڕبکەرەوە"));
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      _warn(tr('لینکەکە دروست نییە — دەبێت بە https:// دەست پێبکات'));
      return;
    }

    setState(() => _loading = true);
    try {
      final data = <String, dynamic>{
        'title': _titleCtrl.text.trim(),
        'video_url': url,
        'description': _descCtrl.text.trim(),
      };
      final table = Supabase.instance.client.from('videos');
      if (widget.videoToEdit == null) {
        data['created_at'] = DateTime.now().toIso8601String();
        await table.insert(data);
      } else {
        await table.update(data).eq('id', widget.videoToEdit!['id']);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('❌ Save video error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trf("هەڵە: {0}", [e])),
            backgroundColor: const Color(0xFFDC3545),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isEditing = widget.videoToEdit != null;
    final thumb = youtubeThumb(_urlCtrl.text.trim());

    return Directionality(
      textDirection: AppLang.direction,
      child: Padding(
        padding:
            EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: Material(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          clipBehavior: Clip.antiAlias,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                20, 10, 20, MediaQuery.paddingOf(context).bottom + 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 45,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.video_library_rounded,
                        color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isEditing
                            ? tr("دەستکاریکردنی ڤیدیۆ")
                            : tr("زیادکردنی ڤیدیۆ"),
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                          color:
                              isDark ? Colors.white : const Color(0xFF1A1A2E),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _field(tr("ناونیشانی ڤیدیۆ *"), _titleCtrl, isDark),
                const SizedBox(height: 12),
                _field(
                  tr("لینکی ڤیدیۆ (YouTube) *"),
                  _urlCtrl,
                  isDark,
                  hint: 'https://youtu.be/...',
                  keyboard: TextInputType.url,
                  ltr: true,
                ),
                if (thumb != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: OptimizedNetworkImage(
                          imageUrl: thumb, fit: BoxFit.cover),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                _field(tr("وەسفی ڤیدیۆ"), _descCtrl, isDark, maxLines: 3),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _loading ? null : _save,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(
                      isEditing ? tr("نوێکردنەوە") : tr("بڵاوکردنەوە"),
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

  Widget _field(
    String label,
    TextEditingController ctrl,
    bool isDark, {
    int maxLines = 1,
    String? hint,
    TextInputType? keyboard,
    bool ltr = false,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboard,
      textDirection: ltr ? TextDirection.ltr : null,
      style: TextStyle(
        fontSize: 13.5,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        alignLabelWithHint: true,
        labelStyle: TextStyle(
          fontSize: 12.5,
          color: isDark ? Colors.white54 : Colors.grey.shade700,
        ),
        hintStyle: TextStyle(
            fontSize: 12, color: isDark ? Colors.white30 : Colors.grey),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F0F14) : Colors.grey.shade50,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.1)
                : Colors.grey.shade300,
          ),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}
