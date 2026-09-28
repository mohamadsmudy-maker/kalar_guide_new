import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/image_service.dart';
import '../../services/location_service.dart';

/// 📝 شاشەی ناردنی سکاڵای هاوڵاتی (Pro Design)
class SubmitComplaintScreen extends StatefulWidget {
  const SubmitComplaintScreen({super.key});

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState extends State<SubmitComplaintScreen> {
  final _descCtrl = TextEditingController();

  String? _selectedComplaintType;
  String? _responsibleAuthority;

  final Map<String, String> _complaintTypesMap = {
    'خۆڵ و خاشاک و ژینگە': 'شارەوانی کەلار',
    'ناڕێکی شار و سیفەتی گشتی': 'قایمقامیەتی قەزای کەلار',
    'کێشەی پچڕانی کارەبا': 'بەڕێوەبەرایەتی کارەبای گەرمیان',
    'کێشەی پچڕان یان لێچوونی ئاو': 'فەرمانگەی ئاوی کەلار',
    'کێشەی ڕێگاوبان و چاڵ و چۆڵی':
    'سەرۆکایەتی شارەوانی کەلار (بەشی ڕێگاوبان)',
    'تەندروستی و خاوێنی مۆڵ و ڕێستۆرانت':
    'بەڕێوەبەرایەتی تەندروستی گەرمیان',
  };

  final List<XFile> _images = [];
  bool _loadingLocation = true;
  bool _isSubmitting = false;
  double? _lat;
  double? _lng;
  String _locationStatusText = "خەریکی وەرگرتنی لۆکەیشنی GPS...";
  gmaps.GoogleMapController? _mapController;

  @override
  void initState() {
    super.initState();
    _getAutomaticLocation();
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _getAutomaticLocation() async {
    setState(() => _loadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locationStatusText = "لۆکەیشن (GPS) کوژاوەتەوە ⚠";
          _loadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _locationStatusText = "مۆڵەتی لۆکەیشن ڕەتکرایەوە ❌";
            _loadingLocation = false;
          });
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _locationStatusText = "لۆکەیشنی GPS وەرگیرا ✓";
        _loadingLocation = false;
      });

      if (_mapController != null && _lat != null && _lng != null) {
        _mapController!.animateCamera(
          gmaps.CameraUpdate.newLatLngZoom(
            gmaps.LatLng(_lat!, _lng!),
            17,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _locationStatusText = "هەڵە لە وەرگرتنی لۆکەیشن";
        _loadingLocation = false;
      });
    }
  }

  Future<void> _handleImagePicking() async {
    if (_images.length >= 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تەنها دەتوانیت تا ٢ وێنە زیاد بکەیت ⚠"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    bool isGarbage = _selectedComplaintType != null &&
        _selectedComplaintType!.contains('خۆڵ و خاشاک');

    if (isGarbage) {
      await _pickImageFromSource(ImageSource.camera);
    } else {
      showModalBottomSheet(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (context) => Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "وێنەی کێشە هەڵبژێرە",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildSourceCard(
                        icon: Icons.camera_alt_rounded,
                        label: "کامێرا",
                        color: AppColors.primary,
                        onTap: () {
                          Navigator.pop(context);
                          _pickImageFromSource(ImageSource.camera);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSourceCard(
                        icon: Icons.photo_library_rounded,
                        label: "گەلەری",
                        color: Colors.purple,
                        onTap: () {
                          Navigator.pop(context);
                          _pickImageFromSource(ImageSource.gallery);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
    }
  }

  Widget _buildSourceCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withValues(alpha: 0.3),
            width: 1.5,
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: color,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    final picker = ImagePicker();
    try {
      if (source == ImageSource.gallery) {
        final pickedList = await picker.pickMultiImage(imageQuality: 70);
        if (pickedList.isNotEmpty) {
          setState(() {
            int remainingSlots = 2 - _images.length;
            _images.addAll(pickedList.take(remainingSlots));
          });
        }
      } else {
        final pickedFile =
        await picker.pickImage(source: source, imageQuality: 70);
        if (pickedFile != null) {
          setState(() => _images.add(pickedFile));
        }
      }
    } catch (_) {}
  }

  Future<void> _submitComplaint() async {
    if (_selectedComplaintType == null || _images.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تکایە جۆری کێشە و وێنەیەک دیاری بکە ⚠"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_lat == null || _lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("تکایە چاوەڕێ بکە تا لۆکەیشن دەدۆزرێتەوە 📍"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    gmaps.LatLng userLoc = gmaps.LatLng(_lat!, _lng!);
    if (!KalarBoundaryChecker.isWithinKalar(userLoc)) {
      _showOutOfBoundaryDialog();
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final user = AuthSessionManager.currentUser;

      List<String> uploadedUrls = [];
      for (var img in _images) {
        String url = await ImageCompressionService.uploadImage(img);
        uploadedUrls.add(url);
      }

      await Supabase.instance.client.from('complaints').insert({
        'user_id': user?['id']?.toString(),
        'title': _selectedComplaintType,
        'description': _descCtrl.text.trim(),
        'category': _selectedComplaintType,
        'responsible_authority': _responsibleAuthority,
        'latitude': _lat,
        'longitude': _lng,
        'images': uploadedUrls,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      if (mounted) {
        _showSuccessDialog();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("هەڵە ڕووی دا: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showOutOfBoundaryDialog() {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.red.shade400,
                        Colors.red.shade700,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.location_off_rounded,
                    color: Colors.white,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "سنووری جوگرافی نەگونجاو",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: Color(0xFF1A1A2E),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.red.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        color: Colors.red.shade700,
                        size: 22,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "تکایە! ناردنی سکاڵا تەنها لە سنووری شاری کەلاردا بەردەستە.",
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.red.shade900,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      "تێدەگەم ✅",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          insetPadding: const EdgeInsets.all(20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.shade400,
                        Colors.green.shade700,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 55,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  "سکاڵاکەت نێردرا!",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: Color(0xFF1A1A2E),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "سکاڵاکەت بە سەرکەوتوویی نێردرا بۆ $_responsibleAuthority",
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.grey,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.shade600,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    child: const Text(
                      "باشە ✅",
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
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

  @override
  Widget build(BuildContext context) {
    bool isGarbageSelected = _selectedComplaintType != null &&
        _selectedComplaintType!.contains('خۆڵ و خاشاک');

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F6F9),
        appBar: AppBar(
          backgroundColor: AppColors.primary,
          elevation: 0,
          title: const Text(
            "ناردنی سکاڵای هاوڵاتی",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
              color: Colors.white,
            ),
          ),
          centerTitle: true,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 🎯 هەنگاوی ١
              _buildStepHeader("١", "جۆری کێشە هەڵبژێرە"),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: _selectedComplaintType != null
                      ? Colors.green.shade50
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _selectedComplaintType != null
                        ? Colors.green.shade400
                        : AppColors.primary.withValues(alpha: 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedComplaintType,
                    isExpanded: true,
                    hint: const Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          "جۆری کێشە هەڵبژێرە...",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    items: _complaintTypesMap.keys.map((type) {
                      return DropdownMenuItem<String>(
                        value: type,
                        child: Row(
                          children: [
                            Icon(
                              _getComplaintIcon(type),
                              color: _selectedComplaintType == type
                                  ? Colors.green.shade800
                                  : AppColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              type,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: _selectedComplaintType == type
                                    ? Colors.green.shade800
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: _selectedComplaintType != null
                        ? null
                        : (v) {
                      setState(() {
                        _selectedComplaintType = v;
                        _responsibleAuthority = _complaintTypesMap[v];
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              if (_selectedComplaintType == null) ...[
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.grey.shade200,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 50,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "تکایە سەرەتا جۆری کێشە هەڵبژێرە",
                        style: TextStyle(
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ] else ...[
                // 🏛️ لایەنی پەیوەندیدار
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.green.shade400,
                        Colors.green.shade600,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.verified_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "لایەنی پەیوەندیدار",
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _responsibleAuthority ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 📸 هەنگاوی ٢
                _buildStepHeader("٢", "وێنەی کێشەکە"),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: _handleImagePicking,
                  child: Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color:
                        const Color(0xFF2196F3).withValues(alpha: 0.4),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: _images.isEmpty
                        ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2196F3)
                                .withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isGarbageSelected
                                ? Icons.camera_alt_rounded
                                : Icons.add_a_photo_rounded,
                            color: const Color(0xFF2196F3),
                            size: 30,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isGarbageSelected
                              ? "وێنەگرتن بە کامێرا"
                              : "وێنە بگرە (کامێرا یان گەلەری)",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2196F3),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isGarbageSelected
                              ? "مەرجە وێنەی ڕاستەوخۆ بێت"
                              : "تا ٢ وێنە",
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    )
                        : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ..._images.map((img) => Container(
                          width: 85,
                          height: 105,
                          margin: const EdgeInsets.symmetric(
                            horizontal: 6,
                          ),
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              ClipRRect(
                                borderRadius:
                                BorderRadius.circular(12),
                                child: Image.file(
                                  File(img.path),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () => setState(
                                        () => _images.remove(img),
                                  ),
                                  child: Container(
                                    padding:
                                    const EdgeInsets.all(3),
                                    decoration:
                                    const BoxDecoration(
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
                        )),
                        if (_images.length < 2)
                          Container(
                            width: 45,
                            height: 45,
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.add_a_photo,
                              color: Color(0xFF2196F3),
                              size: 20,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 🗺️ هەنگاوی ٣
                _buildStepHeader("٣", "شوێنی کێشە لەسەر نەخشە"),
                const SizedBox(height: 10),
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: Colors.grey.shade300,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: AbsorbPointer(
                      child: gmaps.GoogleMap(
                        initialCameraPosition: gmaps.CameraPosition(
                          target: _lat != null && _lng != null
                              ? gmaps.LatLng(_lat!, _lng!)
                              : const gmaps.LatLng(34.6189, 45.3156),
                          zoom: 16,
                        ),
                        zoomControlsEnabled: false,
                        scrollGesturesEnabled: false,
                        markers: _lat != null && _lng != null
                            ? {
                          gmaps.Marker(
                            markerId: const gmaps.MarkerId(
                              'current_loc',
                            ),
                            position: gmaps.LatLng(_lat!, _lng!),
                            icon: gmaps.BitmapDescriptor
                                .defaultMarkerWithHue(
                              gmaps.BitmapDescriptor.hueRed,
                            ),
                          ),
                        }
                            : {},
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _lat != null
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _lat != null
                            ? Icons.check_circle_rounded
                            : Icons.access_time_rounded,
                        color: _lat != null
                            ? Colors.green.shade700
                            : Colors.orange.shade700,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _locationStatusText,
                          style: TextStyle(
                            fontSize: 11,
                            color: _lat != null
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // 📝 هەنگاوی ٤
                _buildStepHeader("٤", "وەسفی کێشە (ئارەزوومەندانە)"),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _descCtrl,
                  maxLines: 4,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "ڕووداوەکە لێرە زیاتر باس بکەرەوە...",
                    hintStyle: const TextStyle(
                      fontSize: 13,
                      color: Colors.grey,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    prefixIcon: const Padding(
                      padding: EdgeInsets.only(bottom: 60),
                      child: Icon(
                        Icons.description_outlined,
                        color: AppColors.primary,
                      ),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(
                        color: Colors.grey.shade300,
                        width: 1.5,
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: const BorderSide(
                        color: AppColors.primary,
                        width: 2,
                      ),
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 28),

                // 🚀 دوگمەی ناردن
                SizedBox(
                  height: 56,
                  child: _isSubmitting
                      ? const Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                    ),
                  )
                      : ElevatedButton.icon(
                    onPressed: _submitComplaint,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                      ),
                      elevation: 4,
                      shadowColor:
                      AppColors.primary.withValues(alpha: 0.4),
                    ),
                    icon: const Icon(
                      Icons.send_rounded,
                      size: 22,
                    ),
                    label: const Text(
                      "ناردنی سکاڵا",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // ❌ پەشیمانبوونەوە
                SizedBox(
                  height: 50,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      side: BorderSide(
                        color: Colors.red.shade300,
                        width: 1.5,
                      ),
                    ),
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.red.shade700,
                      size: 20,
                    ),
                    label: Text(
                      "پەشیمانبوونەوە",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade700,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // 🎯 هێدەری هەنگاوەکان
  Widget _buildStepHeader(String step, String title) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              step,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w900,
            color: Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }

  // 🎯 ئایکۆنی جۆری سکاڵا
  IconData _getComplaintIcon(String type) {
    if (type.contains('خۆڵ') || type.contains('خاشاک')) {
      return Icons.delete_rounded;
    } else if (type.contains('کارەبا')) {
      return Icons.bolt_rounded;
    } else if (type.contains('ئاو')) {
      return Icons.water_drop_rounded;
    } else if (type.contains('ڕێگا') || type.contains('چاڵ')) {
      return Icons.construction_rounded;
    } else if (type.contains('تەندروستی')) {
      return Icons.local_hospital_rounded;
    } else if (type.contains('شار') || type.contains('سیفەت')) {
      return Icons.location_city_rounded;
    }
    return Icons.report_problem_rounded;
  }
}