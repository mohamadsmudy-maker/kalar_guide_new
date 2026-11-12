import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../l10n/tr.dart';

/// 🎬 شاشەی بەڕێوەبردنی ڤیدیۆکان
class AdminVideosScreen extends StatefulWidget {
  const AdminVideosScreen({super.key});

  @override
  State<AdminVideosScreen> createState() => _AdminVideosScreenState();
}

class _AdminVideosScreenState extends State<AdminVideosScreen> {
  bool _isLoading = true;
  bool _isDeleting = false;
  List<Map<String, dynamic>> _videosList = [];

  @override
  void initState() {
    super.initState();
    _fetchVideos();
  }

  Future<void> _fetchVideos() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

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
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ _deleteVideo چاککراو — بە mounted پشکنین
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
            content: Text(tr("ڤیدیۆکە سڕایەوە 🗑️")),
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
              backgroundColor: const Color(0xFFDC3545)),
        );
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // ✅ _openAddDialog — بە await
  Future<void> _openAddDialog({Map<String, dynamic>? videoToEdit}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _AddEditVideoScreen(videoToEdit: videoToEdit),
      ),
    );

    if (mounted) await _fetchVideos();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F5F8),
        appBar: AppBar(
          title: Text(
            tr("بەڕێوەبردنی ڤیدیۆکان 🎬"),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _videosList.isEmpty
                ? Center(
                    child: Text(
                      tr("هیچ ڤیدیۆیەکی تۆمارکراو نییە 📭"),
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _videosList.length,
                    itemBuilder: (context, index) {
                      final vid = _videosList[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(12),
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.indigo.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: Color(0xFF4F5BD5),
                            ),
                          ),
                          title: Text(
                            tr(vid['title'] ?? ''),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            tr(vid['description'] ?? ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Color(0xFF1E88E5),
                                  size: 20,
                                ),
                                onPressed: _isDeleting
                                    ? null
                                    : () => _openAddDialog(videoToEdit: vid),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete,
                                  color: Color(0xFFDC3545),
                                  size: 20,
                                ),
                                onPressed: _isDeleting
                                    ? null
                                    : () => _deleteVideo(vid['id']),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          onPressed: _isDeleting ? null : () => _openAddDialog(),
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// ➕ شاشەی زیادکردن / دەستکاریکردنی ڤیدیۆ
// ═══════════════════════════════════════════════════════════
class _AddEditVideoScreen extends StatefulWidget {
  final Map<String, dynamic>? videoToEdit;
  const _AddEditVideoScreen({this.videoToEdit});

  @override
  State<_AddEditVideoScreen> createState() => _AddEditVideoScreenState();
}

class _AddEditVideoScreenState extends State<_AddEditVideoScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _urlCtrl;
  late final TextEditingController _descCtrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl =
        TextEditingController(text: widget.videoToEdit?['title'] ?? '');
    _urlCtrl =
        TextEditingController(text: widget.videoToEdit?['video_url'] ?? '');
    _descCtrl =
        TextEditingController(text: widget.videoToEdit?['description'] ?? '');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _urlCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_titleCtrl.text.trim().isEmpty || _urlCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr("تکایە ناونیشان و لینکی ڤیدیۆ پڕبکەرەوە ⚠")),
          backgroundColor: const Color(0xFFD9822B),
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final data = {
        'title': _titleCtrl.text.trim(),
        'video_url': _urlCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
      };

      if (widget.videoToEdit == null) {
        data['created_at'] = DateTime.now().toIso8601String();
        await Supabase.instance.client.from('videos').insert(data);
      } else {
        await Supabase.instance.client
            .from('videos')
            .update(data)
            .eq('id', widget.videoToEdit!['id']);
      }

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr("پاشەکەوتکرا ✅")),
            backgroundColor: const Color(0xFF0F9D7A),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Save video error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(trf("هەڵە: {0}", [e])),
              backgroundColor: const Color(0xFFDC3545)),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.videoToEdit != null;
    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F5F8),
        appBar: AppBar(
          title: Text(
            tr(isEditing ? "دەستکاریکردنی ڤیدیۆ ✏️" : "زیادکردنی ڤیدیۆ 🎬"),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _titleCtrl,
                  decoration: InputDecoration(
                    labelText: tr("ناونیشانی ڤیدیۆ *"),
                    prefixIcon: const Icon(
                      Icons.title_rounded,
                      color: AppColors.primary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _urlCtrl,
                  decoration: InputDecoration(
                    labelText: tr("لینکی ڤیدیۆ (YouTube) *"),
                    prefixIcon: const Icon(
                      Icons.link_rounded,
                      color: AppColors.primary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _descCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: tr("وەسفی ڤیدیۆ"),
                    alignLabelWithHint: true,
                    prefixIcon: const Icon(
                      Icons.description_rounded,
                      color: AppColors.primary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: _save,
                          child: Text(
                            tr(isEditing ? "نوێکردنەوە ✅" : "بڵاوکردنەوە ✅"),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
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
}
