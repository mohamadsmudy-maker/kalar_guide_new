import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_colors.dart';
import '../../l10n/tr.dart';
import '../complaints/complaint_instruction_dialog.dart';
import '../departments/departments_screen.dart';
import '../emergency/emergency_main_screen.dart';
import '../events/events_screen.dart';
import '../gallery/gallery_screen.dart';
import '../map_screen.dart';
import '../neighborhoods/neighborhoods_screen.dart';
import '../stores/suggest_place_screen.dart';
import '../videos/user_videos.dart';

/// 🧰 ناوەندی خزمەتگوزارییەکان — هەموو بەشەکان لە یەک شوێن.
/// دیزاینی ئارام: هەر بەش لە یەک کارتدایە، ئایکۆنەکان بە یەک ڕەنگی سەرەکین
/// (تەنها فریاکەوتن سوورە چونکە مانای تایبەتی هەیە).
/// ڕەنگی هێمن بەپێی بەش (ئایکۆنەکان تەنها ڕەنگ دەگرن، نەک خشتی گەورە)
const Color _kCity = AppColors.primary; // شین
const Color _kMedia = Color(0xFFD9822B); // پرتەقاڵی
const Color _kHelp = Color(0xFF0F9D7A); // سەوز

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

    final sections = <_Section>[
      _Section(tr('شار و شوێن'), [
        _Service(
          title: tr('نەخشە'),
          subtitle: tr('گەڕەک و شوێنەکان لەسەر نەخشە'),
          icon: Icons.map_rounded,
          color: _kCity,
          onTap: (c) => _open(c, const MapScreen()),
        ),
        _Service(
          title: tr('گەڕەکان'),
          subtitle: tr('زانیاری گەڕەکەکانی کەلار'),
          icon: Icons.location_city_rounded,
          color: _kCity,
          onTap: (c) => _open(c, const NeighborhoodsScreen()),
        ),
        _Service(
          title: tr('فەرمانگە و مامەڵەکان'),
          subtitle: tr('پێداویستی و تێچووی مامەڵەکان'),
          icon: Icons.account_balance_rounded,
          color: _kCity,
          onTap: (c) => _open(c, const DepartmentsScreen()),
        ),
        _Service(
          title: tr('ڕووداو و بۆنەکان'),
          subtitle: tr('چالاکییەکانی شارەکەمان'),
          icon: Icons.event_rounded,
          color: _kCity,
          onTap: (c) => _open(c, const EventsScreen()),
        ),
      ]),
      _Section(tr('وێنە و ڤیدیۆ'), [
        _Service(
          title: tr('گەلەری'),
          subtitle: tr('جوانترین وێنەکانی شار'),
          icon: Icons.photo_library_rounded,
          color: _kMedia,
          onTap: (c) => _open(c, const GalleryScreen()),
        ),
        _Service(
          title: tr('ڤیدیۆکان'),
          subtitle: tr('ڤیدیۆ و ڕێنماییەکان'),
          icon: Icons.play_circle_rounded,
          color: _kMedia,
          onTap: (c) => _open(c, const UserVideosScreen()),
        ),
      ]),
      _Section(tr('هاوکاری و پەیوەندی'), [
        _Service(
          title: tr('فریاکەوتن'),
          subtitle: tr('ژمارە گرنگەکانی کەلار'),
          icon: Icons.emergency_rounded,
          color: AppColors.red,
          onTap: (c) => _open(c, const EmergencyScreen()),
        ),
        _Service(
          title: tr('ناردنی سکاڵا'),
          subtitle: tr('سکاڵا بۆ شارەوانی بنێرە'),
          icon: Icons.campaign_rounded,
          color: _kHelp,
          onTap: (c) => ComplaintInstructionDialog.show(c),
        ),
        _Service(
          title: tr('پێشنیاری شوێن'),
          subtitle: tr('شوێنێکی نوێمان پێ بناسێنە'),
          icon: Icons.add_location_alt_rounded,
          color: _kHelp,
          onTap: (c) => _open(c, const SuggestPlaceScreen()),
        ),
      ]),
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
          padding: EdgeInsets.fromLTRB(
              16, 8, 16, 110 + MediaQuery.paddingOf(context).bottom),
          children: [
            for (final s in sections) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 16, 6, 8),
                child: Text(
                  s.title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white60 : const Color(0xFF6B7280),
                  ),
                ),
              ),
              _SectionCard(items: s.items, isDark: isDark),
            ],
          ],
        ),
      ),
    );
  }
}

class _Section {
  final String title;
  final List<_Service> items;
  const _Section(this.title, this.items);
}

class _Service {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final void Function(BuildContext) onTap;

  const _Service({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.color = AppColors.primary,
  });
}

/// کارتێکی سپی کە چەند ڕیزێکی تێدایە، بە هێڵی جیاکەرەوە
class _SectionCard extends StatelessWidget {
  final List<_Service> items;
  final bool isDark;

  const _SectionCard({required this.items, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final card = isDark ? AppColors.darkCard : Colors.white;
    return Container(
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  thickness: 1,
                  indent: 70,
                  endIndent: 16,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.07)
                      : const Color(0xFFEEF0F4),
                ),
              _ServiceRow(service: items[i], isDark: isDark),
            ],
          ],
        ),
      ),
    );
  }
}

class _ServiceRow extends StatelessWidget {
  final _Service service;
  final bool isDark;

  const _ServiceRow({required this.service, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final s = service;
    return Semantics(
      button: true,
      label: s.title,
      child: InkWell(
        onTap: () => s.onTap(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: s.color.withValues(alpha: isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(s.icon, color: s.color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      s.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w500,
                        color:
                            isDark ? Colors.white54 : const Color(0xFF8A90A0),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                AppLang.isRtl
                    ? Icons.chevron_left_rounded
                    : Icons.chevron_right_rounded,
                color: isDark ? Colors.white30 : const Color(0xFFB4B9C6),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
