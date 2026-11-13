import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// جۆرەکانی سووتەمەنی و دراو.
///
/// ئەدمین لە خشتەی `price_types` دەیانگۆڕێت (زیادکردن، سڕینەوە، ڕیزکردن).
/// تا ئەو خشتەیە نەبێت یان داتا نەهاتبێت، لیستی ناو ئەپ بەکاردێت،
/// بۆیە هیچ شتێک ناشکێت. دوایین لیستی هاتوو لەسەر مۆبایل پاشەکەوت دەکرێت.
enum PriceKind {
  fuel,
  currency;

  String get db => name;
}

class PriceTypes {
  PriceTypes._();

  static const _cachePrefix = 'price_types_v1_';

  static List<Map<String, dynamic>> _fuel = const [];
  static List<Map<String, dynamic>> _currency = const [];
  static bool _loaded = false;
  static Future<void>? _inflight;

  /// بەکارهێنەرەکان بۆ نوێکردنەوەی ڕواڵەت
  static final ValueNotifier<int> version = ValueNotifier(0);

  /// لیستی ئێستا (کۆپییەکی نەگۆڕ نییە — نەیگۆڕیت)
  static List<Map<String, dynamic>> of(
    PriceKind kind,
    List<Map<String, dynamic>> defaults,
  ) {
    final list = kind == PriceKind.fuel ? _fuel : _currency;
    return list.isEmpty ? defaults : list;
  }

  /// ئایا لیستی ڕاستەقینە هاتووە؟
  static bool get loaded => _loaded;

  /// یەکجار لە هەر دەستپێکردنێک؛ بانگکردنی دووبارە هەمان داواکاری دەگەڕێنێتەوە
  static Future<void> ensureLoaded() => _inflight ??= _load().whenComplete(() {
        _inflight = null;
      });

  static Future<void> refresh() => _load();

  static Future<void> _load() async {
    await _readCache();
    try {
      final res = await Supabase.instance.client
          .from('price_types')
          .select()
          .order('sort_order')
          .order('id');
      final rows = List<Map<String, dynamic>>.from(res);
      _apply(rows);
      _loaded = true;
      _writeCache(rows);
    } catch (e) {
      debugPrint('⚠️ price_types: $e — لیستی ناو ئەپ بەکاردێت');
    }
  }

  static void _apply(List<Map<String, dynamic>> rows) {
    final fuel = <Map<String, dynamic>>[];
    final cur = <Map<String, dynamic>>[];
    for (final r in rows) {
      final m = fromRow(r);
      if (m == null) continue;
      (r['kind'] == 'currency' ? cur : fuel).add(m);
    }
    _fuel = fuel;
    _currency = cur;
    version.value++;
  }

  static Future<void> _readCache() async {
    if (_loaded || _fuel.isNotEmpty || _currency.isNotEmpty) return;
    try {
      final p = await SharedPreferences.getInstance();
      final raw = p.getString('${_cachePrefix}rows');
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      _apply(list);
    } catch (_) {}
  }

  static Future<void> _writeCache(List<Map<String, dynamic>> rows) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString('${_cachePrefix}rows', jsonEncode(rows));
    } catch (_) {}
  }

  /// ڕیزی داتابەیس → هەمان شێوەی لیستی ناو ئەپ
  @visibleForTesting
  static Map<String, dynamic>? fromRow(Map<String, dynamic> r) {
    final key = '${r['key'] ?? ''}'.trim();
    final nameKu = '${r['name_ku'] ?? ''}'.trim();
    if (key.isEmpty || nameKu.isEmpty) return null;
    String? s(dynamic v) {
      final t = '${v ?? ''}'.trim();
      return t.isEmpty ? null : t;
    }

    final isFuel = r['kind'] != 'currency';
    final grp = s(r['grp']) ?? (isFuel ? 'fuel' : 'fiat');
    final unitKu = s(r['unit_ku']) ?? (isFuel ? 'لیتر' : '');
    return {
      'key': key,
      'name_ku': nameKu,
      'name_ar': s(r['name_ar']) ?? nameKu,
      'name_en': s(r['name_en']) ?? nameKu,
      'color': s(r['color']) ?? '#1E88E5',
      'group': grp,
      'order': (r['sort_order'] as num?)?.toInt() ?? 0,
      'unit_ku': unitKu,
      'unit_ar': s(r['unit_ar']) ?? unitKu,
      'unit_en': s(r['unit_en']) ?? unitKu,
      if (isFuel) 'emoji': s(r['emoji']) ?? '⛽',
      if (!isFuel) ...{
        'flag': s(r['emoji']) ?? '💱',
        'symbol': s(r['symbol']) ?? '',
        'per': (r['per'] as num?) ?? 1,
      },
    };
  }

  // ═══════════════════════════════════════════════════════════
  // ✏️ بۆ شاشەی ئەدمین
  // ═══════════════════════════════════════════════════════════
  static SupabaseClient get _db => Supabase.instance.client;

  /// ڕیزەکانی داتابەیس (بۆ دەستکاری)، بەپێی ڕیز
  static Future<List<Map<String, dynamic>>> fetchRows(PriceKind kind) async {
    final res = await _db
        .from('price_types')
        .select()
        .eq('kind', kind.db)
        .order('sort_order')
        .order('id');
    return List<Map<String, dynamic>>.from(res);
  }

  static Future<void> insert(Map<String, dynamic> row) async {
    await _db.from('price_types').insert(row);
    await refresh();
  }

  static Future<void> update(dynamic id, Map<String, dynamic> row) async {
    await _db.from('price_types').update(row).eq('id', id);
    await refresh();
  }

  static Future<void> delete(dynamic id) async {
    await _db.from('price_types').delete().eq('id', id);
    await refresh();
  }

  /// ڕیزکردنی نوێ: `orderedIds` بەپێی ئەو ڕیزەی ئەدمین دایناوە
  static Future<void> saveOrder(List<dynamic> orderedIds) async {
    for (var i = 0; i < orderedIds.length; i++) {
      await _db
          .from('price_types')
          .update({'sort_order': i + 1}).eq('id', orderedIds[i]);
    }
    await refresh();
  }

  /// جۆرێکی ناو ئەپ → ڕیزی داتابەیس (بۆ «گەڕاندنەوەی جۆرە سەرەکییەکان»)
  static Map<String, dynamic> rowFromDefault(
      PriceKind kind, Map<String, dynamic> t, int order) {
    final isFuel = kind == PriceKind.fuel;
    return {
      'kind': kind.db,
      'key': t['key'],
      'name_ku': t['name_ku'],
      'name_ar': t['name_ar'],
      'name_en': t['name_en'],
      'color': t['color'],
      'grp': t['group'],
      'emoji': isFuel ? t['emoji'] : t['flag'],
      'symbol': isFuel ? null : t['symbol'],
      'per': isFuel ? 1 : (t['per'] ?? 1),
      'unit_ku': t['unit_ku'],
      'unit_ar': t['unit_ar'],
      'unit_en': t['unit_en'],
      'sort_order': order,
    };
  }

  static Future<void> insertMany(List<Map<String, dynamic>> rows) async {
    await _db.from('price_types').upsert(rows, onConflict: 'kind,key');
    await refresh();
  }

  /// کلیلی نوێ و نەگۆڕ: لە ناوی ئینگلیزی (یان کوردی)ەوە، بێ دووبارەبوون
  static String makeKey(String nameEn, String nameKu, Set<String> taken) {
    var base = nameEn
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    if (base.isEmpty) {
      base = 'type_${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    }
    var key = base;
    var n = 2;
    while (taken.contains(key)) {
      key = '${base}_$n';
      n++;
    }
    return key;
  }

  @visibleForTesting
  static void resetForTest() {
    _fuel = const [];
    _currency = const [];
    _loaded = false;
    _inflight = null;
  }
}
