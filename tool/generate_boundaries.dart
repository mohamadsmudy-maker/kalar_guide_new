// tool/generate_boundaries.dart
//
// ئەم سکریپتە فایلی Excel دەخوێنێتەوە و GeoJSON دروست دەکات
// بە CRS ی WGS84 (EPSG:4326) بۆ بەکارهێنان لە Google Maps.
//
// جێبەجێکردن:
//   dart run tool/generate_boundaries.dart

import 'dart:convert';
import 'dart:io';
import 'package:excel/excel.dart';
import 'package:proj4dart/proj4dart.dart';

void main() {
  // ===== ڕێکخستن =====
  const inputFile = 'assets/data/خاڵی گەڕەکەکانی کەلار.xlsx';
  const outputFile = 'assets/data/kelar_boundaries.geojson';
  const invalidFile = 'assets/data/invalid_neighborhoods.json';

  // ===== پشکنینی فایل =====
  final input = File(inputFile);
  if (!input.existsSync()) {
    print('❌ فایلی Excel نەدۆزرایەوە: $inputFile');
    print('   دڵنیابە فایلەکە لە assets/data/ دایە.');
    return;
  }

  print('📂 خوێندنەوەی: $inputFile');

  // ===== خوێندنەوەی Excel =====
  final bytes = input.readAsBytesSync();
  final excel = Excel.decodeBytes(bytes);

  if (excel.tables.isEmpty) {
    print('❌ فایلی Excel بەتاڵە!');
    return;
  }

  final sheetName = excel.tables.keys.first;
  final sheet = excel.tables[sheetName]!;
  print('📄 شییت: $sheetName — ${sheet.maxRows} ڕیز');

  // ===== کۆکردنەوەی داتا بەپێی گەڕەک =====
  final Map<String, List<Map<String, double>>> neighborhoods = {};

  // ڕیزی ٠ سەرێکە، لە ڕیزی ١ دەست پێدەکەین
  for (var i = 1; i < sheet.maxRows; i++) {
    final row = sheet.row(i);
    if (row.length < 4) continue;

    final aCell = row[0]?.value;
    final bCell = row[1]?.value;
    final cCell = row[2]?.value;
    final dCell = row[3]?.value;

    final a = _toDouble(aCell);
    final b = _toDouble(bCell);
    final c = _toDouble(cCell);
    final d = dCell?.toString().trim() ?? '';

    if (a == null || b == null || c == null || d.isEmpty) continue;

    neighborhoods.putIfAbsent(d, () => []);
    neighborhoods[d]!.add({'A': a, 'B': b, 'C': c});
  }

  print('🏘️  ژمارەی گەڕەکەکان: ${neighborhoods.length}');

  // ===== ئامادەکردنی گۆڕەرەوەکانی پڕۆجێکشن =====
  final utm38n = Projection.parse(
    '+proj=utm +zone=38 +datum=WGS84 +units=m +no_defs',
  );
  final wgs84 = Projection.parse(
    '+proj=longlat +datum=WGS84 +no_defs',
  );

  // ===== دروستکردنی پۆلیگۆن =====
  final List<Map<String, dynamic>> features = [];
  final List<Map<String, dynamic>> invalid = [];

  neighborhoods.forEach((name, points) {
    // ١) ڕیزبەندی بەپێی A
    points.sort((x, y) => x['A']!.compareTo(y['A']!));

    // ٢) لابردنی خاڵی دووبارە
    final unique = <List<double>>[];
    final seen = <String>{};

    for (final p in points) {
      final key = '${p['B']},${p['C']}';
      if (!seen.contains(key)) {
        seen.add(key);
        unique.add([p['B']!, p['C']!]);
      }
    }

    // ٣) پشکنینی ژمارەی خاڵ
    if (unique.length < 3) {
      invalid.add({
        'name': name,
        'reason': 'کەمتر لە ٣ خاڵ',
        'points': unique.length,
      });
      return;
    }

    // ٤) داخستنی پۆلیگۆن (خاڵی یەکەم دووبارە بکەوە لە کۆتایی)
    final ring = [...unique, unique.first];

    // ٥) گۆڕینی UTM → WGS84 (Lon, Lat)
    final lonLatRing = <List<double>>[];
    for (final pt in ring) {
      final transformed = utm38n.transform(
        wgs84,
        Point(x: pt[0], y: pt[1]),
      );
      lonLatRing.add([
        _round(transformed.x, 7), // Lon
        _round(transformed.y, 7), // Lat
      ]);
    }

    // ٦) زیادکردنی Feature
    features.add({
      'type': 'Feature',
      'properties': {
        'name': name,
        'points': unique.length,
      },
      'geometry': {
        'type': 'Polygon',
        'coordinates': [lonLatRing],
      },
    });
  });

  // ===== دروستکردنی GeoJSON =====
  final geoJson = {
    'type': 'FeatureCollection',
    'crs': {
      'type': 'name',
      'properties': {'name': 'urn:ogc:def:crs:EPSG::4326'},
    },
    'features': features,
  };

  // ===== دڵنیابوون لە فۆلدەر =====
  Directory('assets/data').createSync(recursive: true);

  // ===== پاشەکەوتکردن =====
  File(outputFile).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(geoJson),
  );

  File(invalidFile).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert(invalid),
  );

  // ===== ئەنجام =====
  print('');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('✅ تەواو بوو!');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('   ${features.length} پۆلیگۆن دروستکرا → $outputFile');
  print('   ${invalid.length} گەڕەک نەتوانرا → $invalidFile');

  if (invalid.isNotEmpty) {
    print('');
    print('⚠️  گەڕەکە نادروستەکان:');
    for (final item in invalid) {
      print('   • ${item['name']} — ${item['reason']}');
    }
  }
}

// ===== گۆڕینی بەها بۆ double =====
double? _toDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

// ===== خاڵکردنەوەی ژمارە =====
double _round(double value, int decimals) {
  final factor = _pow10(decimals);
  return (value * factor).round() / factor;
}

double _pow10(int n) {
  var result = 1.0;
  for (var i = 0; i < n; i++) {
    result *= 10;
  }
  return result;
}