// lib/screens/admin/place_picker_sheet.dart
//
// هەڵبژاردنی شوێنێکی تۆمارکراو: سەرەتا دەرمانخانەکان پیشان دەدات، نووسین
// لە خانەی گەڕاندا لە هەموو شوێنەکان بە ناو دەگەڕێت.

import 'dart:async';
import 'package:flutter/material.dart';

import '../../l10n/tr.dart';

class PlacePickerSheet extends StatefulWidget {
  final Future<List<Map<String, dynamic>>> Function(String query) search;
  final Color color;

  const PlacePickerSheet(
      {super.key, required this.search, required this.color});

  static Future<Map<String, dynamic>?> show(
    BuildContext context, {
    required Future<List<Map<String, dynamic>>> Function(String query) search,
    required Color color,
  }) =>
      showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => PlacePickerSheet(search: search, color: color),
      );

  @override
  State<PlacePickerSheet> createState() => _PlacePickerSheetState();
}

class _PlacePickerSheetState extends State<PlacePickerSheet> {
  final _q = TextEditingController();
  Timer? _debounce;
  List<Map<String, dynamic>>? _items;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _run('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _q.dispose();
    super.dispose();
  }

  Future<void> _run(String q) async {
    final id = ++_request;
    setState(() => _items = null);
    final res = await widget.search(q);
    if (mounted && id == _request) setState(() => _items = res);
  }

  void _onChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _run(q));
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    return Directionality(
      textDirection: AppLang.direction,
      child: Material(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        clipBehavior: Clip.antiAlias,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          padding:
              EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: TextField(
                  controller: _q,
                  autofocus: false,
                  onChanged: _onChanged,
                  decoration: InputDecoration(
                    hintText: tr('گەڕان بە ناوی شوێن...'),
                    prefixIcon: Icon(Icons.search_rounded, color: widget.color),
                    filled: true,
                    fillColor: const Color(0xFFF4F6FA),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: items == null
                    ? Center(
                        child: CircularProgressIndicator(color: widget.color))
                    : items.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                tr(_q.text.trim().isEmpty
                                    ? 'هیچ دەرمانخانەیەک لە شوێنەکاندا نەدۆزرایەوە. ناوەکەی لە سەرەوە بنووسە.'
                                    : 'هیچ شوێنێک بەم ناوە نەدۆزرایەوە'),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade600),
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) {
                              final p = items[i];
                              final address = '${p['address'] ?? ''}'.trim();
                              return ListTile(
                                leading: Icon(Icons.local_pharmacy_rounded,
                                    color: widget.color),
                                title: Text('${p['name'] ?? ''}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                subtitle: address.isEmpty
                                    ? null
                                    : Text(address, maxLines: 1),
                                onTap: () => Navigator.pop(context, p),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
