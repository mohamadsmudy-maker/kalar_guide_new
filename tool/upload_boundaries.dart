// tool/upload_boundaries.dart
//
// ئەم سکریپتە فایلی GeoJSON دەخوێنێتەوە و گەڕەکەکان
// بە سنوورەکانیانەوە دەخاتە ناو Supabase.
//
// جێبەجێکردن:
//   dart run tool/upload_boundaries.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;  // ✅ زیادکرا بۆ sin
import 'package:supabase/supabase.dart';

void main() async {
  // ═══════════════════════════════════════════════════════════
  // 🔑 ڕێکخستن
  // ═══════════════════════════════════════════════════════════
  const supabaseUrl = 'https://krqrhrqtmcpwpcsxkaql.supabase.co';
  const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtycXJocnF0bWNwd3Bjc3hrYXFsIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg5NDg4MzIsImV4cCI6MjEwNDUyNDgzMn0.2jFpZfH3x9POPboN841XM8pu6uqErX6Viq5Luvgbldo';

  const geoJsonFile = 'assets/data/kelar_boundaries.geojson';

  print('');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('📂 خوێندنەوەی: $geoJsonFile');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

  // ═══════════════════════════════════════════════════════════
  // 📖 خوێندنەوەی GeoJSON
  // ═══════════════════════════════════════════════════════════
  final file = File(geoJsonFile);
  if (!file.existsSync()) {
    print('❌ فایلی GeoJSON نەدۆزرایەوە!');
    return;
  }

  final json = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  final features = json['features'] as List;

  print('✅ ${features.length} گەڕەک دۆزرایەوە لە GeoJSON');
  print('');

  // ═══════════════════════════════════════════════════════════
  // 🔌 پەیوەندی بە Supabase
  // ═══════════════════════════════════════════════════════════
  final supabase = SupabaseClient(supabaseUrl, supabaseKey);

  int successCount = 0;
  int updateCount = 0;
  int errorCount = 0;

  // ═══════════════════════════════════════════════════════════
  // 📤 خستنە ناو
  // ═══════════════════════════════════════════════════════════
  for (int i = 0; i < features.length; i++) {
    final feature = features[i];
    final props = feature['properties'] as Map<String, dynamic>;
    final geom = feature['geometry'] as Map<String, dynamic>;

    final name = props['name'] as String;
    final polygonCoords = geom['coordinates'] as List;
    final ring = (polygonCoords.first as List);

    // گۆڕینی کۆئۆردینەت
    final boundaryPoints = ring.map((coord) {
      final c = coord as List;
      return {
        'lat': (c[1] as num).toDouble(),
        'lng': (c[0] as num).toDouble(),
      };
    }).toList();

    // حسابکردنی ناوەند
    double sumLat = 0, sumLng = 0;
    for (final p in boundaryPoints) {
      sumLat += p['lat'] as double;
      sumLng += p['lng'] as double;
    }
    final centerLat = sumLat / boundaryPoints.length;
    final centerLng = sumLng / boundaryPoints.length;

    // حسابکردنی ڕووبەر
    final areaKm2 = _calculateArea(boundaryPoints);

    try {
      // پشکنین ئەگەر گەڕەک هەیە
      final existing = await supabase
          .from('neighborhoods')
          .select('id')
          .eq('name_ku', name)
          .maybeSingle();

      final data = {
        'name_ku': name,
        'center_latitude': centerLat,
        'center_longitude': centerLng,
        'center_lat': centerLat,
        'center_lng': centerLng,
        'boundary': boundaryPoints,
        'area_km2': areaKm2,
        'display_order': i + 1,
        'is_active': true,
      };

      if (existing != null) {
        await supabase
            .from('neighborhoods')
            .update(data)
            .eq('id', existing['id']);
        print('🔄 نوێکرایەوە: $name');
        updateCount++;
      } else {
        await supabase.from('neighborhoods').insert(data);
        print('✅ زیادکرا: $name');
        successCount++;
      }
    } catch (e) {
      print('❌ هەڵە لە $name: $e');
      errorCount++;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 ئەنجام
  // ═══════════════════════════════════════════════════════════
  print('');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('📊 ئەنجامەکان');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('✅ زیادکراو: $successCount');
  print('🔄 نوێکراو: $updateCount');
  print('❌ هەڵە: $errorCount');
  print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
  print('');
}

// ═══════════════════════════════════════════════════════════
// 📐 حسابکردنی ڕووبەر (Shoelace Formula)
// ═══════════════════════════════════════════════════════════
double _calculateArea(List<Map<String, dynamic>> points) {
  if (points.length < 3) return 0;

  const earthRadius = 6371000.0; // مەتر
  double area = 0;

  for (int i = 0; i < points.length; i++) {
    final p1 = points[i];
    final p2 = points[(i + 1) % points.length];

    final lat1 = (p1['lat'] as double) * math.pi / 180;
    final lat2 = (p2['lat'] as double) * math.pi / 180;
    final lng1 = (p1['lng'] as double) * math.pi / 180;
    final lng2 = (p2['lng'] as double) * math.pi / 180;

    // ✅ چاککراو — math.sin
    area += (lng2 - lng1) *
        (2 + math.sin(lat1).abs() + math.sin(lat2).abs());
  }

  area = area * earthRadius * earthRadius / 2;
  return (area.abs() / 1000000); // بۆ کم²
}