import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/image_service.dart';

/// 📦 شاشەی زیادکردنی بەکۆمەڵی کاڵاکان
class AdminBulkAddProductsScreen extends StatefulWidget {
  final String storeId;
  final String storeName;

  const AdminBulkAddProductsScreen({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  State<AdminBulkAddProductsScreen> createState() =>
      _AdminBulkAddProductsScreenState();
}

class _AdminBulkAddProductsScreenState
    extends State<AdminBulkAddProductsScreen> {
  final List<Map<String, dynamic>> _rows = [];
  List<Map<String, dynamic>> _mains = [], _subs = [];
  bool _loadingData = true, _loading = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    for (var r in _rows) {
      (r['name'] as TextEditingController).dispose();
      (r['price'] as TextEditingController).dispose();
      (r['description'] as TextEditingController).dispose();
    }
    super.dispose();
  }

  List<Map<String, dynamic>> _deduplicate(List<Map<String, dynamic>> rawList) {
    return rawList
        .fold<Map<String, Map<String, dynamic>>>({}, (map, item) {
      map[item['name']] = item;
      return map;
    })
        .values
        .toList();
  }

  Future<void> _fetch() async {
    final m = await Supabase.instance.client.from('main_categories').select();
    final s = await Supabase.instance.client.from('sub_categories').select();
    if (mounted) {
      setState(() {
        _mains = _deduplicate(List<Map<String, dynamic>>.from(m));
        _subs = List<Map<String, dynamic>>.from(s);
        _loadingData = false;
        if (_mains.isNotEmpty) _addRow();
      });
    }
  }

  void _addRow() {
    if (_mains.isEmpty) return;
    String main = _mains[0]['name'];
    var subList = _subs.where((s) => s['parent'] == main).toList();
    setState(() {
      _rows.add({
        'name': TextEditingController(),
        'price': TextEditingController(),
        'description': TextEditingController(),
        'main': main,
        'sub': subList.isNotEmpty ? subList[0]['name'] : 'نادیار',
        'images': <XFile>[],
      });
    });
  }

  Future<void> _pickImages(List<XFile> storeImages) async {
    if (storeImages.length >= 4) return;
    final picker = ImagePicker();
    final pickedList = await picker.pickMultiImage(imageQuality: 70);
    if (pickedList.isNotEmpty) {
      setState(() {
        int remainingSlots = 4 - storeImages.length;
        storeImages.addAll(pickedList.take(remainingSlots));
      });
    }
  }

  Future<void> _saveAll() async {
    for (var r in _rows) {
      List<XFile> imgs = r['images'];
      if (imgs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("تکایە هەر کاڵایەک بەلایەنی کەمەوە ١ وێنەی هەبێت ⚠"),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    }

    setState(() => _loading = true);
    try {
      for (var r in _rows) {
        List<XFile> imgs = r['images'];
        List<String> uploadedUrls = [];

        for (var imgFile in imgs) {
          String url = await ImageCompressionService.uploadImage(imgFile);
          uploadedUrls.add(url);
        }

        await Supabase.instance.client.from('products').insert({
          'store_id': widget.storeId,
          'name': r['name'].text,
          'price': r['price'].text,
          'category': r['sub'],
          'img': uploadedUrls.isNotEmpty ? uploadedUrls.first : '',
          'images': uploadedUrls,
          'details': {
            'main_category': r['main'],
            'description': r['description'].text,
            'sizes': ['S', 'M', 'L'],
          },
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("کاڵاکان زیادکران ✅"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("هەڵە: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingData) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.storeName)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F5F8),
        appBar: AppBar(
          title: Text(
            "زیادکردنی بەکۆمەڵ: ${widget.storeName}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Column(
          children: [
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: _rows.length,
                itemBuilder: (context, i) {
                  var r = _rows[i];
                  var subList =
                  _subs.where((s) => s['parent'] == r['main']).toList();
                  List<XFile> storeImages = r['images'];

                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
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
                        Row(
                          children: [
                            Text(
                              "کاڵای ${i + 1}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.primary,
                              ),
                            ),
                            const Spacer(),
                            IconButton(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 20,
                              ),
                              onPressed: () {
                                (r['name'] as TextEditingController).dispose();
                                (r['price'] as TextEditingController)
                                    .dispose();
                                (r['description'] as TextEditingController)
                                    .dispose();
                                setState(() => _rows.removeAt(i));
                              },
                            ),
                          ],
                        ),
                        TextField(
                          controller: r['name'],
                          decoration: const InputDecoration(
                            hintText: "ناوی کاڵا",
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButton<String>(
                                value: r['main'],
                                isExpanded: true,
                                items: _mains
                                    .map((m) => DropdownMenuItem(
                                  value: m['name'].toString(),
                                  child: Text(
                                    m['name'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                    ),
                                  ),
                                ))
                                    .toList(),
                                onChanged: (val) => setState(() {
                                  r['main'] = val!;
                                  var ns = _subs
                                      .where((s) => s['parent'] == val)
                                      .toList();
                                  r['sub'] =
                                  ns.isNotEmpty ? ns[0]['name'] : '';
                                }),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: DropdownButton<String>(
                                value: subList.any(
                                        (s) => s['name'] == r['sub'])
                                    ? r['sub']
                                    : (subList.isNotEmpty
                                    ? subList[0]['name']
                                    : null),
                                isExpanded: true,
                                items: subList
                                    .map((s) => DropdownMenuItem(
                                  value: s['name'].toString(),
                                  child: Text(
                                    s['name'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                    ),
                                  ),
                                ))
                                    .toList(),
                                onChanged: (val) =>
                                    setState(() => r['sub'] = val!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: r['price'],
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            hintText: "نرخ (د.ع)",
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: r['description'],
                          decoration: const InputDecoration(
                            hintText: "وەسف",
                            isDense: true,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(
                                storeImages.isNotEmpty
                                    ? Icons.photo_library
                                    : Icons.add_a_photo,
                                color: storeImages.isNotEmpty
                                    ? Colors.green
                                    : AppColors.primary,
                              ),
                              onPressed: storeImages.length < 4
                                  ? () => _pickImages(storeImages)
                                  : null,
                            ),
                            Text(
                              "(${storeImages.length}/4)",
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _addRow,
                      icon: const Icon(Icons.add),
                      label: const Text("زیادکردنی ڕیز"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _loading
                        ? const Center(child: CircularProgressIndicator())
                        : ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: _saveAll,
                      icon: const Icon(Icons.save),
                      label: const Text("پاشەکەوت"),
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