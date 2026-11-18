// lib/screens/pharmacy/on_duty_pharmacy_screen.dart
//
// 💊 دەرمانخانەی ئێشکگر — ئەمشەو کام دەرمانخانە کراوەیە، و شەوانی داهاتوو.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_colors.dart';
import '../../l10n/tr.dart';
import '../../services/pharmacy_duty_service.dart';

const _green = Color(0xFF059669);
const _days = 7;

/// ناوی ڕۆژەکانی هەفتە (DateTime.weekday: دووشەممە = ١)
String weekdayName(DateTime d) => tr(const [
      'دووشەممە',
      'سێشەممە',
      'چوارشەممە',
      'پێنجشەممە',
      'هەینی',
      'شەممە',
      'یەکشەممە',
    ][d.weekday - 1]);

String dutyDateLabel(DateTime d) =>
    '${weekdayName(d)} ${AppLang.localDigits('${d.day}/${d.month}', AppLang.code)}';

class OnDutyPharmacyScreen extends StatefulWidget {
  /// بۆ تێست؛ ئەگەر نەدرا لە Supabase دەهێنرێت
  final Future<List<PharmacyDuty>> Function(DateTime from, int days)? loader;
  final DateTime Function()? clock;

  const OnDutyPharmacyScreen({super.key, this.loader, this.clock});

  @override
  State<OnDutyPharmacyScreen> createState() => _OnDutyPharmacyScreenState();
}

class _OnDutyPharmacyScreenState extends State<OnDutyPharmacyScreen> {
  List<PharmacyDuty>? _items;
  bool _error = false;
  late DateTime _tonight;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _tonight = PharmacyDutyService.dutyNight((widget.clock ?? DateTime.now)());
    setState(() => _error = false);
    try {
      final items = await (widget.loader ?? PharmacyDutyService.fetchRange)(_tonight, _days);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      debugPrint('⚠️ on-duty pharmacies: $e');
      if (mounted) setState(() => _error = true);
    }
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(' ', ''));
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  Future<void> _openMap(PharmacyDuty p) async {
    final uri = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=${p.latitude},${p.longitude}');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBackground : const Color(0xFFF4F6FA);
    final card = isDark ? const Color(0xFF1A1B2E) : Colors.white;
    final fg = isDark ? Colors.white : const Color(0xFF1A1A2E);
    final sub = isDark ? Colors.white60 : Colors.grey.shade600;

    Widget body;
    if (_error) {
      body = _message(Icons.cloud_off_rounded, tr('بارکردن سەرکەوتوو نەبوو'), sub,
          action: TextButton.icon(
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(tr('دووبارە هەوڵبدەرەوە')),
          ));
    } else if (_items == null) {
      body = const Center(child: CircularProgressIndicator(color: _green));
    } else {
      final items = _items!;
      final tonight = items.where((p) => _sameDay(p.dutyDate, _tonight)).toList();
      final later = <DateTime, List<PharmacyDuty>>{};
      for (final p in items) {
        if (!_sameDay(p.dutyDate, _tonight)) {
          later.putIfAbsent(DateTime(p.dutyDate.year, p.dutyDate.month, p.dutyDate.day), () => []).add(p);
        }
      }

      body = RefreshIndicator(
        color: _green,
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _tonightHeader(),
            const SizedBox(height: 12),
            if (tonight.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18)),
                child: Text(
                  tr('هێشتا دەرمانخانەی ئێشکگری ئەمشەو دیاری نەکراوە'),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: sub),
                ),
              )
            else
              for (final p in tonight) _tonightCard(p, card, fg, sub),
            if (later.isNotEmpty) ...[
              const SizedBox(height: 22),
              Text(tr('ڕۆژانی داهاتوو'),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: fg)),
              const SizedBox(height: 10),
              for (final e in later.entries) _laterDay(e.key, e.value, card, fg, sub),
            ],
          ],
        ),
      );
    }

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: Text(tr('دەرمانخانەی ئێشکگر'),
              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        ),
        body: body,
      ),
    );
  }

  Widget _message(IconData icon, String text, Color color, {Widget? action}) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: color),
            const SizedBox(height: 12),
            Text(text, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
            if (action != null) action,
          ],
        ),
      );

  Widget _tonightHeader() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF047857), _green]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Icon(Icons.nightlight_round, color: Colors.white, size: 30),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${tr('ئەمشەو')} — ${dutyDateLabel(_tonight)}',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(tr('تا کاتژمێر ٨ی بەیانی'),
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _tonightCard(PharmacyDuty p, Color card, Color fg, Color sub) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _green.withValues(alpha: 0.35), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.local_pharmacy_rounded, color: _green),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(tr(p.name),
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: fg)),
                ),
              ],
            ),
            if (p.address.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(children: [
                Icon(Icons.location_on_rounded, size: 16, color: sub),
                const SizedBox(width: 4),
                Expanded(child: Text(tr(p.address), style: TextStyle(fontSize: 13, color: sub))),
              ]),
            ],
            if (p.note.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(p.note, style: TextStyle(fontSize: 13, color: sub)),
            ],
            if (p.phone.isNotEmpty || p.hasLocation) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  if (p.phone.isNotEmpty)
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => _call(p.phone),
                        style: FilledButton.styleFrom(
                          backgroundColor: _green,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.call_rounded, size: 18),
                        label: Text(tr('پەیوەندی')),
                      ),
                    ),
                  if (p.phone.isNotEmpty && p.hasLocation) const SizedBox(width: 10),
                  if (p.hasLocation)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openMap(p),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _green,
                          side: const BorderSide(color: _green),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.map_rounded, size: 18),
                        label: Text(tr('نەخشە')),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      );

  Widget _laterDay(DateTime day, List<PharmacyDuty> list, Color card, Color fg, Color sub) =>
      Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dutyDateLabel(day),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: _green)),
            for (final p in list)
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Text(tr(p.name),
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: fg)),
                    ),
                  ),
                  if (p.phone.isNotEmpty)
                    IconButton(
                      tooltip: tr('پەیوەندی'),
                      onPressed: () => _call(p.phone),
                      icon: const Icon(Icons.call_rounded, color: _green, size: 20),
                    ),
                ],
              ),
          ],
        ),
      );
}
