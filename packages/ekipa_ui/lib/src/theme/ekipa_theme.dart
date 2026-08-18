import 'package:ekipa_ui/src/tokens/colors.dart';
import 'package:ekipa_ui/src/tokens/spacing.dart';
import 'package:ekipa_ui/src/tokens/typography.dart';
import 'package:flutter/material.dart';

/// Assembles the Material [ThemeData] the app runs under.
///
/// The primitives in this package read the token classes directly rather than
/// going through `Theme.of(context)`. *Why:* a token read through the theme can
/// be overridden anywhere up the tree, which is how a design system quietly
/// stops being one — and it makes every primitive's test need a `MaterialApp`
/// wrapper to say anything at all.
///
/// So what is this for? Two things the primitives cannot cover: the Material
/// widgets we do use (text fields, selection handles, scrollbars, the snack
/// bar), and the platform chrome — status bar icons, overscroll colour, text
/// selection. Left at Material's defaults those render in Material purple on a
/// slate ground, which is the exact "assembled rather than designed" tell.
abstract final class EkipaTheme {
  /// The single theme. There is no light counterpart, by decision — see
  /// [ZarColors].
  static ThemeData dark() {
    const scheme = ColorScheme.dark(
      primary: ZarColors.ember,
      onPrimary: ZarColors.emberInk,
      secondary: ZarColors.sand,
      onSecondary: ZarColors.ground,
      error: ZarColors.rose,
      onError: ZarColors.ground,
      surface: ZarColors.surface,
      onSurface: ZarColors.ink,
      outline: ZarColors.hairline,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: ZarColors.ground,
      canvasColor: ZarColors.ground,
      splashFactory: NoSplash.splashFactory,
      // The ink ripple is Material's signature and it fights a design where the
      // feedback is a scale press (ZarMotion). Turned off once, here, rather
      // than per widget.
      highlightColor: Colors.transparent,
      hoverColor: Colors.transparent,
      fontFamily: ZarType.packaged(ZarType.systemFamily),
      textTheme: _textTheme,
      dividerTheme: const DividerThemeData(
        color: ZarColors.hairline,
        thickness: ZarLayout.hairline,
        space: ZarLayout.hairline,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: ZarColors.ember,
        selectionColor: ZarColors.emberWash,
        selectionHandleColor: ZarColors.ember,
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: ZarColors.surfaceRaised,
        contentTextStyle: ZarType.body,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: ZarRadius.allMd),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: ZarColors.ember,
        linearTrackColor: ZarColors.hairline,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: ZarColors.ground,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: ZarType.heading,
        iconTheme: IconThemeData(color: ZarColors.ink),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: ZarColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: ZarColors.scrim,
        shape: RoundedRectangleBorder(borderRadius: ZarRadius.topLg),
      ),
    );
  }

  /// Maps the Zar scale onto Material's slots.
  ///
  /// Only the slots a Material widget can reach for are filled. The unfilled
  /// ones are unfilled on purpose: a screen that needs `displayLarge` is a
  /// screen reaching past the scale, and it should have to say so.
  static const TextTheme _textTheme = TextTheme(
    headlineLarge: ZarType.title,
    headlineMedium: ZarType.heading,
    titleLarge: ZarType.heading,
    titleMedium: ZarType.bodyStrong,
    bodyLarge: ZarType.body,
    bodyMedium: ZarType.body,
    bodySmall: ZarType.caption,
    labelLarge: ZarType.label,
    labelMedium: ZarType.label,
    labelSmall: ZarType.caption,
  );
}
