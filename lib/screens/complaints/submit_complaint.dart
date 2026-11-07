// lib/screens/complaints/submit_complaint.dart
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/app_colors.dart';
import '../../services/auth_service.dart';
import '../../services/image_service.dart';
import '../../services/location_service.dart';
import '../../services/audio_service.dart';
import '../../services/neighborhood_service.dart';
import '../../widgets/voice_recorder_widget.dart';

part 'submit_complaint_ui.dart';

// ═══════════════════════════════════════════════════════════
// 🗂 Complaint types (single source of truth)
// ═══════════════════════════════════════════════════════════
class _ComplaintType {
  final String name;
  final String authority;
  final IconData icon;
  final Color color;
  final bool cameraOnly;

  const _ComplaintType(
      this.name,
      this.authority,
      this.icon,
      this.color, {
        this.cameraOnly = false,
      });
}

const List<_ComplaintType> _kTypes = [
  _ComplaintType('خۆڵ و خاشاک و ژینگە', 'شارەوانی کەلار',
      Icons.delete_rounded, Color(0xFF2E7D32),
      cameraOnly: true),
  _ComplaintType('ناڕێکی شار و سیفەتی گشتی', 'قایمقامیەتی قەزای کەلار',
      Icons.location_city_rounded, Color(0xFF5E35B1)),
  _ComplaintType('کێشەی پچڕانی کارەبا', 'بەڕێوەبەرایەتی کارەبای گەرمیان',
      Icons.bolt_rounded, Color(0xFFF9A825)),
  _ComplaintType('کێشەی پچڕان یان لێچوونی ئاو', 'فەرمەنگەی ئاوی کەلار',
      Icons.water_drop_rounded, Color(0xFF0288D1)),
  _ComplaintType(
      'کێشەی ڕێگاوبان و چاڵ و چۆڵی',
      'سەرۆکایەتی شارەوانی کەلار (بەشی ڕێگاوبان)',
      Icons.construction_rounded,
      Color(0xFFEF6C00)),
  _ComplaintType('تەندروستی و خاوێنی مۆڵ و ڕێستۆرانت',
      'بەڕێوەبەرایەتی تەندروستی گەرمیان', Icons.local_hospital_rounded,
      Color(0xFFC62828)),
  _ComplaintType('کێشەی تر', 'گشتی', Icons.report_problem_rounded,
      Color(0xFF546E7A)),
];

enum _LocIssue { none, serviceOff, denied, deniedForever, mocked, error }

/// 📝 شاشەی ناردنی سکاڵای هاوڵاتی — ULTRA PRO MAX V7
class SubmitComplaintScreen extends StatefulWidget {
  const SubmitComplaintScreen({super.key});

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState extends State<SubmitComplaintScreen>
    with TickerProviderStateMixin {
  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
  static const int _maxImages = 2;
  static const int _maxDescLength = 500;
  static const int _minDescForOther = 10;

  final _descCtrl = TextEditingController();
  final _scrollController = ScrollController();
  final _imageKey = GlobalKey();
  final _mapKey = GlobalKey();
  final _descKey = GlobalKey();

  _ComplaintType? _type;
  String? _voicePath;
  final List<XFile> _images = [];

  bool _isSubmitting = false;
  bool _submitted = false;
  bool _isDraft = false;
  String _submitStage = '';
  double _uploadProgress = 0;

  // 📍 Location
  double? _lat;
  double? _lng;
  double? _accuracy;
  bool _locationBusy = false;
  _LocIssue _locIssue = _LocIssue.none;
  String _locationStatusText = 'خەریکی وەرگرتنی لۆکەیشنی GPS...';
  gmaps.GoogleMapController? _mapController;

  // 🏘 Neighborhood
  String? _neighborhoodName;
  int? _neighborhoodId;
  bool _detectingNeighborhood = false;

  // 🎞 Animation
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  Timer? _draftDebounce;

  // ═══════════════════════════════════════════════════════════
  // 🔁 Lifecycle
  // ═══════════════════════════════════════════════════════════
  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.92, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _descCtrl.addListener(_scheduleDraftSave);

    _getAutomaticLocation();
    _loadDraft();
  }

  @override
  void dispose() {
    _draftDebounce?.cancel();
    _descCtrl.removeListener(_scheduleDraftSave);
    _descCtrl.dispose();
    _scrollController.dispose();
    _pulseController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 🧮 Derived state
  // ═══════════════════════════════════════════════════════════
  bool get _hasType => _type != null;
  bool get _hasImages => _images.isNotEmpty;
  bool get _hasLocation => _lat != null && _lng != null;
  bool get _isReady => _hasType && _hasImages && _hasLocation;
  int get _doneCount =>
      [_hasType, _hasImages, _hasLocation].where((e) => e).length;

  bool get _isDirty =>
      _type != null ||
          _descCtrl.text.trim().isNotEmpty ||
          _images.isNotEmpty ||
          _voicePath != null;

  String _ku(num n) => n.toString().replaceAllMapped(
    RegExp(r'\d'),
        (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)],
  );

  // ═══════════════════════════════════════════════════════════
  // 📍 GPS
  // ═══════════════════════════════════════════════════════════
  void _setLoc(_LocIssue issue, String text) {
    if (!mounted) return;
    setState(() {
      _locIssue = issue;
      _locationStatusText = text;
      _locationBusy = false;
    });
  }

  Future<void> _getAutomaticLocation() async {
    if (_locationBusy) return;
    setState(() {
      _locationBusy = true;
      _locIssue = _LocIssue.none;
      _locationStatusText = 'خەریکی وەرگرتنی لۆکەیشنی GPS...';
    });

    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _setLoc(_LocIssue.serviceOff, 'لۆکەیشن (GPS) کوژاوەتەوە ⚠');
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        _setLoc(_LocIssue.denied, 'مۆڵەتی لۆکەیشن ڕەتکرایەوە ❌');
        return;
      }
      if (permission == LocationPermission.deniedForever) {
        _setLoc(_LocIssue.deniedForever,
            'مۆڵەتی لۆکەیشن بە تەواوی ڕەتکراوەتەوە — لە ڕێکخستنەکان بیکەرەوە');
        return;
      }

      Position position;
      try {
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          ),
        );
      } on TimeoutException {
        final last = await Geolocator.getLastKnownPosition();
        if (last == null) rethrow;
        position = last;
      }

      if (!mounted) return;

      if (position.isMocked) {
        setState(() {
          _lat = null;
          _lng = null;
          _accuracy = null;
        });
        _setLoc(_LocIssue.mocked,
            'لۆکەیشنی ساختە دۆزرایەوە — تکایە GPSی ڕاستەقینە بەکاربهێنە 🚫');
        return;
      }

      setState(() {
        _lat = position.latitude;
        _lng = position.longitude;
        _accuracy = position.accuracy;
        _locIssue = _LocIssue.none;
        _locationBusy = false;
        _locationStatusText = 'لۆکەیشنی GPS وەرگیرا ✓';
      });

      _mapController?.animateCamera(
        gmaps.CameraUpdate.newLatLngZoom(
          gmaps.LatLng(position.latitude, position.longitude),
          17,
        ),
      );

      await _detectNeighborhood();
    } catch (e) {
      debugPrint('❌ GPS error: $e');
      _setLoc(_LocIssue.error, 'هەڵە لە وەرگرتنی لۆکەیشن — دووبارە هەوڵبدەرەوە');
    }
  }

  Future<void> _detectNeighborhood() async {
    if (!_hasLocation) return;
    setState(() => _detectingNeighborhood = true);

    try {
      final n = await NeighborhoodService.findNeighborhoodByLocation(
        lat: _lat!,
        lng: _lng!,
      );
      if (!mounted) return;
      setState(() {
        _neighborhoodName = n?.nameKu;
        _neighborhoodId = n == null ? null : int.tryParse(n.id.toString());
        _detectingNeighborhood = false;
      });
    } catch (e) {
      debugPrint('⚠️ neighborhood error: $e');
      if (mounted) setState(() => _detectingNeighborhood = false);
    }
  }

  Future<void> _openLocationFix() async {
    if (_locIssue == _LocIssue.serviceOff) {
      await Geolocator.openLocationSettings();
    } else if (_locIssue == _LocIssue.deniedForever) {
      await Geolocator.openAppSettings();
    } else {
      await _getAutomaticLocation();
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 💾 Draft
  // ═══════════════════════════════════════════════════════════
  void _scheduleDraftSave() {
    _draftDebounce?.cancel();
    _draftDebounce =
        Timer(const Duration(milliseconds: 800), () => _saveDraft());
  }

  Future<void> _saveDraft() async {
    if (_submitted) return;
    if (!_isDirty) {
      await _clearDraft();
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('draft_type', _type?.name ?? '');
      await prefs.setString('draft_desc', _descCtrl.text);
      await prefs.setStringList(
          'draft_images', _images.map((e) => e.path).toList());
      if (_voicePath != null) {
        await prefs.setString('draft_voice', _voicePath!);
      } else {
        await prefs.remove('draft_voice');
      }
    } catch (e) {
      debugPrint('⚠️ Save draft error: $e');
    }
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final typeName = prefs.getString('draft_type');
      final desc = prefs.getString('draft_desc') ?? '';
      final voice = prefs.getString('draft_voice');
      final imgPaths = prefs.getStringList('draft_images') ?? [];

      String? validVoice;
      if (voice != null && voice.isNotEmpty && await File(voice).exists()) {
        validVoice = voice;
      }

      final validImages = <XFile>[];
      for (final p in imgPaths) {
        if (await File(p).exists()) validImages.add(XFile(p));
      }

      _ComplaintType? type;
      for (final t in _kTypes) {
        if (t.name == typeName) type = t;
      }

      if (type == null && desc.isEmpty && validImages.isEmpty) return;
      if (!mounted) return;

      setState(() {
        _type = type;
        _descCtrl.text = desc;
        _voicePath = validVoice;
        _images
          ..clear()
          ..addAll(validImages.take(_maxImages));
        _isDraft = true;
      });
    } catch (e) {
      debugPrint('⚠️ Load draft error: $e');
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('draft_type');
      await prefs.remove('draft_desc');
      await prefs.remove('draft_voice');
      await prefs.remove('draft_images');
    } catch (_) {}
  }

  void _resetForm() {
    setState(() {
      _type = null;
      _images.clear();
      _voicePath = null;
      _isDraft = false;
      _descCtrl.clear();
    });
    _clearDraft();
  }

  // ═══════════════════════════════════════════════════════════
  // 🗂 Type picker
  // ═══════════════════════════════════════════════════════════
  void _showTypeSheet() {
    HapticFeedback.selectionClick();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(),
                const SizedBox(height: 14),
                const Text('جۆری کێشە هەڵبژێرە',
                    style:
                    TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _kTypes.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final t = _kTypes[i];
                      final selected = _type == t;
                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.pop(ctx);
                          HapticFeedback.selectionClick();
                          setState(() => _type = t);
                          _saveDraft();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selected
                                ? t.color.withValues(alpha: 0.12)
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected
                                  ? t.color
                                  : Colors.grey.shade200,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: t.color.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(t.icon, color: t.color, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(t.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 13)),
                                    const SizedBox(height: 2),
                                    Text(t.authority,
                                        style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.grey.shade600)),
                                  ],
                                ),
                              ),
                              if (selected)
                                Icon(Icons.check_circle_rounded,
                                    color: t.color),
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
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📸 Images
  // ═══════════════════════════════════════════════════════════
  Future<void> _handleImagePicking() async {
    if (_images.length >= _maxImages) {
      _showSnackBar('تەنها دەتوانیت تا ${_ku(_maxImages)} وێنە زیاد بکەیت ⚠',
          Colors.orange);
      return;
    }
    if (_type?.cameraOnly ?? false) {
      await _pickImageFromSource(ImageSource.camera);
    } else {
      _showImageSourceSheet();
    }
  }

  void _showImageSourceSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _sheetHandle(),
                const SizedBox(height: 16),
                const Text('وێنەی کێشە هەڵبژێرە',
                    style:
                    TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildSourceCard(
                        icon: Icons.camera_alt_rounded,
                        label: 'کامێرا',
                        color: AppColors.primary,
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickImageFromSource(ImageSource.camera);
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSourceCard(
                        icon: Icons.photo_library_rounded,
                        label: 'گەلەری',
                        color: Colors.purple,
                        onTap: () {
                          Navigator.pop(ctx);
                          _pickImageFromSource(ImageSource.gallery);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImageFromSource(ImageSource source) async {
    final picker = ImagePicker();
    try {
      if (source == ImageSource.gallery) {
        final list = await picker.pickMultiImage(imageQuality: 70);
        if (list.isEmpty || !mounted) return;
        setState(() {
          _images.addAll(list.take(_maxImages - _images.length));
        });
      } else {
        final file = await picker.pickImage(
          source: source,
          imageQuality: 70,
          maxWidth: 1920,
        );
        if (file == null || !mounted) return;
        setState(() => _images.add(file));
      }
      HapticFeedback.lightImpact();
      _saveDraft();
    } on PlatformException catch (e) {
      debugPrint('❌ Image pick error: $e');
      _showSnackBar('ناتوانم دەستم بگات بە کامێرا یان گەلەری — مۆڵەتەکان بپشکنە',
          Colors.red);
    } catch (e) {
      debugPrint('❌ Image pick error: $e');
    }
  }

  void _previewImage(XFile img) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: InteractiveViewer(
                child: Image.file(File(img.path), fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🚀 Submit
  // ═══════════════════════════════════════════════════════════
  Future<void> _scrollTo(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return;
    await Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      alignment: 0.1,
    );
  }

  void _fail(String msg, {GlobalKey? scrollTo}) {
    _showSnackBar(msg, Colors.orange);
    HapticFeedback.vibrate();
    if (scrollTo != null) _scrollTo(scrollTo);
  }

  void _setStage(String text, [double? progress]) {
    if (!mounted) return;
    setState(() {
      _submitStage = text;
      if (progress != null) _uploadProgress = progress;
    });
  }

  Future<void> _submitComplaint() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();

    if (_type == null) {
      _fail('تکایە جۆری کێشە دیاری بکە ⚠');
      return;
    }
    if (_images.isEmpty) {
      _fail('تکایە لانیکەم یەک وێنە هەڵبژێرە ⚠', scrollTo: _imageKey);
      return;
    }
    if (!_hasLocation) {
      _fail(
        _locIssue == _LocIssue.mocked
            ? 'لۆکەیشنی ساختە قبوڵ ناکرێت 🚫'
            : 'تکایە چاوەڕێ بکە تا لۆکەیشن دەدۆزرێتەوە 📍',
        scrollTo: _mapKey,
      );
      return;
    }

    final desc = _descCtrl.text.trim();
    if (_type!.name == 'کێشەی تر' &&
        desc.length < _minDescForOther &&
        _voicePath == null) {
      _fail('بۆ «کێشەی تر» تکایە وەسفێکی کورت بنووسە یان دەنگ تۆمار بکە ✍',
          scrollTo: _descKey);
      return;
    }

    if (!KalarBoundaryChecker.isWithinKalarWithBuffer(
        gmaps.LatLng(_lat!, _lng!))) {
      _showOutOfBoundaryDialog();
      return;
    }

    setState(() {
      _isSubmitting = true;
      _uploadProgress = 0;
      _submitStage = 'ئامادەکردن...';
    });
    HapticFeedback.mediumImpact();

    var voiceFailed = false;

    try {
      final supabaseUser = Supabase.instance.client.auth.currentUser;
      final sessionUser = AuthSessionManager.currentUser;
      final String? userId =
          sessionUser?['id']?.toString() ?? supabaseUser?.id;

      // ═══ ١. وێنەکان (هاوکات) ═══
      _setStage('بارکردنی وێنەکان...', 0.05);
      var done = 0;
      final uploadedUrls = await Future.wait(
        _images.map((img) async {
          final url = await ImageCompressionService.uploadImage(img)
              .timeout(const Duration(seconds: 60));
          done++;
          _setStage('بارکردنی وێنەکان (${_ku(done)}/${_ku(_images.length)})...',
              0.05 + 0.6 * done / _images.length);
          return url;
        }),
      );

      // ═══ ٢. دەنگ ═══
      String? voiceUrl;
      if (_voicePath != null && _voicePath!.isNotEmpty) {
        _setStage('بارکردنی دەنگ...', 0.7);
        try {
          final f = File(_voicePath!);
          if (await f.exists() && await f.length() >= 1000) {
            voiceUrl = await AudioService.uploadAudio(_voicePath!)
                .timeout(const Duration(seconds: 60));
          } else {
            voiceFailed = true;
          }
        } catch (e) {
          debugPrint('⚠️ voice upload: $e');
          voiceFailed = true;
        }
      }

      // ═══ ٣. گەڕەک ═══
      _setStage('پشکنینی گەڕەک...', 0.8);
      var neighborhoodId = _neighborhoodId;
      var neighborhoodName = _neighborhoodName;
      if (neighborhoodName == null) {
        try {
          final n = await NeighborhoodService.findNeighborhoodByLocation(
            lat: _lat!,
            lng: _lng!,
          );
          neighborhoodId = n == null ? null : int.tryParse(n.id.toString());
          neighborhoodName = n?.nameKu;
        } catch (e) {
          debugPrint('⚠️ neighborhood error: $e');
        }
      }

      // ═══ ٤. پاشەکەوتکردن ═══
      _setStage('تۆمارکردنی سکاڵا...', 0.9);
      final data = <String, dynamic>{
        if (userId != null && userId.isNotEmpty) 'user_id': userId,
        'title': _type!.name,
        'description': desc,
        'category': _type!.name,
        'responsible_authority': _type!.authority,
        'latitude': _lat,
        'longitude': _lng,
        'images': uploadedUrls,
        'status': 'pending',
        'created_at': DateTime.now().toUtc().toIso8601String(),
        'neighborhood_name': neighborhoodName,
        if (neighborhoodId != null && neighborhoodId > 0)
          'neighborhood_id': neighborhoodId,
        if (voiceUrl != null && voiceUrl.isNotEmpty) 'voice_url': voiceUrl,
      };

      await Supabase.instance.client
          .from('complaints')
          .insert(data)
          .timeout(const Duration(seconds: 30));

      _submitted = true;
      _draftDebounce?.cancel();
      await _clearDraft();
      _setStage('تەواو ✓', 1);

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      if (voiceFailed) {
        _showSnackBar(
            'سکاڵا نێردرا، بەڵام دەنگەکە نەنێردرا ⚠', Colors.orange);
      }
      _showSuccessDialog();
    } on PostgrestException catch (e) {
      debugPrint('❌ Postgrest error: ${e.message}');
      if (!mounted) return;
      final m = e.message;
      if (m.contains('voice_url')) {
        _showSnackBar('⚠️ ستوونی voice_url لە داتابەیسدا نییە. ئەدمین ئاگادار بکە.',
            Colors.red);
      } else if (m.contains('neighborhood_id')) {
        _showSnackBar(
            '⚠️ ستوونی neighborhood_id لە داتابەیسدا نییە.', Colors.red);
      } else if (m.contains('row-level security')) {
        _showSnackBar(
            '⚠️ کێشەی ئاسایش — تکایە دووبارە بچۆ ژوورەوە.', Colors.red);
      } else {
        _showSnackBar('هەڵەی داتابەیس، تکایە دووبارە هەوڵبدەرەوە', Colors.red);
      }
    } on TimeoutException {
      _showSnackBar(
          'پەیوەندی زۆر هێواشە — تکایە ئینتەرنێت بپشکنە و دووبارە هەوڵبدەرەوە ⏱',
          Colors.red);
    } on SocketException {
      _showSnackBar('ئینتەرنێت نییە — پەیوەندییەکەت بپشکنە 📡', Colors.red);
    } catch (e) {
      debugPrint('❌ Submit error: $e');
      _showSnackBar('هەڵەیەک ڕووی دا، تکایە دووبارە هەوڵبدەرەوە', Colors.red);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📢 Dialogs
  // ═══════════════════════════════════════════════════════════
  Future<void> _confirmCancel() async {
    if (!_isDirty) {
      Navigator.pop(context);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('دەتەوێت بڕۆیت؟',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17)),
          content: const Text('زانیارییەکانت وەک ڕەشنووس پاشەکەوت دەکرێن، یان دەتوانیت بیانسڕیتەوە.',
              style: TextStyle(fontSize: 13, height: 1.5)),
          actionsAlignment: MainAxisAlignment.spaceBetween,
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'stay'),
              child: const Text('مانەوە'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              child: Text('سڕینەوە',
                  style: TextStyle(color: Colors.red.shade700)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: const Text('پاشەکەوت'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || choice == null || choice == 'stay') return;
    if (choice == 'discard') {
      _submitted = true; // prevents PopScope from re-saving
      await _clearDraft();
    } else {
      await _saveDraft();
    }
    if (mounted) Navigator.pop(context);
  }

  void _showOutOfBoundaryDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _gradientIcon(Icons.location_off_rounded,
                    [Colors.red.shade400, Colors.red.shade700]),
                const SizedBox(height: 20),
                const Text('سنووری جوگرافی نەگونجاو',
                    style:
                    TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Text(
                    'تکایە! ناردنی سکاڵا تەنها لە سنووری شاری کەلاردا بەردەستە.',
                    style: TextStyle(fontSize: 13, height: 1.5),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          Navigator.pop(ctx);
                          _getAutomaticLocation();
                        },
                        child: const Text('نوێکردنەوەی شوێن'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('تێدەگەم ✅',
                            style: TextStyle(fontWeight: FontWeight.w900)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Dialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(28)),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (_, __) => Transform.scale(
                      scale: _pulseAnimation.value,
                      child: _gradientIcon(Icons.check_rounded,
                          [Colors.green.shade400, Colors.green.shade700]),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('سکاڵاکەت نێردرا!',
                      style:
                      TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
                  const SizedBox(height: 12),
                  Text(
                    _neighborhoodName != null
                        ? 'سکاڵاکەت نێردرا بۆ ${_type?.authority}\nگەڕەک: $_neighborhoodName'
                        : 'سکاڵاکەت نێردرا بۆ ${_type?.authority}',
                    style: const TextStyle(
                        fontSize: 13, color: Colors.grey, height: 1.6),
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
                            borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () {
                        Navigator.pop(ctx);
                        Navigator.pop(context, true); // ⭐ caller can refresh
                      },
                      child: const Text('باشە ✅',
                          style: TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 15)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message,
              style:
              const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
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
    final garbage = _type?.cameraOnly ?? false;

    return PopScope(
      canPop: !_isSubmitting,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveDraft();
      },
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          backgroundColor: const Color(0xFFF4F6F9),
          appBar: _buildAppBar(),
          body: Column(
            children: [
              _buildProgressSteps(),
              Expanded(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  behavior: HitTestBehavior.translucent,
                  child: SingleChildScrollView(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isDraft) _buildDraftBanner(),
                        _buildStepHeader('١', 'جۆری کێشە هەڵبژێرە'),
                        const SizedBox(height: 10),
                        _buildTypeSelector(),
                        const SizedBox(height: 20),
                        if (_type == null)
                          _buildEmptyStateInfo()
                        else ...[
                          _buildAuthorityCard(),
                          const SizedBox(height: 12),
                          _buildNeighborhoodCard(),
                          const SizedBox(height: 20),
                          Column(
                            key: _imageKey,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildStepHeader('٢', 'وێنەی کێشەکە'),
                              const SizedBox(height: 10),
                              _buildImageSection(garbage),
                            ],
                          ),
                          const SizedBox(height: 20),
                          Column(
                            key: _mapKey,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildStepHeader(
                                  '٣', 'شوێنی کێشە لەسەر نەخشە'),
                              const SizedBox(height: 10),
                              _buildMapSection(),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildStepHeader(
                              '٤', 'تۆمارکردنی دەنگ (ئارەزوومەندانە) 🎤'),
                          const SizedBox(height: 10),
                          VoiceRecorderWidget(
                            onRecorded: (path) {
                              setState(() => _voicePath = path);
                              _saveDraft();
                            },
                          ),
                          if (_voicePath != null) ...[
                            const SizedBox(height: 8),
                            _buildVoiceConfirmation(),
                          ],
                          const SizedBox(height: 20),
                          Column(
                            key: _descKey,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildStepHeader(
                                  '٥',
                                  _type!.name == 'کێشەی تر'
                                      ? 'وەسفی کێشە (پێویستە)'
                                      : 'وەسفی کێشە (ئارەزوومەندانە)'),
                              const SizedBox(height: 10),
                              _buildDescriptionField(),
                            ],
                          ),
                          const SizedBox(height: 28),
                          _buildSubmitButton(),
                          const SizedBox(height: 12),
                          _buildCancelButton(),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDraftBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.history_edu_rounded, color: Colors.amber.shade800),
          const SizedBox(width: 10),
          const Expanded(
            child: Text('ڕەشنووس بارکرا — دەتوانیت درێژە بدەیت',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87)),
          ),
          TextButton(
            onPressed: _resetForm,
            child: Text('دەستپێکی نوێ',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700)),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () => setState(() => _isDraft = false),
          ),
        ],
      ),
    );
  }

  Widget _buildImageSection(bool garbage) {
    const blue = Color(0xFF2196F3);

    return GestureDetector(
      onTap: _images.isEmpty ? _handleImagePicking : null,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _hasImages
                ? Colors.green.shade400
                : blue.withValues(alpha: 0.4),
            width: 2,
          ),
        ),
        child: _images.isEmpty
            ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (_, __) => Transform.scale(
                scale: _pulseAnimation.value,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    garbage
                        ? Icons.camera_alt_rounded
                        : Icons.add_a_photo_rounded,
                    color: blue,
                    size: 30,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              garbage
                  ? 'وێنەگرتن بە کامێرا'
                  : 'وێنە بگرە (کامێرا یان گەلەری)',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: blue, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              garbage
                  ? 'مەرجە وێنەی ڕاستەوخۆ بێت'
                  : 'تا ${_ku(_maxImages)} وێنە',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final img in List<XFile>.of(_images))
              Container(
                width: 95,
                height: 115,
                margin: const EdgeInsets.symmetric(horizontal: 6),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    GestureDetector(
                      onTap: () => _previewImage(img),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(img.path),
                          fit: BoxFit.cover,
                          cacheWidth: 300,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(
                                Icons.broken_image_rounded,
                                color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          setState(() => _images.remove(img));
                          _saveDraft();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.close,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            if (_images.length < _maxImages)
              GestureDetector(
                onTap: _handleImagePicking,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      shape: BoxShape.circle),
                  child: const Icon(Icons.add_a_photo, color: blue, size: 20),
                ),
              ),
          ],
        ),
      ),
    );
  }

}