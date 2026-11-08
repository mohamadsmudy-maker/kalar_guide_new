import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import '../services/audio_service.dart';
import '../l10n/tr.dart';

/// 🎤 Widget ی تۆمارکردنی دەنگ
class VoiceRecorderWidget extends StatefulWidget {
  final Function(String? path) onRecorded;
  final String? initialPath;

  const VoiceRecorderWidget({
    super.key,
    required this.onRecorded,
    this.initialPath,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget> {
  bool _isRecording = false;
  bool _isPlaying = false;
  int _recordSeconds = 0;
  Timer? _timer;
  String? _recordedPath;
  final AudioPlayer _player = AudioPlayer();

  // ✅ StreamSubscription بۆ چاودێریکردنی دۆخ
  StreamSubscription<PlayerState>? _playerStateSub;

  @override
  void initState() {
    super.initState();
    _recordedPath = widget.initialPath;

    // ✅ گوێگرتن بە یەکجار
    _playerStateSub = _player.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        if (mounted) {
          setState(() => _isPlaying = false);
          _player.seek(Duration.zero);
        }
      }
    });
  }

  @override
  void dispose() {
    // ✅ Timer.cancel
    _timer?.cancel();

    // ✅ StreamSubscription.cancel
    _playerStateSub?.cancel();

    // ✅ Player.dispose
    _player.dispose();

    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // وەستاندن
      final path = await AudioService.stopRecording();
      _timer?.cancel();

      if (mounted) {
        setState(() {
          _isRecording = false;
          _recordedPath = path;
        });
        widget.onRecorded(path);
      }
    } else {
      // دەستپێکردن
      final path = await AudioService.startRecording();

      if (path != null && mounted) {
        setState(() {
          _isRecording = true;
          _recordSeconds = 0;
          _recordedPath = null;
        });

        _timer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() => _recordSeconds++);
        });
      } else {
        _showError(tr('نەتوانرا تۆمارکردن دەست پێبکات'));
      }
    }
  }

  // ✅ چاککراو — بێ StreamSubscription ی نوێ
  Future<void> _togglePlay() async {
    if (_recordedPath == null) return;

    try {
      if (_isPlaying) {
        await _player.pause();
        if (mounted) setState(() => _isPlaying = false);
      } else {
        // ✅ تەنها ئەگەر URL ی جیاواز بێت، setFilePath بکە
        if (_player.audioSource == null) {
          await _player.setFilePath(_recordedPath!);
        }

        _player.play();
        if (mounted) setState(() => _isPlaying = true);
      }
    } catch (e) {
      debugPrint('❌ Play error: $e');
      _showError(tr('نەتوانرا دەنگ لێبدرێت'));
    }
  }

  Future<void> _deleteRecording() async {
    if (_recordedPath != null) {
      try {
        final file = File(_recordedPath!);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }

    // ✅ وەستاندنی Player
    try {
      await _player.stop();
    } catch (_) {}

    if (mounted) {
      setState(() {
        _recordedPath = null;
        _recordSeconds = 0;
        _isPlaying = false;
      });
      widget.onRecorded(null);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(tr(msg)), backgroundColor: const Color(0xFFDC3545)),
    );
  }

  String _formatDuration(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _isRecording
            ? Colors.red.shade50
            : const Color(0xFFF0F4F8),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _isRecording
              ? Colors.red.shade300
              : const Color(0xFFE0E6ED),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // 🎤 دوگمەی تۆمارکردن
          GestureDetector(
            onTap: _toggleRecording,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: _isRecording
                    ? const LinearGradient(
                  colors: [Color(0xFFDC3545), Color(0xFFDC3545)],
                )
                    : const LinearGradient(
                  colors: [Color(0xFF1E88E5), Color(0xFF1E88E5)],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isRecording
                        ? const Color(0xFFDC3545)
                        : const Color(0xFF1E88E5))
                        .withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                _isRecording ? Icons.stop : Icons.mic,
                color: Colors.white,
                size: 24,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ⏱ کاتی تۆمارکردن / دوگمەی لێدان
          Expanded(
            child: _isRecording
                ? Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: const BoxDecoration(
                    color: Color(0xFFDC3545),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  trf('خەریکی تۆمارکردنە... {0}', [_formatDuration(_recordSeconds)]),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFDC3545),
                  ),
                ),
              ],
            )
                : _recordedPath != null
                ? Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    color: const Color(0xFF1E88E5),
                    size: 36,
                  ),
                  onPressed: _togglePlay,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    tr('دەنگ تۆمارکراوە'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E88E5),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFDC3545),
                  ),
                  onPressed: _deleteRecording,
                ),
              ],
            )
                : Text(
              tr('🎤 کلیک بکە بۆ تۆمارکردنی دەنگ'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }
}