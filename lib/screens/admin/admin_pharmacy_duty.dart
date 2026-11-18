// lib/screens/admin/admin_pharmacy_duty.dart
//
// 💊 ئەدمین: خشتەی دەرمانخانەی ئێشکگر (زیادکردن و سڕینەوە).

import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/pharmacy_duty_service.dart';
import '../pharmacy/on_duty_pharmacy_screen.dart' show dutyDateLabel;

const _green = Color(0xFF059669);
const _days = 30;

class AdminPharmacyDutyScreen extends StatefulWidget {
  const AdminPharmacyDutyScreen({super.key});

  @override
  State<AdminPharmacyDutyScreen> createState() => _AdminPharmacyDutyScreenState();
}

class _AdminPharmacyDutyScreenState extends State<AdminPharmacyDutyScreen> {
  List<PharmacyDuty>? _items;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final from = PharmacyDutyService.dutyNight(DateTime.now());
      final items = await PharmacyDutyService.fetchRange(from, _days);
      if (mounted) setState(() => _items = items);
    } catch (e) {
      debugPrint('⚠️ admin pharmacy duty: $e');
      if (mounted) setState(() => _error = true);
    }
  }

  void _snack(String msg, {bool ok = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ok ? _green : const Color(0xFFDC3545),
      content: Text(msg),
    ));
  }

  Future<void> _delete(PharmacyDuty p) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          title: Text(tr('سڕینەوە')),
          content: Text('${p.name}\n${dutyDateLabel(p.dutyDate)}'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('پاشگەزبوونەوە'))),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(tr('سڕینەوە')),
            ),
          ],
        ),
      ),
    );
    if (yes != true) return;
    try {
      await PharmacyDutyService.delete(p.id);
      _load();
    } catch (e) {
      _snack(tr('هەڵەیەک ڕوویدا'), ok: false);
    }
  }

  Future<void> _add() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddDutySheet(),
    );
    if (saved == true) {
      _snack(tr('✅ پاشەکەوت کرا'));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final groups = <DateTime, List<PharmacyDuty>>{};
    for (final p in items ?? const <PharmacyDuty>[]) {
      groups.putIfAbsent(p.dutyDate, () => []).add(p);
    }

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: Text(tr('دەرمانخانەی ئێشکگر'),
              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          backgroundColor: _green,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text(tr('دەرمانخانەی ئێشکگر زیاد بکە')),
        ),
        body: _error
            ? Center(
                child: TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(tr('دووبارە هەوڵبدەرەوە')),
                ),
              )
            : items == null
                ? const Center(child: CircularProgressIndicator(color: _green))
                : groups.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            tr('هیچ دەرمانخانەیەکی ئێشکگر دانەنراوە'),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        children: [
                          for (final e in groups.entries)
                            Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.fromLTRB(14, 12, 4, 4),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(dutyDateLabel(e.key),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w900, color: _green)),
                                  for (final p in e.value)
                                    Row(
                                      children: [
                                        const Icon(Icons.local_pharmacy_rounded,
                                            size: 18, color: _green),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(p.name,
                                              style: const TextStyle(
                                                  fontSize: 15, fontWeight: FontWeight.w700)),
                                        ),
                                        IconButton(
                                          tooltip: tr('سڕینەوە'),
                                          onPressed: () => _delete(p),
                                          icon: Icon(Icons.delete_rounded,
                                              color: Colors.red.shade400, size: 20),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
      ),
    );
  }
}

class _AddDutySheet extends StatefulWidget {
  const _AddDutySheet();

  @override
  State<_AddDutySheet> createState() => _AddDutySheetState();
}

class _AddDutySheetState extends State<_AddDutySheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();
  late DateTime _date = PharmacyDutyService.dutyNight(DateTime.now());
  List<Map<String, dynamic>> _places = [];
  Map<String, dynamic>? _place;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    PharmacyDutyService.pharmacyPlaces().then((p) {
      if (mounted) setState(() => _places = p);
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  void _pickPlace(Map<String, dynamic>? p) {
    setState(() {
      _place = p;
      _name.text = (p?['name'] ?? '').toString();
      _phone.text = (p?['phone'] ?? '').toString();
      _address.text = (p?['address'] ?? '').toString();
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year, now.month, now.day - 1),
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      double? toDouble(Object? v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');
      await PharmacyDutyService.add(
        dutyDate: _date,
        name: _name.text,
        dukanId: (_place?['id'] as num?)?.toInt(),
        phone: _phone.text,
        address: _address.text,
        latitude: toDouble(_place?['latitude']),
        longitude: toDouble(_place?['longitude']),
        note: _note.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('⚠️ add duty: $e');
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('هەڵەیەک ڕوویدا'))));
      }
    }
  }

  InputDecoration _dec(String label) => InputDecoration(
        labelText: label,
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      );

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLang.direction,
      child: Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('دەرمانخانەی ئێشکگر زیاد بکە'),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _pickDate,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text('${tr('شەوی')} ${dutyDateLabel(_date)}'),
              ),
              const SizedBox(height: 14),
              if (_places.isNotEmpty) ...[
                DropdownButtonFormField<Map<String, dynamic>?>(
                  initialValue: _place,
                  isExpanded: true,
                  decoration: _dec(tr('دەرمانخانەیەک لە شوێنەکان هەڵبژێرە')),
                  items: [
                    DropdownMenuItem(value: null, child: Text(tr('یان بە دەست بنووسە'))),
                    for (final p in _places)
                      DropdownMenuItem(
                        value: p,
                        child: Text('${p['name'] ?? ''}', overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: _pickPlace,
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _name,
                onChanged: (_) => setState(() {}),
                decoration: _dec('${tr('ناوی دەرمانخانە')} *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textDirection: TextDirection.ltr,
                decoration: _dec(tr('ژمارەی مۆبایل')),
              ),
              const SizedBox(height: 12),
              TextField(controller: _address, decoration: _dec(tr('ناونیشان'))),
              const SizedBox(height: 12),
              TextField(controller: _note, decoration: _dec(tr('تێبینی'))),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _saving || _name.text.trim().isEmpty ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: _green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(tr('پاشەکەوت'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
