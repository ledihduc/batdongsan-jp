// Android implementation of GMS availability check.
// Imported only when dart.library.io is available (native platforms).
// Uses google_api_availability v5 API (resolved: 5.0.1 in pubspec.lock).
import 'dart:io' show Platform;

import 'package:google_api_availability/google_api_availability.dart';

/// Returns true only on Android when Google Play Services are available.
/// On non-Android native platforms (iOS, macOS) returns true — FCM works natively.
///
/// GMS states that block FCM and return false (AC-N9 / D9):
///   - [serviceMissing]             — GMS not installed (Huawei, AOSP ROM).
///   - [serviceVersionUpdateRequired] — GMS too old; FCM API level mismatch.
///   - [serviceDisabled]            — GMS disabled by user/MDM.
///   - [serviceInvalid]             — Corrupted / unofficial GMS build.
///   - [serviceUpdating]            — GMS currently updating; FCM unreliable.
///   - [notAvailableOnPlatform]     — Reported on non-GMS Android forks.
///   - [unknown]                    — Cannot determine; degrade to no-FCM.
///
/// Any exception also returns false (crash safety per R6).
Future<bool> checkGmsAvailability() async {
  if (!Platform.isAndroid) return true;

  try {
    final status = await GoogleApiAvailability.instance
        .checkGooglePlayServicesAvailability();

    // Only [success] (value 0) guarantees FCM will function correctly.
    return status == GooglePlayServicesAvailability.success;
  } catch (_) {
    // Platform channel failure or plugin not initialised — degrade gracefully.
    return false;
  }
}
