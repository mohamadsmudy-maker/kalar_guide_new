// lib/screens/admin/admin_tickers.dart
//
// 📺 توڵی هەواڵی بەپەلە — کۆنترۆڵی ئەدمین (زیادکردن، گۆڕین، سڕینەوە)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../config/app_colors.dart';
import '../../l10n/tr.dart';
import '../../services/ticker_service.dart';

class AdminTickersScreen extends StatefulWidget {
  const AdminTickersScreen({super.key});

  @override
  State<AdminTickersScreen> createState() => _AdminTickersScreenState();
}

class _AdminTickersScreenState extends State<AdminTickersScreen> {
  List<NewsTicker> _tickers = [];
  bool _loading = true;
  String? _busy; // id being toggled

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final list = await TickerService.fetchAll();
      if (mounted) setState(() { _tickers = list; _loading = false; });
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggle(NewsTicker t) async {
    setState(() => _busy = '${t.id}');
    try {
      await TickerService.setActive(t.id, active: !t.isActive);
      await _load();
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _delete(NewsTicker t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          title: Text(tr('توڵی هەواڵ سڕینەوە')),
          content: Text(t.textKu.isNotEmpty ? t.textKu : tr('ئەم تووڵە بسڕرێتەوە؟')),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(tr('پەشیمانبوونەوە'))),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(tr('سڕینەوە')),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await TickerService.delete(t.id);
    if (mounted) {
      _showSnack(tr('تووڵەکە سڕایەوە'));
      _load();
    }
  }

  void _openEdit([NewsTicker? ticker]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TickerEditSheet(ticker: ticker),
    );
    if (saved == true) _load();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          backgroundColor: const Color(0xFFB71C1C),
          foregroundColor: Colors.white,
          title: Text(tr('توڵی هەواڵەکان'),
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: tr('نوێکردنەوە'),
              onPressed: _load,
            ),
          ],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openEdit(),
          backgroundColor: const Color(0xFFB71C1C),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text(tr('توڵی هەواڵ زیادبکە')),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _tickers.isEmpty
                ? _buildEmpty()
                : _buildList(),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.tv_rounded, size: 40, color: Color(0xFFB71C1C)),
        ),
        const SizedBox(height: 16),
        Text(tr('تووڵی هەواڵ نییە'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black54)),
        const SizedBox(height: 8),
        Text(tr('توڵی هەواڵ زیادبکە'),
            style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
        const SizedBox(height: 100),
      ],
    ),
  );

  Widget _buildList() {
    return ReorderableListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      itemCount: _tickers.length,
      onReorderItem: (oldIdx, newIdx) async {
        final list = List<NewsTicker>.from(_tickers);
        final item = list.removeAt(oldIdx);
        list.insert(newIdx, item);
        setState(() => _tickers = list);
        // persist new display_order
        for (int i = 0; i < list.length; i++) {
          await TickerService.upsert({'id': list[i].id, 'display_order': i});
        }
      },
      itemBuilder: (ctx, i) {
        final t = _tickers[i];
        return _buildCard(t, key: ValueKey(t.id));
      },
    );
  }

  Widget _buildCard(NewsTicker t, {required Key key}) {
    final isBusy = _busy == '${t.id}';
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: t.isActive
            ? const BorderSide(color: Color(0xFFEF9A9A), width: 1.5)
            : BorderSide(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: t.isActive
              ? LinearGradient(
                  colors: [Colors.red.shade50, Colors.white],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: t.isActive ? const Color(0xFFB71C1C) : Colors.grey.shade300,
              shape: BoxShape.circle,
              boxShadow: t.isActive
                  ? [BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 8)]
                  : null,
            ),
            child: Icon(
              Icons.tv_rounded,
              color: t.isActive ? Colors.white : Colors.grey.shade600,
              size: 22,
            ),
          ),
          title: Text(
            t.textKu.isNotEmpty ? t.textKu : '—',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: t.isActive ? Colors.black87 : Colors.grey,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                _langChip('ku', t.textKu),
                const SizedBox(width: 4),
                _langChip('ar', t.textAr),
                const SizedBox(width: 4),
                _langChip('en', t.textEn),
                const SizedBox(width: 4),
                _langChip('fa', t.textFa),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              isBusy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Switch(
                      value: t.isActive,
                      activeThumbColor: const Color(0xFFB71C1C),
                      onChanged: (_) => _toggle(t),
                    ),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 20),
                color: AppColors.primary,
                tooltip: tr('توڵی هەواڵ گۆڕین'),
                onPressed: () => _openEdit(t),
              ),
              IconButton(
                icon: const Icon(Icons.delete_rounded, size: 20),
                color: Colors.red.shade400,
                tooltip: tr('توڵی هەواڵ سڕینەوە'),
                onPressed: () => _delete(t),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.drag_handle_rounded, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langChip(String code, String text) {
    final has = text.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: has ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        code.toUpperCase(),
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: has ? AppColors.primary : Colors.grey.shade400,
        ),
      ),
    );
  }
}

// ── Edit / Add sheet ──────────────────────────────────────────────────────────

class _TickerEditSheet extends StatefulWidget {
  final NewsTicker? ticker;
  const _TickerEditSheet({this.ticker});

  @override
  State<_TickerEditSheet> createState() => _TickerEditSheetState();
}

class _TickerEditSheetState extends State<_TickerEditSheet> {
  final _kuCtrl = TextEditingController();
  final _arCtrl = TextEditingController();
  final _enCtrl = TextEditingController();
  final _faCtrl = TextEditingController();
  final _orderCtrl = TextEditingController();
  bool _isActive = true;
  bool _saving = false;

  bool get _isEdit => widget.ticker != null;

  @override
  void initState() {
    super.initState();
    if (_isEdit) {
      _kuCtrl.text = widget.ticker!.textKu;
      _arCtrl.text = widget.ticker!.textAr;
      _enCtrl.text = widget.ticker!.textEn;
      _faCtrl.text = widget.ticker!.textFa;
      _orderCtrl.text = widget.ticker!.displayOrder.toString();
      _isActive = widget.ticker!.isActive;
    }
  }

  @override
  void dispose() {
    _kuCtrl.dispose();
    _arCtrl.dispose();
    _enCtrl.dispose();
    _faCtrl.dispose();
    _orderCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_kuCtrl.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      final data = <String, dynamic>{
        'text_ku': _kuCtrl.text.trim(),
        'text_ar': _arCtrl.text.trim(),
        'text_en': _enCtrl.text.trim(),
        'text_fa': _faCtrl.text.trim(),
        'is_active': _isActive,
        'display_order': int.tryParse(_orderCtrl.text.trim()) ?? 0,
      };
      if (_isEdit) data['id'] = widget.ticker!.id;
      await TickerService.upsert(data);
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Directionality(
      textDirection: AppLang.direction,
      child: Container(
        padding: EdgeInsets.only(bottom: bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: const BoxDecoration(
                      color: Color(0xFFB71C1C),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.tv_rounded, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    tr(_isEdit ? 'توڵی هەواڵ گۆڕین' : 'توڵی هەواڵ زیادبکە'),
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _field(_kuCtrl, tr('دەقی تووڵ (کوردی)'), required: true, rtl: true),
              const SizedBox(height: 14),
              _field(_arCtrl, tr('دەقی تووڵ (عەرەبی)'), rtl: true),
              const SizedBox(height: 14),
              _field(_enCtrl, tr('دەقی تووڵ (ئینگلیزی)'), rtl: false),
              const SizedBox(height: 14),
              _field(_faCtrl, tr('دەقی تووڵ (فارسی)'), rtl: true),
              const SizedBox(height: 14),
              _field(
                _orderCtrl,
                tr('ریزی پیشاندان'),
                keyboard: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                rtl: false,
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
                activeThumbColor: const Color(0xFFB71C1C),
                title: Text(tr(_isActive ? 'چالاک' : 'ناچالاک'),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: _saving || _kuCtrl.text.trim().isEmpty ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFB71C1C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5))
                      : Text(tr('پاشەکەوت'),
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w900)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    bool rtl = true,
    TextInputType keyboard = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: ctrl,
      textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
      textAlign: rtl ? TextAlign.right : TextAlign.left,
      keyboardType: keyboard,
      inputFormatters: inputFormatters,
      onChanged: required ? (_) => setState(() {}) : null,
      decoration: InputDecoration(
        labelText: label + (required ? ' *' : ''),
        labelStyle: TextStyle(
          color: required && ctrl.text.trim().isEmpty
              ? Colors.red
              : Colors.grey.shade600,
        ),
        filled: true,
        fillColor: const Color(0xFFF8F9FA),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFB71C1C), width: 2),
        ),
        contentPadding: const EdgeInsets.all(14),
      ),
    );
  }
}
