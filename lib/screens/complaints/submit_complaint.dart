// lib/screens/complaints/submit_complaint.dart
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
import '../../services/neighborhood_service.dart';
import '../../widgets/voice_recorder_widget.dart';

/// 📝 شاشەی ناردنی سکاڵای هاوڵاتی — Pro Edition v5
/// ⭐ نوێکاری: ناردنی سکاڵا پێویستی بە ئەکاونت نییە
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

  // ⭐ گەڕەک
  String? _neighborhoodName;
  int? _neighborhoodId;
  bool _detectingNeighborhood = false;

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

      await _detectNeighborhood();
    } catch (e) {
      setState(() {
        _locationStatusText = "هەڵە لە وەرگرتنی لۆکەیشن";
        _loadingLocation = false;
      });
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🏘️ دۆزینەوەی گەڕەک
  // ═══════════════════════════════════════════════════════════
  Future<void> _detectNeighborhood() async {
    if (_lat == null || _lng == null) return;

    setState(() => _detectingNeighborhood = true);

    try {
      final neighborhood = await NeighborhoodService.findNeighborhoodByLocation(
        lat: _lat!,
        lng: _lng!,
      );

      if (mounted) {
        setState(() {
          _neighborhoodName = neighborhood?.nameKu;
          _neighborhoodId = int.tryParse(neighborhood?.id ?? '0');
          _detectingNeighborhood = false;
        });
        debugPrint('🏘️ گەڕەک: $_neighborhoodName (id: $_neighborhoodId)');
      }
    } catch (e) {
      debugPrint('⚠️ neighborhood detect error: $e');
      if (mounted) setState(() => _detectingNeighborhood = false);
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
  // 🚀 ناردن — ⭐ نوێکراو: پێویستی بە ئەکاونت نییە
  // ═══════════════════════════════════════════════════════════
  Future<void> _submitComplaint() async {
    // ═══ پشکنینەکانی سەرەتا ═══
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
      // ⭐⭐⭐ لابردنی پشکنینی Login ⭐⭐⭐
      // ئێستا ناردنی سکاڵا پێویستی بە ئەکاونت نییە
      // تەنها ئەگەر بەکارهێنەر چووبێتە ژوورەوە، user_id دەنێرین
      final supabaseUser = Supabase.instance.client.auth.currentUser;
      final sessionUser = AuthSessionManager.currentUser;

      // ⭐ user_id بە شێوەیەکی ئارەزوومەندانە
      // ئەگەر بەکارهێنەر نەچووبێتە ژوورەوە، null دەنێرین
      final String? userId =
          sessionUser?['id']?.toString() ?? supabaseUser?.id;

      debugPrint('👤 User ID (optional): $userId');

      // ═══ ١. بارکردنی وێنەکان ═══
      debugPrint('📸 ========== بارکردنی وێنەکان ==========');
      List<String> uploadedUrls = [];
      for (int i = 0; i < _images.length; i++) {
        try {
          String url = await ImageCompressionService.uploadImage(_images[i]);
          uploadedUrls.add(url);
          debugPrint('✅ وێنەی ${i + 1} بارکرا');
        } catch (e) {
          debugPrint('❌ هەڵە لە وێنەی ${i + 1}: $e');
          rethrow;
        }
      }

      // ═══ ٢. بارکردنی دەنگ ═══
      String? voiceUrl;
      if (_voicePath != null && _voicePath!.isNotEmpty) {
        final voiceFile = File(_voicePath!);
        if (await voiceFile.exists()) {
          final fileSize = await voiceFile.length();
          if (fileSize >= 1000) {
            try {
              voiceUrl = await AudioService.uploadAudio(_voicePath!);
              debugPrint('✅ دەنگ بارکرا');
            } catch (e) {
              debugPrint('⚠️ دەنگ بار نەکرا: $e');
              voiceUrl = null;
            }
          }
        }
      }

      // ═══ ٣. دۆزینەوەی گەڕەک ═══
      int? neighborhoodId = _neighborhoodId;
      String? neighborhoodName = _neighborhoodName;

      if (neighborhoodName == null) {
        try {
          final neighborhood =
          await NeighborhoodService.findNeighborhoodByLocation(
            lat: _lat!,
            lng: _lng!,
          );
          neighborhoodId = int.tryParse(neighborhood?.id ?? '0');
          neighborhoodName = neighborhood?.nameKu;
        } catch (e) {
          debugPrint('⚠️ neighborhood find error: $e');
        }
      }

      // ═══ ٤. پاشەکەوتکردن ═══
      final complaintData = <String, dynamic>{
        // ⭐ user_id بە شێوەیەکی ئارەزوومەندانە
        // ئەگەر بەکارهێنەر نەچووبێتە ژوورەوە، ئەم خانەیە نانێردرێت
        if (userId != null && userId.isNotEmpty) 'user_id': userId,
        'title': _selectedComplaintType,
        'description': _descCtrl.text.trim(),
        'category': _selectedComplaintType,
        'responsible_authority': _responsibleAuthority,
        'latitude': _lat,
        'longitude': _lng,
        'images': uploadedUrls,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
        'neighborhood_id': neighborhoodId,
        'neighborhood_name': neighborhoodName,
      };

      if (voiceUrl != null && voiceUrl.isNotEmpty) {
        complaintData['voice_url'] = voiceUrl;
      }

      debugPrint('📤 ناردنی سکاڵا: $complaintData');

      // ⭐ ناردن بۆ Supabase
      await Supabase.instance.client.from('complaints').insert(complaintData);

      debugPrint('✅ سکاڵا نێردرا بە سەرکەوتوویی');

      if (mounted) _showSuccessDialog();
    } on PostgrestException catch (e) {
      debugPrint('❌ Postgrest error: ${e.message}');
      if (mounted) {
        if (e.message.contains('voice_url')) {
          _showSnackBar(
            "⚠️ ستوونی voice_url لە داتابەیس نییە.",
            Colors.red,
          );
        } else if (e.message.contains('row-level security')) {
          _showSnackBar(
            "⚠️ کێشەی ئاسایش: تکایە دووبارە هەوڵبدەوە.",
            Colors.red,
          );
        } else if (e.message.contains('user_id')) {
          _showSnackBar(
            "⚠️ کێشەی user_id: تکایە پەیوەندی بکە بە بەڕێوەبەر.",
            Colors.red,
          );
        } else {
          _showSnackBar("هەڵەی داتابەیس: ${e.message}", Colors.red);
        }
      }
    } catch (e) {
      debugPrint('❌ هەڵە: $e');
      if (mounted) _showSnackBar("هەڵە ڕووی دا: $e", Colors.red);
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
                    ),
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
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade200, width: 1.5),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline_rounded,
                          color: Colors.red.shade700, size: 22),
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
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("تێدەگەم ✅",
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 15)),
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
                    ),
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
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _neighborhoodName != null
                      ? "سکاڵاکەت نێردرا بۆ $_responsibleAuthority\nگەڕەک: $_neighborhoodName"
                      : "سکاڵاکەت نێردرا بۆ $_responsibleAuthority",
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
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.pop(context);
                    },
                    child: const Text("باشە ✅",
                        style: TextStyle(
                            fontWeight: FontWeight.w900, fontSize: 15)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 13)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              _buildStepHeader("١", "جۆری کێشە هەڵبژێرە"),
              const SizedBox(height: 10),
              _buildComplaintTypeDropdown(),
              const SizedBox(height: 20),

              if (_selectedComplaintType == null) ...[
                _buildEmptyStateInfo(),
              ] else ...[
                _buildAuthorityCard(),
                const SizedBox(height: 12),
                _buildNeighborhoodCard(),
                const SizedBox(height: 20),
                _buildStepHeader("٢", "وێنەی کێشەکە"),
                const SizedBox(height: 10),
                _buildImageSection(isGarbageSelected),
                const SizedBox(height: 20),
                _buildStepHeader("٣", "شوێنی کێشە لەسەر نەخشە"),
                const SizedBox(height: 10),
                _buildMapSection(),
                const SizedBox(height: 20),
                _buildStepHeader(
                    "٤", "تۆمارکردنی دەنگ (ئارەزوومەندانە) 🎤"),
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
                _buildStepHeader("٥", "وەسفی کێشە (ئارەزوومەندانە)"),
                const SizedBox(height: 10),
                _buildDescriptionField(),
                const SizedBox(height: 28),
                _buildSubmitButton(),
                const SizedBox(height: 12),
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
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _selectedComplaintType,
          isExpanded: true,
          hint: const Row(
            children: [
              Icon(Icons.search_rounded,
                  color: AppColors.primary, size: 20),
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
        border: Border.all(color: Colors.grey.shade200, width: 1.5),
      ),
      child: Column(
        children: [
          Icon(Icons.info_outline_rounded,
              size: 50, color: Colors.grey.shade400),
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
          colors: [Colors.green.shade400, Colors.green.shade600],
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
            child: const Icon(Icons.verified_rounded,
                color: Colors.white, size: 20),
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

  Widget _buildNeighborhoodCard() {
    if (_detectingNeighborhood) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.blue.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue.shade200, width: 1.5),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.blue),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                "دۆزینەوەی گەڕەک...",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final hasNeighborhood =
        _neighborhoodName != null && _neighborhoodName!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: hasNeighborhood
            ? LinearGradient(
          colors: [Colors.blue.shade400, Colors.blue.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        color: hasNeighborhood ? null : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        boxShadow: hasNeighborhood
            ? [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hasNeighborhood
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.location_city_rounded,
              color: hasNeighborhood ? Colors.white : Colors.grey.shade600,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "گەڕەک",
                  style: TextStyle(
                    color: hasNeighborhood
                        ? Colors.white70
                        : Colors.grey.shade600,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hasNeighborhood ? _neighborhoodName! : "گەڕەک نەدۆزرایەوە",
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: hasNeighborhood
                        ? Colors.white
                        : Colors.grey.shade700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          if (hasNeighborhood)
            const Icon(Icons.check_circle_rounded,
                color: Colors.white, size: 22),
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
                      onTap: () =>
                          setState(() => _images.remove(img)),
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
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
        border: Border.all(color: Colors.green.shade200),
      ),
      child: const Row(
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.green, size: 18),
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
        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        prefixIcon: const Padding(
          padding: EdgeInsets.only(bottom: 60),
          child: Icon(Icons.description_outlined, color: AppColors.primary),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
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
                    color: AppColors.primary, strokeWidth: 2.5),
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
        ),
        icon: const Icon(Icons.send_rounded, size: 22),
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
          side: BorderSide(color: Colors.red.shade300, width: 1.5),
        ),
        onPressed: () => Navigator.pop(context),
        icon:
        Icon(Icons.close_rounded, color: Colors.red.shade700, size: 20),
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