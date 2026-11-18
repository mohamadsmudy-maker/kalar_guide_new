// lib/screens/admin/admin_neighborhood_alerts.dart
//
// 📍 ئەدمین: ئاگادارییەک بۆ گەڕەکێک (بڕینی ئاو، کارەبا...). زیادکردن ئاگاداری
// push بۆ ئەوانە دەنێرێت کە ئەو گەڕەکەیان هەڵبژاردووە (Database Webhook).

import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/neighborhood_alert_service.dart';

const _blue = Color(0xFF1E88E5);

class AdminNeighborhoodAlertsScreen extends StatefulWidget {
  const AdminNeighborhoodAlertsScreen({super.key});

  @override
  State<AdminNeighborhoodAlertsScreen> createState() => _AdminNeighborhoodAlertsScreenState();
}

class _AdminNeighborhoodAlertsScreenState extends State<AdminNeighborhoodAlertsScreen> {
  List<NeighborhoodAlert>? _items;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final items = await NeighborhoodAlertService.latest();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      debugPrint('⚠️ admin neighborhood alerts: $e');
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _delete(NeighborhoodAlert a) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          title: Text(tr('سڕینەوە')),
          content: Text(a.title),
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
      await NeighborhoodAlertService.delete(a.id);
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('هەڵەیەک ڕوویدا'))));
      }
    }
  }

  Future<void> _add() async {
    final sent = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _AddAlertSheet(),
    );
    if (sent == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF0F9D7A),
        content: Text(tr('ئاگادارییەکە نێردرا')),
      ));
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: Text(tr('ئاگاداریی گەڕەکەکان'),
              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _add,
          backgroundColor: _blue,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.campaign_rounded),
          label: Text(tr('ئاگاداریی نوێ')),
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
                ? const Center(child: CircularProgressIndicator(color: _blue))
                : items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(tr('هیچ ئاگادارییەک نەنێردراوە'),
                              style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final a = items[i];
                          final d = a.createdAt;
                          return Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '📍 ${a.neighborhoodName}'
                                        '${d == null ? '' : '  •  ${AppLang.localDigits('${d.day}/${d.month}', AppLang.code)}'}',
                                        style: const TextStyle(
                                            fontSize: 12, fontWeight: FontWeight.w800, color: _blue),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(a.title,
                                          style: const TextStyle(
                                              fontSize: 15, fontWeight: FontWeight.w900)),
                                      if (a.body.isNotEmpty)
                                        Text(a.body,
                                            style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  tooltip: tr('سڕینەوە'),
                                  onPressed: () => _delete(a),
                                  icon: Icon(Icons.delete_rounded, color: Colors.red.shade400, size: 20),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class _AddAlertSheet extends StatefulWidget {
  const _AddAlertSheet();

  @override
  State<_AddAlertSheet> createState() => _AddAlertSheetState();
}

class _AddAlertSheetState extends State<_AddAlertSheet> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  List<Map<String, dynamic>> _neighborhoods = [];
  Map<String, dynamic>? _nbh;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    NeighborhoodAlertService.neighborhoods().then((n) {
      if (mounted) setState(() {
        _neighborhoods = n;
        _loading = false;
      });
    }).catchError((Object e) {
      debugPrint('⚠️ neighborhoods: $e');
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  bool get _ready => _nbh != null && _title.text.trim().isNotEmpty && !_saving;

  Future<void> _send() async {
    setState(() => _saving = true);
    try {
      await NeighborhoodAlertService.add(
        neighborhoodId: (_nbh!['id'] as num).toInt(),
        neighborhoodName: '${_nbh!['name_ku'] ?? ''}',
        title: _title.text,
        body: _body.text,
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('⚠️ add alert: $e');
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
              Text(tr('ئاگاداریی نوێ'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(tr('تەنها ئەوانە وەری دەگرن کە ئەم گەڕەکەیان لە ئەپدا هەڵبژاردووە.'),
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600)),
              const SizedBox(height: 16),
              if (_loading)
                const Center(child: CircularProgressIndicator(color: _blue))
              else
                DropdownButtonFormField<Map<String, dynamic>>(
                  initialValue: _nbh,
                  isExpanded: true,
                  decoration: _dec('${tr('گەڕەک')} *'),
                  items: [
                    for (final n in _neighborhoods)
                      DropdownMenuItem(value: n, child: Text('${n['name_ku'] ?? ''}')),
                  ],
                  onChanged: (v) => setState(() => _nbh = v),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                onChanged: (_) => setState(() {}),
                decoration: _dec('${tr('ناونیشان')} *'),
              ),
              const SizedBox(height: 12),
              TextField(controller: _body, maxLines: 3, decoration: _dec(tr('وردەکاری'))),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: _ready ? _send : null,
                style: FilledButton.styleFrom(
                  backgroundColor: _blue,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded),
                label: Text(tr('ناردن'),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
