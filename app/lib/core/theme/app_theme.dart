import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'design_tokens.dart';

/// Material [ThemeData] derived from [HD] design tokens.
///
/// This is the fallback for Material widgets that still read from
/// `Theme.of(context)` (AppBar, ElevatedButton, TextField defaults, etc.)
/// during the migration to `ds_*` components. New code should prefer
/// the `Ds*` widget family which consumes [HD] tokens directly.
class AppTheme {
  AppTheme._();

  // ── Legacy aliases — keep so call sites still compile during migration. ─
  // All map to the unified [HD] palette.
  static const Color primaryColor = HD.accent;
  static const Color primaryDark = HD.accentDeep;
  static const Color onPrimaryColor = HD.paperRaised;
  static const Color backgroundColor = HD.paper;
  static const Color onBackgroundColor = HD.ink;
  static const Color surfaceColor = HD.paperRaised;
  static const Color onSurfaceColor = HD.ink;
  static const Color surfaceVariant = HD.paperSunken;
  static const Color onSurfaceVariant = HD.inkSoft;
  static const Color outlineColor = HD.hairlineStrong;
  static const Color outlineVariant = HD.hairline;
  static const Color secondaryColor = HD.positive;
  static const Color onSecondaryColor = HD.paperRaised;
  static const Color secondaryContainer = HD.positiveTint;
  static const Color onSecondaryContainer = HD.positive;
  static const Color cardBgColor = HD.paperRaised;
  static const Color lightBgColor = HD.accentTint;
  static const Color chipBgColor = HD.accentSoft;
  static const Color inputBgColor = HD.paperRaised;

  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);
    final textTheme = GoogleFonts.hankenGroteskTextTheme(base.textTheme).apply(
      bodyColor: HD.ink,
      displayColor: HD.ink,
    );

    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: HD.accent,
        onPrimary: HD.paperRaised,
        primaryContainer: HD.accentSoft,
        onPrimaryContainer: HD.accentDeep,
        secondary: HD.positive,
        onSecondary: HD.paperRaised,
        secondaryContainer: HD.positiveTint,
        onSecondaryContainer: HD.positive,
        tertiary: HD.warning,
        onTertiary: HD.paperRaised,
        tertiaryContainer: HD.warningTint,
        onTertiaryContainer: HD.warning,
        error: HD.negative,
        onError: HD.paperRaised,
        errorContainer: HD.negativeTint,
        onErrorContainer: HD.negative,
        surface: HD.paperRaised,
        onSurface: HD.ink,
        surfaceContainerLowest: HD.paperRaised,
        surfaceContainerLow: HD.paper,
        surfaceContainer: HD.paper,
        surfaceContainerHigh: HD.paperSunken,
        surfaceContainerHighest: HD.paperSunken,
        onSurfaceVariant: HD.inkSoft,
        outline: HD.hairlineStrong,
        outlineVariant: HD.hairline,
      ),
      textTheme: textTheme,
      scaffoldBackgroundColor: HD.paper,
      canvasColor: HD.paper,
      dividerColor: HD.hairline,
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        backgroundColor: HD.paper,
        foregroundColor: HD.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: HD.sectionTitle(),
        iconTheme: const IconThemeData(color: HD.ink, size: 22),
        actionsIconTheme: const IconThemeData(color: HD.ink, size: 22),
        shape: const Border(bottom: BorderSide(color: HD.hairline, width: 1)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: HD.accent,
          foregroundColor: HD.paperRaised,
          disabledBackgroundColor: HD.paperSunken,
          disabledForegroundColor: HD.inkMuted,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HD.r8),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: HD.s16,
            horizontal: HD.s24,
          ),
          elevation: 0,
          textStyle: HD.buttonLabel(),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: HD.ink,
          side: const BorderSide(color: HD.hairlineStrong, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(HD.r8),
          ),
          padding: const EdgeInsets.symmetric(
            vertical: HD.s16,
            horizontal: HD.s24,
          ),
          textStyle: HD.buttonLabel(color: HD.ink),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: HD.accent,
          textStyle: HD.buttonLabel(color: HD.accent),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: HD.paperRaised,
        hintStyle: HD.body(color: HD.inkMuted),
        labelStyle: HD.eyebrow(),
        floatingLabelStyle: HD.eyebrow(color: HD.accent),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HD.r8),
          borderSide: const BorderSide(color: HD.hairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HD.r8),
          borderSide: const BorderSide(color: HD.hairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HD.r8),
          borderSide: const BorderSide(color: HD.accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HD.r8),
          borderSide: const BorderSide(color: HD.negative),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(HD.r8),
          borderSide: const BorderSide(color: HD.negative, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: HD.s16,
          vertical: HD.s12,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: HD.neutralTint,
        labelStyle: HD.caption(color: HD.ink),
        side: const BorderSide(color: HD.hairline),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HD.r4),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: HD.s8,
          vertical: HD.s4,
        ),
      ),
      cardTheme: CardThemeData(
        color: HD.paperRaised,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HD.r12),
          side: const BorderSide(color: HD.hairline),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: HD.paperRaised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HD.r12),
        ),
        titleTextStyle: HD.sectionTitle(),
        contentTextStyle: HD.body(),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: HD.paperRaised,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(HD.r12)),
        ),
        showDragHandle: true,
        dragHandleColor: HD.hairlineStrong,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: HD.ink,
        contentTextStyle: HD.body(color: HD.paperRaised),
        actionTextColor: HD.accent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HD.r8),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: HD.ink,
        unselectedLabelColor: HD.inkMuted,
        labelStyle: HD.bodyBold(),
        unselectedLabelStyle: HD.body(),
        indicator: const UnderlineTabIndicator(
          borderSide: BorderSide(color: HD.accent, width: 2),
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: HD.hairline,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: HD.accent,
        linearTrackColor: HD.hairline,
        circularTrackColor: HD.hairline,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return HD.accent;
          return HD.paperRaised;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return HD.accentSoft;
          return HD.paperSunken;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return HD.accent;
          return HD.paperRaised;
        }),
        checkColor: const WidgetStatePropertyAll(HD.paperRaised),
        side: const BorderSide(color: HD.hairlineStrong, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HD.r4),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return HD.accent;
          return HD.hairlineStrong;
        }),
      ),
      iconTheme: const IconThemeData(color: HD.ink, size: 20),
      listTileTheme: const ListTileThemeData(
        iconColor: HD.inkSoft,
        textColor: HD.ink,
        tileColor: Colors.transparent,
        contentPadding: EdgeInsets.symmetric(
          horizontal: HD.s16,
          vertical: HD.s4,
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: HD.hairline,
        thickness: 1,
        space: 1,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: HD.paperRaised,
        indicatorColor: HD.accentSoft,
        labelTextStyle: WidgetStatePropertyAll(HD.navLabel()),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: HD.accent, size: 22);
          }
          return const IconThemeData(color: HD.inkMuted, size: 22);
        }),
        elevation: 0,
        height: 64,
      ),
    );
  }
}
