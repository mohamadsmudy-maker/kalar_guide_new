// lib/screens/admin/admin_prayer_times.dart
import 'package:flutter/material.dart';

import '../../services/prayer/kalar_prayer_times.dart';
import '../../services/prayer/prayer_times_repository.dart';
import '../../l10n/tr.dart';

/// 🕌 ئەدمین: دەستکاریکردنی کاتە فەرمییەکانی نوێژ
///
/// هەر ڕۆژێک کە لێرە پاشەکەوت بکرێت، بۆ هەموو بەکارهێنەران و هەموو
/// ساڵەکان پیشان دەدرێت (پێویستی بە نوێکردنەوەی ئەپ نییە).
class AdminPrayerTimesScreen extends StatefulWidget {
  const AdminPrayerTimesScreen({super.key});

  @override
  State<AdminPrayerTimesScreen> createState() => _AdminPrayerTimesScreenState();
}

class _AdminPrayerTimesScreenState extends State<AdminPrayerTimesScreen> {
  static const _gold = Color(0xFFFFD700);
  static const _months = [
    'کانوونی دووەم',
    'شوبات',
    'ئازار',
    'نیسان',
    'ئایار',
    'حوزەیران',
    'تەممووز',
    'ئاب',
    'ئەیلوول',
    'تشرینی یەکەم',
    'تشرینی دووەم',
    'کانوونی یەکەم',
  ];
  static const _names = {
    'fajr': 'بەیانی',
    'sunrise': 'خۆرهەڵاتن',
    'dhuhr': 'نیوەڕۆ',
    'asr': 'عەسر',
    'maghrib': 'ئێوارە',
    'isha': 'خەوتنان',
  };

  int _month = DateTime.now().month;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    await PrayerTimesRepository.loadCache();
    await PrayerTimesRepository.refresh();
    if (mounted) setState(() => _loading = false);
  }

  /// ساڵێکی کەبیسە بۆ ئەوەی ٢٩ی شوباتیش هەبێت
  int get _year => 2028;

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tr(text)),
      backgroundColor: error ? Colors.red.shade700 : Colors.green.shade700,
    ));
  }

  Future<void> _save(Map<String, Map<String, String>> days) async {
    setState(() => _saving = true);
    try {
      await PrayerTimesRepository.upsert(days);
      _snack(trf('{0} ڕۆژ پاشەکەوت کرا ✅', [days.length]));
    } catch (e) {
      debugPrint('❌ save prayer times: $e');
      _snack(tr('پاشەکەوت نەکرا. دڵنیابە کە وەک ئەدمین چوویتەتە ژوورەوە.'),
          error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(String key) async {
    setState(() => _saving = true);
    try {
      await PrayerTimesRepository.delete(key);
      _snack(tr('گەڕایەوە بۆ کاتی ناو ئەپ'));
    } catch (e) {
      _snack(tr('سڕینەوە سەرکەوتوو نەبوو'), error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // ✏️ دەستکاریکردنی یەک ڕۆژ
  // ═══════════════════════════════════════════════════════════
  Future<void> _editDay(DateTime date) async {
    final key = KalarPrayerTimes.dayKey(date);
    final current = KalarPrayerTimes.forDay(date);
    final ctrls = {
      for (final id in KalarPrayerTimes.ids)
        id: TextEditingController(text: current.times[id]),
    };
    String? error;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => Directionality(
          textDirection: AppLang.direction,
          child: AlertDialog(
            backgroundColor: const Color(0xFF1A2030),
            title: Text('${date.day} ${tr(_months[date.month - 1])}',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w900)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final id in KalarPrayerTimes.ids)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextField(
                        controller: ctrls[id],
                        keyboardType: TextInputType.datetime,
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          labelText: _names[id],
                          labelStyle: const TextStyle(color: Colors.white60),
                          isDense: true,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ),
                  if (error != null)
                    Text(tr(error!),
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    tr('دەتوانیت وەک ئامۆژگاری بنووسیت، بۆ نموونە عەسر 02:42. ئەپەکە خۆی دەیکات بە 14:42.'),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(tr('پاشگەزبوونەوە'))),
              FilledButton(
                style: FilledButton.styleFrom(
                    backgroundColor: _gold, foregroundColor: Colors.black),
                onPressed: () {
                  final out = <String, String>{};
                  for (final id in KalarPrayerTimes.ids) {
                    final v = KalarPrayerTimes.normalize(id, ctrls[id]!.text);
                    if (v == null) {
                      setLocal(
                          () => error = trf('کاتی {0} هەڵەیە', [_names[id]]));
                      return;
                    }
                    out[id] = v;
                  }
                  if (!KalarPrayerTimes.isValidDay(out)) {
                    setLocal(() => error = 'کاتەکان بە ڕیز نین');
                    return;
                  }
                  Navigator.pop(ctx, out);
                },
                child: Text(tr('پاشەکەوت')),
              ),
            ],
          ),
        ),
      ),
    );
    for (final c in ctrls.values) {
      c.dispose();
    }
    if (result != null) await _save({key: result});
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 پەیستکردنی مانگێکی تەواو
  // ═══════════════════════════════════════════════════════════
  Future<void> _pasteMonth() async {
    final ctrl = TextEditingController();
    final parsed = await showDialog<Map<String, Map<String, String>>>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setLocal) => Directionality(
            textDirection: AppLang.direction,
            child: AlertDialog(
              backgroundColor: const Color(0xFF1A2030),
              title: Text(trf('پەیستکردنی {0}', [tr(_months[_month - 1])]),
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900)),
              content: SizedBox(
                width: 420,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('هەر دێڕێک یەک ڕۆژە: ڕۆژ بەیانی خۆرهەڵاتن نیوەڕۆ عەسر ئێوارە خەوتنان'),
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr('نموونە:  7 05:05 06:30 11:47 02:37 05:04 06:15'),
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: _gold, fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: ctrl,
                      maxLines: 10,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontFamily: 'monospace'),
                      decoration:
                          const InputDecoration(border: OutlineInputBorder()),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 6),
                      Text(tr(error!),
                          style: const TextStyle(
                              color: Colors.redAccent, fontSize: 12)),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: Text(tr('پاشگەزبوونەوە'))),
                FilledButton(
                  style: FilledButton.styleFrom(
                      backgroundColor: _gold, foregroundColor: Colors.black),
                  onPressed: () {
                    final r = parseMonth(ctrl.text, _month, _year);
                    if (r.error != null) {
                      setLocal(() => error = r.error);
                      return;
                    }
                    Navigator.pop(ctx, r.days);
                  },
                  child: Text(tr('پاشەکەوت')),
                ),
              ],
            ),
          ),
        );
      },
    );
    ctrl.dispose();
    if (parsed != null && parsed.isNotEmpty) await _save(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final days = DateUtils.getDaysInMonth(_year, _month);
    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1421),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1B2E),
          foregroundColor: Colors.white,
          title: Text(tr('کاتەکانی نوێژ'),
              style: const TextStyle(fontWeight: FontWeight.w900)),
          actions: [
            IconButton(
              tooltip: tr('پەیستکردنی مانگ'),
              onPressed: _saving ? null : _pasteMonth,
              icon: const Icon(Icons.content_paste_rounded, color: _gold),
            ),
          ],
          bottom: _saving
              ? const PreferredSize(
                  preferredSize: Size.fromHeight(3),
                  child: LinearProgressIndicator(minHeight: 3, color: _gold),
                )
              : null,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, color: _gold),
                    onPressed: () =>
                        setState(() => _month = _month == 1 ? 12 : _month - 1),
                  ),
                  Expanded(
                    child: Text(
                      tr(_months[_month - 1]),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w900),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, color: _gold),
                    onPressed: () =>
                        setState(() => _month = _month == 12 ? 1 : _month + 1),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Wrap(
                spacing: 12,
                children: [
                  _legend(Colors.green, 'گۆڕدراو لەلایەن ئەدمین'),
                  _legend(_gold, 'خشتەی ئامۆژگاری'),
                  _legend(Colors.white38, 'هەژمارکراو'),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _gold))
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                        itemCount: days,
                        itemBuilder: (_, i) =>
                            _dayTile(DateTime(_year, _month, i + 1)),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _legend(Color c, String text) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(tr(text),
              style: const TextStyle(color: Colors.white60, fontSize: 11)),
        ],
      );

  Widget _dayTile(DateTime date) {
    final day = KalarPrayerTimes.forDay(date);
    final color = switch (day.source) {
      PrayerSource.admin => Colors.green,
      PrayerSource.official => _gold,
      PrayerSource.calculated => Colors.white38,
    };
    final t = day.times;
    return Card(
      color: const Color(0xFF1A2030),
      margin: const EdgeInsets.only(bottom: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withValues(alpha: 0.35)),
      ),
      child: ListTile(
        dense: true,
        onTap: _saving ? null : () => _editDay(date),
        onLongPress: day.source == PrayerSource.admin && !_saving
            ? () => _delete(KalarPrayerTimes.dayKey(date))
            : null,
        leading: CircleAvatar(
          radius: 16,
          backgroundColor: color.withValues(alpha: 0.15),
          child: Text('${date.day}',
              style: TextStyle(color: color, fontWeight: FontWeight.w900)),
        ),
        title: Text(
          tr(KalarPrayerTimes.ids
              .map((id) => KalarPrayerTimes.format12(t[id]!).split(' ').first)
              .join('   ')),
          textDirection: TextDirection.ltr,
          style: const TextStyle(
              color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700),
        ),
        subtitle: day.source == PrayerSource.admin
            ? Text(tr('بۆ گەڕانەوە بۆ کاتی ئەپ، پەنجە ڕابگرە'),
                style: const TextStyle(color: Colors.white38, fontSize: 10))
            : null,
        trailing:
            const Icon(Icons.edit_rounded, color: Colors.white38, size: 18),
      ),
    );
  }
}

/// ئەنجامی [parseMonth]
class ParsedMonth {
  const ParsedMonth(this.days, this.error);
  final Map<String, Map<String, String>> days;
  final String? error;
}

/// دێڕەکانی "ڕۆژ بەیانی خۆرهەڵاتن نیوەڕۆ عەسر ئێوارە خەوتنان" دەخوێنێتەوە.
/// کاتەکان دەتوانن ١٢ سەعاتی بن (وەک ئامۆژگاری) یان ٢٤ سەعاتی.
ParsedMonth parseMonth(String text, int month, int year) {
  final out = <String, Map<String, String>>{};
  final maxDay = DateUtils.getDaysInMonth(year, month);
  final lines = text
      .split(RegExp(r'[\r\n]+'))
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty);
  var n = 0;
  for (final line in lines) {
    n++;
    final parts =
        line.split(RegExp(r'[\s,|\t]+')).where((p) => p.isNotEmpty).toList();
    if (parts.length != 7) {
      return ParsedMonth(
          const {}, trf('دێڕی {0}: دەبێت ٧ بەش بێت (ڕۆژ + ٦ کات)', [n]));
    }
    final day = int.tryParse(KalarPrayerTimes.toLatinDigits(parts[0]));
    if (day == null || day < 1 || day > maxDay) {
      return ParsedMonth(const {}, trf('دێڕی {0}: ڕۆژی هەڵە', [n]));
    }
    final times = <String, String>{};
    for (var i = 0; i < 6; i++) {
      final id = KalarPrayerTimes.ids[i];
      final v = KalarPrayerTimes.normalize(id, parts[i + 1]);
      if (v == null)
        return ParsedMonth(
            const {}, trf('دێڕی {0}: کاتی هەڵە "{1}"', [n, parts[i + 1]]));
      times[id] = v;
    }
    if (!KalarPrayerTimes.isValidDay(times)) {
      return ParsedMonth(const {}, trf('دێڕی {0}: کاتەکان بە ڕیز نین', [n]));
    }
    out[KalarPrayerTimes.dayKey(DateTime(year, month, day))] = times;
  }
  if (out.isEmpty) return const ParsedMonth({}, 'هیچ دێڕێک نییە');
  return ParsedMonth(out, null);
}
