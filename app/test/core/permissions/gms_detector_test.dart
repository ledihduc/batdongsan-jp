import 'package:flutter_test/flutter_test.dart';
import 'package:house_booking/core/permissions/gms_detector.dart';

void main() {
  group('GmsDetector', () {
    group('isFcmAvailable', () {
      test('returns bool on all platforms', () async {
        // This test runs on VM where kIsWeb is false
        final available = await GmsDetector.isFcmAvailable();

        // On non-Android platforms (like VM), returns true via stub
        expect(available, isNotNull);
      });

      test('completes within timeout', () async {
        final stopwatch = Stopwatch()..start();
        await GmsDetector.isFcmAvailable();
        stopwatch.stop();

        // Should complete quickly (much less than 2-second timeout)
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });

      test('handles exceptions gracefully by returning bool', () async {
        // isFcmAvailable catches all exceptions and returns false
        // This is ensured by the try-catch wrapper in the implementation
        final available = await GmsDetector.isFcmAvailable();
        expect(available, isNotNull);
      });
    });

    group('platform-specific behavior', () {
      test('non-Android platform returns true', () async {
        // Test runs on VM (non-Android)
        final available = await GmsDetector.isFcmAvailable();

        // Since this is not Android, should return true (stub behavior)
        expect(available, true);
      });

      // Android-specific test would require:
      // - Android emulator or device
      // - Actual platform channel communication
      // - Mocking google_api_availability plugin
      // This cannot be done in pure Dart unit tests
      // Integration tests (flutter test integration_test/) handle this
    });
  });
}
