// lib/services/ticker_service.dart
import 'package:supabase_flutter/supabase_flutter.dart';

class NewsTicker {
  final int id;
  final String textKu;
  final String textAr;
  final String textEn;
  final String textFa;
  final bool isActive;
  final int displayOrder;

  const NewsTicker({
    required this.id,
    required this.textKu,
    required this.textAr,
    required this.textEn,
    required this.textFa,
    required this.isActive,
    required this.displayOrder,
  });

  factory NewsTicker.fromMap(Map<String, dynamic> m) => NewsTicker(
        id: m['id'] as int,
        textKu: (m['text_ku'] as String?) ?? '',
        textAr: (m['text_ar'] as String?) ?? '',
        textEn: (m['text_en'] as String?) ?? '',
        textFa: (m['text_fa'] as String?) ?? '',
        isActive: (m['is_active'] as bool?) ?? true,
        displayOrder: (m['display_order'] as int?) ?? 0,
      );

  String textFor(String lang) {
    switch (lang) {
      case 'ar':
        return textAr.isNotEmpty ? textAr : textKu;
      case 'en':
        return textEn.isNotEmpty ? textEn : textKu;
      case 'fa':
        return textFa.isNotEmpty ? textFa : textKu;
      default:
        return textKu;
    }
  }
}

class TickerService {
  static final _db = Supabase.instance.client;

  /// هەڵەی تۆڕ فڕێ دەدات (نەک لیستی بەتاڵ)، تاکو توڵەکە لە کاتی
  /// پچڕانی ئینتەرنێتدا ون نەبێت
  static Future<List<NewsTicker>> fetchActive() async {
    final res = await _db
        .from('news_tickers')
        .select()
        .eq('is_active', true)
        .order('display_order')
        .order('created_at');
    return (res as List)
        .map((e) => NewsTicker.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<NewsTicker>> fetchAll() async {
    final res = await _db
        .from('news_tickers')
        .select()
        .order('display_order')
        .order('created_at');
    return (res as List)
        .map((e) => NewsTicker.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> upsert(Map<String, dynamic> data) async {
    if (data.containsKey('id')) {
      final id = data['id'] as int;
      final payload = Map<String, dynamic>.from(data)..remove('id');
      await _db.from('news_tickers').update(payload).eq('id', id);
    } else {
      await _db.from('news_tickers').insert(data);
    }
  }

  static Future<void> delete(int id) async {
    await _db.from('news_tickers').delete().eq('id', id);
  }

  static Future<void> setActive(int id, {required bool active}) async {
    await _db
        .from('news_tickers')
        .update({'is_active': active})
        .eq('id', id);
  }
}
