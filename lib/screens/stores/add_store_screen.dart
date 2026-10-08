import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../services/image_service.dart';
import 'map_picker.dart';

/// 🏪 شاشەی زیادکردن / دەستکاریکردنی شوێن — Full Pro Edition
class AddStoreScreen extends StatefulWidget {
  final Map<String, dynamic>? storeToEdit;

  const AddStoreScreen({super.key, this.storeToEdit});

  @override
  State<AddStoreScreen> createState() => _AddStoreScreenState();
}

class _AddStoreScreenState extends State<AddStoreScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _descController = TextEditingController();

  String? _selectedMainCategory;
  String? _selectedSubCategory;
  String _storeType = 'حکومی';

  List<String> _mainCategories = [];
  List<String> _subCategories = [];

  // ✅ وێنەکان
  final List<XFile> _storeImages = [];
  XFile? _logoImage;

  // ✅ وێنە کۆنەکان (لە کاتی دەستکاریکردن)
  List<String> _existingImages = [];
  String? _existingLogo;

  bool _loading = false;
  bool _gettingLocation = false;

  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    if (widget.storeToEdit != null) {
      _nameController.text = widget.storeToEdit!['name'] ?? '';
      _phoneController.text = widget.storeToEdit!['phone'] ?? '';
      _addressController.text = widget.storeToEdit!['address'] ?? '';
      _descController.text = widget.storeToEdit!['description'] ?? '';
      _selectedMainCategory = widget.storeToEdit!['category'];
      _selectedSubCategory = widget.storeToEdit!['sub_category'];
      _storeType = widget.storeToEdit!['type'] ?? 'حکومی';
      _latitude = double.tryParse(
        widget.storeToEdit!['latitude']?.toString() ?? '',
      );
      _longitude = double.tryParse(
        widget.storeToEdit!['longitude']?.toString() ?? '',
      );

      // ✅ وێنەکانی کۆن
      final oldImages = widget.storeToEdit!['images'];
      if (oldImages is List) {
        _existingImages = List<String>.from(
          oldImages.map((e) => e.toString()),
        );
      } else if (widget.storeToEdit!['image'] != null &&
          widget.storeToEdit!['image'].toString().isNotEmpty) {
        _existingImages = [widget.storeToEdit!['image'].toString()];
      }

      _existingLogo = widget.storeToEdit!['logo']?.toString();
    }
    _fetchCategories();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      final res = await Supabase.instance.client
          .from('main_categories')
          .select('name')
          .order('name');

      final List<dynamic> rawList = res as List;

      if (mounted) {
        setState(() {
          _mainCategories = rawList
              .map((e) => e['name'].toString())
              .toSet()
              .toList();

          if (_selectedMainCategory != null &&
              _mainCategories.contains(_selectedMainCategory)) {
            _fetchSubCategories(_selectedMainCategory!);
          }
        });
      }
    } catch (e) {
      debugPrint('❌ Categories error: $e');
    }
  }

  Future<void> _fetchSubCategories(String mainCategory) async {
    try {
      final res = await Supabase.instance.client
          .from('sub_categories')
          .select('name')
          .eq('parent', mainCategory)
          .order('name');

      final List<dynamic> rawList = res as List;

      if (mounted) {
        setState(() {
          _subCategories =
              rawList.map((e) => e['name'].toString()).toList();
          if (_selectedSubCategory != null &&
              !_subCategories.contains(_selectedSubCategory)) {
            _selectedSubCategory = null;
          }
        });
      }
    } catch (e) {
      debugPrint('❌ SubCategories error: $e');
    }
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final pickedList = await picker.pickMultiImage(imageQuality: 70);
    if (pickedList.isNotEmpty) {
      setState(() {
        int remainingSlots = 3 - _storeImages.length;
        _storeImages.addAll(pickedList.take(remainingSlots));
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _gettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackBar('تکایە GPS هەڵبکە ⚠', Colors.orange);
        setState(() => _gettingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackBar('مۆڵەتی لۆکەیشن ڕەتکرایەوە ❌', Colors.red);
          setState(() => _gettingLocation = false);
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });

      _showSnackBar('GPS وەرگیرا ✅', Colors.green);
    } catch (e) {
      _showSnackBar('هەڵە: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _gettingLocation = false);
    }
  }

  Future<void> _openMapPicker() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLat: _latitude,
          initialLng: _longitude,
        ),
      ),
    );

    if (result == null) return;

    if (result is Map) {
      final location = result['location'] as gmaps.LatLng?;

      setState(() {
        if (location != null) {
          _latitude = location.latitude;
          _longitude = location.longitude;
        }

        final poiName = result['name']?.toString() ?? '';
        final poiAddress = result['address']?.toString() ?? '';
        final poiPhone = result['phone']?.toString() ?? '';

        if (poiName.isNotEmpty && _nameController.text.trim().isEmpty) {
          _nameController.text = poiName;
        }
        if (poiAddress.isNotEmpty &&
            _addressController.text.trim().isEmpty) {
          _addressController.text = poiAddress;
        }
        if (poiPhone.isNotEmpty && _phoneController.text.trim().isEmpty) {
          _phoneController.text = poiPhone;
        }
      });

      _showSnackBar('زانیاری شوێنەکە هێنرا ✅', Colors.green);
    } else if (result is gmaps.LatLng) {
      setState(() {
        _latitude = result.latitude;
        _longitude = result.longitude;
      });
      _showSnackBar('شوێن هەڵبژێردرا ✅', Colors.green);
    }
  }

  void _showSnackBar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(fontSize: 12)),
          backgroundColor: color,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }
  }

  Future<void> _saveStore() async {
    if (_nameController.text.trim().isEmpty) {
      _showSnackBar('ناوی شوێن بنووسە ⚠', Colors.orange);
      return;
    }
    if (_selectedMainCategory == null) {
      _showSnackBar('کەرت هەڵبژێرە ⚠', Colors.orange);
      return;
    }
    if (_addressController.text.trim().isEmpty) {
      _showSnackBar('ناونیشان بنووسە ⚠', Colors.orange);
      return;
    }

    setState(() => _loading = true);

    try {
      final storeName = _nameController.text.trim();

      // ✅ پشکنینی ناوی دووبارە
      final existingStore = await Supabase.instance.client
          .from('dukan')
          .select('id')
          .eq('name', storeName)
          .neq('id', widget.storeToEdit?['id'] ?? -1)
          .maybeSingle();

      if (existingStore != null) {
        _showSnackBar('شوێنێک بەم ناوە پێشتر هەیە! ❌', Colors.red);
        setState(() => _loading = false);
        return;
      }

      // ✅ ١. بارکردنی هەموو وێنە نوێیەکان
      List<String> newImageUrls = [];
      if (_storeImages.isNotEmpty) {
        for (var img in _storeImages) {
          try {
            final url = await ImageCompressionService.uploadImage(img);
            newImageUrls.add(url);
          } catch (e) {
            debugPrint('❌ Image upload error: $e');
          }
        }
      }

      // ✅ ٢. کۆکردنەوەی هەموو وێنەکان (کۆن + نوێ)
      final allImages = [..._existingImages, ...newImageUrls];

      // ✅ ٣. بارکردنی لۆگۆ
      String logoUrl = _existingLogo ?? '';
      if (_logoImage != null) {
        try {
          logoUrl = await ImageCompressionService.uploadImage(_logoImage!);
        } catch (e) {
          debugPrint('❌ Logo upload error: $e');
        }
      }

      // ✅ ٤. دروستکردنی داتا
      final storeData = {
        'name': storeName,
        'phone': _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        'address': _addressController.text.trim(),
        'description': _descController.text.trim(),
        'category': _selectedMainCategory,
        'sub_category': _selectedSubCategory,
        'type': _storeType,
        'latitude': _latitude,
        'longitude': _longitude,
        'image': allImages.isNotEmpty ? allImages.first : '',
        'images': allImages, // ✅ هەموو وێنەکان
        'logo': logoUrl.isNotEmpty ? logoUrl : null,
      };

      if (widget.storeToEdit == null) {
        storeData['created_at'] = DateTime.now().toIso8601String();
        await Supabase.instance.client.from('dukan').insert(storeData);
        _showSnackBar('زیادکرا ✅', Colors.green);
      } else {
        await Supabase.instance.client
            .from('dukan')
            .update(storeData)
            .eq('id', widget.storeToEdit!['id']);
        _showSnackBar('نوێکرایەوە ✅', Colors.green);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint('❌ Save store error: $e');
      _showSnackBar('هەڵە: $e', Colors.red);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.storeToEdit != null;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor:
        isDark ? const Color(0xFF0F0F14) : const Color(0xFFF4F6F9),
        appBar: AppBar(
          title: Text(
            isEditing ? 'دەستکاریکردنی شوێن' : 'زیادکردنی شوێن',
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageSection(isDark),
              const SizedBox(height: 12),
              _buildInfoSection(isDark),
              const SizedBox(height: 12),
              _buildLocationSection(isDark),
              const SizedBox(height: 20),
              _buildActionButtons(isEditing),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImageSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'وێنەکان',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                // ✅ لۆگۆ
                GestureDetector(
                  onTap: () async {
                    final picked = await ImagePicker().pickImage(
                      source: ImageSource.gallery,
                      imageQuality: 70,
                    );
                    if (picked != null) {
                      setState(() => _logoImage = picked);
                    }
                  },
                  child: Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(left: 8),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Colors.purple.shade200,
                        width: 2,
                      ),
                    ),
                    child: _logoImage != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.file(
                        File(_logoImage!.path),
                        fit: BoxFit.cover,
                      ),
                    )
                        : (_existingLogo != null &&
                        _existingLogo!.isNotEmpty)
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _existingLogo!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Column(
                          mainAxisAlignment:
                          MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.business_rounded,
                              color: Colors.purple.shade400,
                              size: 28,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'لۆگۆ',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.purple.shade700,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                        : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.business_rounded,
                          color: Colors.purple.shade400,
                          size: 28,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'لۆگۆ',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.purple.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // ✅ وێنە کۆنەکان
                ..._existingImages.asMap().entries.map((entry) {
                  return Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(left: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.network(
                            entry.value,
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade200,
                              child: const Icon(
                                Icons.broken_image,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => setState(
                                  () => _existingImages.removeAt(entry.key),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
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
                }),

                // ✅ وێنە نوێیەکان
                ..._storeImages.asMap().entries.map((entry) {
                  return Container(
                    width: 100,
                    height: 100,
                    margin: const EdgeInsets.only(left: 8),
                    child: Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: Image.file(
                            File(entry.value.path),
                            width: 100,
                            height: 100,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => setState(
                                  () => _storeImages.removeAt(entry.key),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
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
                }),

                // ✅ دوگمەی زیادکردن
                if (_storeImages.length + _existingImages.length < 3)
                  GestureDetector(
                    onTap: _pickImages,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color:
                        AppColors.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_rounded,
                            color: AppColors.primary,
                            size: 30,
                          ),
                          SizedBox(height: 4),
                          Text(
                            'زیادکردن',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDropdown(
                  label: 'کەرت *',
                  value: _selectedMainCategory,
                  items: _mainCategories,
                  isDark: isDark,
                  onChanged: (val) {
                    setState(() {
                      _selectedMainCategory = val;
                      _selectedSubCategory = null;
                    });
                    if (val != null) _fetchSubCategories(val);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildDropdown(
                  label: 'ژێربەش',
                  value: _selectedSubCategory,
                  items: _subCategories,
                  isDark: isDark,
                  onChanged: (val) =>
                      setState(() => _selectedSubCategory = val),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildTypeButton(
                  label: 'حکومی',
                  icon: Icons.account_balance_rounded,
                  isSelected: _storeType == 'حکومی',
                  onTap: () => setState(() => _storeType = 'حکومی'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildTypeButton(
                  label: 'ناحکومی',
                  icon: Icons.storefront_rounded,
                  isSelected: _storeType == 'ناحکومی',
                  onTap: () => setState(() => _storeType = 'ناحکومی'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildTextField(_nameController, 'ناوی شوێن *', isDark: isDark),
          const SizedBox(height: 10),
          _buildTextField(
            _phoneController,
            'مۆبایل',
            keyboard: TextInputType.phone,
            isDark: isDark,
          ),
          const SizedBox(height: 10),
          _buildTextField(_addressController, 'ناونیشان *', isDark: isDark),
          const SizedBox(height: 10),
          _buildTextField(
            _descController,
            'وەسف',
            maxLines: 3,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildLocationSection(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A22) : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildLocationButton(
                  icon: Icons.my_location_rounded,
                  label: _latitude != null
                      ? 'GPS وەرگیرا ✓'
                      : 'وەرگرتنی GPS',
                  color: _latitude != null
                      ? Colors.green
                      : AppColors.primary,
                  isLoading: _gettingLocation,
                  onTap: _gettingLocation ? null : _getCurrentLocation,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildLocationButton(
                  icon: Icons.map_rounded,
                  label: 'نەخشە',
                  color: Colors.blueAccent,
                  onTap: _openMapPicker,
                ),
              ),
            ],
          ),
          if (_latitude != null && _longitude != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionButtons(bool isEditing) {
    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 50,
            child: OutlinedButton(
              onPressed: () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(color: Colors.grey.shade400),
              ),
              child: const Text(
                'پاشگەزبوونەوە',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              onPressed: _saveStore,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: Icon(
                isEditing ? Icons.save_rounded : Icons.add_circle_rounded,
              ),
              label: Text(
                isEditing ? 'نوێکردنەوە' : 'تۆمارکردن',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField(
      TextEditingController controller,
      String label, {
        int maxLines = 1,
        TextInputType? keyboard,
        required bool isDark,
      }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboard,
      style: TextStyle(
        fontSize: 13,
        color: isDark ? Colors.white : Colors.black87,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: isDark ? Colors.white54 : Colors.grey.shade700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F0F14) : Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        isDense: true,
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required bool isDark,
    required Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      hint: Text(
        'هەڵبژێرە',
        style: TextStyle(
          fontSize: 11,
          color: isDark ? Colors.white54 : Colors.grey.shade500,
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(
            item,
            style: const TextStyle(fontSize: 12),
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          fontSize: 12,
          color: isDark ? Colors.white54 : Colors.grey.shade700,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: isDark ? const Color(0xFF0F0F14) : Colors.grey.shade50,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 8,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildTypeButton({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : Colors.grey.shade700,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocationButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: color,
                  ),
                )
              else
                Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}