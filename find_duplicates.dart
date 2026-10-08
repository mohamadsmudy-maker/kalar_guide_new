import 'dart:io';

void main() {
  // دەگەڕێین لە هەموو پرۆژەکە، نەک تەنها lib
  final rootDir = Directory('.');

  // ناوی فایل → لیستی ڕێگاکان
  final Map<String, List<String>> filesByName = {};

  // ئەم فۆڵدەرانە پشت گوێ بخە
  const skipFolders = {
    '.dart_tool',
    'build',
    '.git',
    '.idea',
    'windows',
    'linux',
    'macos',
    'web',
    'android',
    'ios',
    'node_modules',
  };

  print('🔍 گەڕان بۆ فایلە دووبارەکان لە هەموو پرۆژەکە...\n');

  for (final entity in rootDir.listSync(recursive: true)) {
    if (entity is! File) continue;
    if (!entity.path.endsWith('.dart')) continue;

    // پشکنینی فۆڵدەرەکانی پشت گوێخراو
    final parts = entity.path.split(Platform.pathSeparator);
    if (parts.any(skipFolders.contains)) continue;

    final name = entity.uri.pathSegments.last;
    filesByName.putIfAbsent(name, () => []).add(entity.path);
  }

  // دۆزینەوەی دووبارەکان
  int count = 0;
  final duplicates = <String, List<String>>{};

  filesByName.forEach((name, paths) {
    if (paths.length > 1) {
      count++;
      duplicates[name] = paths;
    }
  });

  if (count == 0) {
    print('✅ هیچ فایلێکی دووبارە نەدۆزرایەوە!');
    print('   پرۆژەکە پاکە 🎉');
    return;
  }

  // پیشاندانی ئەنجام
  print('⚠️  کۆی: $count فایلی دووبارە:\n');

  duplicates.forEach((name, paths) {
    print('📄 $name (${paths.length} کۆپی):');
    for (final p in paths) {
      print('   → $p');
    }
    print('');
  });

  // پشکنینی ناوی کلاسەکان
  print('\n═══════════════════════════════════');
  print('🔎 پشکنینی ناوی Class ی دووبارە...');
  print('═══════════════════════════════════\n');

  final Map<String, List<String>> classLocations = {};
  final classRegex = RegExp(r'^class\s+(\w+)', multiLine: true);

  for (final entry in filesByName.entries) {
    if (entry.value.length != 1) continue;
    final path = entry.value.first;

    try {
      final content = File(path).readAsStringSync();
      final matches = classRegex.allMatches(content);

      for (final m in matches) {
        final className = m.group(1)!;
        classLocations.putIfAbsent(className, () => []).add(path);
      }
    } catch (_) {}
  }

  int dupClasses = 0;
  classLocations.forEach((className, paths) {
    if (paths.length > 1) {
      dupClasses++;
      print('🚨 class $className (${paths.length} شوێن):');
      for (final p in paths) {
        print('   → $p');
      }
      print('');
    }
  });

  if (dupClasses == 0) {
    print('✅ هیچ Class ی دووبارە نییە');
  } else {
    print('📊 کۆی: $dupClasses Class ی دووبارە');
  }
}