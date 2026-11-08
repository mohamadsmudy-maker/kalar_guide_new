import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/l10n/privacy_policy_text.dart';

void main() {
  test('privacy policy exists in ku/ar/en with the same structure', () {
    final ku = PrivacyPolicyText.of('ku');
    for (final lang in ['ar', 'en']) {
      final p = PrivacyPolicyText.of(lang);
      expect(p.title, isNot(ku.title), reason: lang);
      expect(p.sections.length, ku.sections.length, reason: lang);
      for (var i = 0; i < ku.sections.length; i++) {
        expect(p.sections[i].points.length, ku.sections[i].points.length,
            reason: '$lang section $i');
      }
    }
    // Google Play: سڕینەوەی ئەکاونت دەبێت باس کرابێت
    expect(PrivacyPolicyText.of('en').sections.expand((s) => s.points).join(' '),
        contains('Delete account'));
  });
}
