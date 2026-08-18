import 'package:flutter/material.dart';
import 'colors.dart';
import 'text_styles.dart';

/// Dusk is the only theme. Deliberate: the visual thesis is warmth found in
/// the dark, which a light-mode inversion would undermine rather than serve.
class EkipaTheme {
  static ThemeData get dusk {
    const c = EkipaColors.dusk;
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: c.bg,
      fontFamily: EkipaTextStyles.body.fontFamily,
      colorScheme: ColorScheme.fromSeed(
        seedColor: c.moss,
        brightness: Brightness.dark,
        primary: c.moss,
        surface: c.bg,
        error: c.danger,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      extensions: const [c],
    );
  }
}
