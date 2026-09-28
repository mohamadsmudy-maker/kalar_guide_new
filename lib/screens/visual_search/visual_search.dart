import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/ai_service.dart';
import '../../services/image_service.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../products/product_details.dart';

/// 🎨 شاشەی گەڕانی وێنەیی زیرەک
class VisualSearchScreen extends StatefulWidget {
  const VisualSearchScreen({super.key});

  @override
  State<VisualSearchScreen> createState() => _VisualSearchScreenState();
}

class _VisualSearchScreenState extends State<VisualSearchScreen> {
  bool _isAnalyzing = false;
  String _loadingText = "سەرقاڵی شیکردنەوەی وێنەکەین بە AI... ✨";

  Future<void> _pickAndSearch(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    try {
      final XFile? image =
      await picker.pickImage(source: source, imageQuality: 70);
      if (image == null) return;

      setState(() {
        _isAnalyzing = true;
        _loadingText = "AI خەریکە وێنەکە دەناسێتەوە... 🤖";
      });

      String aiKeywords = await AiService.searchByImageGivenFile(image);
      aiKeywords = aiKeywords.replaceAll(RegExp(r'[^\w\sؠ-ي]'), '').trim();

      setState(() {
        _loadingText = "گەڕان بەدوای: '$aiKeywords'... 🔍";
      });

      final bytes = await image.readAsBytes();
      final compressedBytes =
      await ImageCompressionService.compressImage(bytes);
      final fileName =
          'visual_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await Supabase.instance.client.storage
          .from('images')
          .uploadBinary(fileName, compressedBytes);

      List<Map<String, dynamic>> res = [];

      if (aiKeywords.isNotEmpty &&
          aiKeywords != "کاڵا" &&
          aiKeywords.length > 1) {
        var data = await Supabase.instance.client
            .from('products')
            .select()
            .ilike('name', '%$aiKeywords%')
            .limit(12);
        res = List<Map<String, dynamic>>.from(data);
      }

      if (res.isEmpty) {
        final generalData = await Supabase.instance.client
            .from('products')
            .select()
            .order('id', ascending: false)
            .limit(8);
        res = List<Map<String, dynamic>>.from(generalData);
      }

      final uniqueProducts = {
        for (var e in res) e['id']?.toString() ?? e['name']: e
      }.values.toList();

      if (mounted) {
        setState(() => _isAnalyzing = false);
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => _SimilarItemsScreen(
              imagePath: image.path,
              products: uniqueProducts,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isAnalyzing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("هەڵە ڕووی دا: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: const Text(
            "گەڕانی وێنەیی زیرەک",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          backgroundColor: Colors.transparent,
          iconTheme: const IconThemeData(color: Colors.white),
          elevation: 0,
        ),
        body: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: AppColors.primary,
                      size: 50,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      "وێنەی هەر کاڵایەک بگرە، با AI بە دوایدا بگەڕێت و کاڵای هاوشێوەت بۆ بدۆزێتەوە 📸✨",
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    GestureDetector(
                      onTap: _isAnalyzing
                          ? null
                          : () => _pickAndSearch(ImageSource.camera),
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 4),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              color: Colors.white,
                              size: 38,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isAnalyzing)
              Container(
                color: Colors.black87,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _loadingText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              bottom: 30,
              left: 20,
              right: 20,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    onPressed: () => _pickAndSearch(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_rounded),
                    label: const Text(
                      "هەڵبژاردنی وێنە لە گالەری",
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SimilarItemsScreen extends StatelessWidget {
  final String imagePath;
  final List<Map<String, dynamic>> products;

  const _SimilarItemsScreen({
    required this.imagePath,
    required this.products,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F5F8),
        appBar: AppBar(
          title: const Text(
            "کاڵا هاوشێوەکان",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 1,
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.white,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(imagePath),
                      width: 60,
                      height: 60,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "کاڵا دۆزراوە هاوشێوەکان",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        "باشترین ئەنجامەکان بۆ وێنەکەی تۆ",
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Expanded(
              child: products.isEmpty
                  ? const Center(
                child: Text("هیچ کاڵایەکی هاوشێوە نەدۆزرایەوە 📦"),
              )
                  : GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 0.72,
                ),
                itemCount: products.length,
                itemBuilder: (context, index) {
                  var prod = products[index];
                  return GestureDetector(
                    onTap: () =>
                        ProductDetailsSheet.show(context, prod),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: OptimizedNetworkImage(
                                imageUrl: prod['img'] ?? '',
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Column(
                              crossAxisAlignment:
                              CrossAxisAlignment.start,
                              children: [
                                Text(
                                  prod['name'] ?? '',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "${prod['price'] ?? ''} د.ع",
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}