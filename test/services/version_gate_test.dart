import 'package:flutter_test/flutter_test.dart';
import 'package:luilaykhao_app/services/version_gate_service.dart';

void main() {
  group('VersionGateResult.resolvedStoreUrl', () {
    test('falls back to generic store_url when no platform link is set', () {
      const result = VersionGateResult(
        blocked: false,
        updateAvailable: true,
        storeUrl: 'https://example.com/generic',
      );
      // The test VM is neither iOS nor Android, so it resolves the fallback.
      expect(result.resolvedStoreUrl, 'https://example.com/generic');
    });

    test('returns null when every store link is empty', () {
      const result = VersionGateResult(
        blocked: false,
        updateAvailable: true,
        storeUrl: '',
        iosStoreUrl: '',
        androidStoreUrl: '',
      );
      expect(result.resolvedStoreUrl, isNull);
    });

    test('ok result is not blocked and has no update', () {
      expect(VersionGateResult.ok.blocked, isFalse);
      expect(VersionGateResult.ok.updateAvailable, isFalse);
      expect(VersionGateResult.ok.resolvedStoreUrl, isNull);
    });
  });
}
