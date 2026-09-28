import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/ai_service.dart';
import '../../services/image_service.dart';

/// 🛍️ شاشەی زیادکردنی کاڵا بۆ فرۆشیار
class VendorAddProductScreen extends StatefulWidget {
  final String storeId;
  final String storeName;

  const VendorAddProductScreen({
    super.key,
    required this.storeId,
    required this.storeName,
  });

  @override
  State<VendorAddProductScreen> createState() =>
      _VendorAddProductScreenState();
}

class _VendorAddProductScreenState extends State<VendorAddProductScreen> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  List<Map<String, dynamic>> _mains = [];
  List<Map<String, dynamic>> _subs = [];
  bool _loadingData = true;
  bool _loading = false;

  String? _selectedMain;
  String? _selectedSub;
  final List<XFile> _images = [];

  @override
  void initState() {
    super.initState();
    _fetchCategories();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _descCtrl.dispose();
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

  Future<void> _fetchCategories() async {
    try {
      final m = await Supabase.instance.client.from('main_categories').select();
      final s = await Supabase.instance.client.from('sub_categories').select();
      if (mounted) {
        setState(() {
          _mains = _deduplicate(List<Map<String, dynamic>>.from(m));
          _subs = List<Map<String, dynamic>>.from(s);
          if (_mains.isNotEmpty) _selectedMain = _mains[0]['name'];
          var subList =
          _subs.where((sub) => sub['parent'] == _selectedMain).toList();
          if (subList.isNotEmpty) _selectedSub = subList[0]['name'];
          _loadingData = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedList = await picker.pickMultiImage(imageQuality: 70);
    if (pickedList.isNotEmpty) {
      setState(() {
        int remainingSlots = 4 - _images.length;
        _images.addAll(pickedList.take(remainingSlots));
      });
    }
  }

  Future<void> _generateAiDescription() async {
    if (_nameCtrl.text.trim().isEmpty || _priceCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تکایە سەرەتا ناو و نرخی کاڵا بنووسە ⚠"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("AI سەرقاڵی نووسینی وەسفە... ✨")),
    );

    try {
      String aiDesc = await AiService.generateDescription(
        _nameCtrl.text.trim(),
        _priceCtrl.text.trim(),
      );
      setState(() => _descCtrl.text = aiDesc);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("هەڵە: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _saveProduct() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _priceCtrl.text.trim().isEmpty ||
        _images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تکایە ناو، نرخ و وێنەی کاڵا پڕبکەوە ⚠"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      List<String> uploadedUrls = [];
      for (var imgFile in _images) {
        String url = await ImageCompressionService.uploadImage(imgFile);
        uploadedUrls.add(url);
      }

      await Supabase.instance.client.from('products').insert({
        'store_id': widget.storeId,
        'name': _nameCtrl.text.trim(),
        'price': _priceCtrl.text.trim(),
        'category': _selectedSub ?? '',
        'img': uploadedUrls.isNotEmpty ? uploadedUrls.first : '',
        'images': uploadedUrls,
        'details': {
          'main_category': _selectedMain ?? '',
          'description': _descCtrl.text.trim(),
          'sizes': ['S', 'M', 'L'],
        },
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("کاڵاکە بە سەرکەوتوویی زیادکرا ✅"),
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
        appBar: AppBar(
          title: Text("زیادکردنی کاڵا بۆ ${widget.storeName}"),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    var subList =
    _subs.where((s) => s['parent'] == _selectedMain).toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F5F8),
        appBar: AppBar(
          title: Text(
            "زیادکردنی کاڵا: ${widget.storeName}",
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _nameCtrl,
                  decoration: InputDecoration(
                    labelText: "ناوی کاڵا *",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: "بەشی سەرەکی",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        initialValue: _mains.any((m) => m['name'] == _selectedMain)
                            ? _selectedMain
                            : null,
                        items: _mains
                            .map((m) => DropdownMenuItem(
                          value: m['name'].toString(),
                          child: Text(
                            m['name'],
                            style: const TextStyle(fontSize: 12),
                          ),
                        ))
                            .toList(),
                        onChanged: (val) {
                          setState(() {
                            _selectedMain = val!;
                            var ns = _subs
                                .where((s) => s['parent'] == val)
                                .toList();
                            _selectedSub =
                            ns.isNotEmpty ? ns[0]['name'] : '';
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: "بەشی لاوەکی",
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        initialValue: subList.any((s) => s['name'] == _selectedSub)
                            ? _selectedSub
                            : (subList.isNotEmpty
                            ? subList[0]['name']
                            : null),
                        items: subList
                            .map((s) => DropdownMenuItem(
                          value: s['name'].toString(),
                          child: Text(
                            s['name'],
                            style: const TextStyle(fontSize: 12),
                          ),
                        ))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedSub = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: "نرخ (د.ع) *",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: "وەسف",
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    suffixIcon: IconButton(
                      icon: const Icon(
                        Icons.auto_awesome,
                        color: AppColors.primary,
                      ),
                      tooltip: "وەسف بە AI ✨",
                      onPressed: _generateAiDescription,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "وێنەکان (تا 4 وێنە) *",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _images.length < 4 ? _pickImages : null,
                  child: Container(
                    height: 110,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    child: _images.isEmpty
                        ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.add_a_photo_rounded,
                          color: AppColors.primary,
                          size: 32,
                        ),
                        SizedBox(height: 6),
                        Text(
                          "کرتە بکە بۆ دانانی وێنە",
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    )
                        : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.all(8),
                      itemCount: _images.length +
                          (_images.length < 4 ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i == _images.length) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.add_circle,
                                  size: 36,
                                  color: AppColors.primary,
                                ),
                                onPressed: _pickImages,
                              ),
                            ),
                          );
                        }
                        return Container(
                          width: 90,
                          margin: const EdgeInsets.only(right: 8),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(_images[i].path),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => setState(
                                        () => _images.removeAt(i),
                                  ),
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                    ),
                                    padding: const EdgeInsets.all(4),
                                    child: const Icon(
                                      Icons.close,
                                      size: 12,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _saveProduct,
                    child: const Text(
                      "پاشەکەوتکردنی کاڵا ✅",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}