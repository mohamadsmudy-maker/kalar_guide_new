import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/tr.dart';
import '../services/app_control.dart';

/// 📢 ڕاگەیاندنی ئەدمین لە سەرەوەی لاپەڕەی سەرەکی. بەکارهێنەر دەتوانێت دایبخات؛
/// هەر کاتێک ئەدمین دەقەکە بگۆڕێت، دووبارە دەردەکەوێتەوە.
class AnnouncementBanner extends StatefulWidget {
  const AnnouncementBanner({super.key});

  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  static const _prefKey = 'announcement_dismissed_id';
  String _dismissed = '';

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (mounted) setState(() => _dismissed = p.getString(_prefKey) ?? '');
    });
  }

  Future<void> _dismiss(String id) async {
    setState(() => _dismissed = id);
    final p = await SharedPreferences.getInstance();
    await p.setString(_prefKey, id);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppControlState>(
      valueListenable: AppControl.state,
      builder: (context, s, _) {
        if (!s.hasAnnouncement || s.announcementId == _dismissed) {
          return const SizedBox.shrink();
        }
        final (color, icon) = switch (s.announcementLevel) {
          AnnounceLevel.warning => (const Color(0xFFD9822B), Icons.warning_amber_rounded),
          AnnounceLevel.success => (const Color(0xFF0F9D7A), Icons.check_circle_rounded),
          AnnounceLevel.info => (const Color(0xFF1E88E5), Icons.campaign_rounded),
        };
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 6, 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.45)),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.announcementText,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : const Color(0xFF1A1A2E),
                  ),
                ),
              ),
              IconButton(
                tooltip: tr('داخستن'),
                icon: Icon(Icons.close_rounded, size: 18, color: color),
                onPressed: () => _dismiss(s.announcementId),
              ),
            ],
          ),
        );
      },
    );
  }
}
