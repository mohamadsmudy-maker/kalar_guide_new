// lib/screens/favorites/local_favorites_tab.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_colors.dart';
import '../../l10n/tr.dart';
import '../../services/local_favorites.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../widgets/full_screen_image_viewer.dart';

/// تابی دڵخوازی ڤیدیۆ یان گەلەری (لەسەر مۆبایل هەڵگیراوە)
class LocalFavoritesTab extends StatefulWidget {
  const LocalFavoritesTab({super.key, required this.kind});

  /// [LocalFavorites.videos] یان [LocalFavorites.gallery]
  final String kind;

  @override
  State<LocalFavoritesTab> createState() => _LocalFavoritesTabState();
}

class _LocalFavoritesTabState extends State<LocalFavoritesTab> {
  bool get _isVideo => widget.kind == LocalFavorites.videos;

  @override
  void initState() {
    super.initState();
    LocalFavorites.ensureLoaded();
  }

  Future<void> _openVideo(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final card = isDark ? const Color(0xFF1A1A22) : Colors.white;
    final text = isDark ? Colors.white : AppColors.textPrimary;
    final sub = isDark ? Colors.white54 : AppColors.textSecondary;

    return ValueListenableBuilder<int>(
      valueListenable: LocalFavorites.changes,
      builder: (context, _, __) {
        final items = LocalFavorites.items(widget.kind);
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4D67).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(_isVideo ? Icons.smart_display_rounded : Icons.photo_library_rounded,
                        size: 40, color: const Color(0xFFFF4D67)),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    tr(_isVideo ? 'هێشتا هیچ ڤیدیۆیەکت دڵخواز نەکردووە' : 'هێشتا هیچ وێنەیەکت دڵخواز نەکردووە'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: text, fontWeight: FontWeight.w800, fontSize: 15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tr('کرتە لە ❤️ بکە بۆ پاشەکەوتکردن'),
                    style: TextStyle(color: sub),
                  ),
                ],
              ),
            ),
          );
        }

        if (!_isVideo) {
          return GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: items.length,
            itemBuilder: (_, i) {
              final it = items[i];
              final url = '${it['key']}';
              return GestureDetector(
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FullScreenImageViewer(
                      imageUrl: url,
                      imageTitle: '${it['title'] ?? ''}',
                      category: it['category']?.toString(),
                    ),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: OptimizedNetworkImage(imageUrl: url, fit: BoxFit.cover),
                ),
              );
            },
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final it = items[i];
            final url = '${it['key']}';
            final thumb = '${it['thumb'] ?? ''}';
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: card,
                borderRadius: BorderRadius.circular(16),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => _openVideo(url),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 128,
                        height: 76,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (thumb.startsWith('http'))
                              OptimizedNetworkImage(imageUrl: thumb, fit: BoxFit.cover)
                            else
                              ColoredBox(
                                color: AppColors.primary.withValues(alpha: 0.12),
                                child: const Icon(Icons.movie_rounded, color: AppColors.primary),
                              ),
                            const Center(
                              child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 30),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          tr((it['title']?.toString() ?? '').isEmpty ? '—' : it['title'].toString()),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontWeight: FontWeight.w800, color: text),
                        ),
                      ),
                      IconButton(
                        tooltip: tr('لابردن'),
                        onPressed: () => LocalFavorites.remove(widget.kind, url),
                        icon: const Icon(Icons.favorite_rounded, color: Color(0xFFFF4D67)),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
