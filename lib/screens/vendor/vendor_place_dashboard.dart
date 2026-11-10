// lib/screens/vendor/vendor_place_dashboard.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../l10n/tr.dart';
import '../../utils/place_display.dart';
import '../admin/admin_news.dart';
import '../stores/store_news_screen.dart';

/// کردارێکی نرخ (بۆ بەنزینخانە و نوسینگەی دراو)
class VendorPriceActions {
  const VendorPriceActions({
    required this.onPrices,
    required this.onChart,
    required this.onPdf,
    required this.pdfBusy,
  });
  final VoidCallback onPrices;
  final VoidCallback onChart;
  final VoidCallback? onPdf;
  final bool pdfBusy;
}

/// 🏪 داشبۆردی شوێنی ڤێندەر: زانیاری، ئامار، هەواڵەکان (زیادکردن، دەستکاری،
/// سڕینەوە)، دەستکاری وەسف و ناونیشان، و ئەگەر هەبێت نرخەکان.
///
/// هەموو نووسینێک لە Supabase بە RLS پارێزراوە (ڤێندەر تەنها شوێنی خۆی).
class VendorPlaceDashboard extends StatefulWidget {
  const VendorPlaceDashboard({
    super.key,
    required this.place,
    required this.kindLabel,
    required this.icon,
    required this.color,
    this.prices,
    this.onChanged,
  });

  final Map<String, dynamic> place;
  final String kindLabel;
  final IconData icon;
  final Color color;
  final VendorPriceActions? prices;
  final VoidCallback? onChanged;

  @override
  State<VendorPlaceDashboard> createState() => _VendorPlaceDashboardState();
}

class _VendorPlaceDashboardState extends State<VendorPlaceDashboard> {
  bool _loading = true;
  List<Map<String, dynamic>> _news = [];

  SupabaseClient get _db => Supabase.instance.client;
  String get _storeId => '${widget.place['id']}';

  @override
  void initState() {
    super.initState();
    _loadNews();
  }

  Future<void> _loadNews() async {
    setState(() => _loading = true);
    try {
      final res = await _db
          .from('news')
          .select('id, title, description, images, views, likes, created_at, news_type, store_id')
          .eq('store_id', _storeId)
          .order('created_at', ascending: false)
          .limit(50);
      if (!mounted) return;
      setState(() {
        _news = List<Map<String, dynamic>>.from(res as List);
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  int _sum(String key) => _news.fold<int>(0, (s, n) => s + ((n[key] as num?)?.toInt() ?? 0));

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.toneRed : AppColors.toneTeal,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _addOrEditNews([Map<String, dynamic>? news]) async {
    HapticFeedback.selectionClick();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddNewsScreen(newsToEdit: news, forcedStoreId: _storeId),
      ),
    );
    if (mounted) _loadNews();
  }

  Future<void> _deleteNews(Map<String, dynamic> news) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tr('سڕینەوەی هەواڵ')),
        content: Text(trf('دڵنیایت لە سڕینەوەی «{0}»؟', ['${news['title'] ?? ''}'])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tr('نەخێر'))),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.toneRed),
            onPressed: () => Navigator.pop(c, true),
            child: Text(tr('سڕینەوە')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      final res = await _db.from('news').delete().eq('id', news['id']).select('id');
      if (!mounted) return;
      if ((res as List).isEmpty) {
        _toast(tr('ڕێگەت پێنەدراوە'), error: true);
      } else {
        _toast(tr('سڕایەوە'));
        _loadNews();
      }
    } catch (e) {
      if (mounted) _toast(tr('هەڵەیەک ڕوویدا'), error: true);
    }
  }

  Future<void> _editInfo() async {
    HapticFeedback.selectionClick();
    final desc = TextEditingController(text: '${widget.place['description'] ?? ''}');
    final addr = TextEditingController(text: '${widget.place['address'] ?? ''}');
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (c) => Directionality(
        textDirection: AppLang.direction,
        child: Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(c).bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(tr('دەستکاری زانیاری شوێن'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 14),
              TextField(
                controller: addr,
                decoration: InputDecoration(
                  labelText: tr('ناونیشان'),
                  prefixIcon: const Icon(Icons.location_on_rounded),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: desc,
                minLines: 3,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: tr('وەسف و وردەکاری'),
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () => Navigator.pop(c, true),
                icon: const Icon(Icons.check_rounded),
                label: Text(tr('پاشەکەوتکردن'), style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ],
          ),
        ),
      ),
    );
    if (saved != true || !mounted) return;
    try {
      final res = await _db
          .from('dukan')
          .update({'address': addr.text.trim(), 'description': desc.text.trim()})
          .eq('id', widget.place['id'])
          .select('id');
      if (!mounted) return;
      if ((res as List).isEmpty) {
        _toast(tr('ڕێگەت پێنەدراوە — پەیوەندی بە ئەدمینەوە بکە'), error: true);
        return;
      }
      widget.place['address'] = addr.text.trim();
      widget.place['description'] = desc.text.trim();
      setState(() {});
      widget.onChanged?.call();
      _toast(tr('پاشەکەوت کرا'));
    } catch (e) {
      if (mounted) _toast(tr('هەڵەیەک ڕوویدا'), error: true);
    }
  }

  void _openPage() {
    HapticFeedback.selectionClick();
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => StoreNewsScreen(store: widget.place)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = widget.place;
    final color = widget.color;
    final card = isDark ? AppColors.darkCard : Colors.white;
    final text = isDark ? Colors.white : AppColors.textPrimary;
    final sub = isDark ? Colors.white54 : AppColors.textSecondary;
    final image = '${p['logo'] ?? ''}'.startsWith('http') ? '${p['logo']}' : '${p['image'] ?? ''}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ─── سەرپەڕە ───
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color.lerp(color, Colors.black, 0.25)!, color],
            ),
            boxShadow: [
              BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 6)),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: image.startsWith('http')
                    ? Image.network(image,
                        fit: BoxFit.cover, errorBuilder: (_, __, ___) => Icon(widget.icon, color: color, size: 30))
                    : Icon(widget.icon, color: color, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(p['name']?.toString() ?? ''),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.kindLabel} • ${tr(PlaceDisplay.address(p['address']))}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ─── ئامار ───
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              _stat(Icons.article_rounded, _loading ? '…' : PlaceDisplay.digits(_news.length), tr('هەواڵ'), color, text,
                  sub),
              _stat(Icons.visibility_rounded, _loading ? '…' : PlaceDisplay.digits(_sum('views')), tr('بینین'),
                  AppColors.toneIndigo, text, sub),
              _stat(Icons.thumb_up_rounded, _loading ? '…' : PlaceDisplay.digits(_sum('likes')), tr('بەدڵبوون'),
                  AppColors.toneRose, text, sub),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // ─── کردارەکان ───
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          onPressed: () => _addOrEditNews(),
          icon: const Icon(Icons.add_rounded),
          label: Text(tr('بڵاوکردنەوەی هەواڵ یان ئاگاداری'),
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _action(Icons.edit_note_rounded, tr('دەستکاری زانیاری'), AppColors.toneTeal, _editInfo)),
            const SizedBox(width: 10),
            Expanded(child: _action(Icons.storefront_rounded, tr('لاپەڕەکەم'), AppColors.toneSlate, _openPage)),
          ],
        ),
        if (widget.prices != null) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _action(Icons.price_change_rounded, tr('نرخ و مێژوو'), color, widget.prices!.onPrices)),
              const SizedBox(width: 10),
              Expanded(
                  child: _action(Icons.show_chart_rounded, tr('چارت'), AppColors.toneIndigo, widget.prices!.onChart)),
              const SizedBox(width: 10),
              Expanded(
                child: _action(Icons.picture_as_pdf_rounded, 'PDF', AppColors.toneRed, widget.prices!.onPdf,
                    busy: widget.prices!.pdfBusy),
              ),
            ],
          ),
        ],
        const SizedBox(height: 20),

        // ─── هەواڵەکانم ───
        Text(tr('هەواڵەکانم'), style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: text)),
        const SizedBox(height: 10),
        if (_loading)
          const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
        else if (_news.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16)),
            child: Text(
              tr('هێشتا هیچ هەواڵێکت بڵاو نەکردۆتەوە'),
              textAlign: TextAlign.center,
              style: TextStyle(color: sub, fontWeight: FontWeight.w700),
            ),
          )
        else
          for (final n in _news) _newsTile(n, card, text, sub),
      ],
    );
  }

  Widget _stat(IconData icon, String value, String label, Color c, Color text, Color sub) => Expanded(
        child: Column(
          children: [
            Icon(icon, color: c, size: 20),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: text)),
            Text(label, style: TextStyle(fontSize: 11, color: sub, fontWeight: FontWeight.w600)),
          ],
        ),
      );

  Widget _action(IconData icon, String label, Color color, VoidCallback? onTap, {bool busy = false}) => Material(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Column(
              children: [
                busy
                    ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: color))
                    : Icon(icon, color: color, size: 22),
                const SizedBox(height: 4),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
              ],
            ),
          ),
        ),
      );

  Widget _newsTile(Map<String, dynamic> n, Color card, Color text, Color sub) {
    final when = DateTime.tryParse('${n['created_at'] ?? ''}')?.toLocal();
    final date = when == null
        ? ''
        : PlaceDisplay.digits(
            '${when.year}/${when.month.toString().padLeft(2, '0')}/${when.day.toString().padLeft(2, '0')}');
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr((n['title']?.toString() ?? '').isEmpty ? '—' : n['title'].toString()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w900, color: text),
                ),
                const SizedBox(height: 3),
                Text(
                  '${tr(n['news_type']?.toString() ?? 'هەواڵ')} • $date • 👁 ${PlaceDisplay.digits((n['views'] as num?)?.toInt() ?? 0)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: sub),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: tr('دەستکاری'),
            onPressed: () => _addOrEditNews(n),
            icon: const Icon(Icons.edit_rounded, color: AppColors.primary, size: 20),
          ),
          IconButton(
            tooltip: tr('سڕینەوە'),
            onPressed: () => _deleteNews(n),
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.toneRed, size: 20),
          ),
        ],
      ),
    );
  }
}
