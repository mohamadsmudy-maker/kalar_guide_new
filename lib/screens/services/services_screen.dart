import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_colors.dart';
import '../../l10n/tr.dart';
import '../complaints/complaint_instruction_dialog.dart';
import '../emergency/emergency_main_screen.dart';
import '../gallery/gallery_screen.dart';
import '../map_screen.dart';
import '../neighborhoods/neighborhoods_screen.dart';
import '../stores/suggest_place_screen.dart';
import '../videos/user_videos.dart';

/// 🧰 ناوەندی خزمەتگوزارییەکان — هەموو بەشەکان لە یەک شوێن
class ServicesScreen extends StatelessWidget {
  final VoidCallback? onMenuTap;

  const ServicesScreen({super.key, this.onMenuTap});

  void _open(BuildContext context, Widget screen) {
    HapticFeedback.selectionClick();
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : const Color(0xFFF4F6FA);
    final fg = isDark ? Colors.white : const Color(0xFF1A1A2E);

    final city = [
      _Service(
        title: tr('نەخشە'),
        subtitle: tr('گەڕەک و شوێنەکان لەسەر نەخشە'),
        icon: Icons.map_rounded,
        colors: const [Color(0xFF0F9D7A), Color(0xFF16C79A)],
        onTap: (c) => _open(c, const MapScreen()),
      ),
      _Service(
        title: tr('گەڕەکان'),
        subtitle: tr('زانیاری گەڕەکەکانی کەلار'),
        icon: Icons.location_city_rounded,
        colors: const [Color(0xFF1E88E5), Color(0xFF42A5F5)],
        onTap: (c) => _open(c, const NeighborhoodsScreen()),
      ),
    ];
    final content = [
      _Service(
        title: tr('گەلەری'),
        subtitle: tr('جوانترین وێنەکانی شار'),
        icon: Icons.photo_library_rounded,
        colors: const [Color(0xFFD9822B), Color(0xFFF2A65A)],
        onTap: (c) => _open(c, const GalleryScreen()),
      ),
      _Service(
        title: tr('ڤیدیۆکان'),
        subtitle: tr('ڤیدیۆ و ڕێنماییەکان'),
        icon: Icons.play_circle_fill_rounded,
        colors: const [Color(0xFFE53E6B), Color(0xFFFF6B9A)],
        onTap: (c) => _open(c, const UserVideosScreen()),
      ),
    ];
    final help = [
      _Service(
        title: tr('فریاکەوتن'),
        subtitle: tr('ژمارە گرنگەکانی کەلار'),
        icon: Icons.emergency_rounded,
        colors: const [Color(0xFFDC3545), Color(0xFFFF6B6B)],
        onTap: (c) => _open(c, const EmergencyScreen()),
      ),
      _Service(
        title: tr('ناردنی سکاڵا'),
        subtitle: tr('سکاڵا بۆ شارەوانی بنێرە'),
        icon: Icons.campaign_rounded,
        colors: const [Color(0xFF4F5BD5), Color(0xFF7986F2)],
        onTap: (c) => ComplaintInstructionDialog.show(c),
      ),
      _Service(
        title: tr('پێشنیاری شوێن'),
        subtitle: tr('شوێنێکی نوێمان پێ بناسێنە'),
        icon: Icons.add_location_alt_rounded,
        colors: const [Color(0xFF00897B), Color(0xFF26B5A6)],
        onTap: (c) => _open(c, const SuggestPlaceScreen()),
      ),
    ];

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: isDark ? const Color(0xFF1A1A22) : Colors.white,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          leading: onMenuTap != null
              ? IconButton(
                  icon: Icon(Icons.menu_rounded, color: fg),
                  onPressed: onMenuTap,
                  tooltip: tr('مێنیو'),
                )
              : null,
          title: Text(
            tr('خزمەتگوزارییەکان'),
            style:
                TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: fg),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
          children: [
            _header(tr('شار و شوێن'), Icons.explore_rounded,
                const Color(0xFF1E88E5), isDark),
            _grid(city),
            _header(tr('وێنە و ڤیدیۆ'), Icons.perm_media_rounded,
                const Color(0xFFD9822B), isDark),
            _grid(content),
            _header(tr('هاوکاری و پەیوەندی'), Icons.support_agent_rounded,
                const Color(0xFFDC3545), isDark),
            _grid(help),
          ],
        ),
      ),
    );
  }

  Widget _header(String title, IconData icon, Color color, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 10),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.72)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(11),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Text(
            title,
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

  Widget _grid(List<_Service> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.42,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _ServiceCard(service: items[i]),
    );
  }
}

class _Service {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> colors;
  final void Function(BuildContext) onTap;

  const _Service({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.colors,
    required this.onTap,
  });
}

class _ServiceCard extends StatelessWidget {
  final _Service service;

  const _ServiceCard({required this.service});

  @override
  Widget build(BuildContext context) {
    final s = service;
    return Semantics(
      button: true,
      label: s.title,
      child: Material(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: s.colors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: InkWell(
            onTap: () => s.onTap(context),
            splashColor: Colors.white24,
            child: Stack(
              children: [
                // ئایکۆنی گەورەی کاڵ لە پشتەوە
                PositionedDirectional(
                  bottom: -16,
                  start: -12,
                  child: Icon(
                    s.icon,
                    size: 86,
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Icon(s.icon, color: Colors.white, size: 22),
                      ),
                      const Spacer(),
                      Text(
                        s.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
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
