import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/app_control.dart';
import 'package:kalar_guide_new/services/complaint_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory tmp;
  late List<Map<String, dynamic>> inserted;
  var online = true;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('cq');
    inserted = [];
    online = true;
    ComplaintQueue.storageDir = () async => tmp;
    ComplaintQueue.uploadImage = (p) async {
      if (!online) throw const SocketException('offline');
      return 'https://cdn/${p.split('/').last}';
    };
    ComplaintQueue.uploadVoice = (p) async => 'https://cdn/voice';
    ComplaintQueue.insert = (row) async {
      if (!online) throw const SocketException('offline');
      inserted.add(row);
    };
  });
  tearDown(() => tmp.delete(recursive: true));

  Future<String> file(String name) async {
    final f = File('${tmp.path}/$name')..writeAsStringSync('x');
    return f.path;
  }

  test('بێ ئینتەرنێت دەمێنێتەوە، دواتر دەنێردرێت و فایلەکان دەسڕدرێنەوە', () async {
    final img = await file('photo.jpg');
    final item = await ComplaintQueue.enqueue(
      data: {'title': 'خۆڵ کۆنەکراوەتەوە', 'status': 'pending'},
      images: [img],
      voice: await file('v.m4a'),
    );
    expect(ComplaintQueue.pending.value, 1);
    expect(File(item.images.single).existsSync(), isTrue, reason: 'copied to permanent storage');

    online = false;
    expect(await ComplaintQueue.flush(), 0);
    expect((await ComplaintQueue.load()).length, 1, reason: 'kept for later');

    online = true;
    expect(await ComplaintQueue.flush(), 1);
    expect(inserted.single['title'], 'خۆڵ کۆنەکراوەتەوە');
    expect(inserted.single['images'], ['https://cdn/img0.jpg']);
    expect(inserted.single['voice_url'], 'https://cdn/voice');
    expect(await ComplaintQueue.load(), isEmpty);
    expect(ComplaintQueue.pending.value, 0);
    expect(File(item.images.single).existsSync(), isFalse, reason: 'files cleaned up');
  });

  test('چەند سکاڵا بە ڕیز دەنێردرێن', () async {
    await ComplaintQueue.enqueue(data: {'title': 'a'}, images: [await file('a.jpg')]);
    await ComplaintQueue.enqueue(data: {'title': 'b'}, images: [await file('b.jpg')]);
    expect(await ComplaintQueue.flush(), 2);
    expect(inserted.map((e) => e['title']), ['a', 'b']);
  });

  test('complaint_mode: بە بنەڕەت هەموو کێشەکانی شار', () {
    final def = AppControlState.fromRows(const []);
    expect(def.wasteOnlyComplaints, isFalse);
    expect(def.wasteAuthority, AppControlState.defaultWasteAuthority);
    final off = AppControlState.fromRows(const [
      {'key': 'complaint_mode', 'value': {'waste_only': true, 'authority': 'کۆمپانیای پاکی'}},
    ]);
    expect(off.wasteOnlyComplaints, isTrue);
    expect(off.wasteAuthority, 'کۆمپانیای پاکی');
  });
}
