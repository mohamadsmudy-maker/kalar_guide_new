import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🎵 خزمەتگوزاری دەنگی ئەدان
///
/// ✅ تایبەتمەندییەکان:
/// - Custom Sound بۆ هەر نوێژێک
/// - سەرەکی: دەنگی جیاواز بۆ بەیانی
/// - Volume Control
/// - Test Playback
class AdhanService {
  static final AudioPlayer _player = AudioPlayer();
  static const String _prefsPrefix = 'adhan_sound_';

  /// ⭐ Sounds ی بەردەست
  static const Map<String, String> availableSounds = {
    'adhan_default': 'ئەدانی ئاسایی',
    'adhan_fajr': 'ئەدانی بەیانی',
    'adhan_makkah': 'ئەدانی مەککە',
    'adhan_madinah': 'ئەدانی مەدینە',
    'adhan_alafasy': 'ئەدانی العفاسی',
    'adhan_abdulbasit': 'ئەدانی عبدالباسط',
    'beep': 'دەنگی ئاگادارکردنەوە',
    'silent': 'بێدەنگ',
  };

  /// ⭐ Sound ی بنەڕەتی بۆ هەر نوێژێک
  static const Map<String, String> defaultSounds = {
    'بەیانی': 'adhan_fajr',
    'Fajr': 'adhan_fajr',
    'نیوەڕۆ': 'adhan_default',
    'Dhuhr': 'adhan_default',
    'عەسر': 'adhan_default',
    'Asr': 'adhan_default',
    'مەغریب': 'adhan_default',
    'Maghrib': 'adhan_default',
    'عیشا': 'adhan_default',
    'Isha': 'adhan_default',
  };

  /// ✅ دەستپێکردن
  static Future<void> initialize() async {
    try {
      await _player.setReleaseMode(ReleaseMode.stop);
      debugPrint('✅ AdhanService initialized');
    } catch (e) {
      debugPrint('❌ AdhanService init error: $e');
    }
  }

  /// ✅ وەرگرتنی Sound بۆ نوێژێک
  static Future<String> getSoundForPrayer(String prayerName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = '$_prefsPrefix$prayerName';
      return prefs.getString(key) ?? defaultSounds[prayerName] ?? 'adhan_default';
    } catch (e) {
      return 'adhan_default';
    }
  }

  /// ✅ دانانی Sound بۆ نوێژێک
  static Future<void> setSoundForPrayer({
    required String prayerName,
    required String soundName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_prefsPrefix$prayerName', soundName);
      debugPrint('✅ Sound set: $prayerName → $soundName');
    } catch (e) {
      debugPrint('❌ Set sound error: $e');
    }
  }

  /// ✅ ژەنینی ئەدان
  static Future<void> playAdhan({
    required String prayerName,
    double volume = 1.0,
  }) async {
    try {
      final sound = await getSoundForPrayer(prayerName);

      if (sound == 'silent') {
        debugPrint('🔇 Silent — بێدەنگ');
        return;
      }

      await _player.setVolume(volume);
      await _player.play(AssetSource('audio/$sound.mp3'));
      debugPrint('🎵 Playing: $sound');
    } catch (e) {
      debugPrint('❌ Play error: $e');
    }
  }

  /// ✅ وەستاندن
  static Future<void> stop() async {
    try {
      await _player.stop();
    } catch (e) {
      debugPrint('❌ Stop error: $e');
    }
  }

  /// ✅ Pause
  static Future<void> pause() async {
    try {
      await _player.pause();
    } catch (e) {
      debugPrint('❌ Pause error: $e');
    }
  }

  /// ✅ Test Playback
  static Future<void> testSound(String soundName) async {
    try {
      if (soundName == 'silent') return;
      await _player.stop();
      await _player.play(AssetSource('audio/$soundName.mp3'));
    } catch (e) {
      debugPrint('❌ Test error: $e');
    }
  }

  /// ✅ Volume
  static Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume.clamp(0.0, 1.0));
    } catch (e) {
      debugPrint('❌ Volume error: $e');
    }
  }

  /// ✅ ئایا دەژەنرێت؟
  static bool get isPlaying => _player.state == PlayerState.playing;

  /// ✅ پاککردنەوە
  static Future<void> dispose() async {
    await _player.dispose();
  }
}