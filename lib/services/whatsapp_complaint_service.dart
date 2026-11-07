import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/tr.dart';

/// 📱 خزمەتگوزاری پرۆ بۆ ناردنی سکاڵا بۆ واتسئاپ
/// ✅ نامەی فۆرماتکراو + لۆکەیشن + وێنە + ڤۆیس
class WhatsAppComplaintService {
  WhatsAppComplaintService._();

  // ═══════════════════════════════════════════════════════════
  // 🚀 API ی سەرەکی
  // ═══════════════════════════════════════════════════════════

  /// 📤 ناردنی سکاڵا بۆ واتسئاپ (بە هەموو پێکهاتەکان)
  static Future<bool> sendComplaint({
    required BuildContext context,
    required Map<String, dynamic> complaint,
    bool showPreview = false,
  }) async {
    try {
      // ١. دەرهێنانی ژمارەی مۆبایل
      final phone = _extractPhone(complaint);
      if (phone == null || phone.isEmpty) {
        _showSnack(context, tr('⚠️ ژمارەی مۆبایلی سکاڵاکە نەدۆزرایەوە'), Colors.orange);
        return false;
      }

      // ٢. دروستکردنی نامە
      final message = buildMessage(complaint);

      // ٣. پیشاندانی Preview (ئارەزوومەندانە)
      if (showPreview) {
        final confirmed = await showWhatsAppPreviewSheet(
          context: context,
          complaint: complaint,
          phone: phone,
          message: message,
        );
        if (confirmed != true) return false;
      }

      // ٤. داگرتنی وێنە و ڤۆیسەکان
      if (!context.mounted) return false;
      _showSnack(context, tr('⏳ ئامادەکردنی فایلەکان...'), Colors.blue);
      final mediaFiles = await _downloadMedia(complaint);

      // ٥. ناردن
      if (!context.mounted) return false;
      return await _send(
        context: context,
        phone: phone,
        message: message,
        files: mediaFiles,
      );
    } catch (e) {
      debugPrint('❌ WhatsApp send error: $e');
      if (context.mounted) _showSnack(context, trf('هەڵە: {0}', [e]), Colors.red);
      return false;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📞 دەرهێنانی ژمارەی مۆبایل
  // ═══════════════════════════════════════════════════════════
  static String? _extractPhone(Map<String, dynamic> c) {
    final raw = c['user_phone']?.toString() ??
        c['phone']?.toString() ??
        c['contact_phone']?.toString() ??
        '';
    if (raw.isEmpty) return null;

    var clean = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (clean.isEmpty) return null;

    // لابردنی 0 ی سەرەتا
    if (clean.startsWith('0')) clean = clean.substring(1);

    // زیادکردنی کۆدی عێراق
    if (!clean.startsWith('964')) clean = '964$clean';

    return clean;
  }

  // ═══════════════════════════════════════════════════════════
  // 📝 دروستکردنی نامەی پرۆفیشناڵ
  // ═══════════════════════════════════════════════════════════
  static String buildMessage(Map<String, dynamic> c) {
    final title = c['title']?.toString() ?? 'سکاڵا';
    final desc = c['description']?.toString() ?? '';
    final authority = c['responsible_authority']?.toString() ?? '';
    final status = c['status']?.toString() ?? 'pending';
    final adminNotes = c['admin_notes']?.toString() ?? '';

    final lat = double.tryParse(c['latitude']?.toString() ?? '');
    final lng = double.tryParse(c['longitude']?.toString() ?? '');

    final buffer = StringBuffer();

    // ─── سەرەتا ───
    buffer.writeln('🆘 *ڕێبەری کەلار* — سکاڵای فەرمی');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln();

    // ─── دۆخ ───
    final statusEmoji = _statusEmoji(status);
    final statusText = _statusText(status);
    buffer.writeln('$statusEmoji *دۆخ:* $statusText');
    buffer.writeln();

    // ─── ناونیشان ───
    buffer.writeln('📋 *ناونیشان:*');
    buffer.writeln(title);
    buffer.writeln();

    // ─── لایەنی پەیوەندیدار ───
    if (authority.isNotEmpty) {
      buffer.writeln('🏛️ *لایەنی پەیوەندیدار:*');
      buffer.writeln(authority);
      buffer.writeln();
    }

    // ─── وەسف ───
    if (desc.isNotEmpty) {
      buffer.writeln('📝 *وەسف:*');
      buffer.writeln(desc);
      buffer.writeln();
    }

    // ─── تێبینی ئەدمین ───
    if (adminNotes.isNotEmpty) {
      buffer.writeln('💬 *تێبینی ئەدمین:*');
      buffer.writeln(adminNotes);
      buffer.writeln();
    }

    // ─── لۆکەیشن ───
    if (lat != null && lng != null && lat != 0 && lng != 0) {
      buffer.writeln('📍 *شوێنی سکاڵا لەسەر نەخشە:*');
      buffer.writeln('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      buffer.writeln();
      buffer.writeln('🔗 کۆئۆردینەت:');
      buffer.writeln('`$lat, $lng`');
      buffer.writeln();
    }

    // ─── بەروار ───
    final createdAt = c['created_at']?.toString();
    if (createdAt != null) {
      final dt = DateTime.tryParse(createdAt);
      if (dt != null) {
        final dateStr =
            '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
        final timeStr =
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
        buffer.writeln('📅 *بەروار:* $dateStr — $timeStr');
      }
    }

    buffer.writeln();
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('_ئەم نامەیە لەلایەن ئەپی ڕێبەری کەلارەوە نێردراوە_');
    buffer.writeln('🌐 kalar-guide.app');

    return buffer.toString();
  }

  static String _statusEmoji(String s) {
    switch (s) {
      case 'pending':
        return '⏳';
      case 'approved':
      case 'in_progress':
        return '✅';
      case 'rejected':
        return '❌';
      case 'completed':
        return '🎉';
      default:
        return '📋';
    }
  }

  static String _statusText(String s) {
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
        return s;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📥 داگرتنی وێنە و ڤۆیسەکان بۆ فایلی کاتی
  // ═══════════════════════════════════════════════════════════
  static Future<List<XFile>> _downloadMedia(Map<String, dynamic> c) async {
    final files = <XFile>[];
    Directory tempDir;
    try {
      tempDir = await getTemporaryDirectory();
    } catch (e) {
      debugPrint('⚠️ Temp dir error: $e');
      return files;
    }

    // ─── وێنەکان ───
    final images = c['images'];
    if (images is List && images.isNotEmpty) {
      for (int i = 0; i < images.length; i++) {
        try {
          final url = images[i].toString().trim();
          if (url.isEmpty || !url.startsWith('http')) continue;

          final file = await _downloadFile(
            url: url,
            directory: tempDir.path,
            fileName: 'kalar_complaint_img_${i}_${DateTime.now().millisecondsSinceEpoch}.jpg',
          );
          if (file != null) files.add(XFile(file.path));
        } catch (e) {
          debugPrint('❌ Download image $i failed: $e');
        }
      }
    }

    // ─── ڤۆیس ───
    final voiceUrl = c['voice_url']?.toString() ?? '';
    if (voiceUrl.isNotEmpty && voiceUrl.startsWith('http')) {
      try {
        final file = await _downloadFile(
          url: voiceUrl,
          directory: tempDir.path,
          fileName: 'kalar_complaint_voice_${DateTime.now().millisecondsSinceEpoch}.m4a',
        );
        if (file != null) files.add(XFile(file.path));
      } catch (e) {
        debugPrint('❌ Download voice failed: $e');
      }
    }

    return files;
  }

  static Future<File?> _downloadFile({
    required String url,
    required String directory,
    required String fileName,
  }) async {
    try {
      final file = File('$directory/$fileName');
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        debugPrint('⚠️ Download ${response.statusCode}: $url');
        return null;
      }

      await file.writeAsBytes(response.bodyBytes);
      debugPrint('✅ Downloaded: $fileName (${response.bodyBytes.length} bytes)');
      return file;
    } catch (e) {
      debugPrint('❌ Download error: $e');
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📤 ناردن — بە فایل ئەگەر هەبوو، بێ فایل ئەگەر نەبوو
  // ═══════════════════════════════════════════════════════════
  static Future<bool> _send({
    required BuildContext context,
    required String phone,
    required String message,
    required List<XFile> files,
  }) async {
    if (files.isEmpty) {
      return _openWhatsAppDirect(
        context: context,
        phone: phone,
        message: message,
      );
    }

    try {
      final result = await Share.shareXFiles(
        files,
        text: message,
        subject: tr('سکاڵای ڕێبەری کەلار'),
        sharePositionOrigin: _getSharePosition(context),
      );

      return result.status == ShareResultStatus.success ||
          result.status == ShareResultStatus.dismissed;
    } catch (e) {
      debugPrint('❌ Share error: $e');
      // فۆڵباک بۆ واتسئاپ بێ فایل
      if (!context.mounted) return false;
      return _openWhatsAppDirect(
        context: context,
        phone: phone,
        message: message,
      );
    }
  }

  /// 📱 کردنەوەی واتسئاپ ڕاستەوخۆ بە تێکست
  static Future<bool> _openWhatsAppDirect({
    required BuildContext context,
    required String phone,
    required String message,
  }) async {
    try {
      final encoded = Uri.encodeComponent(message);
      final url = Uri.parse('https://wa.me/$phone?text=$encoded');

      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
        return true;
      }

      // فۆڵباک بۆ whatsapp://
      final fallback =
      Uri.parse('whatsapp://send?phone=$phone&text=$encoded');
      if (await canLaunchUrl(fallback)) {
        await launchUrl(fallback, mode: LaunchMode.externalApplication);
        return true;
      }

      if (context.mounted) {
        _showSnack(context, tr('⚠️ واتسئاپ دامەزراو نییە'), Colors.orange);
      }
      return false;
    } catch (e) {
      debugPrint('❌ WhatsApp open error: $e');
      if (context.mounted) _showSnack(context, trf('هەڵە: {0}', [e]), Colors.red);
      return false;
    }
  }

  static Rect? _getSharePosition(BuildContext context) {
    try {
      final box = context.findRenderObject() as RenderBox?;
      if (box == null) return null;
      return box.localToGlobal(Offset.zero) & box.size;
    } catch (_) {
      return null;
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 📋 کۆپیکردنی نامە بۆ Clipboard
  // ═══════════════════════════════════════════════════════════
  static Future<void> copyMessage(
      BuildContext context,
      Map<String, dynamic> complaint,
      ) async {
    final message = buildMessage(complaint);
    await Clipboard.setData(ClipboardData(text: message));
    if (!context.mounted) return;
    _showSnack(context, tr('✅ نامە کۆپی کرا'), Colors.green);
  }

  // ═══════════════════════════════════════════════════════════
  // 🎨 پیشاندانی Bottom Sheet ی Preview
  // ═══════════════════════════════════════════════════════════
  static Future<bool?> showWhatsAppPreviewSheet({
    required BuildContext context,
    required Map<String, dynamic> complaint,
    required String phone,
    required String message,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WhatsAppPreviewSheet(
        complaint: complaint,
        phone: phone,
        message: message,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🔔 SnackBar Helper
  // ═══════════════════════════════════════════════════════════
  static void _showSnack(BuildContext context, String msg, Color color) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr(msg),
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
          ),
        ),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// 🎨 Bottom Sheet ی Preview — پرۆفیشناڵ
// ═══════════════════════════════════════════════════════════════
class _WhatsAppPreviewSheet extends StatelessWidget {
  final Map<String, dynamic> complaint;
  final String phone;
  final String message;

  const _WhatsAppPreviewSheet({
    required this.complaint,
    required this.phone,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // شمەرەکردنی فایلەکان
    final images = complaint['images'];
    final imageCount = images is List ? images.length : 0;
    final hasVoice = (complaint['voice_url']?.toString() ?? '').isNotEmpty;
    final hasLocation = (complaint['latitude']?.toString() ?? '').isNotEmpty &&
        (complaint['longitude']?.toString() ?? '').isNotEmpty;

    return Directionality(
      textDirection: AppLang.direction,
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
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
            const SizedBox(height: 16),

            // ═══ Header ═══
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  // ئایکۆنی واتسئاپ
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF25D366), Color(0xFF128C7E)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF25D366)
                              .withValues(alpha: 0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.chat_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tr('ناردن بۆ واتسئاپ'),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF1A1A2E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          tr('پێداچوونەوە بکە پێش ناردن'),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white54
                                : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ═══ Info Cards ═══
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _buildInfoCard(
                    icon: Icons.phone_rounded,
                    label: tr('ژمارە'),
                    value: phone,
                    color: const Color(0xFF25D366),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildInfoCard(
                    icon: Icons.attach_file_rounded,
                    label: tr('فایل'),
                    value: '${imageCount + (hasVoice ? 1 : 0)}',
                    color: const Color(0xFF8B5CF6),
                    isDark: isDark,
                  ),
                  const SizedBox(width: 8),
                  _buildInfoCard(
                    icon: Icons.location_on_rounded,
                    label: tr('شوێن'),
                    value: hasLocation ? 'بەردەست' : 'نەماوە',
                    color: hasLocation
                        ? const Color(0xFF1E88E5)
                        : Colors.grey,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ═══ File Chips ═══
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (imageCount > 0)
                    _buildFileChip(
                      icon: Icons.image_rounded,
                      label: trf('{0} وێنە', [imageCount]),
                      color: const Color(0xFF1E88E5),
                    ),
                  if (hasVoice)
                    _buildFileChip(
                      icon: Icons.mic_rounded,
                      label: tr('دەنگ'),
                      color: const Color(0xFFE91E63),
                    ),
                  if (hasLocation)
                    _buildFileChip(
                      icon: Icons.map_rounded,
                      label: tr('لینکی نەخشە'),
                      color: const Color(0xFFF59E0B),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ═══ Message Preview ═══
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                constraints: const BoxConstraints(maxHeight: 260),
                decoration: BoxDecoration(
                  // باکگراوندی وەک واتسئاپ
                  color: isDark
                      ? const Color(0xFF0B141A)
                      : const Color(0xFFECE5DD),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : Colors.black.withValues(alpha: 0.05),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1F2C33)
                          : const Color(0xFFDCF8C6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      tr(message),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.6,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ═══ Buttons ═══
            Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                0,
                20,
                MediaQuery.of(context).padding.bottom + 16,
              ),
              child: Row(
                children: [
                  // پاشگەزبوونەوە
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context, false),
                      icon: const Icon(Icons.close_rounded, size: 18),
                      label: Text(
                        tr('پاشگەزبوونەوە'),
                        style: const TextStyle(fontWeight: FontWeight.w900),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // ناردن
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(
                        Icons.send_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                      label: Text(
                        tr('ناردن بۆ واتسئاپ'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 54),
                        elevation: 4,
                        shadowColor:
                        const Color(0xFF25D366).withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
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

  Widget _buildInfoCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 6),
            Text(
              tr(label),
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              tr(value),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFileChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            tr(label),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}