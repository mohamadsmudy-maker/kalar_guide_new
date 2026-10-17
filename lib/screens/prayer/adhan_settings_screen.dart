import 'package:flutter/material.dart';
import '../../../services/adhan_service.dart';

/// 🎵 شاشەی ڕێکخستنی دەنگی ئەدان
class AdhanSettingsScreen extends StatefulWidget {
  const AdhanSettingsScreen({super.key});

  @override
  State<AdhanSettingsScreen> createState() => _AdhanSettingsScreenState();
}

class _AdhanSettingsScreenState extends State<AdhanSettingsScreen> {
  final List<String> _prayers = [
    'بەیانی',
    'نیوەڕۆ',
    'عەسر',
    'مەغریب',
    'عیشا',
  ];

  final Map<String, String> _currentSounds = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSounds();
  }

  Future<void> _loadSounds() async {
    for (final prayer in _prayers) {
      _currentSounds[prayer] =
      await AdhanService.getSoundForPrayer(prayer);
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F1421),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A1B2E),
          foregroundColor: Colors.white,
          title: const Text(
            '🎵 دەنگی ئەدان',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        body: _loading
            ? const Center(
          child: CircularProgressIndicator(color: Color(0xFFFFD700)),
        )
            : ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ⭐ Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFFFD700).withValues(alpha: 0.15),
                    const Color(0xFFFFB300).withValues(alpha: 0.05),
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color:
                      const Color(0xFFFFD700).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.music_note_rounded,
                      color: Color(0xFFFFD700),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'دەنگی جیاواز بۆ هەر نوێژێک',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'دەتوانیت بۆ هەر نوێژێک دەنگی جیاواز هەڵبژێریت',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // ⭐ لیستی نوێژەکان
            ..._prayers.map((prayer) => _buildPrayerSoundCard(prayer)),

            const SizedBox(height: 20),

            // ⭐ دوگمەی گشتی
            _buildGlobalButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPrayerSoundCard(String prayer) {
    final currentSound = _currentSounds[prayer] ?? 'adhan_default';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A2030),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFFD700).withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: Color(0xFFFFD700),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                prayer,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              // ⭐ دوگمەی Play
              IconButton(
                icon: const Icon(
                  Icons.play_circle_filled_rounded,
                  color: Color(0xFFFFD700),
                  size: 28,
                ),
                onPressed: () => AdhanService.testSound(currentSound),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ⭐ Dropdown بۆ هەڵبژاردنی دەنگ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1421),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.1),
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: currentSound,
                isExpanded: true,
                dropdownColor: const Color(0xFF1A2030),
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFFFFD700),
                ),
                items: AdhanService.availableSounds.entries.map((entry) {
                  return DropdownMenuItem<String>(
                    value: entry.key,
                    child: Text(
                      entry.value,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) async {
                  if (value == null) return;
                  await AdhanService.setSoundForPrayer(
                    prayerName: prayer,
                    soundName: value,
                  );
                  setState(() => _currentSounds[prayer] = value);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalButton() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () async {
              for (final prayer in _prayers) {
                await AdhanService.setSoundForPrayer(
                  prayerName: prayer,
                  soundName: 'adhan_default',
                );
              }
              await _loadSounds();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ هەموو دەنگەکان گەڕێنرانەوە'),
                    backgroundColor: Color(0xFF10B981),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700).withValues(alpha: 0.1),
              foregroundColor: const Color(0xFFFFD700),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                ),
              ),
            ),
            icon: const Icon(Icons.restore_rounded, size: 20),
            label: const Text(
              'گەڕاندنەوە بۆ دەنگی بنەڕەتی',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
        ),
      ],
    );
  }
}