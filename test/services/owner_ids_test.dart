import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/auth_service.dart';

void main() {
  test('ownerIds: بێ چوونەژوورەوە و بێ Supabase بەتاڵە و هەڵە نادات', () {
    expect(AuthSessionManager.ownerIds, isEmpty);
  });
}
