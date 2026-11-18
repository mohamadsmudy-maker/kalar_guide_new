// lib/screens/onboarding/language_picker_step.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/app_colors.dart';
import '../../config/settings_provider.dart';
import '../../l10n/tr.dart';
import '../../widgets/common/language_flag.dart';

/// 🌍 هەڵبژاردنی زمان لە یەکەم کردنەوەی ئەپ.
/// ڕیز: کوردی، عەرەبی، فارسی، ئینگلیزی ([SettingsProvider.availableLanguages]).
class LanguagePickerStep extends StatelessWidget {
  const LanguagePickerStep({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.onContinue,
  });

  final String selected;
  final ValueChanged<String> onSelect;
  final VoidCallback onContinue;

  /// ناونیشان بە هەر چوار زمانەکە، چونکە هێشتا زمان هەڵنەبژێردراوە
  static const _titles = <String, String>{
    'ku': 'زمانەکەت هەڵبژێرە',
    'ar': 'اختر لغتك',
    'fa': 'زبان خود را انتخاب کنید',
    'en': 'Choose your language',
  };

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = isDark ? Colors.white : AppColors.textPrimary;
    final muted = isDark ? Colors.white60 : AppColors.textSecondary;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      children: [
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
            child: const Icon(Icons.translate_rounded,
                size: 48, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 24),
        Text(
          _titles[selected] ?? _titles['ku']!,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: fg),
        ),
        const SizedBox(height: 8),
        Text(
          [
            for (final l in SettingsProvider.availableLanguages)
              if (l.id != selected) _titles[l.id]!,
          ].join('  •  '),
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, height: 1.6, color: muted),
        ),
        const SizedBox(height: 28),
        for (final lang in SettingsProvider.availableLanguages)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _LanguageCard(
              key: ValueKey('lang-${lang.id}'),
              lang: lang,
              selected: lang.id == selected,
              isDark: isDark,
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(lang.id);
              },
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          height: 56,
          child: ElevatedButton(
            key: const ValueKey('lang-continue'),
            onPressed: onContinue,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              elevation: 4,
            ),
            child: Text(
              tr('بەردەوامبە'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}

class _LanguageCard extends StatelessWidget {
  const _LanguageCard({
    super.key,
    required this.lang,
    required this.selected,
    required this.isDark,
    required this.onTap,
  });

  final LanguageOption lang;
  final bool selected;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = selected
        ? AppColors.primary
        : (isDark ? Colors.white12 : Colors.black12);
    final bg = selected
        ? AppColors.primary.withValues(alpha: isDark ? 0.22 : 0.08)
        : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.white);

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: border, width: selected ? 2 : 1),
          ),
          child: Row(
            children: [
              LanguageFlag(languageId: lang.id, emoji: lang.flag),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  lang.native,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                selected
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? AppColors.primary
                    : (isDark ? Colors.white38 : Colors.black26),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
