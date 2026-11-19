// lib/screens/admin/admin_waste_schedule.dart
//
// 🗑️ ئەدمین: بۆ هەر گەڕەکێک ئەو ڕۆژانەی ئۆتۆمبێلی خۆڵ دێت + کات + تێبینی.
// هاوڵاتی لە پەیجی گەڕەکەکەی دەیبینێت و دەتوانێت شەوی پێشتر ئاگادار بکرێتەوە.

import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../models/neighborhood.dart';
import '../../services/neighborhood_service.dart';
import '../../services/waste_schedule_service.dart';

const _green = Color(0xFF0F9D7A);

class AdminWasteScheduleScreen extends StatefulWidget {
  const AdminWasteScheduleScreen({super.key, this.neighborhoods, this.schedules, this.saver});

  // بۆ تاقیکردنەوە
  final Future<List<Neighborhood>> Function()? neighborhoods;
  final Future<List<WasteSchedule>> Function()? schedules;
  final Future<void> Function(WasteSchedule s)? saver;

  @override
  State<AdminWasteScheduleScreen> createState() => _AdminWasteScheduleScreenState();
}

class _AdminWasteScheduleScreenState extends State<AdminWasteScheduleScreen> {
  List<Neighborhood>? _nbhs;
  Map<int, WasteSchedule> _byId = {};
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final r = await Future.wait([
        (widget.neighborhoods ?? NeighborhoodService.getAll)(),
        (widget.schedules ?? WasteScheduleService.all)(),
      ]);
      if (!mounted) return;
      setState(() {
        _nbhs = r[0] as List<Neighborhood>;
        _byId = {for (final s in r[1] as List<WasteSchedule>) s.neighborhoodId: s};
      });
    } catch (e) {
      debugPrint('⚠️ admin waste schedule: $e');
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _edit(Neighborhood n) async {
    final id = n.idAsInt;
    if (id == null) return;
    final saved = await showModalBottomSheet<WasteSchedule>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (_) => WasteScheduleSheet(
        initial: _byId[id] ?? WasteSchedule(neighborhoodId: id, neighborhoodName: n.nameKu),
        neighborhoodName: n.nameKu,
        saver: widget.saver ?? WasteScheduleService.save,
      ),
    );
    if (saved != null && mounted) {
      setState(() => _byId[id] = saved);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: _green,
        content: Text(tr('✅ پاشەکەوتکرا')),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _nbhs;
    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: Text(tr('کاتی ئۆتۆمبێلی خۆڵ'),
              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
        ),
        body: _error
            ? Center(
                child: TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(tr('دووبارە هەوڵبدەرەوە')),
                ),
              )
            : list == null
                ? const Center(child: CircularProgressIndicator(color: _green))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final n = list[i];
                      final s = _byId[n.idAsInt];
                      final days = s == null || s.isEmpty
                          ? tr('هێشتا دیاری نەکراوە')
                          : [
                              for (final d in WasteSchedule.weekOrder)
                                if (s.weekdays.contains(d)) tr(WasteSchedule.dayName(d)),
                            ].join('، ');
                      return Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        child: ListTile(
                          key: ValueKey('nbh-${n.id}'),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          leading: Icon(Icons.local_shipping_rounded,
                              color: s == null || s.isEmpty ? Colors.grey : _green),
                          title: Text(tr(n.nameKu), style: const TextStyle(fontWeight: FontWeight.w800)),
                          subtitle: Text(
                            s != null && s.timeText.isNotEmpty ? '$days · ${s.timeText}' : days,
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 12.5),
                          ),
                          trailing: const Icon(Icons.edit_rounded, size: 18),
                          onTap: () => _edit(n),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

class WasteScheduleSheet extends StatefulWidget {
  const WasteScheduleSheet({
    super.key,
    required this.initial,
    required this.neighborhoodName,
    required this.saver,
  });

  final WasteSchedule initial;
  final String neighborhoodName;
  final Future<void> Function(WasteSchedule s) saver;

  @override
  State<WasteScheduleSheet> createState() => _WasteScheduleSheetState();
}

class _WasteScheduleSheetState extends State<WasteScheduleSheet> {
  late final Set<int> _days = {...widget.initial.weekdays};
  late final _time = TextEditingController(text: widget.initial.timeText);
  late final _note = TextEditingController(text: widget.initial.note);
  bool _saving = false;

  @override
  void dispose() {
    _time.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final s = WasteSchedule(
      neighborhoodId: widget.initial.neighborhoodId,
      neighborhoodName: widget.neighborhoodName,
      weekdays: _days.toList()..sort(),
      timeText: _time.text.trim(),
      note: _note.text.trim(),
    );
    try {
      await widget.saver(s);
      if (mounted) Navigator.pop(context, s);
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('هەڵەیەک ڕوویدا'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLang.direction,
      child: Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(trf('گەڕەکی {0}', [tr(widget.neighborhoodName)]),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              Text(tr('ڕۆژەکانی هاتنی ئۆتۆمبێل'), style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final d in WasteSchedule.weekOrder)
                  FilterChip(
                    key: ValueKey('day-$d'),
                    selectedColor: _green.withValues(alpha: 0.18),
                    checkmarkColor: _green,
                    label: Text(tr(WasteSchedule.dayName(d))),
                    selected: _days.contains(d),
                    onSelected: (v) => setState(() => v ? _days.add(d) : _days.remove(d)),
                  ),
              ]),
              const SizedBox(height: 14),
              TextField(
                controller: _time,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: tr('کات (ئارەزوومەندانە، بۆ نموونە 7:00 - 10:00)'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              TextField(
                controller: _note,
                maxLength: 300,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: tr('تێبینی (ئارەزوومەندانە)'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                height: 50,
                child: FilledButton(
                  key: const ValueKey('waste-save'),
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(backgroundColor: _green),
                  child: Text(tr('پاشەکەوتکردن'), style: const TextStyle(fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
