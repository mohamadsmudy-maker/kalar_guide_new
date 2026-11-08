import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../services/prayer/kalar_prayer_times.dart';
import '../../services/prayer/prayer_reminders.dart';
import 'adhan_settings_screen.dart';
import 'notification_test_screen.dart';
import '../../l10n/tr.dart';

/// ⚙️ ڕێکخستنی کاتەکانی نوێژ
///
/// تەنها ئەو ڕێکخستنانەی کە بەڕاستی کار دەکەن لێرەن.
class PrayerSettingsScreen extends StatefulWidget {
  const PrayerSettingsScreen({super.key});

  @override
  State<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends State<PrayerSettingsScreen> {
  static const _gold = Color(0xFFFFD700);
  static const _minuteChoices = [10, 15, 20, 30, 45, 60];

  bool _loaded = false;
  bool _notifications = true;
  bool _friday = true;
  int _fridayMinutes = 30;
  bool _ramadan = true;
  int _ramadanMinutes = 30;
  bool _kurdishDigits = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final s = await PrayerReminderSettings.load();
    if (!mounted) return;
    setState(() {
      _notifications = p.getBool('prayer_notif') ?? true;
      _friday = s.friday;
      _fridayMinutes = s.fridayMinutes;
      _ramadan = s.ramadan;
      _ramadanMinutes = s.ramadanMinutes;
      _kurdishDigits = s.kurdishDigits;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool('prayer_notif', _notifications);
    await p.setBool(PrayerReminderSettings.kFriday, _friday);
    await p.setInt(PrayerReminderSettings.kFridayMinutes, _fridayMinutes);
    await p.setBool(PrayerReminderSettings.kRamadan, _ramadan);
    await p.setInt(PrayerReminderSettings.kRamadanMinutes, _ramadanMinutes);
    await p.setBool(PrayerReminderSettings.kKurdishDigits, _kurdishDigits);
  }

  void _set(VoidCallback change) {
    HapticFeedback.selectionClick();
    setState(change);
    _save();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1421),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1B2E),
          foregroundColor: Colors.white,
          title: Text(tr('ڕێکخستنی نوێژ'), style: const TextStyle(fontWeight: FontWeight.w900)),
        ),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator(color: _gold))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _section(tr('🔔 ئاگادارکردنەوە')),
                  _switchTile(
                    icon: Icons.notifications_active_rounded,
                    title: tr('ئاگادارکردنەوەی بانگ'),
                    subtitle: tr('لە کاتی هەر بانگێکدا'),
                    value: _notifications,
                    onChanged: (v) => _set(() => _notifications = v),
                  ),
                  _actionTile(
                    icon: Icons.music_note_rounded,
                    title: tr('دەنگی بانگ'),
                    subtitle: tr('دەنگی جیاواز بۆ هەر نوێژێک'),
                    onTap: () => _push(const AdhanSettingsScreen()),
                  ),
                  const SizedBox(height: 16),
                  _section(tr('🕌 نوێژی هەینی')),
                  _switchTile(
                    icon: Icons.mosque_rounded,
                    title: tr('بیرخستنەوەی هەینی'),
                    subtitle: tr('پێش بانگی نیوەڕۆی هەینی'),
                    value: _friday,
                    onChanged: (v) => _set(() => _friday = v),
                  ),
                  if (_friday)
                    _minutesTile(_fridayMinutes, (v) => _set(() => _fridayMinutes = v)),
                  const SizedBox(height: 16),
                  _section(tr('🌙 ڕەمەزان')),
                  _switchTile(
                    icon: Icons.nights_stay_rounded,
                    title: tr('بیرخستنەوەی پارشێو و بەربانگ'),
                    subtitle: tr('تەنها لە مانگی ڕەمەزاندا'),
                    value: _ramadan,
                    onChanged: (v) => _set(() => _ramadan = v),
                  ),
                  if (_ramadan)
                    _minutesTile(_ramadanMinutes, (v) => _set(() => _ramadanMinutes = v)),
                  const SizedBox(height: 16),
                  _section(tr('🔢 پیشاندان')),
                  _switchTile(
                    icon: Icons.translate_rounded,
                    title: tr('ژمارەی کوردی'),
                    subtitle: KalarPrayerTimes.format12('17:04', kurdishDigits: _kurdishDigits),
                    value: _kurdishDigits,
                    onChanged: (v) => _set(() => _kurdishDigits = v),
                  ),
                  const SizedBox(height: 16),
                  _section(tr('🧪 تاقیکردنەوە')),
                  _actionTile(
                    icon: Icons.bug_report_rounded,
                    title: tr('تاقیکردنەوەی ئاگادارکردنەوە'),
                    subtitle: tr('بزانە ئاگادارکردنەوەکان دەگەن'),
                    onTap: () => _push(const NotificationTestScreen()),
                  ),
                ],
              ),
      ),
    );
  }

  void _push(Widget screen) =>
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(
          tr(title),
          style: const TextStyle(color: _gold, fontSize: 14, fontWeight: FontWeight.w900),
        ),
      );

  Widget _card({required Widget child, Color? border}) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2030),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border ?? Colors.white.withValues(alpha: 0.05)),
        ),
        child: child,
      );

  Widget _leading(IconData icon) => Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: _gold.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: _gold, size: 18),
      );

  Widget _texts(String title, String subtitle) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr(title),
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(tr(subtitle), style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ],
        ),
      );

  Widget _switchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      _card(
        child: Row(
          children: [
            _leading(icon),
            const SizedBox(width: 12),
            _texts(title, subtitle),
            Switch(value: value, onChanged: onChanged, activeThumbColor: _gold),
          ],
        ),
      );

  Widget _actionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) =>
      InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: _card(
          border: _gold.withValues(alpha: 0.2),
          child: Row(
            children: [
              _leading(icon),
              const SizedBox(width: 12),
              _texts(title, subtitle),
              const Icon(Icons.arrow_back_ios_rounded, color: _gold, size: 14),
            ],
          ),
        ),
      );

  Widget _minutesTile(int value, ValueChanged<int> onChanged) => _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tr('چەند خولەک پێشتر؟'),
                style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Wrap(
              runSpacing: 6,
              spacing: 6,
              children: [
                for (final m in _minuteChoices)
                  ChoiceChip(
                    label: Text('$m'),
                    selected: value == m,
                    onSelected: (_) => onChanged(m),
                    selectedColor: _gold,
                    backgroundColor: Colors.white.withValues(alpha: 0.06),
                    labelStyle: TextStyle(
                      color: value == m ? Colors.black : Colors.white70,
                      fontWeight: FontWeight.w900,
                      fontSize: 11,
                    ),
                    visualDensity: VisualDensity.compact,
                    showCheckmark: false,
                  ),
              ],
            ),
          ],
        ),
      );
}
