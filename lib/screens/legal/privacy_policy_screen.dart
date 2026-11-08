// lib/screens/legal/privacy_policy_screen.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_colors.dart';
import '../../l10n/privacy_policy_text.dart';
import '../../l10n/tr.dart';

/// 🔒 سیاسەتی تایبەتمەندی (ku / ar / en) — هەمان دەقی docs/privacy-policy.html
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final p = PrivacyPolicyText.of(AppLang.code);
    final card = isDark ? const Color(0xFF1E293B) : Colors.white;
    final hairline = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE8EDF3);
    final body = TextStyle(
      fontSize: 14,
      height: 1.7,
      color: isDark ? Colors.white70 : const Color(0xFF334155),
    );

    return Directionality(
      textDirection: AppLang.direction,
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(p.title),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            Text(
              '${p.updatedLabel}: ${PrivacyPolicyText.updated}',
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 8),
            Text(p.intro, style: body),
            const SizedBox(height: 12),
            for (final s in p.sections)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.title,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w900,
                        color: isDark ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final point in s.points)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.only(top: 9),
                              child: CircleAvatar(radius: 2.5, backgroundColor: AppColors.primary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(child: Text(point, style: body)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: hairline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.contactLabel,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w900,
                      color: isDark ? Colors.white : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(p.contactName, style: body),
                  InkWell(
                    onTap: () => launchUrl(
                      Uri.parse('tel:${PrivacyPolicyText.contactPhone.replaceAll(' ', '')}'),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        PrivacyPolicyText.contactPhone,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(p.changes, style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8))),
          ],
        ),
      ),
    );
  }
}
