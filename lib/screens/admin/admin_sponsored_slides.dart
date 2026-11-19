// lib/screens/admin/admin_sponsored_slides.dart
//
// 📢 ئەدمین: ڕیکلامی بازرگانی لە سلایدی پەیجی سەرەکی. وێنە، ناونیشان،
// دوگمە (پەیوەندی، واتسئاپ، لینک، شوێن)، ماوە، و ئاماری بینین و کرتە.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../l10n/tr.dart';
import '../../services/image_service.dart';
import '../../services/sponsored_slides_service.dart';
import '../../widgets/common/optimized_network_image.dart';

const _orange = Color(0xFFE67E22);

/// دۆخی ڕیکلامێک لە ڕۆژی [now]
String sponsoredStatus(SponsoredSlide s, DateTime now) {
  final d = DateTime(now.year, now.month, now.day);
  if (!s.isActive) return 'وەستێنراو';
  if (d.isBefore(s.startsOn)) return 'هێشتا دەستی پێنەکردووە';
  if (d.isAfter(s.endsOn)) return 'تەواو بووە';
  return 'چالاکە';
}

class AdminSponsoredSlidesScreen extends StatefulWidget {
  const AdminSponsoredSlidesScreen({super.key, this.loader});

  /// بۆ تاقیکردنەوە
  final Future<List<SponsoredSlide>> Function()? loader;

  @override
  State<AdminSponsoredSlidesScreen> createState() => _AdminSponsoredSlidesScreenState();
}

class _AdminSponsoredSlidesScreenState extends State<AdminSponsoredSlidesScreen> {
  List<SponsoredSlide>? _items;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = false);
    try {
      final items = await (widget.loader ?? SponsoredSlidesService.all)();
      if (mounted) setState(() => _items = items);
    } catch (e) {
      debugPrint('⚠️ admin sponsored: $e');
      if (mounted) setState(() => _error = true);
    }
  }

  Future<void> _edit([SponsoredSlide? s]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => SponsoredSlideEditor(slide: s)),
    );
    if (changed == true) _load();
  }

  Future<void> _delete(SponsoredSlide s) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: AlertDialog(
          title: Text(tr('سڕینەوە')),
          content: Text(s.title),
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
      await SponsoredSlidesService.delete(s.id);
      _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('هەڵەیەک ڕوویدا'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _items;
    final now = DateTime.now();
    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6FA),
        appBar: AppBar(
          backgroundColor: _orange,
          foregroundColor: Colors.white,
          centerTitle: true,
          title: Text(tr('سلایدی ڕیکلام'),
              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
          actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(),
          backgroundColor: _orange,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add_rounded),
          label: Text(tr('ڕیکلامی نوێ')),
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
                ? const Center(child: CircularProgressIndicator(color: _orange))
                : items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            tr('هیچ ڕیکلامێک نییە. زۆرترین ٣ ڕیکلام لە سلایدەکەدا دەردەکەون، دوای هەر ٢ هەواڵ یەک ڕیکلام.'),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 14, height: 1.6, color: Colors.grey.shade600),
                          ),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                        itemCount: items.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final s = items[i];
                          final status = sponsoredStatus(s, now);
                          final live = status == 'چالاکە';
                          final ctr = s.views == 0 ? 0 : (s.clicks * 100 / s.views);
                          String d(DateTime x) => AppLang.localDigits('${x.year}/${x.month}/${x.day}');
                          return Material(
                            key: ValueKey('slide-${s.id}'),
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => _edit(s),
                              child: Row(children: [
                                SizedBox(
                                  width: 96,
                                  height: 96,
                                  child: OptimizedNetworkImage(imageUrl: s.imageUrl, fit: BoxFit.cover),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(s.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontWeight: FontWeight.w900)),
                                        const SizedBox(height: 2),
                                        Text('${tr(status)} · ${d(s.startsOn)} → ${d(s.endsOn)}',
                                            style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w700,
                                                color: live ? const Color(0xFF0F9D7A) : Colors.grey.shade600)),
                                        const SizedBox(height: 6),
                                        Text(
                                          trf('👁 {0} بینین · 👆 {1} کرتە · {2}٪', [
                                            AppLang.localDigits('${s.views}'),
                                            AppLang.localDigits('${s.clicks}'),
                                            AppLang.localDigits(ctr.toStringAsFixed(1)),
                                          ]),
                                          style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                IconButton(
                                  tooltip: tr('سڕینەوە'),
                                  onPressed: () => _delete(s),
                                  icon: Icon(Icons.delete_rounded, color: Colors.red.shade400, size: 20),
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class SponsoredSlideEditor extends StatefulWidget {
  const SponsoredSlideEditor({super.key, this.slide});

  final SponsoredSlide? slide;

  @override
  State<SponsoredSlideEditor> createState() => _SponsoredSlideEditorState();
}

class _SponsoredSlideEditorState extends State<SponsoredSlideEditor> {
  late final _title = TextEditingController(text: widget.slide?.title ?? '');
  late final _subtitle = TextEditingController(text: widget.slide?.subtitle ?? '');
  late final _value = TextEditingController(text: widget.slide?.actionValue ?? '');
  late String _action = widget.slide?.actionType ?? 'phone';
  late bool _active = widget.slide?.isActive ?? true;
  late DateTime _start = widget.slide?.startsOn ?? _today();
  late DateTime _end = widget.slide?.endsOn ?? _today().add(const Duration(days: 30));
  late String _imageUrl = widget.slide?.imageUrl ?? '';
  XFile? _picked;
  bool _saving = false;

  static DateTime _today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    _value.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (f != null) setState(() => _picked = f);
  }

  Future<void> _pickDate(bool start) async {
    final d = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2025),
      lastDate: DateTime(2035),
    );
    if (d == null) return;
    setState(() {
      if (start) {
        _start = d;
        if (_end.isBefore(_start)) _end = _start;
      } else {
        _end = d.isBefore(_start) ? _start : d;
      }
    });
  }

  String? get _valueHint => switch (_action) {
        'phone' || 'whatsapp' => tr('ژمارەی مۆبایل، بۆ نموونە 07701234567'),
        'url' => tr('لینک، بۆ نموونە facebook.com/...'),
        'place' => tr('ژمارەی (id) ـی شوێن لە ئەپەکەدا'),
        _ => null,
      };

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || (_imageUrl.isEmpty && _picked == null)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('وێنە و ناونیشان پێویستن ⚠'))));
      return;
    }
    setState(() => _saving = true);
    try {
      if (_picked != null) _imageUrl = await ImageCompressionService.uploadImage(_picked!);
      final s = SponsoredSlide(
        id: widget.slide?.id ?? 0,
        title: _title.text,
        subtitle: _subtitle.text,
        imageUrl: _imageUrl,
        actionType: _action,
        actionValue: _action == 'none' ? '' : _value.text,
        startsOn: _start,
        endsOn: _end,
        isActive: _active,
        displayOrder: widget.slide?.displayOrder ?? 0,
      );
      await SponsoredSlidesService.save(s, isNew: widget.slide == null);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('❌ save sponsored: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('هەڵەیەک ڕوویدا'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    String d(DateTime x) => AppLang.localDigits('${x.year}/${x.month}/${x.day}');
    InputDecoration deco(String label, {String? hint}) => InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        );
    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: _orange,
          foregroundColor: Colors.white,
          title: Text(tr(widget.slide == null ? 'ڕیکلامی نوێ' : 'دەستکاریی ڕیکلام'),
              style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.white)),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: _picked != null
                      ? Image.file(File(_picked!.path), fit: BoxFit.cover)
                      : _imageUrl.isNotEmpty
                          ? OptimizedNetworkImage(imageUrl: _imageUrl, fit: BoxFit.cover)
                          : _imageHint(),
                ),
              ),
            ),
            if (_picked != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(tr('✅ وێنەیەکی نوێ هەڵبژێردرا'), style: const TextStyle(color: Color(0xFF0F9D7A))),
              ),
            const SizedBox(height: 14),
            TextField(controller: _title, maxLength: 80, decoration: deco(tr('ناونیشان'))),
            TextField(controller: _subtitle, maxLength: 160, decoration: deco(tr('دەقی کورت (ئارەزوومەندانە)'))),
            DropdownButtonFormField<String>(
              initialValue: _action,
              decoration: deco(tr('دوگمە')),
              items: [
                for (final t in SponsoredSlide.actionTypes)
                  DropdownMenuItem(value: t, child: Text(tr(SponsoredSlide.actionLabel(t)))),
              ],
              onChanged: (v) => setState(() => _action = v ?? 'none'),
            ),
            if (_action != 'none') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _value,
                textDirection: TextDirection.ltr,
                decoration: deco(tr('بەها'), hint: _valueHint),
              ),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(true),
                  icon: const Icon(Icons.event_rounded),
                  label: Text(trf('دەستپێک: {0}', [d(_start)])),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(false),
                  icon: const Icon(Icons.event_busy_rounded),
                  label: Text(trf('کۆتایی: {0}', [d(_end)])),
                ),
              ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tr('چالاکە'), style: const TextStyle(fontWeight: FontWeight.w800)),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 52,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: _orange),
                child: _saving
                    ? const SizedBox(
                        width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text(tr('پاشەکەوتکردن'), style: const TextStyle(fontWeight: FontWeight.w900)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _imageHint() => Container(
        color: Colors.grey.shade200,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_photo_alternate_rounded, size: 40, color: Colors.grey.shade600),
            const SizedBox(height: 6),
            Text(tr('وێنەی ڕیکلام هەڵبژێرە (باشترین: پانی ١٦:٩)'),
                style: TextStyle(color: Colors.grey.shade700)),
          ],
        ),
      );
}
