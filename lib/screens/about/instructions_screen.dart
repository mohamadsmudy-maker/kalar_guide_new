import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:kalar_guide_new/config/app_colors.dart';
import '../../l10n/tr.dart';

/// 📋 شاشەی ڕێنمایی مامەڵە فەرمانگەکان — ULTRA PRO MAX V5
///   • گەڕان • کارتی کردنەوە/داخستن • لیستی پێداویستی بە ✓
///   • کۆپی و هاوبەشکردنی لیستەکە • ئاگاداری بەرواری پشکنین
class InstructionsScreen extends StatefulWidget {
  const InstructionsScreen({super.key});

  @override
  State<InstructionsScreen> createState() => _InstructionsScreenState();
}

class _InstructionsScreenState extends State<InstructionsScreen> {
  // ═══════════════════════════════════════════════════════════
  // 📅 دوایین جار کە زانیارییەکان پشکنران — هەر کاتێک نرخەکانت نوێکردەوە، ئەمەش بگۆڕە
  // ═══════════════════════════════════════════════════════════
  static const String _lastReviewed = '٢٠٢٦/١١';

  // ═══════════════════════════════════════════════════════════
  // 📚 Data
  //   kind: doc = بەڵگەنامە (لیستی ✓) | info = زانیاری
  // ═══════════════════════════════════════════════════════════
  static final List<_InstructionData> _instructions = [
    _InstructionData(
      icon: Icons.directions_car_rounded,
      title: tr('مۆڵەتی شۆفێری'),
      color: AppColors.primary,
      office: 'بەڕێوەبەرایەتی هاتوچۆ',
      items: [
        const _Item.doc('ناسنامەی نیشتمانی', 'کارتی نیشتمانی (ڕەسەن)'),
        const _Item.doc('کارتی زانیاری', 'کارتی زانیاری (ڕەسەن)'),
        const _Item.doc('پاسپۆرت', 'پاسپۆرت (ڕەسەن)'),
        const _Item.doc('پشکنینی پزیشکی', 'لە فەرمانگەکە دەکرێت'),
        const _Item.doc('کۆدی سەردانیکردن', 'لە ماڵپەڕی هاتوچۆ وەربگرە'),
        const _Item.info('⏱️ ماوە', '٣٠-٦٠ خولەک'),
        const _Item.info('💰 نرخ', '٩١,٠٠٠ دینار'),
      ],
    ),
    _InstructionData(
      icon: Icons.home_work_rounded,
      title: tr('مۆڵەتی بیناکردن'),
      color: AppColors.green,
      office: 'بەڕێوەبەرایەتی شارەوانی',
      items: [
        const _Item.doc('وێنەی تۆمار', 'لە ٣ مانگ کۆنتر نەبێت'),
        const _Item.doc('چەسپاندنی سنوور', 'لە ٣ مانگ کۆنتر نەبێت'),
        const _Item.doc('ناسنامەی باری شارستانی', 'ڕەسەن'),
        const _Item.doc('بریکارنامە', 'ئەگەر بریکار هەبێت'),
        const _Item.info('💰 نرخ', 'لە ٢٠٠,٠٠٠ دینارەوە'),
        const _Item.info('📝 تێبینی', 'نرخ بەپێی قەبارە دەگۆڕێت'),
      ],
    ),
    _InstructionData(
      icon: Icons.card_membership_rounded,
      title: tr('پاسپۆرت'),
      color: AppColors.purple,
      office: 'بەڕێوەبەرایەتی پاسپۆرت',
      items: [
        const _Item.doc('کارتی نیشتمانی', 'ڕەسەن'),
        const _Item.doc('کارتی زانیاری', 'ڕەسەن'),
        const _Item.doc('پاسپۆرتە کۆنەکە', 'ئەگەر هەبێت'),
        const _Item.info('⏱️ ماوە', '٣٠-٦٠ خولەک'),
        const _Item.info('💰 نرخ', '٩١,٠٠٠ دینار'),
        const _Item.info('💳 پارەدان', 'تەنها بە کارتی بانکی'),
      ],
    ),
  ];

  static const List<String> _notes = [
    'نرخ و مەرجەکان دەگۆڕێن — پێش چوون پەیوەندی بە فەرمانگەکە بکە',
    'بەڵگەنامە ڕەسەنەکان پێویستن (کۆپی وەرناگیرێت)',
    'کۆدی سەردانیکردن لە ماڵپەڕی فەرمی وەربگرە',
    'پشکنینی پزیشکی تەنها بۆ ٣ مانگ کار دەکات',
  ];

  static final List<_ContactLink> _contacts = [
    _ContactLink(
      icon: Icons.language_rounded,
      label: tr('ماڵپەڕی خزمەتگوزاری'),
      displayValue: 'service.gov.krd',
      url: 'https://service.gov.krd',
      color: AppColors.primary,
    ),
    _ContactLink(
      icon: Icons.directions_car_rounded,
      label: tr('ماڵپەڕی هاتوچۆ'),
      displayValue: 'sultraffic.com',
      url: 'https://www.sultraffic.com',
      color: AppColors.green,
    ),
  ];

  // ═══════════════════════════════════════════════════════════
  // 📊 State
  // ═══════════════════════════════════════════════════════════
  String _query = '';
  final Set<int> _expanded = {0};

  /// بەڵگەنامە ئامادەکراوەکان: "cardIndex:itemIndex"
  final Set<String> _checked = {};

  String _norm(String s) => s
      .toLowerCase()
      .replaceAll('ي', 'ی')
      .replaceAll('ى', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll('ہ', 'ە')
      .replaceAll('ۀ', 'ە');

  List<int> get _visible {
    final q = _norm(_query.trim());
    if (q.isEmpty) return List.generate(_instructions.length, (i) => i);
    return [
      for (var i = 0; i < _instructions.length; i++)
        if (_norm(_instructions[i].title).contains(q) ||
            _norm(_instructions[i].office).contains(q) ||
            _instructions[i].items.any((it) => _norm(it.label).contains(q) || _norm(it.value).contains(q)))
          i,
    ];
  }

  String _asText(_InstructionData d) {
    final b = StringBuffer('📋 ${d.title}\n📍 ${d.office}\n\n');
    for (final it in d.items) {
      b.writeln(it.isDoc ? '☐ ${it.label} — ${it.value}' : '${it.label}: ${it.value}');
    }
    b.write('\n— ڕێبەری کەلار (پشکنراوە $_lastReviewed)');
    return b.toString();
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(tr(msg), style: const TextStyle(fontWeight: FontWeight.w700)),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 1),
      ));
  }

  Future<void> _launchUrl(String url) async {
    try {
      final ok = await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      if (!ok && mounted) _snack(tr('⚠️ نەتوانرا ماڵپەڕەکە بکرێتەوە'));
    } catch (e) {
      debugPrint('❌ $e');
      if (mounted) _snack(tr('⚠️ نەتوانرا ماڵپەڕەکە بکرێتەوە'));
    }
  }

  // ═══════════════════════════════════════════════════════════
  // 🏗️ Build
  // ═══════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.background;
    final textTheme = Theme.of(context).textTheme;
    final visible = _visible;

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: bgColor,
        appBar: AppBar(
          title: Text(
            tr('ڕێنمایی مامەڵە فەرمانگەکان'),
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white),
          ),
          backgroundColor: AppColors.darkBackground,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            _buildReviewedBanner(isDark, textTheme),
            const SizedBox(height: 12),
            _buildSearch(isDark),
            const SizedBox(height: 16),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Column(
                  children: [
                    Icon(Icons.search_off_rounded, size: 56, color: isDark ? Colors.white24 : Colors.grey.shade300),
                    const SizedBox(height: 10),
                    Text(tr('هیچ ئەنجامێک نەدۆزرایەوە'),
                        style: TextStyle(color: isDark ? Colors.white54 : Colors.grey, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            else
              for (final i in visible) ...[
                _buildInstructionCard(i, isDark, textTheme),
                const SizedBox(height: 14),
              ],
            const SizedBox(height: 6),
            _buildNotesCard(textTheme),
            const SizedBox(height: 20),
            _buildSectionTitle(tr('📞 پەیوەندی'), isDark, textTheme),
            const SizedBox(height: 12),
            for (int i = 0; i < _contacts.length; i++) ...[
              _buildContactRow(_contacts[i], isDark, textTheme),
              if (i < _contacts.length - 1) const SizedBox(height: 8),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildReviewedBanner(bool isDark, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              trf('دوایین پشکنینی زانیارییەکان: {0}', [_lastReviewed]),
              style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w800, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearch(bool isDark) {
    return TextField(
      onChanged: (v) => setState(() => _query = v),
      decoration: InputDecoration(
        hintText: tr('گەڕان... (پاسپۆرت، شۆفێری، نرخ)'),
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: isDark ? AppColors.darkCard : AppColors.surface,
        isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // 🎴 کارتی ڕێنمایی
  // ═══════════════════════════════════════════════════════════
  Widget _buildInstructionCard(int index, bool isDark, TextTheme textTheme) {
    final data = _instructions[index];
    final open = _expanded.contains(index) || _query.trim().isNotEmpty;
    final docs = [for (var j = 0; j < data.items.length; j++) if (data.items[j].isDoc) j];
    final done = docs.where((j) => _checked.contains('$index:$j')).length;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: data.color.withValues(alpha: 0.3), width: 1.5),
        boxShadow: [BoxShadow(color: data.color.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // ── سەردێڕ ──
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => open ? _expanded.remove(index) : _expanded.add(index));
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [data.color, data.color.withValues(alpha: 0.8)],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(data.icon, color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tr(data.title),
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white)),
                          const SizedBox(height: 2),
                          Text('📍 ${tr(data.office)}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white70)),
                        ],
                      ),
                    ),
                    if (docs.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${_ku(done)}/${_ku(docs.length)}',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                      ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(Icons.expand_more_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── ناوەڕۆک ──
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                children: [
                  for (int j = 0; j < data.items.length; j++)
                    data.items[j].isDoc
                        ? _buildDocRow(index, j, data, isDark, textTheme)
                        : _buildInfoRow(data.items[j], isDark, textTheme),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _smallBtn(Icons.copy_rounded, 'کۆپی لیست', data.color, () {
                          Clipboard.setData(ClipboardData(text: _asText(data)));
                          HapticFeedback.mediumImpact();
                          _snack(tr('✅ کۆپی کرا'));
                        }),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _smallBtn(Icons.share_rounded, 'هاوبەشکردن', data.color, () {
                          Share.share(_asText(data), subject: data.title);
                        }),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDocRow(int index, int j, _InstructionData data, bool isDark, TextTheme textTheme) {
    final key = '$index:$j';
    final checked = _checked.contains(key);
    final item = data.items[j];

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => checked ? _checked.remove(key) : _checked.add(key));
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 20,
              height: 20,
              margin: const EdgeInsets.only(top: 1),
              decoration: BoxDecoration(
                color: checked ? data.color : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: data.color, width: 1.6),
              ),
              child: checked ? const Icon(Icons.check_rounded, size: 14, color: Colors.white) : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr(item.label),
                    style: textTheme.bodyMedium?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                      decoration: checked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  Text(
                    tr(item.value),
                    style: textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      color: isDark ? Colors.white60 : AppColors.textSecondary,
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

  Widget _buildInfoRow(_Item item, bool isDark, TextTheme textTheme) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.04) : AppColors.backgroundGrey,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              tr(item.label),
              style: textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white70 : AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              tr(item.value),
              // ✅ پێشتر TextAlign.left بوو، لە RTL دا دەبێت end بێت
              textAlign: TextAlign.end,
              style: textTheme.bodySmall?.copyWith(
                fontSize: 12,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Text(tr(label), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
        ),
      ),
    );
  }

  static String _ku(int n) =>
      n.toString().replaceAllMapped(RegExp(r'\d'), (m) => '٠١٢٣٤٥٦٧٨٩'[int.parse(m[0]!)]);

  // ═══════════════════════════════════════════════════════════
  // ⚠️ Notes Card
  // ═══════════════════════════════════════════════════════════
  Widget _buildNotesCard(TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.orange.withValues(alpha: 0.15), AppColors.orange.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.3), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.orange.withValues(alpha: 0.2), shape: BoxShape.circle),
                child: const Icon(Icons.warning_amber_rounded, color: AppColors.orange, size: 20),
              ),
              const SizedBox(width: 10),
              Text(
                tr('تێبینی گرنگ'),
                style: textTheme.titleSmall?.copyWith(fontSize: 14, fontWeight: FontWeight.w900, color: AppColors.orange),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (int i = 0; i < _notes.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == _notes.length - 1 ? 0 : 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: Icon(Icons.circle, size: 6, color: AppColors.orange),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tr(_notes[i]),
                      style: textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: AppColors.orange,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark, TextTheme textTheme) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.yellow, AppColors.orange]),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          tr(title),
          style: textTheme.titleMedium?.copyWith(
            fontSize: 15,
            fontWeight: FontWeight.w900,
            color: isDark ? Colors.white : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildContactRow(_ContactLink contact, bool isDark, TextTheme textTheme) {
    return Material(
      color: isDark ? AppColors.darkCard : AppColors.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: () => _launchUrl(contact.url),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: contact.color.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: contact.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(contact.icon, color: contact.color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(contact.label),
                      style: textTheme.labelSmall?.copyWith(
                        fontSize: 11,
                        color: isDark ? Colors.white54 : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tr(contact.displayValue),
                      textDirection: TextDirection.ltr,
                      style: textTheme.titleSmall?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w900,
                        color: contact.color,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: tr('کۆپی'),
                icon: Icon(Icons.copy_rounded, size: 16, color: isDark ? Colors.white54 : Colors.grey),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: contact.url));
                  _snack(tr('✅ لینک کۆپی کرا'));
                },
              ),
              Icon(Icons.open_in_new_rounded, size: 16, color: contact.color),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// 🧱 Data Models
// ═══════════════════════════════════════════════════════════
class _InstructionData {
  final IconData icon;
  final String title;
  final String office;
  final Color color;
  final List<_Item> items;

  const _InstructionData({
    required this.icon,
    required this.title,
    required this.office,
    required this.color,
    required this.items,
  });
}

class _Item {
  final String label;
  final String value;
  final bool isDoc;

  const _Item.doc(this.label, this.value) : isDoc = true;
  const _Item.info(this.label, this.value) : isDoc = false;
}

class _ContactLink {
  final IconData icon;
  final String label;
  final String displayValue;
  final String url;
  final Color color;

  const _ContactLink({
    required this.icon,
    required this.label,
    required this.displayValue,
    required this.url,
    required this.color,
  });
}
