// lib/screens/admin/admin_general_prices.dart
//
// نرخی گشتی کەلار — کاتێک هەموو بەنزینخانەکان (یان نوسینگەکانی دراو)
// ناچالاک بن، هاوڵاتیان ئەم نرخانە دەبینن کە ئەدمین خۆی دایدەنێت.

import 'package:flutter/material.dart';
import '../../l10n/tr.dart';
import '../../services/currency_service.dart';
import '../../services/fuel_service.dart';
import '../../services/price_types.dart';

const _fuelColor = Color(0xFFD9822B);
const _currencyColor = Color(0xFF0F9D7A);

/// کارتی سەرەوەی لیستی ئەدمین کە شاشەی نرخی گشتی دەکاتەوە
class GeneralPricesCard extends StatelessWidget {
  final bool isFuel;
  final bool allInactive;
  final bool isDark;

  const GeneralPricesCard({
    super.key,
    required this.isFuel,
    required this.allInactive,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final color = allInactive ? const Color(0xFFDC3545) : (isFuel ? _fuelColor : _currencyColor);
    return Material(
      color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AdminGeneralPricesScreen(isFuel: isFuel)),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.45), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.public_rounded, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('نرخی گشتی کەلار'),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      tr(allInactive
                          ? 'هەموویان ناچالاکن — ئێستا هاوڵاتیان ئەم نرخانە دەبینن'
                          : 'تەنها کاتێک پیشان دەدرێت کە هەموویان ناچالاک بن'),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: allInactive ? color : (isDark ? Colors.white54 : Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.edit_rounded, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminGeneralPricesScreen extends StatefulWidget {
  final bool isFuel;
  const AdminGeneralPricesScreen({super.key, required this.isFuel});

  @override
  State<AdminGeneralPricesScreen> createState() => _AdminGeneralPricesScreenState();
}

class _AdminGeneralPricesScreenState extends State<AdminGeneralPricesScreen> {
  bool _loading = true;
  bool _saving = false;
  List<Map<String, String>> _types = [];
  Map<String, dynamic> _saved = {};

  /// fuel: key → [price]   currency: key → [buy, sell]
  final Map<String, List<TextEditingController>> _ctrls = {};

  Color get _color => widget.isFuel ? _fuelColor : _currencyColor;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final l in _ctrls.values) {
      for (final c in l) {
        c.dispose();
      }
    }
    super.dispose();
  }

  static String _show(dynamic v) {
    if (v is! num || v <= 0) return '';
    return v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  }

  /// ژمارەی کوردی/عەرەبی/فارسی و کۆما قبووڵ دەکات
  static double _parse(String s) {
    const ar = '٠١٢٣٤٥٦٧٨٩', fa = '۰۱۲۳۴۵۶۷۸۹';
    final b = StringBuffer();
    for (final ch in s.trim().split('')) {
      final i = ar.indexOf(ch), j = fa.indexOf(ch);
      b.write(i >= 0 ? i : (j >= 0 ? j : ch));
    }
    return double.tryParse(b.toString().replaceAll(',', '').replaceAll('٬', '')) ?? 0;
  }

  Future<void> _load() async {
    await PriceTypes.ensureLoaded();
    final saved = widget.isFuel
        ? await FuelService.getGeneralPrices()
        : await CurrencyService.getGeneralPrices();
    final types = widget.isFuel
        ? FuelService.getFuelTypesForLang(AppLang.code)
        : CurrencyService.getCurrencyTypesForLang(AppLang.code);
    if (!mounted) return;
    for (final t in types) {
      final key = t['key']!;
      final v = saved[key];
      _ctrls[key] = widget.isFuel
          ? [TextEditingController(text: _show(v))]
          : [
              TextEditingController(text: _show(v is Map ? v['buy'] : null)),
              TextEditingController(text: _show(v is Map ? v['sell'] : null)),
            ];
    }
    setState(() {
      _types = types;
      _saved = saved;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final now = DateTime.now().toUtc().toIso8601String();
    final out = <String, dynamic>{};
    for (final e in _ctrls.entries) {
      if (widget.isFuel) {
        final p = _parse(e.value[0].text);
        if (p > 0) out[e.key] = p;
      } else {
        final buy = _parse(e.value[0].text), sell = _parse(e.value[1].text);
        if (buy <= 0 && sell <= 0) continue;
        final old = _saved[e.key];
        final same = old is Map && old['buy'] == buy && old['sell'] == sell;
        out[e.key] = {'buy': buy, 'sell': sell, 'updated_at': same ? (old['updated_at'] ?? now) : now};
      }
    }

    setState(() => _saving = true);
    final ok = widget.isFuel
        ? await FuelService.saveGeneralPrices(out)
        : await CurrencyService.saveGeneralPrices(out);
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: ok ? const Color(0xFF0F9D7A) : const Color(0xFFDC3545),
      content: Text(tr(ok ? 'نرخی گشتی پاشەکەوت کرا' : 'پاشەکەوت نەکرا. دووبارە هەوڵ بدەرەوە.')),
    ));
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F1421) : const Color(0xFFF5F6FA),
        appBar: AppBar(
          title: Text(
            tr('نرخی گشتی کەلار'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
          ),
          backgroundColor: const Color(0xFF1A1B2E),
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        bottomNavigationBar: _loading
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _color,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      icon: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded),
                      label: Text(
                        tr('پاشەکەوت'),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                ),
              ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: _color))
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: _color, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tr('ئەم نرخانە تەنها کاتێک بۆ هاوڵاتیان پیشان دەدرێن کە هەموو شوێنەکان ناچالاک بن. خانەی بەتاڵ پیشان نادرێت.'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  for (final t in _types) _row(t, isDark),
                ],
              ),
      ),
    );
  }

  Widget _row(Map<String, String> t, bool isDark) {
    final c = _ctrls[t['key']]!;
    final mark = widget.isFuel ? t['emoji'] : t['flag'];
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1B2E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${mark ?? ''} ${t['name']}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: isDark ? Colors.white : const Color(0xFF1A1A2E),
            ),
          ),
          const SizedBox(height: 10),
          if (widget.isFuel)
            _field(c[0], trf('نرخ بۆ {0} (د.ع)', [t['unit'] ?? '']), isDark)
          else
            Row(
              children: [
                Expanded(child: _field(c[0], tr('کڕین (د.ع)'), isDark)),
                const SizedBox(width: 10),
                Expanded(child: _field(c[1], tr('فرۆشتن (د.ع)'), isDark)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label, bool isDark) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textDirection: TextDirection.ltr,
      style: TextStyle(fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87),
      decoration: InputDecoration(
        labelText: label,
        isDense: true,
        filled: true,
        fillColor: isDark ? const Color(0xFF0F1421) : const Color(0xFFF8F9FA),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _color, width: 2),
        ),
      ),
    );
  }
}
