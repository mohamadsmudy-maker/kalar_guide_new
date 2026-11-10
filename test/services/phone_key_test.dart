import 'package:flutter_test/flutter_test.dart';
import 'package:kalar_guide_new/services/auth_service.dart';

void main() {
  test('phoneKey: same number in different formats', () {
    const want = '7500000002';
    expect(AuthSessionManager.phoneKey('07500000002'), want);
    expect(AuthSessionManager.phoneKey('+964 750 000 0002'), want);
    expect(AuthSessionManager.phoneKey('009647500000002'), want);
    expect(AuthSessionManager.phoneKey('0750-000-0002'), want);
    expect(AuthSessionManager.phoneKey(null), '');
  });

  test('guest cannot edit station prices', () {
    expect(AuthSessionManager.canEditStation(stationId: 1, stationPhone: '07500000002'), isFalse);
  });
}
