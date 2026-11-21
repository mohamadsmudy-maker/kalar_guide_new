// lib/screens/admin/admin_place_claims.dart
//
// 🏪 ئەدمین: داواکانی «ئەم شوێنە هی منە». پەسەندکردن → داواکەر دەبێتە
// ڤێندەری ئەو شوێنە و خۆی زانیارییەکانی نوێ دەکاتەوە.

import 'package:flutter/material.dart';

import '../../l10n/tr.dart';
import '../../services/place_claim_service.dart';

const _blue = Color(0xFF1E88E5);

class AdminPlaceClaimsScreen extends StatefulWidget {
  const AdminPlaceClaimsScreen({super.key, this.loader, this.reviewer});

  final Future<List<PlaceClaim>> Function()? loader;
  final Future<bool> Function(int id, bool approve)? reviewer;

  @override
  State<AdminPlaceClaimsScreen> createState() => _AdminPlaceClaimsScreenState();
}

class _AdminPlaceClaimsScreenState extends State<AdminPlaceClaimsScreen> {
  List<PlaceClaim>? _items;
  bool _error = false;
  final Set<int> _busy = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final items = await (widget.loader ?? PlaceClaimService.pending)();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      debugPrint('⚠️ place claims: $e');
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _review(PlaceClaim c, bool approve) async {
    if (approve) {
      final yes = await showDialog<bool>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: AppLang.direction,
          child: AlertDialog(
            title: Text(tr('پەسەندکردن')),
            content: Text(trf('«{0}» دەبێتە بەڕێوەبەری «{1}» و دەتوانێت زانیارییەکانی بگۆڕێت. دڵنیایت؟',
                [c.userName, c.storeName])),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('پاشگەزبوونەوە'))),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(tr('پەسەندکردن'))),
            ],
          ),
        ),
      );
      if (yes != true) return;
    }
    setState(() => _busy.add(c.id));
    bool ok;
    try {
      ok = await (widget.reviewer != null
          ? widget.reviewer!(c.id, approve)
          : PlaceClaimService.review(c.id, approve: approve));
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    setState(() {
      _busy.remove(c.id);
      if (ok) _items = _items?.where((x) => x.id != c.id && !(approve && x.storeId == c.storeId)).toList();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(tr(!ok ? 'هەڵەیەک ڕوویدا' : approve ? '✅ پەسەند کرا' : 'ڕەتکرایەوە')),
    ));
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
          title: Text(tr('داوای خاوەنداریەتی'),
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
            : items == null
                ? const Center(child: CircularProgressIndicator(color: _blue))
                : items.isEmpty
                    ? Center(
                        child: Text(tr('هیچ داوایەکی نوێ نییە'),
                            style: TextStyle(fontSize: 15, color: Colors.grey.shade600)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final c = items[i];
                          final busy = _busy.contains(c.id);
                          return Container(
                            key: ValueKey('claim-${c.id}'),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(tr(c.storeName.isEmpty ? '—' : c.storeName),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                              const SizedBox(height: 4),
                              Text('👤 ${c.userName}   📞 ${c.userPhone}',
                                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
                              if (c.note.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text('💬 ${c.note}', style: const TextStyle(fontSize: 13, height: 1.5)),
                              ],
                              const SizedBox(height: 10),
                              Row(children: [
                                Expanded(
                                  child: OutlinedButton(
                                    key: ValueKey('reject-${c.id}'),
                                    onPressed: busy ? null : () => _review(c, false),
                                    child: Text(tr('ڕەتکردنەوە')),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: FilledButton(
                                    key: ValueKey('approve-${c.id}'),
                                    onPressed: busy ? null : () => _review(c, true),
                                    child: Text(tr('پەسەندکردن')),
                                  ),
                                ),
                              ]),
                            ]),
                          );
                        },
                      ),
      ),
    );
  }
}
