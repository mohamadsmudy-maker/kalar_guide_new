import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../services/prayer_notification_service.dart';
import 'adhan_settings_screen.dart';
import 'notification_test_screen.dart';

/// ⚙️ شاشەی ڕێکخستنی کاتەکانی نوێژ — ULTRA PRO
class PrayerSettingsScreen extends StatefulWidget {
  const PrayerSettingsScreen({super.key});

  @override
  State<PrayerSettingsScreen> createState() => _PrayerSettingsScreenState();
}

class _PrayerSettingsScreenState extends State<PrayerSettingsScreen> {
  // ⭐ Settings
  bool _is24Hour = true;
  bool _adhanEnabled = true;
  bool _notificationsEnabled = true;
  bool _vibrationEnabled = true;
  bool _fajrAlertEnabled = true;
  bool _preAlertEnabled = true;
  int _preAlertMinutes = 10;
  String _calculationMethod = '3';
  String _asrMethod = '0';
  bool _showHijri = true;
  bool _showSunrise = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _is24Hour = prefs.getBool('prayer_24h') ?? true;
      _adhanEnabled = prefs.getBool('adhan_enabled') ?? true;
      _notificationsEnabled = prefs.getBool('prayer_notif') ?? true;
      _vibrationEnabled = prefs.getBool('prayer_vibrate') ?? true;
      _fajrAlertEnabled = prefs.getBool('fajr_alert') ?? true;
      _preAlertEnabled = prefs.getBool('pre_alert') ?? true;
      _preAlertMinutes = prefs.getInt('pre_alert_minutes') ?? 10;
      _calculationMethod = prefs.getString('calc_method') ?? '3';
      _asrMethod = prefs.getString('asr_method') ?? '0';
      _showHijri = prefs.getBool('show_hijri') ?? true;
      _showSunrise = prefs.getBool('show_sunrise') ?? true;
    });
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('prayer_24h', _is24Hour);
    await prefs.setBool('adhan_enabled', _adhanEnabled);
    await prefs.setBool('prayer_notif', _notificationsEnabled);
    await prefs.setBool('prayer_vibrate', _vibrationEnabled);
    await prefs.setBool('fajr_alert', _fajrAlertEnabled);
    await prefs.setBool('pre_alert', _preAlertEnabled);
    await prefs.setInt('pre_alert_minutes', _preAlertMinutes);
    await prefs.setString('calc_method', _calculationMethod);
    await prefs.setString('asr_method', _asrMethod);
    await prefs.setBool('show_hijri', _showHijri);
    await prefs.setBool('show_sunrise', _showSunrise);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1421),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1B2E),
          foregroundColor: Colors.white,
          title: const Text(
            '⚙️ ڕێکخستنی نوێژ',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ═══ Section: گشتی ═══
            _buildSection('🌐 گشتی'),
            _buildSwitchTile(
              icon: Icons.access_time_rounded,
              title: 'کاتی 24 سەعات',
              subtitle: 'پیشاندانی کات بە شێوەی 24h',
              value: _is24Hour,
              onChanged: (v) {
                setState(() => _is24Hour = v);
                _saveSettings();
              },
            ),
            _buildSwitchTile(
              icon: Icons.calendar_today_rounded,
              title: 'پیشاندانی هیجری',
              subtitle: 'بەرواری هیجری پیشان بدە',
              value: _showHijri,
              onChanged: (v) {
                setState(() => _showHijri = v);
                _saveSettings();
              },
            ),
            _buildSwitchTile(
              icon: Icons.wb_twilight_rounded,
              title: 'پیشاندانی خۆرهەڵات',
              subtitle: 'کاتی خۆرهەڵات پیشان بدە',
              value: _showSunrise,
              onChanged: (v) {
                setState(() => _showSunrise = v);
                _saveSettings();
              },
            ),

            const SizedBox(height: 20),

            // ═══ Section: Adhan ═══
            _buildSection('🎵 ئەدان'),
            _buildSwitchTile(
              icon: Icons.volume_up_rounded,
              title: 'دەنگی ئەدان',
              subtitle: 'کاتێک نوێژ دەهات، ئەدان بژەنە',
              value: _adhanEnabled,
              onChanged: (v) {
                setState(() => _adhanEnabled = v);
                _saveSettings();
              },
            ),
            _buildActionTile(
              icon: Icons.music_note_rounded,
              title: 'ڕێکخستنی دەنگی ئەدان',
              subtitle: 'دەنگی جیاواز بۆ هەر نوێژێک',
              color: const Color(0xFFFFD700),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AdhanSettingsScreen(),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ═══ Section: Notifications ═══
            _buildSection('🔔 ئاگادارکردنەوە'),
            _buildSwitchTile(
              icon: Icons.notifications_active_rounded,
              title: 'ئاگادارکردنەوە',
              subtitle: 'ئاگادارکردنەوە بۆ هەر نوێژێک',
              value: _notificationsEnabled,
              onChanged: (v) {
                setState(() => _notificationsEnabled = v);
                _saveSettings();
              },
            ),
            _buildSwitchTile(
              icon: Icons.vibration_rounded,
              title: 'لەرینەوە',
              subtitle: 'لەگەڵ Notification لەرینەوە',
              value: _vibrationEnabled,
              onChanged: (v) {
                setState(() => _vibrationEnabled = v);
                _saveSettings();
              },
            ),
            _buildSwitchTile(
              icon: Icons.nights_stay_rounded,
              title: 'ئاگاداری بەیانی',
              subtitle: 'ئاگاداری تایبەت بۆ بەیانی',
              value: _fajrAlertEnabled,
              onChanged: (v) {
                setState(() => _fajrAlertEnabled = v);
                _saveSettings();
              },
            ),
            _buildSwitchTile(
              icon: Icons.schedule_rounded,
              title: 'ئاگاداری پێش نوێژ',
              subtitle: 'ئاگاداری پێش نوێژ',
              value: _preAlertEnabled,
              onChanged: (v) {
                setState(() => _preAlertEnabled = v);
                _saveSettings();
              },
            ),
            if (_preAlertEnabled)
              _buildSliderTile(
                icon: Icons.timer_rounded,
                title: 'کاتی پێش ئاگاداری',
                value: _preAlertMinutes,
                min: 5,
                max: 30,
                onChanged: (v) {
                  setState(() => _preAlertMinutes = v.round());
                  _saveSettings();
                },
              ),
            _buildActionTile(
              icon: Icons.science_rounded,
              title: 'تاقیکردنەوەی Notifications',
              subtitle: 'تاقی بکەرەوە ئایا کار دەکەن',
              color: const Color(0xFF10B981),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const NotificationTestScreen(),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // ═══ Section: Calculation ═══
            _buildSection('🧮 شێوازی حسابکردن'),
            _buildDropdownTile(
              icon: Icons.public_rounded,
              title: 'شێوازی حسابکردن',
              value: _calculationMethod,
              items: {
                '2': 'ISNA (ئەمریکا)',
                '3': 'Muslim World League',
                '4': 'Umm Al-Qura (مەککە)',
                '5': 'Egyptian General Authority',
                '1': 'University of Islamic Sciences',
              },
              onChanged: (v) {
                setState(() => _calculationMethod = v);
                _saveSettings();
              },
            ),
            _buildDropdownTile(
              icon: Icons.access_time_rounded,
              title: 'شێوازی عەسر',
              value: _asrMethod,
              items: {
                '0': 'Shafi\'i (ستاندارد)',
                '1': 'Hanafi (حەنەفی)',
              },
              onChanged: (v) {
                setState(() => _asrMethod = v);
                _saveSettings();
              },
            ),

            const SizedBox(height: 20),

            // ═══ Reset Button ═══
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _showResetDialog(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withValues(alpha: 0.1),
                  foregroundColor: Colors.red,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: Colors.red.withValues(alpha: 0.4),
                    ),
                  ),
                ),
                icon: const Icon(Icons.restore_rounded),
                label: const Text(
                  'گەڕاندنەوە بۆ دۆخی سەرەتا',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFFFFD700),
          fontSize: 14,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2030),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFFFFD700), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: const Color(0xFFFFD700),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1A2030),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: color.withValues(alpha: 0.2),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_back_ios_rounded,
                color: color,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSliderTile({
    required IconData icon,
    required String title,
    required int value,
    required double min,
    required double max,
    required Function(double) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2030),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFFFFD700), size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$value خولەک',
                  style: const TextStyle(
                    color: Color(0xFFFFD700),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value.toDouble(),
            min: min,
            max: max,
            divisions: (max - min).toInt(),
            activeColor: const Color(0xFFFFD700),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownTile({
    required IconData icon,
    required String title,
    required String value,
    required Map<String, String> items,
    required Function(String) onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2030),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: const Color(0xFFFFD700), size: 18),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1421),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: const Color(0xFF1A2030),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFFFFD700),
                ),
                items: items.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showResetDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1A2030),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'گەڕاندنەوە بۆ دۆخی سەرەتا',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          content: const Text(
            'ئایا دڵنیایت؟ هەموو ڕێکخستنەکان دەگەڕێنەوە بۆ دۆخی سەرەتا.',
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text(
                'پاشگەزبوونەوە',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                await PrayerNotificationService.cancelAll();

                if (!mounted) return;
                Navigator.pop(ctx);
                _loadSettings();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ ڕێکخستنەکان گەڕێنرانەوە'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              },
              child: const Text(
                'بەڵێ',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }
}