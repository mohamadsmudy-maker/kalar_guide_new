import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// 🖼️ فەنکشنی ئایزۆلەیت بۆ کۆمپرێسکردنی وێنە
@pragma('vm:entry-point')
Uint8List processImageInIsolate(Uint8List imageBytes) {
  final image = img.decodeImage(imageBytes);
  if (image == null) return imageBytes;
  final resized = img.copyResize(image, width: 800);
  return Uint8List.fromList(img.encodeJpg(resized, quality: 70));
}

/// 🖼️ خزمەتگوزاری کۆمپرێس و ئەپلۆدی وێنە
class ImageCompressionService {
  /// کۆمپرێسکردنی وێنە
  static Future<Uint8List> compressImage(Uint8List imageBytes) async {
    return await compute(processImageInIsolate, imageBytes);
  }

  /// ئەپلۆدی وێنە بۆ Supabase Storage و وەرگرتنی URL
  static Future<String> uploadImage(XFile file) async {
    final bytes = await file.readAsBytes();
    final compressedBytes = await compressImage(bytes);
    final fileName = 'img_${DateTime.now().millisecondsSinceEpoch}.jpg';

    await Supabase.instance.client.storage
        .from('images')
        .uploadBinary(fileName, compressedBytes);

    return Supabase.instance.client.storage.from('images').getPublicUrl(fileName);
  }
}