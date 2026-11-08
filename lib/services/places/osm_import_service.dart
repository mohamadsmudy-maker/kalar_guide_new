// lib/services/places/osm_import_service.dart
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../../l10n/tr.dart';

/// شوێنێک لە OpenStreetMap
class OsmPlace {
  OsmPlace({
    required this.externalId,
    required this.name,
    required this.lat,
    required this.lng,
    required this.kind,
    required this.isGovernment,
    this.phone,
    this.address,
  });

  /// `osm:node/123`, `osm:way/45`
  final String externalId;
  final String name;
  final double lat;
  final double lng;

  /// جۆری OSM، بۆ نموونە `pharmacy`, `restaurant`, `shop:supermarket`
  final String kind;
  final bool isGovernment;
  final String? phone;
  final String? address;
}

/// 🗺️ هێنانی شوێنەکانی کەلار لە OpenStreetMap (Overpass API)
///
/// داتای OSM لەژێر مۆڵەتی ODbL ـە: بەکارهێنان و هەڵگرتنی ڕێگەپێدراوە،
/// بەو مەرجەی «© OpenStreetMap contributors» بنووسرێت.
/// (داتای Google Maps بە پێچەوانەوە ناکرێت کۆپی بکرێت.)
class OsmImportService {
  OsmImportService._();

  /// سنووری کەلار (باشوور، ڕۆژئاوا، باکوور، ڕۆژهەڵات)
  static const bbox = (34.575, 45.285, 34.665, 45.385);

  static const _endpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
  ];

  /// Overpass داوای ناوێکی ڕوون دەکات (هەندێک سێرڤەر داواکاری بێ ناو ڕەت دەکەنەوە)
  static const _headers = {
    'User-Agent': 'KalarGuide/1.1 (Kalar city guide app; admin import)',
    'Accept': 'application/json',
  };

  static String get query {
    final (s, w, n, e) = bbox;
    final b = '($s,$w,$n,$e)';
    return '[out:json][timeout:60];'
        '('
        'nwr["name"]["amenity"]$b;'
        'nwr["name"]["shop"]$b;'
        'nwr["name"]["office"]$b;'
        'nwr["name"]["leisure"]$b;'
        'nwr["name"]["tourism"]$b;'
        'nwr["name"]["healthcare"]$b;'
        ');'
        'out center tags;';
  }

  /// هەموو شوێنەکان دەهێنێت (هەڵەکان فڕێ دەدرێن بۆ ئەوەی شاشەکە پەیامێک پیشان بدات)
  static Future<List<OsmPlace>> fetch({http.Client? client}) async {
    final c = client ?? http.Client();
    Object? lastError;
    try {
      for (final url in _endpoints) {
        // POST، پاشان GET (هەندێک تۆڕی مۆبایل POST ڕێگە نادەن)
        for (final usePost in [true, false]) {
          try {
            final res = usePost
                ? await c
                    .post(Uri.parse(url), headers: _headers, body: {'data': query})
                    .timeout(const Duration(seconds: 70))
                : await c
                    .get(Uri.parse(url).replace(queryParameters: {'data': query}),
                        headers: _headers)
                    .timeout(const Duration(seconds: 70));
            if (res.statusCode == 200) {
              return parse(utf8.decode(res.bodyBytes));
            }
            lastError = '${Uri.parse(url).host}: HTTP ${res.statusCode}';
          } catch (e) {
            lastError = '${Uri.parse(url).host}: $e';
          }
        }
      }
    } finally {
      if (client == null) c.close();
    }
    throw Exception('OpenStreetMap: $lastError');
  }

  /// وەڵامی Overpass → لیستی شوێن (بێ دووبارە، بێ ناو فڕێ دەدرێت)
  static List<OsmPlace> parse(String body) {
    final data = jsonDecode(body);
    final elements = (data is Map ? data['elements'] : null) as List? ?? const [];
    final out = <String, OsmPlace>{};
    for (final raw in elements) {
      if (raw is! Map) continue;
      final tags = (raw['tags'] as Map?)?.map((k, v) => MapEntry('$k', '$v')) ?? {};
      final name = _pickName(tags);
      if (name == null) continue;
      final lat = (raw['lat'] ?? (raw['center'] as Map?)?['lat']) as num?;
      final lng = (raw['lon'] ?? (raw['center'] as Map?)?['lon']) as num?;
      if (lat == null || lng == null) continue;
      final id = 'osm:${raw['type']}/${raw['id']}';
      final kind = _kind(tags);
      out[id] = OsmPlace(
        externalId: id,
        name: name,
        lat: lat.toDouble(),
        lng: lng.toDouble(),
        kind: kind,
        isGovernment: _isGovernment(tags),
        phone: tags['phone'] ?? tags['contact:phone'],
        address: tags['addr:street'] ?? tags['addr:full'],
      );
    }
    final list = out.values.toList()..sort((a, b) => a.name.compareTo(b.name));
    return list;
  }

  static String? _pickName(Map<String, String> t) {
    for (final k in ['name:ckb', 'name:ku', 'name', 'name:ar', 'name:en']) {
      final v = t[k]?.trim();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  static String _kind(Map<String, String> t) {
    for (final k in ['amenity', 'healthcare', 'office', 'leisure', 'tourism']) {
      final v = t[k];
      if (v != null && v.isNotEmpty) return v;
    }
    final shop = t['shop'];
    return shop == null ? 'other' : 'shop:$shop';
  }

  static bool _isGovernment(Map<String, String> t) =>
      t['office'] == 'government' ||
      const {'police', 'fire_station', 'townhall', 'courthouse', 'post_office'}
          .contains(t['amenity']) ||
      t['operator:type'] == 'government' ||
      t['operator:type'] == 'public';

  // ═══════════════════════════════════════════════════════════
  // 🏷️ جۆری OSM → وشەی بەش (بۆ دۆزینەوەی بەشی هاوتا لە main_categories)
  // ═══════════════════════════════════════════════════════════
  static const Map<String, List<String>> _kindWords = {
    'hospital': ['تەندروستی', 'نەخۆشخانە'],
    'clinic': ['تەندروستی', 'کلینیک'],
    'doctors': ['تەندروستی', 'پزیشک'],
    'dentist': ['تەندروستی'],
    'pharmacy': ['دەرمانخانە', 'تەندروستی'],
    'restaurant': ['چێشتخانە', 'خواردن'],
    'fast_food': ['چێشتخانە', 'خواردن'],
    'cafe': ['کافێ', 'چایخانە', 'چێشتخانە'],
    'hotel': ['مێوانخانە', 'هوتێل'],
    'guest_house': ['مێوانخانە'],
    'fuel': ['بەنزین', 'سوتەمەنی', 'سووتەمەنی'],
    'school': ['پەروەردە', 'قوتابخانە'],
    'kindergarten': ['پەروەردە', 'باخچەی ساوایان'],
    'university': ['خوێندنی باڵا', 'زانکۆ'],
    'college': ['خوێندنی باڵا', 'پەیمانگا', 'کۆلێژ'],
    'place_of_worship': ['ئایینی', 'ئاینی', 'مزگەوت'],
    'bank': ['بانک'],
    'bureau_de_change': ['دراو', 'سەرافی', 'بانک'],
    'police': ['پۆلیس', 'فەرمانگە'],
    'fire_station': ['ئاگرکوژێنەوە', 'بەرگری شارستانی', 'فەرمانگە'],
    'townhall': ['شارەوانی', 'قایمقام', 'فەرمانگە'],
    'courthouse': ['فەرمانگە', 'حکومی'],
    'post_office': ['فەرمانگە', 'پەیوەندی'],
    'government': ['فەرمانگە', 'حکومی'],
    'ngo': ['ڕێکخراو'],
    'political_party': ['حزب', 'بارەگا'],
    'sports_centre': ['وەرزش', 'یاریگا'],
    'stadium': ['وەرزش', 'یاریگا'],
    'pitch': ['وەرزش', 'یاریگا'],
    'park': ['پارک', 'گەشت'],
  };

  /// بەشی گونجاو لە نێو [categories] (ناوی main_categories)؛ null = ئەدمین هەڵیدەبژێرێت
  static String? suggestCategory(String kind, List<String> categories) {
    final words = kind.startsWith('shop:')
        ? const ['بازاڕ', 'دوکان', 'فرۆشگا']
        : (_kindWords[kind] ?? const <String>[]);
    for (final w in words) {
      final key = AppLang.normalizeKey(w);
      for (final c in categories) {
        if (AppLang.normalizeKey(c).contains(key)) return c;
      }
    }
    return null;
  }

  /// ناوێکی کوردی بۆ جۆری OSM (بۆ پیشاندان لە لیستەکەدا)
  static String kindLabel(String kind) {
    if (kind.startsWith('shop:')) return 'دوکان';
    const labels = {
      'hospital': 'نەخۆشخانە', 'clinic': 'کلینیک', 'doctors': 'پزیشک',
      'dentist': 'ددانساز', 'pharmacy': 'دەرمانخانە', 'restaurant': 'چێشتخانە',
      'fast_food': 'خواردنی خێرا', 'cafe': 'کافێ', 'hotel': 'هوتێل',
      'fuel': 'بەنزینخانە', 'school': 'قوتابخانە', 'kindergarten': 'باخچەی ساوایان',
      'university': 'زانکۆ', 'college': 'کۆلێژ', 'place_of_worship': 'مزگەوت',
      'bank': 'بانک', 'bureau_de_change': 'سەرافی', 'police': 'پۆلیس',
      'fire_station': 'ئاگرکوژێنەوە', 'townhall': 'شارەوانی', 'government': 'فەرمانگە',
      'ngo': 'ڕێکخراو', 'political_party': 'بارەگای حزب', 'park': 'پارک',
    };
    return labels[kind] ?? kind;
  }

  // ═══════════════════════════════════════════════════════════
  // 🔁 دووبارەبوونەوە
  // ═══════════════════════════════════════════════════════════
  /// دووری بە مەتر
  static double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLng = (lng2 - lng1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);
    return 2 * r * math.asin(math.sqrt(a));
  }

  /// ئایا ئەم شوێنە پێشتر لە ئەپەکەدا هەیە؟
  /// [OsmMatch.same] = هەمان external_id؛ [OsmMatch.likely] = هەمان ناو و نزیکتر لە ١٢٠ م
  static OsmMatch match(OsmPlace p, List<Map<String, dynamic>> existing) {
    final name = AppLang.looseKey(p.name);
    var likely = false;
    for (final s in existing) {
      if ('${s['external_id'] ?? ''}' == p.externalId) return OsmMatch.same;
      final lat = (s['latitude'] as num?)?.toDouble();
      final lng = (s['longitude'] as num?)?.toDouble();
      if (lat == null || lng == null) continue;
      if (AppLang.looseKey('${s['name'] ?? ''}') == name &&
          distanceMeters(lat, lng, p.lat, p.lng) < 120) {
        likely = true;
      }
    }
    return likely ? OsmMatch.likely : OsmMatch.none;
  }
}

enum OsmMatch { none, likely, same }
