// lib/screens/stores/suggest_place_screen.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../l10n/tr.dart';
import '../../services/auth_service.dart';
import '../../services/location_service.dart';
import 'map_picker.dart';

/// ➕ پێشنیاری شوێنێکی نوێ لەلایەن هاوڵاتیانەوە — ئەدمین پەسەندی دەکات
class SuggestPlaceScreen extends StatefulWidget {
  const SuggestPlaceScreen({super.key});

  @override
  State<SuggestPlaceScreen> createState() => _SuggestPlaceScreenState();
}

class _SuggestPlaceScreenState extends State<SuggestPlaceScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _note = TextEditingController();

  List<String> _categories = [];
  String? _category;
  double? _lat;
  double? _lng;
  bool _locating = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _loadCategories() async {
    try {
      final res = await Supabase.instance.client.from('main_categories').select('name').order('name');
      if (!mounted) return;
      setState(() {
        _categories = {
          for (final r in res as List) '${(r as Map)['name'] ?? ''}'.trim(),
        }.where((c) => c.isNotEmpty).toList();
      });
    } catch (_) {}
  }

  Future<void> _useMyLocation() async {
    setState(() => _locating = true);
    final pos = await LocationService.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _locating = false;
      if (pos != null) {
        _lat = pos.latitude;
        _lng = pos.longitude;
      }
    });
    if (pos == null) _snack(tr('نەتوانرا شوێنەکەت بدۆزرێتەوە'), AppColors.toneAmber);
  }

  Future<void> _pickOnMap() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MapPickerScreen(initialLat: _lat, initialLng: _lng)),
    );
    if (result is! Map || !mounted) return;
    final loc = result['location'] as gmaps.LatLng?;
    setState(() {
      if (loc != null) {
        _lat = loc.latitude;
        _lng = loc.longitude;
      }
      if (_name.text.trim().isEmpty) _name.text = '${result['name'] ?? ''}'.trim();
      if (_address.text.trim().isEmpty) _address.text = '${result['address'] ?? ''}'.trim();
    });
  }

  void _snack(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: color,
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _send() async {
    final name = _name.text.trim();
    if (name.length < 2) {
      _snack(tr('ناوی شوێن بنووسە'), AppColors.toneAmber);
      return;
    }
    if (_lat == null || _lng == null) {
      _snack(tr('شوێنەکە لەسەر نەخشە دیاری بکە'), AppColors.toneAmber);
      return;
    }
    setState(() => _sending = true);
    try {
      String? opt(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
      await Supabase.instance.client.from('place_suggestions').insert({
        'name': name,
        'category': _category,
        'latitude': _lat,
        'longitude': _lng,
        'address': opt(_address),
        'phone': opt(_phone),
        'note': opt(_note),
      });
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: AppLang.direction,
          child: AlertDialog(
            icon: const Icon(Icons.check_circle_rounded, color: AppColors.toneTeal, size: 44),
            title: Text(tr('سوپاس!')),
            content: Text(tr('پێشنیارەکەت نێردرا. دوای پشکنینی ئەدمین لە ئەپەکەدا دەردەکەوێت.')),
            actions: [
              FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('باشە'))),
            ],
          ),
        ),
      );
      if (mounted) Navigator.pop(context, true);
    } on PostgrestException catch (_) {
      // RLS: داخراوە، زۆر پێشنیاری چاوەڕوان، یان نەچووەتە ژوورەوە
      if (mounted) {
        _snack(tr('ئێستا ناتوانرێت پێشنیار بنێردرێت، دواتر هەوڵ بدەرەوە'), AppColors.toneRed);
      }
    } catch (_) {
      if (mounted) _snack(tr('هەڵەیەک ڕوویدا، تکایە دووبارە هەوڵ بدەرەوە'), AppColors.toneRed);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final loggedIn = AuthSessionManager.isLoggedIn;
    final hairline = isDark ? Colors.white.withValues(alpha: 0.10) : const Color(0xFFE2E8F0);

    InputDecoration deco(String label, IconData icon) => InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 21),
          filled: true,
          fillColor: isDark ? AppColors.darkCard : Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: hairline),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: hairline),
          ),
        );

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(tr('پێشنیاری شوێنی نوێ')),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: !loggedIn
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.add_location_alt_rounded, size: 60, color: AppColors.primary),
                    const SizedBox(height: 14),
                    Text(tr('بۆ پێشنیارکردنی شوێن سەرەتا بچۆ ژوورەوە'), textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => Navigator.pushNamed(context, '/auth').then((_) {
                        if (mounted) setState(() {});
                      }),
                      icon: const Icon(Icons.login_rounded),
                      label: Text(tr('چوونەژوورەوە')),
                    ),
                  ]),
                ),
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Text(
                    tr('شوێنێک دەناسیت کە لە ئەپەکەدا نییە؟ زانیارییەکەی بنێرە و ئێمە زیادی دەکەین.'),
                    style: const TextStyle(color: Color(0xFF64748B), height: 1.6),
                  ),
                  const SizedBox(height: 16),
                  TextField(controller: _name, decoration: deco(tr('ناوی شوێن *'), Icons.storefront_rounded)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    isExpanded: true,
                    decoration: deco(tr('بەش'), Icons.category_rounded),
                    items: [
                      for (final c in _categories) DropdownMenuItem(value: c, child: Text(tr(c))),
                    ],
                    onChanged: (v) => setState(() => _category = v),
                  ),
                  const SizedBox(height: 12),
                  // 📍 شوێن
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkCard : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _lat == null ? hairline : AppColors.toneTeal),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(children: [
                          Icon(
                            _lat == null ? Icons.location_off_rounded : Icons.location_on_rounded,
                            color: _lat == null ? const Color(0xFF94A3B8) : AppColors.toneTeal,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _lat == null
                                  ? tr('شوێن *: هێشتا دیاری نەکراوە')
                                  : '${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                              textDirection: _lat == null ? null : TextDirection.ltr,
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ]),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _locating ? null : _useMyLocation,
                              icon: _locating
                                  ? const SizedBox(
                                      width: 16, height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2))
                                  : const Icon(Icons.my_location_rounded, size: 18),
                              label: Text(tr('شوێنی ئێستام')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickOnMap,
                              icon: const Icon(Icons.map_rounded, size: 18),
                              label: Text(tr('لەسەر نەخشە')),
                            ),
                          ),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: deco(tr('ژمارەی تەلەفۆن'), Icons.phone_rounded),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _address, decoration: deco(tr('ناونیشان'), Icons.place_rounded)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _note,
                    maxLines: 3,
                    maxLength: 500,
                    decoration: deco(tr('تێبینی (ئارەزوومەندانە)'), Icons.notes_rounded),
                  ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded),
                    label: Text(tr('ناردنی پێشنیار')),
                  ),
                ],
              ),
      ),
    );
  }
}
