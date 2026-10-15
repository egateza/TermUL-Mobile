import 'package:flutter/material.dart';

import 'termul_tokens.g.dart';

export 'termul_tokens.g.dart';

/// Tema aplikasi (hanya Gelap). Warna, ukuran, dan gaya teks berasal dari `TermulPalette`, `TermulSize`,
/// `TermulSpacing`, `TermulRadius`, dan `TermulText` (dihasilkan dari docs/design/tokens.json); widget tidak
/// boleh menulis nilai langsung.
///
/// Beda dengan docs/design/flutter.md: tidak memakai `ThemeExtension` karena hanya ada satu tema; token
/// tersedia sebagai konstanta statis.
ThemeData termulTheme() {
  const scheme = ColorScheme.dark(
    primary: TermulPalette.accent,
    onPrimary: TermulPalette.onAccent,
    secondary: TermulPalette.accent,
    onSecondary: TermulPalette.onAccent,
    surface: TermulPalette.ground,
    onSurface: TermulPalette.ink,
    error: TermulPalette.bad,
    onError: TermulPalette.groundDeep,
  );
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: TermulPalette.ground,
    canvasColor: TermulPalette.ground,
    fontFamily: TermulFonts.sans,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    dividerColor: TermulPalette.line,
    textTheme: TextTheme(
      headlineLarge: TermulText.h1,
      headlineMedium: TermulText.h2,
      titleMedium: TermulText.title,
      bodyLarge: TermulText.body,
      bodyMedium: TermulText.body,
      bodySmall: TermulText.bodySm,
      labelLarge: TermulText.label,
      labelSmall: TermulText.caption,
    ).apply(bodyColor: TermulPalette.ink, displayColor: TermulPalette.ink),
    textSelectionTheme: const TextSelectionThemeData(
      cursorColor: TermulPalette.accent,
      selectionColor: TermulPalette.terminalSelection,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: TermulPalette.surfaceRaised,
      contentTextStyle: TermulText.body.copyWith(color: TermulPalette.ink),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(TermulRadius.radiusLg),
        side: const BorderSide(color: TermulPalette.line),
      ),
    ),
  );
}
