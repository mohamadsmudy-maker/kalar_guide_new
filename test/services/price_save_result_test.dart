import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/price_save_result.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('parsePrice accepts Kurdish digits and separators', () {
    expect(parsePrice('157000'), 157000);
    expect(parsePrice('١٥٧٬٠٠٠'), 157000);
    expect(parsePrice(' 157,000 '), 157000);
    expect(parsePrice('۱۵۰۰'), 1500);
    expect(parsePrice('١٫٥'), 1.5);
    expect(parsePrice('abc'), isNull);
    expect(parsePrice(''), isNull);
  });

  test('server status maps to a result', () {
    expect(PriceSaveResult.fromServer('ok'), PriceSaveResult.ok);
    expect(PriceSaveResult.fromServer('forbidden'), PriceSaveResult.forbidden);
    expect(PriceSaveResult.fromServer('not_logged_in'), PriceSaveResult.notLoggedIn);
    expect(PriceSaveResult.fromServer(null), PriceSaveResult.failed);
    for (final r in PriceSaveResult.values) {
      expect(r.message, isNotEmpty);
    }
  });

  test('missing RPC is detected so the app can fall back', () {
    expect(isMissingRpc(const PostgrestException(message: 'x', code: 'PGRST202')), isTrue);
    expect(isMissingRpc(const PostgrestException(message: 'boom', code: '500')), isFalse);
    expect(isPermissionError(const PostgrestException(
        message: 'new row violates row-level security policy', code: '42501')), isTrue);
  });
}
