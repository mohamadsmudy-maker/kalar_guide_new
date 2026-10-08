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
import '../../services/audio_service.dart';
import '../../widgets/voice_recorder_widget.dart';

/// 📝 شاشەی ناردنی سکاڵای هاوڵاتی — Pro Edition v2
class SubmitComplaintScreen extends StatefulWidget {
  const SubmitComplaintScreen({super.key});

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState extends State<SubmitComplaintScreen> {
  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
  final _descCtrl = TextEditingController();

  String? _selectedComplaintType;
  String? _responsibleAuthority;
  String? _voicePath;

  final Map<String, String> _complaintTypesMap = {
    'خۆڵ و خاشاک و ژینگە': 'شارەوانی کەلار',
    'ناڕێکی شار و سیفەتی گشتی': 'قایمقامیەتی قەزای کەلار',
    'کێشەی پچڕانی کارەبا': 'بەڕێوەبەرایەتی کارەبای گەرمیان',
    'کێشەی پچڕان یان لێچوونی ئاو': 'فەرمەنگەی ئاوی کەلار',
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

  // ═══════════════════════════════════════════════════════════
  // 📍 GPS
  // ═══════════════════════════════════════════════════════════
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

  // ═══════════════════════════════════════════════════════════
  // 📸 وێنەکان
  // ═══════════════════════════════════════════════════════════
  Future<void> _handleImagePicking() async {
    if (_images.length >= 2) {
      _showSnackBar("تەنها دەتوانیت تا ٢ وێنە زیاد بکەیت ⚠", Colors.orange);
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
    } catch (e) {
      debugPrint('❌ Image pick error: $e');
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🚀 ناردن — بە چاکسازی بۆ دەنگ
  // ═══════════════════════════════════════════════════════════
  Future<void> _submitComplaint() async {
    // ═══ پشکنینەکان ═══
    if (_selectedComplaintType == null) {
      _showSnackBar("تکایە جۆری کێشە دیاری بکە ⚠", Colors.orange);
      return;
    }

    if (_images.isEmpty) {
      _showSnackBar("تکایە لانیکەم یەک وێنە هەڵبژێرە ⚠", Colors.orange);
      return;
    }

    if (_lat == null || _lng == null) {
      _showSnackBar(
        "تکایە چاوەڕێ بکە تا لۆکەیشن دەدۆزرێتەوە 📍",
        Colors.orange,
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

      // ═══════════════════════════════════════════════════════
      // ١. بارکردنی وێنەکان
      // ═══════════════════════════════════════════════════════
      debugPrint('📸 ========== دەستپێکردنی بارکردن ==========');
      debugPrint('📸 کۆی وێنەکان: ${_images.length}');

      List<String> uploadedUrls = [];
      for (int i = 0; i < _images.length; i++) {
        debugPrint('📸 بارکردنی وێنەی ${i + 1}/${_images.length}...');
        try {
          String url = await ImageCompressionService.uploadImage(_images[i]);
          uploadedUrls.add(url);
          debugPrint('✅ وێنەی ${i + 1} بارکرا: $url');
        } catch (e) {
          debugPrint('❌ هەڵە لە بارکردنی وێنەی ${i + 1}: $e');
          rethrow;
        }
      }
      debugPrint('✅ هەموو وێنەکان بارکران: ${uploadedUrls.length}');

      // ═══════════════════════════════════════════════════════
      // ٢. بارکردنی دەنگ
      // ═══════════════════════════════════════════════════════
      String? voiceUrl;

      debugPrint('🎤 ========== پشکنینی دەنگ ==========');
      debugPrint('🎤 _voicePath: $_voicePath');

      if (_voicePath != null && _voicePath!.isNotEmpty) {
        debugPrint('🎤 دەنگ هەیە — دەستپێکردنی بارکردن...');

        // ✅ پشکنینی هەبوونی فایل
        final voiceFile = File(_voicePath!);
        if (!await voiceFile.exists()) {
          debugPrint('❌ فایلی دەنگ نەدۆزرایەوە: $_voicePath');
          _showSnackBar(
            "⚠️ فایلی دەنگ نەدۆزرایەوە — بەبێ دەنگ بەردەوام دەبین",
            Colors.orange,
          );
        } else {
          final fileSize = await voiceFile.length();
          debugPrint('📁 قەبارەی فایل: ${(fileSize / 1024).toStringAsFixed(1)} KB');

          if (fileSize < 1000) {
            debugPrint('⚠️ فایلی دەنگ زۆر بچووکە');
            _showSnackBar(
              "⚠️ دەنگەکە زۆر کورتە — بەبێ دەنگ بەردەوام دەبین",
              Colors.orange,
            );
          } else {
            // ✅ بارکردن
            try {
              voiceUrl = await AudioService.uploadAudio(_voicePath!);

              if (voiceUrl == null || voiceUrl.isEmpty) {
                debugPrint('❌ بارکردنی دەنگ شکست هێنا');
                _showSnackBar(
                  "⚠️ بارکردنی دەنگ شکست هێنا — بەبێ دەنگ بەردەوام دەبین",
                  Colors.orange,
                );
                voiceUrl = null;
              } else {
                debugPrint('✅ دەنگ بارکرا بە سەرکەوتوویی');
                debugPrint('✅ URL: $voiceUrl');
              }
            } catch (e) {
              debugPrint('❌ هەڵە لە بارکردنی دەنگ: $e');
              voiceUrl = null;
            }
          }
        }
      } else {
        debugPrint('ℹ️ هیچ دەنگێک تۆمار نەکراوە');
      }

      // ═══════════════════════════════════════════════════════
      // ٣. پاشەکەوتکردن لە داتابەیس
      // ═══════════════════════════════════════════════════════
      debugPrint('💾 ========== پاشەکەوتکردن ==========');

      final complaintData = <String, dynamic>{
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
      };

      // ✅ تەنها ئەگەر دەنگ هەبوو زیاد بکە
      if (voiceUrl != null && voiceUrl.isNotEmpty) {
        complaintData['voice_url'] = voiceUrl;
        debugPrint('🎤 voice_url زیادکرا: $voiceUrl');
      } else {
        debugPrint('ℹ️ voice_url زیاد نەکرا (هیچ دەنگێک نییە)');
      }

      debugPrint('📤 داتای کۆتایی: $complaintData');

      await Supabase.instance.client
          .from('complaints')
          .insert(complaintData);

      debugPrint('✅ سکاڵا نێردرا بە سەرکەوتوویی');

      if (mounted) {
        _showSuccessDialog();
      }
    } on PostgrestException catch (e) {
      debugPrint('❌ Postgrest error: ${e.message}');
      debugPrint('❌ Details: ${e.details}');
      debugPrint('❌ Hint: ${e.hint}');

      if (mounted) {
        if (e.message.contains('voice_url')) {
          _showSnackBar(
            "⚠️ ستوونی voice_url لە داتابەیس نییە.\n"
                "تکایە لە Supabase ستوونەکە زیاد بکە.",
            Colors.red,
          );
        } else {
          _showSnackBar("هەڵەی داتابەیس: ${e.message}", Colors.red);
        }
      }
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      if (mounted) {
        _showSnackBar("هەڵە ڕووی دا: $e", Colors.red);
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📢 دیالۆگەکان
  // ═══════════════════════════════════════════════════════════
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
                      colors: [Colors.red.shade400, Colors.red.shade700],
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
                      colors: [Colors.green.shade400, Colors.green.shade700],
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

  // ═══════════════════════════════════════════════════════════
  // 🔔 SnackBar Helper
  // ═══════════════════════════════════════════════════════════
  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
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
              // ═══ هەنگاوی ١: جۆری کێشە ═══
              _buildStepHeader("١", "جۆری کێشە هەڵبژێرە"),
              const SizedBox(height: 10),
              _buildComplaintTypeDropdown(),
              const SizedBox(height: 20),

              if (_selectedComplaintType == null) ...[
                _buildEmptyStateInfo(),
              ] else ...[
                // 🏛️ لایەنی پەیوەندیدار
                _buildAuthorityCard(),
                const SizedBox(height: 20),

                // ═══ هەنگاوی ٢: وێنەکان ═══
                _buildStepHeader("٢", "وێنەی کێشەکە"),
                const SizedBox(height: 10),
                _buildImageSection(isGarbageSelected),
                const SizedBox(height: 20),

                // ═══ هەنگاوی ٣: نەخشە ═══
                _buildStepHeader("٣", "شوێنی کێشە لەسەر نەخشە"),
                const SizedBox(height: 10),
                _buildMapSection(),
                const SizedBox(height: 20),

                // ═══ هەنگاوی ٤: دەنگ ═══
                _buildStepHeader(
                  "٤",
                  "تۆمارکردنی دەنگ (ئارەزوومەندانە) 🎤",
                ),
                const SizedBox(height: 10),
                VoiceRecorderWidget(
                  onRecorded: (path) {
                    debugPrint('🎤 دەنگ تۆمارکرا: $path');
                    setState(() => _voicePath = path);
                  },
                ),
                if (_voicePath != null) ...[
                  const SizedBox(height: 8),
                  _buildVoiceConfirmation(),
                ],
                const SizedBox(height: 20),

                // ═══ هەنگاوی ٥: وەسف ═══
                _buildStepHeader("٥", "وەسفی کێشە (ئارەزوومەندانە)"),
                const SizedBox(height: 10),
                _buildDescriptionField(),
                const SizedBox(height: 28),

                // 🚀 دوگمەی ناردن
                _buildSubmitButton(),
                const SizedBox(height: 12),

                // ❌ پەشیمانبوونەوە
                _buildCancelButton(),
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 UI Widgets
  // ═══════════════════════════════════════════════════════════
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
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildComplaintTypeDropdown() {
    return Container(
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
    );
  }

  Widget _buildEmptyStateInfo() {
    return Container(
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
    );
  }

  Widget _buildAuthorityCard() {
    return Container(
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
    );
  }

  Widget _buildImageSection(bool isGarbageSelected) {
    return GestureDetector(
      onTap: _handleImagePicking,
      child: Container(
        height: 140,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: const Color(0xFF2196F3).withValues(alpha: 0.4),
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
                color: const Color(0xFF2196F3).withValues(alpha: 0.1),
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
              isGarbageSelected ? "مەرجە وێنەی ڕاستەوخۆ بێت" : "تا ٢ وێنە",
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
              margin: const EdgeInsets.symmetric(horizontal: 6),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
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
    );
  }

  Widget _buildMapSection() {
    return Column(
      children: [
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
                    markerId: const gmaps.MarkerId('current_loc'),
                    position: gmaps.LatLng(_lat!, _lng!),
                    icon: gmaps.BitmapDescriptor.defaultMarkerWithHue(
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
            color: _lat != null ? Colors.green.shade50 : Colors.orange.shade50,
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
      ],
    );
  }

  Widget _buildVoiceConfirmation() {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.green.shade200,
        ),
      ),
      child: const Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: Colors.green,
            size: 18,
          ),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'دەنگەکە تۆمارکرا و ئامادەیە بۆ ناردن',
              style: TextStyle(
                fontSize: 12,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
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
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      height: 56,
      child: _isSubmitting
          ? Container(
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2.5,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'خەریکی ناردن...',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
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
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
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
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
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
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 Helpers
  // ═══════════════════════════════════════════════════════════
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