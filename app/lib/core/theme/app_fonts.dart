/// Font utilities for multi-region support.
///
/// Returns Noto Sans JP text theme when [FeatureFlags.isJapan] is true,
/// otherwise returns the theme unchanged (Hanken Grotesk default).
///
/// Usage: wrap the base ThemeData in MaterialApp:
/// ```dart
/// theme: AppFonts.applyToTheme(AppTheme.lightTheme),
/// ```
library;

import 'package:flutter/material.dart';
import 'package:house_booking/core/config/feature_flags.dart';

class AppFonts {
  AppFonts._();

  /// Font family name matching the pubspec.yaml `family:` key.
  static const String notoSansJP = 'NotoSansJP';

  /// Applies the correct font family to [theme] based on the build region.
  ///
  /// - `REGION=jp`: overrides textTheme fontFamily to NotoSansJP.
  /// - All other regions: returns [theme] unchanged.
  ///
  /// This is called once in [MaterialApp.router] so there is no per-frame cost.
  static ThemeData applyToTheme(ThemeData theme) {
    if (!FeatureFlags.isJapan) return theme;
    return theme.copyWith(
      textTheme: theme.textTheme.apply(fontFamily: notoSansJP),
      primaryTextTheme: theme.primaryTextTheme.apply(fontFamily: notoSansJP),
    );
  }

  /// Returns the correct fontFamily string for the current region.
  ///
  /// Useful for [TextStyle] construction outside of ThemeData.
  static String? get regionFontFamily {
    return FeatureFlags.isJapan ? notoSansJP : null;
  }
}
