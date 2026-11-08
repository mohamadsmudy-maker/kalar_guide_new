import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../widgets/common/optimized_network_image.dart';
import 'submit_complaint.dart';
import '../../l10n/tr.dart';

/// 📢 دیالۆگی ڕێنمایی سکاڵا (Single Slide Version)
class ComplaintInstructionDialog {
  static const String _prefsKey = 'complaint_instruction_index';

  static Future<void> show(BuildContext context) async {
    // ١. ئەو ئیندێکسە بخوێنەرەوە کە پاشەکەوت کراوە
    final prefs = await SharedPreferences.getInstance();
    int currentIndex = prefs.getInt(_prefsKey) ?? 0;

    // ٢. هەموو سلایدە چالاکەکان بهێنە (تەنها بۆ زانینی ژمارەیان)
    final response = await Supabase.instance.client
        .from('complaint_instructions')
        .select('id, image_url')
        .eq('is_active', true)
        .order('id', ascending: true);

    final allSlides = List<Map<String, dynamic>>.from(response as List);

    if (allSlides.isEmpty) {
      // ئەگەر هیچ سلاید نەبوو، ڕاستەوخۆ بچۆ بۆ شاشەی ناردنی سکاڵا
      if (!context.mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const SubmitComplaintScreen()),
      );
      return;
    }

    // ٣. ئەگەر ئیندێکس لە سنوور دەرچووە، بگەڕێوە بۆ ٠
    if (currentIndex >= allSlides.length) {
      currentIndex = 0;
    }

    final slideToShow = allSlides[currentIndex];

    // ٤. ئیندێکسی داهاتوو پاشەکەوت بکە (بۆ جاری داهاتوو)
    final nextIndex = (currentIndex + 1) % allSlides.length;
    await prefs.setInt(_prefsKey, nextIndex);

    // ٥. دیالۆگەکە پیشان بدە
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => Directionality(
        textDirection: AppLang.direction,
        child: _ComplaintInstructionContent(slide: slideToShow),
      ),
    );
  }
}

class _ComplaintInstructionContent extends StatefulWidget {
  final Map<String, dynamic> slide;
  const _ComplaintInstructionContent({required this.slide});

  @override
  State<_ComplaintInstructionContent> createState() =>
      _ComplaintInstructionContentState();
}

class _ComplaintInstructionContentState
    extends State<_ComplaintInstructionContent> {
  bool _enableButton = false;
  int _countdown = 3;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        setState(() {
          _countdown = 0;
          _enableButton = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final String imageUrl = widget.slide['image_url'] ?? '';

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: Container(
        width: size.width * 0.95,
        height: size.height * 0.85,
        decoration: BoxDecoration(
          color: const Color(0xFF1E1B2E),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 🖼️ وێنەی سلاید
              if (imageUrl.isNotEmpty)
                OptimizedNetworkImage(imageUrl: imageUrl, fit: BoxFit.cover)
              else
                Container(
                  color: Colors.grey.shade900,
                  child: const Center(
                    child: Icon(
                      Icons.image_outlined,
                      size: 60,
                      color: Colors.white54,
                    ),
                  ),
                ),

              // 🌑 ڕووپۆشی تاریک
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.4),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                      stops: const [0, 0.5, 1],
                    ),
                  ),
                ),
              ),

              // ❌ دوگمەی داخستن
              Positioned(
                top: 14,
                right: 14,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),

              // 📍 بەشی خوارەوە
              Positioned(
                bottom: 30,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ⏱️ کۆنتداون
                    if (!_enableButton)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.7),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFFD9822B),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                trf("تکایە چاوەڕوان بە... {0}", [_countdown]),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // ✅ دوگمەی سەرەکی
                    GestureDetector(
                      onTap: _enableButton
                          ? () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                            const SubmitComplaintScreen(),
                          ),
                        );
                      }
                          : null,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeInOut,
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: _enableButton
                              ? const LinearGradient(
                            colors: [
                              Color(0xFF0F9D7A),
                              Color(0xFF0F9D7A),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                              : LinearGradient(
                            colors: [
                              Colors.grey.shade500,
                              Colors.grey.shade700,
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _enableButton
                                  ? const Color(0xFF0F9D7A)
                                  .withValues(alpha: 0.5)
                                  : Colors.black.withValues(alpha: 0.3),
                              blurRadius: _enableButton ? 20 : 10,
                              spreadRadius: _enableButton ? 2 : 0,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: AnimatedScale(
                          scale: _enableButton ? 1.0 : 0.9,
                          duration: const Duration(milliseconds: 500),
                          child: Icon(
                            _enableButton
                                ? Icons.check_rounded
                                : Icons.lock_clock_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 10),
                    AnimatedOpacity(
                      opacity: 1.0,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          tr(_enableButton
                              ? "کرتە بکە بۆ ناردنی سکاڵا ✅"
                              : "چاوەڕوانی چالاکبوون..."),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
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
      ),
    );
  }
}