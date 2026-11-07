import 'dart:async';

import 'package:flutter/material.dart';
import '../../services/adhan_service.dart';

/// 🎵 شاشەی ڕێکخستنی دەنگی ئەدان (Pro Ultra Max)
///
/// تەنها ئەم API-انەی AdhanService بەکاردێنێت:
///  - getSoundForPrayer(String)
///  - setSoundForPrayer({prayerName, soundName})
///  - testSound(String)
///  - availableSounds (Map<String, String>)

// ───────────────────────── Theme constants ─────────────────────────
class _C {
  static const bg = Color(0xFF0F1421);
  static const appBar = Color(0xFF1A1B2E);
  static const card = Color(0xFF1A2030);
  static const gold = Color(0xFFFFD700);
  static const goldDark = Color(0xFFFFB300);
  static const success = Color(0xFF10B981);
  static const danger = Color(0xFFEF4444);

  static const defaultSound = 'adhan_default';
}

class _PrayerInfo {
  final String name;
  final IconData icon;
  const _PrayerInfo(this.name, this.icon);
}

const List<_PrayerInfo> _prayerInfos = [
  _PrayerInfo('بەیانی', Icons.wb_twilight_rounded),
  _PrayerInfo('نیوەڕۆ', Icons.wb_sunny_rounded),
  _PrayerInfo('عەسر', Icons.wb_cloudy_rounded),
  _PrayerInfo('مەغریب', Icons.nights_stay_rounded),
  _PrayerInfo('عیشا', Icons.dark_mode_rounded),
];

class AdhanSettingsScreen extends StatefulWidget {
  const AdhanSettingsScreen({super.key});

  @override
  State<AdhanSettingsScreen> createState() => _AdhanSettingsScreenState();
}

class _AdhanSettingsScreenState extends State<AdhanSettingsScreen> {
  final Map<String, String> _currentSounds = {};
  final Set<String> _saving = {};

  bool _loading = true;
  bool _bulkBusy = false;
  bool _loadFailed = false;

  /// ناوی ئەو نوێژەی ئێستا پیشاندانی دەنگەکەی دەکرێت
  String? _previewingPrayer;
  Timer? _previewTimer;

  @override
  void initState() {
    super.initState();
    _loadSounds();
  }

  @override
  void dispose() {
    _previewTimer?.cancel();
    super.dispose();
  }

  // ───────────────────────── Data ─────────────────────────

  Future<void> _loadSounds() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _loadFailed = false;
      });
    }
    try {
      final results = await Future.wait(
        _prayerInfos.map((p) => AdhanService.getSoundForPrayer(p.name)),
      );
      for (var i = 0; i < _prayerInfos.length; i++) {
        _currentSounds[_prayerInfos[i].name] = results[i];
      }
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadFailed = true;
      });
    }
  }

  Future<void> _changeSound(String prayer, String sound) async {
    final previous = _currentSounds[prayer] ?? _C.defaultSound;
    if (previous == sound) return;

    setState(() {
      _currentSounds[prayer] = sound;
      _saving.add(prayer);
    });

    try {
      await AdhanService.setSoundForPrayer(
        prayerName: prayer,
        soundName: sound,
      );
      if (!mounted) return;
      setState(() => _saving.remove(prayer));
      _toast('✅ دەنگی $prayer پاشەکەوت کرا');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentSounds[prayer] = previous; // گەڕاندنەوە
        _saving.remove(prayer);
      });
      _toast('❌ نەتوانرا پاشەکەوت بکرێت', error: true);
    }
  }

  Future<void> _applyToAll(String sound) async {
    setState(() => _bulkBusy = true);
    try {
      for (final p in _prayerInfos) {
        await AdhanService.setSoundForPrayer(
          prayerName: p.name,
          soundName: sound,
        );
        _currentSounds[p.name] = sound;
      }
      if (!mounted) return;
      setState(() => _bulkBusy = false);
      _toast('✅ دەنگەکە بۆ هەموو نوێژەکان جێبەجێ کرا');
    } catch (_) {
      await _loadSounds(); // دڵنیابوونەوە لە دۆخی ڕاستەقینە
      if (!mounted) return;
      setState(() => _bulkBusy = false);
      _toast('❌ هەندێک گۆڕانکاری پاشەکەوت نەکران', error: true);
    }
  }

  Future<void> _resetAll() async {
    final ok = await _confirm(
      title: 'گەڕاندنەوە بۆ بنەڕەت',
      message: 'دەنگی هەموو نوێژەکان دەگەڕێتەوە بۆ دەنگی بنەڕەتی. دڵنیایت؟',
    );
    if (ok != true || !mounted) return;
    await _applyToAll(_C.defaultSound);
  }

  // ───────────────────────── Preview ─────────────────────────

  Future<void> _preview(String prayer, String sound) async {
    // دووبارە کرتەکردن لەکاتی پیشاندان: پشتگوێ بخە
    if (_previewingPrayer == prayer) return;

    _previewTimer?.cancel();
    setState(() => _previewingPrayer = prayer);

    // ئەگەر testSound کۆتایی نەهات، دوای ٨ چرکە دووگمەکە ئازاد دەکەین
    _previewTimer = Timer(const Duration(seconds: 8), _clearPreview);

    try {
      await Future<void>.sync(() => AdhanService.testSound(sound));
    } catch (_) {
      if (mounted) _toast('❌ نەتوانرا دەنگەکە لێبدرێت', error: true);
      _clearPreview();
    }
  }

  void _clearPreview() {
    _previewTimer?.cancel();
    if (mounted && _previewingPrayer != null) {
      setState(() => _previewingPrayer = null);
    }
  }

  // ───────────────────────── Dialogs / helpers ─────────────────────────

  void _toast(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Directionality(
            textDirection: TextDirection.rtl,
            child: Text(text),
          ),
          backgroundColor: error ? _C.danger : _C.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
  }

  Future<bool?> _confirm({required String title, required String message}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: _C.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: _C.gold.withValues(alpha: 0.3)),
          ),
          title: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          content: Text(
            message,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'نەخێر',
                style: TextStyle(color: Colors.white60),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'بەڵێ',
                style:
                TextStyle(color: _C.gold, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickSoundForAll() async {
    final sounds = AdhanService.availableSounds;
    final picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: _C.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'دەنگێک هەڵبژێرە بۆ هەموو نوێژەکان',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: sounds.entries.map((e) {
                    return ListTile(
                      leading: const Icon(Icons.music_note_rounded,
                          color: _C.gold),
                      title: Text(
                        e.value,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () => Navigator.pop(ctx, e.key),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (picked != null && mounted) await _applyToAll(picked);
  }

  // ───────────────────────── UI ─────────────────────────

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _C.bg,
        appBar: AppBar(
          backgroundColor: _C.appBar,
          foregroundColor: Colors.white,
          title: const Text(
            '🎵 دەنگی ئەدان',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(color: _C.gold),
      );
    }

    if (_loadFailed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: _C.danger, size: 48),
              const SizedBox(height: 12),
              const Text(
                'نەتوانرا دەنگەکان بخوێندرێنەوە',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadSounds,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _C.gold,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('دووبارە هەوڵبدەوە'),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: _C.gold,
      backgroundColor: _C.card,
      onRefresh: _loadSounds,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          _buildInfoCard(),
          const SizedBox(height: 20),
          ..._prayerInfos.map(_buildPrayerSoundCard),
          const SizedBox(height: 8),
          _buildActions(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _C.gold.withValues(alpha: 0.15),
            _C.goldDark.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.gold.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _C.gold.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.music_note_rounded,
              color: _C.gold,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'دەنگی جیاواز بۆ هەر نوێژێک',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'دەتوانیت بۆ هەر نوێژێک دەنگی جیاواز هەڵبژێریت',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerSoundCard(_PrayerInfo info) {
    final prayer = info.name;
    final sounds = AdhanService.availableSounds;
    var currentSound = _currentSounds[prayer] ?? _C.defaultSound;

    // ئەگەر دەنگی پاشەکەوتکراو لە لیستدا نەمابوو، Dropdown نەشکێت
    if (!sounds.containsKey(currentSound)) {
      currentSound = sounds.containsKey(_C.defaultSound)
          ? _C.defaultSound
          : (sounds.keys.isNotEmpty ? sounds.keys.first : currentSound);
    }

    final isSaving = _saving.contains(prayer);
    final isPreviewing = _previewingPrayer == prayer;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _C.gold.withValues(alpha: isPreviewing ? 0.7 : 0.2),
          width: isPreviewing ? 1.5 : 1,
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
                  color: _C.gold.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(info.icon, color: _C.gold, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                prayer,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(width: 8),
              if (isSaving)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _C.gold,
                  ),
                ),
              const Spacer(),
              IconButton(
                tooltip: 'تاقیکردنەوەی دەنگ',
                icon: isPreviewing
                    ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: _C.gold,
                  ),
                )
                    : const Icon(
                  Icons.play_circle_filled_rounded,
                  color: _C.gold,
                  size: 28,
                ),
                onPressed:
                isPreviewing ? null : () => _preview(prayer, currentSound),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: sounds.containsKey(currentSound) ? currentSound : null,
                isExpanded: true,
                dropdownColor: _C.card,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: _C.gold,
                ),
                items: sounds.entries
                    .map(
                      (e) => DropdownMenuItem<String>(
                    value: e.key,
                    child: Text(
                      e.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                )
                    .toList(),
                onChanged: (_bulkBusy || isSaving)
                    ? null
                    : (value) {
                  if (value != null) _changeSound(prayer, value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      children: [
        // ⭐ هەمان دەنگ بۆ هەموو نوێژەکان
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _bulkBusy ? null : _pickSoundForAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.gold,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            icon: const Icon(Icons.library_music_rounded, size: 20),
            label: const Text(
              'هەمان دەنگ بۆ هەموو نوێژەکان',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // ⭐ گەڕاندنەوە بۆ بنەڕەت
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _bulkBusy ? null : _resetAll,
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.gold.withValues(alpha: 0.1),
              foregroundColor: _C.gold,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: _C.gold.withValues(alpha: 0.4)),
              ),
            ),
            icon: _bulkBusy
                ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _C.gold,
              ),
            )
                : const Icon(Icons.restore_rounded, size: 20),
            label: const Text(
              'گەڕاندنەوە بۆ دەنگی بنەڕەتی',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}