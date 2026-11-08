import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/app_colors.dart';
import '../../l10n/tr.dart';
import '../../widgets/common/auto_translate.dart';
import '../../widgets/common/optimized_network_image.dart';

/// 🎬 شاشەی ڤیدیۆ و ڕێنماییەکان
class UserVideosScreen extends StatefulWidget {
  const UserVideosScreen({super.key});

  @override
  State<UserVideosScreen> createState() => _UserVideosScreenState();
}

class _UserVideosScreenState extends State<UserVideosScreen> {
  late Future<List<Map<String, dynamic>>> _future = _load();

  Future<List<Map<String, dynamic>>> _load() => Supabase.instance.client
      .from('videos')
      .select()
      .order('id', ascending: false);

  Future<void> _refresh() async {
    final f = _load();
    setState(() => _future = f);
    try {
      await f;
    } catch (_) {}
  }

  /// وێنۆچکەی یوتیووب ئەگەر بەستەرەکە یوتیووب بێت
  static String? youtubeThumb(String url) {
    final m = RegExp(
      r'(?:youtu\.be/|youtube\.com/(?:watch\?(?:.*&)?v=|shorts/|embed/|live/))([\w-]{11})',
    ).firstMatch(url);
    return m == null ? null : 'https://img.youtube.com/vi/${m.group(1)}/hqdefault.jpg';
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url.trim());
    final ok = uri != null &&
        uri.hasScheme &&
        await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('نەتوانرا ڤیدیۆکە بکرێتەوە'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F5F8),
        appBar: AppBar(
          title: Text(
            tr("ڤیدیۆ و ڕێنماییەکان 🎬"),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
        ),
        body: RefreshIndicator(
          color: AppColors.primary,
          onRefresh: _refresh,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                );
              }
              if (snapshot.hasError) {
                return _message(
                  icon: Icons.wifi_off_rounded,
                  color: const Color(0xFFD9822B),
                  title: tr('بارکردن سەرکەوتوو نەبوو'),
                  subtitle: tr('پەیوەندی ئینتەرنێت بپشکنە و دووبارە هەوڵ بدەرەوە'),
                  action: true,
                );
              }
              final videos = snapshot.data ?? [];
              if (videos.isEmpty) {
                return _message(
                  icon: Icons.video_library_rounded,
                  color: AppColors.primary,
                  title: tr('هێشتا هیچ ڤیدیۆیەک نییە'),
                  subtitle: tr('ڤیدیۆی ڕێنمایی بەم زووانە لێرە دادەنرێن'),
                );
              }
              return ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                itemCount: videos.length,
                itemBuilder: (context, i) => _card(videos[i]),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _message({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    bool action = false,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
      children: [
        Center(
          child: Container(
            width: 110,
            height: 110,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 52, color: color),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, height: 1.6),
        ),
        if (action) ...[
          const SizedBox(height: 20),
          Center(
            child: FilledButton.icon(
              onPressed: _refresh,
              style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(tr('دووبارە هەوڵدانەوە')),
            ),
          ),
        ],
      ],
    );
  }

  Widget _card(Map<String, dynamic> vid) {
    final url = '${vid['video_url'] ?? ''}';
    final thumb = youtubeThumb(url);
    final title = '${vid['title'] ?? ''}';
    final desc = '${vid['description'] ?? ''}';
    final placeholder = Container(
      color: AppColors.primary.withValues(alpha: 0.12),
      alignment: Alignment.center,
      child: Icon(Icons.movie_rounded,
          size: 48, color: AppColors.primary.withValues(alpha: 0.5)),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        shadowColor: Colors.black12,
        child: InkWell(
          onTap: url.isEmpty ? null : () => _open(url),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (thumb != null)
                      OptimizedNetworkImage(
                        imageUrl: thumb,
                        fit: BoxFit.cover,
                        fallback: placeholder,
                      )
                    else
                      placeholder,
                    const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Color(0x66000000)],
                        ),
                      ),
                    ),
                    Center(
                      child: Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.92),
                          shape: BoxShape.circle,
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 12),
                          ],
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            size: 36, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AutoTranslate(
                      text: title,
                      lang: AppLang.code,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    if (desc.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      AutoTranslate(
                        text: desc,
                        lang: AppLang.code,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.grey.shade600,
                            height: 1.5),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
