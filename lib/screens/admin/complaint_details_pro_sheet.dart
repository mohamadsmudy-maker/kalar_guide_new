import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmaps;
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_colors.dart';
import '../../widgets/common/optimized_network_image.dart';
import '../../services/whatsapp_complaint_service.dart';
import '../../l10n/tr.dart';

/// 🎯 Bottom Sheet ی وردەکاری سکاڵا — ULTRA PRO + WhatsApp
class ComplaintDetailsProSheet extends StatefulWidget {
  final Map<String, dynamic> complaint;
  final VoidCallback? onStatusChanged;

  const ComplaintDetailsProSheet({
    super.key,
    required this.complaint,
    this.onStatusChanged,
  });

  @override
  State<ComplaintDetailsProSheet> createState() =>
      _ComplaintDetailsProSheetState();
}

class _ComplaintDetailsProSheetState extends State<ComplaintDetailsProSheet> {
  // ═══════════════════════════════════════════════════════════
  // 🎤 Audio Player State
  // ═══════════════════════════════════════════════════════════
  final AudioPlayer _voicePlayer = AudioPlayer();
  bool _isPlayingVoice = false;
  bool _isLoadingVoice = false;
  Duration _voiceDuration = Duration.zero;
  Duration _voicePosition = Duration.zero;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _stateSub;
  bool _isPlayerInitialized = false;

  // ═══════════════════════════════════════════════════════════
  // 📝 Note State
  // ═══════════════════════════════════════════════════════════
  final TextEditingController _noteCtrl = TextEditingController();
  bool _savingNote = false;

  // ═══════════════════════════════════════════════════════════
  // 📱 WhatsApp State
  // ═══════════════════════════════════════════════════════════
  bool _sendingWhatsApp = false;

  // 🖼️ گەلەری وێنە
  final PageController _imgCtrl = PageController();
  int _imgIndex = 0;

  @override
  void initState() {
    super.initState();
    _positionSub = _voicePlayer.positionStream.listen((pos) {
      if (mounted) setState(() => _voicePosition = pos);
    });
    _stateSub = _voicePlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() {
            _isPlayingVoice = false;
            _voicePosition = Duration.zero;
          });
          _voicePlayer.seek(Duration.zero);
        }
      }
    });

    _noteCtrl.text = widget.complaint['admin_notes']?.toString() ?? '';
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _stateSub?.cancel();
    _voicePlayer.dispose();
    _noteCtrl.dispose();
    _imgCtrl.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════════════════
  // 🎤 Voice
  // ═══════════════════════════════════════════════════════════
  Future<void> _toggleVoice() async {
    final voiceUrl = widget.complaint['voice_url']?.toString() ?? '';
    if (voiceUrl.isEmpty) return;

    try {
      if (_isPlayingVoice) {
        await _voicePlayer.pause();
        if (mounted) setState(() => _isPlayingVoice = false);
      } else {
        setState(() => _isLoadingVoice = true);
        if (!_isPlayerInitialized) {
          await _voicePlayer.setUrl(voiceUrl);
          _voiceDuration = _voicePlayer.duration ?? Duration.zero;
          _isPlayerInitialized = true;
        }
        if (mounted) {
          setState(() {
            _isLoadingVoice = false;
            _isPlayingVoice = true;
          });
        }
        await _voicePlayer.play();
      }
    } catch (e) {
      debugPrint('❌ Voice error: $e');
      if (mounted) {
        setState(() {
          _isLoadingVoice = false;
          _isPlayingVoice = false;
        });
      }
    }
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  // ═══════════════════════════════════════════════════════════
  // 💾 Save Note
  // ═══════════════════════════════════════════════════════════
  Future<void> _saveNote() async {
    setState(() => _savingNote = true);
    try {
      await Supabase.instance.client
          .from('complaints')
          .update({'admin_notes': _noteCtrl.text.trim()}).eq(
              'id', widget.complaint['id']);

      widget.complaint['admin_notes'] = _noteCtrl.text.trim();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('✅ تێبینی پاشەکەوتکرا')),
            backgroundColor: const Color(0xFF0F9D7A),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trf('هەڵە: {0}', [e])),
            backgroundColor: const Color(0xFFDC3545),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingNote = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📱 WhatsApp Send
  // ═══════════════════════════════════════════════════════════
  Future<void> _sendWhatsApp({bool showPreview = true}) async {
    if (_sendingWhatsApp) return;

    setState(() => _sendingWhatsApp = true);
    HapticFeedback.mediumImpact();

    try {
      await WhatsAppComplaintService.sendComplaint(
        context: context,
        complaint: widget.complaint,
        showPreview: showPreview,
      );
    } finally {
      if (mounted) setState(() => _sendingWhatsApp = false);
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 Update Status + WhatsApp — ⭐ چاککراو
  // ═══════════════════════════════════════════════════════════
  Future<void> _updateStatus(String newStatus) async {
    try {
      await Supabase.instance.client
          .from('complaints')
          .update({'status': newStatus}).eq('id', widget.complaint['id']);

      widget.complaint['status'] = newStatus;

      HapticFeedback.mediumImpact();

      if (!mounted) return;

      // ⭐ messenger پارێزراوە پێش pop
      final messenger = ScaffoldMessenger.of(context);

      // داخستنی sheet
      Navigator.pop(context);
      widget.onStatusChanged?.call();

      // ⭐ messenger بەکاربهێنە نەک context
      messenger.showSnackBar(
        SnackBar(
          content: Text(trf('✅ گۆڕدرا بۆ: {0}', [_statusText(newStatus)])),
          backgroundColor: _color(newStatus),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );

      // ⭐ WhatsApp دوای پەسەندکردن — showPreview: true
      if (newStatus == 'in_progress') {
        await Future.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;

        await WhatsAppComplaintService.sendComplaint(
          context: context,
          complaint: widget.complaint,
          showPreview: true,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trf('هەڵە: {0}', [e])),
            backgroundColor: const Color(0xFFDC3545),
          ),
        );
      }
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final c = widget.complaint;
    final status = c['status'] ?? 'pending';
    final color = _color(status);
    final icon = _icon(status);
    final statusText = _statusText(status);

    double? lat = double.tryParse(c['latitude']?.toString() ?? '');
    double? lng = double.tryParse(c['longitude']?.toString() ?? '');

    final voiceUrl = c['voice_url']?.toString() ?? '';
    final hasVoice = voiceUrl.isNotEmpty;

    final userPhone = _extractPhoneForDisplay(c);
    final hasPhone = userPhone != null;

    List images = [];
    try {
      if (c['images'] is List)
        images = c['images'];
      else if (c['images'] is String) images = [c['images']];
    } catch (_) {}

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Directionality(
      textDirection: AppLang.direction,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.92,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A1A22) : Colors.white,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(28),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ═══ Drag Handle ═══
            const SizedBox(height: 10),
            Container(
              width: 45,
              height: 5,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(height: 8),

            // ═══ Header ═══
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.15),
                    color.withValues(alpha: 0.05),
                  ],
                ),
                border: Border(
                  bottom: BorderSide(
                    color: color.withValues(alpha: 0.3),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Icon(icon, color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tr(statusText),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr(_formatFullDate(c['created_at'])),
                          style: TextStyle(
                            fontSize: 11,
                            color:
                                isDark ? Colors.white54 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 📱 دوگمەی واتسئاپ
                  if (hasPhone)
                    GestureDetector(
                      onTap: _sendingWhatsApp
                          ? null
                          : () => _sendWhatsApp(showPreview: true),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF25D366),
                              Color(0xFF128C7E),
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF25D366)
                                  .withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: _sendingWhatsApp
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.chat_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                      ),
                    ),
                  const SizedBox(width: 6),

                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // ═══ Content ═══
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🖼️ وێنەی گەورە (بە سواپ، کرتە بۆ شاشەی تەواو)
                    if (images.isNotEmpty) ...[
                      _buildImageGallery(images),
                      const SizedBox(height: 12),
                    ],

                    // 🔗 هاوبەشکردن بۆ واتسئاپ
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          WhatsAppComplaintService.shareToWhatsApp(
                              context, widget.complaint);
                        },
                        icon: const Icon(Icons.share_rounded, size: 20),
                        label: Text(
                          tr('هاوبەشکردن بۆ واتسئاپ'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 🎤 دەنگ
                    if (hasVoice) ...[
                      _buildVoiceSection(),
                      const SizedBox(height: 16),
                    ],

                    // 📋 زانیارییەکان
                    _buildInfoCard(
                      'ناونیشان',
                      c['title'] ?? '-',
                      Icons.title_rounded,
                      isDark,
                    ),
                    const SizedBox(height: 8),
                    _buildInfoCard(
                      'لایەنی پەیوەندیدار',
                      c['responsible_authority'] ?? '-',
                      Icons.account_balance_rounded,
                      isDark,
                    ),

                    if (c['description'] != null &&
                        c['description'].toString().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _buildInfoCard(
                        'وەسف',
                        c['description'],
                        Icons.description_rounded,
                        isDark,
                      ),
                    ],

                    // 📞 ژمارەی مۆبایل
                    if (hasPhone) ...[
                      const SizedBox(height: 8),
                      _buildPhoneCard(userPhone, isDark),
                    ],

                    const SizedBox(height: 16),

                    // 🗺️ نەخشە
                    if (lat != null && lng != null && lat != 0 && lng != 0) ...[
                      _buildSectionTitle(tr('شوێن لەسەر نەخشە'), isDark),
                      const SizedBox(height: 8),
                      Container(
                        height: 180,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color:
                                isDark ? Colors.white12 : Colors.grey.shade300,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(14),
                          child: gmaps.GoogleMap(
                            initialCameraPosition: gmaps.CameraPosition(
                              target: gmaps.LatLng(lat, lng),
                              zoom: 16,
                            ),
                            markers: {
                              gmaps.Marker(
                                markerId: const gmaps.MarkerId('loc'),
                                position: gmaps.LatLng(lat, lng),
                                icon:
                                    gmaps.BitmapDescriptor.defaultMarkerWithHue(
                                  gmaps.BitmapDescriptor.hueRed,
                                ),
                              ),
                            },
                            zoomControlsEnabled: false,
                            scrollGesturesEnabled: false,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                          final uri = Uri.parse(
                            'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
                          );
                          if (await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.open_in_new_rounded,
                                color: AppColors.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                tr('کردنەوە لە Google Maps'),
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // 📝 تێبینی ئەدمین
                    _buildSectionTitle(tr('تێبینی ئەدمین'), isDark),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF0F0F14)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isDark ? Colors.white12 : Colors.grey.shade300,
                        ),
                      ),
                      child: TextField(
                        controller: _noteCtrl,
                        maxLines: 3,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 13,
                        ),
                        decoration: InputDecoration(
                          hintText: tr('تێبینییەک بنووسە...'),
                          hintStyle: const TextStyle(fontSize: 12),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.all(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _savingNote ? null : _saveNote,
                        icon: _savingNote
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_rounded, size: 18),
                        label: Text(
                          tr('پاشەکەوتکردنی تێبینی'),
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),

            // ═══ Action Buttons ═══
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F0F14) : Colors.grey.shade50,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white12 : Colors.grey.shade200,
                  ),
                ),
              ),
              child: SafeArea(
                child: _buildActionButtons(status),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎤 Voice Section
  // ═══════════════════════════════════════════════════════════
  Widget _buildVoiceSection() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF1E88E5)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E88E5).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _isLoadingVoice ? null : _toggleVoice,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 2,
                    ),
                  ),
                  child: _isLoadingVoice
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Icon(
                          _isPlayingVoice
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.mic_rounded,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          tr('دەنگی سکاڵا'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr('کرتە بکە بۆ لێدان'),
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_voiceDuration.inSeconds > 0) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  tr(_formatDuration(_voicePosition)),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Expanded(
                  child: Slider(
                    value: _voicePosition.inSeconds
                        .toDouble()
                        .clamp(0, _voiceDuration.inSeconds.toDouble()),
                    max: _voiceDuration.inSeconds
                        .toDouble()
                        .clamp(1, double.infinity),
                    onChanged: (v) =>
                        _voicePlayer.seek(Duration(seconds: v.toInt())),
                    activeColor: Colors.white,
                    inactiveColor: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                Text(
                  tr(_formatDuration(_voiceDuration)),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📞 Phone Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildPhoneCard(String phone, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF25D366).withValues(alpha: 0.15),
            const Color(0xFF25D366).withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF25D366).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF25D366),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.phone_rounded,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('ژمارەی پەیوەندی'),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : Colors.grey.shade600,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr(phone),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF25D366),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () async {
              final uri = Uri(scheme: 'tel', path: phone);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            },
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF25D366).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.call_rounded,
                color: Color(0xFF25D366),
                size: 18,
              ),
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _sendWhatsApp(showPreview: true),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.chat_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 Info Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildInfoCard(
      String label, String value, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F0F14) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr(label),
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white54 : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr(value),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          tr(title),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎯 Action Buttons
  // ═══════════════════════════════════════════════════════════
  Widget _buildActionButtons(String status) {
    if (status == 'pending') {
      return Row(
        children: [
          Expanded(
            child: _buildActionBtn(
              'پەسەندکردن',
              Icons.check_circle_rounded,
              const Color(0xFF0F9D7A),
              () => _updateStatus('in_progress'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildActionBtn(
              'ڕەتکردنەوە',
              Icons.cancel_rounded,
              const Color(0xFFDC3545),
              () => _updateStatus('rejected'),
            ),
          ),
        ],
      );
    } else if (status == 'in_progress' || status == 'approved') {
      return SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: () => _updateStatus('completed'),
          icon: const Icon(Icons.check_circle_rounded, size: 20),
          label: Text(
            tr('تەواوکردن و جێبەجێکردن ✅'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF1E88E5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    } else if (status == 'completed') {
      return _statusBanner(
        'ئەم سکاڵایە جێبەجێکراوە',
        Icons.check_circle_rounded,
        const Color(0xFF1E88E5),
      );
    } else {
      return _statusBanner(
        'ئەم سکاڵایە ڕەتکراوەتەوە',
        Icons.cancel_rounded,
        const Color(0xFFDC3545),
      );
    }
  }

  Widget _buildActionBtn(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18),
        label: Text(
          tr(label),
          style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _statusBanner(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 8),
          Text(
            tr(text),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 Helpers
  // ═══════════════════════════════════════════════════════════
  Color _color(String? s) {
    switch (s) {
      case 'pending':
        return const Color(0xFFD9822B);
      case 'approved':
      case 'in_progress':
        return const Color(0xFF0F9D7A);
      case 'rejected':
        return const Color(0xFFDC3545);
      case 'completed':
        return const Color(0xFF1E88E5);
      default:
        return Colors.grey;
    }
  }

  IconData _icon(String? s) {
    switch (s) {
      case 'pending':
        return Icons.hourglass_top_rounded;
      case 'approved':
      case 'in_progress':
        return Icons.verified_rounded;
      case 'rejected':
        return Icons.cancel_rounded;
      case 'completed':
        return Icons.check_circle_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  String _statusText(String? s) {
    switch (s) {
      case 'pending':
        return 'چاوەڕوان';
      case 'approved':
        return 'پەسەندکراو';
      case 'in_progress':
        return 'لە ئارادایە';
      case 'rejected':
        return 'ڕەتکراو';
      case 'completed':
        return 'جێبەجێکرا';
      default:
        return s ?? '';
    }
  }

  String _formatFullDate(dynamic dateTime) {
    try {
      final dt = DateTime.tryParse(dateTime.toString());
      if (dt == null) return '-';
      return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    } catch (_) {
      return '-';
    }
  }

  String? _extractPhoneForDisplay(Map<String, dynamic> c) {
    final raw = c['user_phone']?.toString() ??
        c['phone']?.toString() ??
        c['contact_phone']?.toString() ??
        '';
    if (raw.trim().isEmpty) return null;
    return raw.trim();
  }

  String _digits(int n) => n.toString().replaceAllMapped(
      RegExp(r'\d'), (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)]);

  /// 🖼️ گەلەری وێنەی گەورە: پانی تەواو، سواپ، ژمارە و خاڵی لاپەڕە
  Widget _buildImageGallery(List images) {
    final width = MediaQuery.sizeOf(context).width - 32;
    final height = (width * 0.78).clamp(220.0, 380.0);
    final multi = images.length > 1;

    return Container(
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _imgCtrl,
              itemCount: images.length,
              onPageChanged: (i) => setState(() => _imgIndex = i),
              itemBuilder: (_, i) => GestureDetector(
                onTap: () => _openImage(images, i),
                child: OptimizedNetworkImage(
                  imageUrl: images[i].toString(),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            // سێبەری خوارەوە بۆ خاڵەکان
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.25),
                      Colors.transparent,
                      Colors.transparent,
                      Colors.black.withValues(alpha: multi ? 0.45 : 0.0),
                    ],
                    stops: const [0.0, 0.25, 0.7, 1.0],
                  ),
                ),
              ),
            ),
            // ئایکۆنی شاشەی تەواو
            PositionedDirectional(
              top: 12,
              start: 12,
              child: IgnorePointer(
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.fullscreen_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ),
            if (multi) ...[
              PositionedDirectional(
                top: 12,
                end: 12,
                child: IgnorePointer(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_digits(_imgIndex + 1)} / ${_digits(images.length)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < images.length; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: i == _imgIndex ? 18 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: i == _imgIndex
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _openImage(List images, int initialIndex) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            PageView.builder(
              controller: PageController(initialPage: initialIndex),
              itemCount: images.length,
              itemBuilder: (ctx, i) => InteractiveViewer(
                child: Center(
                  child: OptimizedNetworkImage(
                    imageUrl: images[i].toString(),
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 20,
              child: IconButton(
                icon: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 30,
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
