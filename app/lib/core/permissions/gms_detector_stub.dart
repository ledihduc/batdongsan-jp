// Stub used on non-Android platforms (iOS, web, macOS, Windows, Linux).
// FCM works on these platforms without GMS → always return true.
Future<bool> checkGmsAvailability() async => true;
