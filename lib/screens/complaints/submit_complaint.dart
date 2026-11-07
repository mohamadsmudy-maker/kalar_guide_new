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

  Widget _sheetHandle() => Container(
    width: 40,
    height: 4,
    decoration: BoxDecoration(
      color: Colors.grey.shade300,
      borderRadius: BorderRadius.circular(2),
    ),
  );

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
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: color, fontSize: 13)),
          ],
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

  Widget _gradientIcon(IconData icon, List<Color> colors) => Container(
    width: 90,
    height: 90,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(colors: colors),
      boxShadow: [
        BoxShadow(
          color: colors.last.withValues(alpha: 0.35),
          blurRadius: 24,
          spreadRadius: 3,
        ),
      ],
    ),
    child: Icon(icon, color: Colors.white, size: 50),
  );

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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.primary,
      elevation: 0,
      title: const Text(
        'ناردنی سکاڵای هاوڵاتی',
        style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
      ),
      centerTitle: true,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.save_rounded),
          tooltip: 'پاشەکەوتکردنی ڕەشنووس',
          onPressed: () async {
            await _saveDraft();
            _showSnackBar('💾 ڕەشنووس پاشەکەوت کرا', Colors.green);
          },
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📊 Progress
  // ═══════════════════════════════════════════════════════════
  Widget _buildProgressSteps() {
    final labels = ['جۆر', 'وێنە', 'شوێن'];
    final done = [_hasType, _hasImages, _hasLocation];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: List.generate(3, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 2 ? 0 : 6),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 5,
                    decoration: BoxDecoration(
                      color: done[i]
                          ? Colors.green.shade500
                          : Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              ...List.generate(3, (i) {
                return Expanded(
                  child: Row(
                    children: [
                      Icon(
                        done[i]
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 14,
                        color: done[i]
                            ? Colors.green.shade600
                            : Colors.grey.shade400,
                      ),
                      const SizedBox(width: 4),
                      Text(labels[i],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: done[i]
                                ? Colors.green.shade700
                                : Colors.grey.shade500,
                          )),
                    ],
                  ),
                );
              }),
              Text('${_ku(_doneCount)} لە ٣',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary)),
            ],
          ),
        ],
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

  // ═══════════════════════════════════════════════════════════
  // 🎨 Widgets
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
            child: Text(step,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13)),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A2E))),
        ),
      ],
    );
  }

  Widget _buildTypeSelector() {
    final t = _type;
    final color = t?.color ?? AppColors.primary;

    return InkWell(
      onTap: _showTypeSheet,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: t != null ? color.withValues(alpha: 0.08) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: t != null ? color : AppColors.primary.withValues(alpha: 0.3),
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(t?.icon ?? Icons.search_rounded, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                t?.name ?? 'جۆری کێشە هەڵبژێرە...',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: t != null ? Colors.black87 : AppColors.primary,
                ),
              ),
            ),
            Text(t != null ? 'گۆڕین' : '',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.bold, color: color)),
            Icon(Icons.keyboard_arrow_down_rounded, color: color),
          ],
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
          Icon(Icons.touch_app_rounded, size: 50, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          const Text('تکایە سەرەتا جۆری کێشە هەڵبژێرە',
              style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 13),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _infoCard({
    required IconData icon,
    required String label,
    required String value,
    required List<Color>? gradient,
    Widget? trailing,
  }) {
    final g = gradient;
    final on = g != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: g != null
            ? LinearGradient(
            colors: g,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight)
            : null,
        color: on ? null : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        boxShadow: g != null
            ? [
          BoxShadow(
            color: g.last.withValues(alpha: 0.3),
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
              color: on
                  ? Colors.white.withValues(alpha: 0.2)
                  : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
            child: Icon(icon,
                color: on ? Colors.white : Colors.grey.shade600, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(
                        color: on ? Colors.white70 : Colors.grey.shade600,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 2),
                Text(value,
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: on ? Colors.white : Colors.grey.shade700,
                        fontSize: 14)),
              ],
            ),
          ),
          if (trailing != null) trailing,
        ],
      ),
    );
  }

  Widget _buildAuthorityCard() {
    return _infoCard(
      icon: Icons.verified_rounded,
      label: 'لایەنی پەیوەندیدار',
      value: _type?.authority ?? '',
      gradient: [Colors.green.shade400, Colors.green.shade600],
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
        child: const Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.blue),
            ),
            SizedBox(width: 12),
            Text('دۆزینەوەی گەڕەک...',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    fontSize: 13)),
          ],
        ),
      );
    }

    final has = _neighborhoodName != null && _neighborhoodName!.isNotEmpty;
    return _infoCard(
      icon: Icons.location_city_rounded,
      label: 'گەڕەک',
      value: has ? _neighborhoodName! : 'گەڕەک نەدۆزرایەوە',
      gradient: has ? [Colors.blue.shade400, Colors.blue.shade600] : null,
      trailing: has
          ? const Icon(Icons.check_circle_rounded,
          color: Colors.white, size: 22)
          : (_hasLocation
          ? IconButton(
        icon: const Icon(Icons.refresh_rounded),
        onPressed: _detectNeighborhood,
        tooltip: 'دووبارە بدۆزەرەوە',
      )
          : null),
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

  Widget _buildMapSection() {
    final hasFix = _locIssue != _LocIssue.none ||
        (!_hasLocation && !_locationBusy);
    final okColor = _hasLocation ? Colors.green : Colors.orange;

    return Column(
      children: [
        Container(
          height: 170,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                AbsorbPointer(
                  child: gmaps.GoogleMap(
                    initialCameraPosition: gmaps.CameraPosition(
                      target: _hasLocation
                          ? gmaps.LatLng(_lat!, _lng!)
                          : const gmaps.LatLng(34.6189, 45.3156),
                      zoom: 16,
                    ),
                    zoomControlsEnabled: false,
                    myLocationButtonEnabled: false,
                    mapToolbarEnabled: false,
                    scrollGesturesEnabled: false,
                    circles: _hasLocation && (_accuracy ?? 0) > 0
                        ? {
                      gmaps.Circle(
                        circleId: const gmaps.CircleId('accuracy'),
                        center: gmaps.LatLng(_lat!, _lng!),
                        radius: _accuracy!.clamp(5, 200).toDouble(),
                        fillColor: Colors.blue.withValues(alpha: 0.12),
                        strokeColor: Colors.blue.withValues(alpha: 0.4),
                        strokeWidth: 1,
                      ),
                    }
                        : {},
                    markers: _hasLocation
                        ? {
                      gmaps.Marker(
                        markerId: const gmaps.MarkerId('current_loc'),
                        position: gmaps.LatLng(_lat!, _lng!),
                        icon: gmaps.BitmapDescriptor
                            .defaultMarkerWithHue(
                            gmaps.BitmapDescriptor.hueRed),
                      ),
                    }
                        : {},
                    onMapCreated: (c) {
                      _mapController = c;
                      if (_hasLocation) {
                        c.moveCamera(gmaps.CameraUpdate.newLatLngZoom(
                            gmaps.LatLng(_lat!, _lng!), 17));
                      }
                    },
                  ),
                ),
                if (_locationBusy)
                  Positioned.fill(
                    child: Container(
                      color: Colors.white.withValues(alpha: 0.6),
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                  ),
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Material(
                    color: Colors.white,
                    elevation: 3,
                    shape: const CircleBorder(),
                    child: IconButton(
                      icon: const Icon(Icons.my_location_rounded,
                          color: AppColors.primary),
                      tooltip: 'نوێکردنەوەی شوێن',
                      onPressed:
                      _locationBusy ? null : _getAutomaticLocation,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: okColor.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            children: [
              Icon(
                _hasLocation
                    ? Icons.check_circle_rounded
                    : Icons.access_time_rounded,
                color: okColor.shade700,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _hasLocation && _accuracy != null
                      ? '$_locationStatusText  (±${_ku(_accuracy!.round())} م)'
                      : _locationStatusText,
                  style: TextStyle(
                      fontSize: 11,
                      color: okColor.shade800,
                      fontWeight: FontWeight.bold),
                ),
              ),
              if (hasFix && !_locationBusy)
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 30),
                  ),
                  onPressed: _openLocationFix,
                  child: Text(
                    _locIssue == _LocIssue.serviceOff ||
                        _locIssue == _LocIssue.deniedForever
                        ? 'ڕێکخستن'
                        : 'دووبارە',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w900),
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
            child: Text('دەنگەکە تۆمارکرا و ئامادەیە بۆ ناردن',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.green,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionField() {
    OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: c, width: w),
    );

    return TextField(
      controller: _descCtrl,
      maxLines: 4,
      maxLength: _maxDescLength,
      textAlign: TextAlign.right,
      textInputAction: TextInputAction.newline,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        hintText: 'ڕووداوەکە لێرە زیاتر باس بکەرەوە...',
        hintStyle: const TextStyle(fontSize: 13, color: Colors.grey),
        filled: true,
        fillColor: Colors.white,
        counterStyle: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        prefixIcon: const Padding(
          padding: EdgeInsets.only(bottom: 60),
          child: Icon(Icons.description_outlined, color: AppColors.primary),
        ),
        border: border(Colors.grey.shade300, 1.5),
        enabledBorder: border(Colors.grey.shade300, 1.5),
        focusedBorder: border(AppColors.primary, 2),
        contentPadding: const EdgeInsets.all(16),
      ),
    );
  }

  Widget _buildSubmitButton() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _isSubmitting
          ? Container(
        key: const ValueKey('busy'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: AppColors.primary, strokeWidth: 2.5),
                ),
                const SizedBox(width: 12),
                Text(_submitStage,
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _uploadProgress > 0 ? _uploadProgress : null,
                minHeight: 5,
                color: AppColors.primary,
                backgroundColor: Colors.white,
              ),
            ),
          ],
        ),
      )
          : SizedBox(
        key: const ValueKey('send'),
        height: 56,
        child: ElevatedButton.icon(
          onPressed: _submitComplaint,
          style: ElevatedButton.styleFrom(
            backgroundColor:
            _isReady ? AppColors.primary : Colors.grey.shade500,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
            elevation: _isReady ? 4 : 0,
          ),
          icon: const Icon(Icons.send_rounded, size: 22),
          label: const Text('ناردنی سکاڵا',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildCancelButton() {
    return SizedBox(
      height: 50,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          side: BorderSide(color: Colors.red.shade300, width: 1.5),
        ),
        onPressed: _isSubmitting ? null : _confirmCancel,
        icon: Icon(Icons.close_rounded, color: Colors.red.shade700, size: 20),
        label: Text('پەشیمانبوونەوە',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700)),
      ),
    );
  }
}