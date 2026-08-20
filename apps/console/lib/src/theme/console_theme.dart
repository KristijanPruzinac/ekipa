import 'package:ekipa_ui/ekipa_ui.dart';
import 'package:flutter/material.dart';

/// The console's visual register.
///
/// **Intention — the same tokens, the opposite density, and two of the three
/// registers deliberately unused.**
///
/// The app is read one-handed, at dusk, by somebody deciding whether to leave
/// the house: one decision per screen, generous spacing, a single warm accent
/// where a person or a place appears. The console is read two-handed, at a
/// desk, by somebody comparing forty numbers. Same palette and same type scale
/// — a second design system is a second thing to keep honest — but laid out for
/// scanning rather than for deciding.
///
/// **What this file does not use, and why that is the point.**
///
/// `ZarType.personName` and `ZarColors.sand` do not appear here and must not.
/// The whole two-register argument in `ZarColors` is that the serif and the
/// warm tone mean *a human being is on screen*. The console never shows one:
/// `12_CONSOLE.md` §2 gives it no view over people, and the audit trail names
/// operators as `OP-7F3A`. Borrowing the human register for a config table
/// would spend the one signal the product has, on a screen with no people in
/// it. City names are places and could arguably take it; they are set in the
/// system face anyway, because "somebody is on screen" is the meaning that
/// matters and it would be a lie here.
///
/// **Ember appears three times.** The live-version marker, the primary action,
/// and the safety-critical mark. Everything else is slate and ink. An accent
/// used on every heading says nothing, which is the failure `ZarColors`
/// describes; a console where three things are orange is a console where the
/// operator's eye goes to the three things that carry consequence.
abstract final class ConsoleTheme {
  /// The console's `ThemeData`.
  static ThemeData dark() {
    final base = EkipaTheme.dark();
    return base.copyWith(
      scaffoldBackgroundColor: ZarColors.ground,
      // Density is the one thing the console genuinely overrides. Material's
      // default target sizes assume a finger; this is a mouse and a keyboard,
      // and the app's 48pt tap target would put nine rows on a screen.
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Measurements that are properties of an operator tool rather than of a phone.
abstract final class ConsoleSpace {
  /// A table row. Tight enough to compare down a column, tall enough to click.
  static const double rowHeight = 38;

  /// The gap between a key and its value inside a row.
  static const double cellGap = 16;

  /// Between rows of unrelated meaning.
  static const double blockGap = ZarSpace.xl;

  /// Between one section and the next.
  static const double sectionGap = ZarSpace.huge;

  /// The console's content ceiling.
  ///
  /// Far wider than `ZarLayout.maxContentWidth`, and for the opposite reason:
  /// the app caps at 560 so running text does not lose the reader between
  /// lines, and there is no running text here. There are columns, and columns
  /// that wrap are columns nobody can compare.
  static const double maxContentWidth = 1080;

  /// The side rail holding the section list.
  static const double railWidth = 232;
}

/// Type for dense, tabular reading.
///
/// Every style here is at or above `ZarType.minimumSize`. The 14.5 floor was
/// set because two proof rounds were rejected for physical eye discomfort, and
/// "it is a dashboard, the user is at a desk" is exactly the argument that
/// would erode it. A dense screen earns its density from spacing, not from
/// shrinking the words.
abstract final class ConsoleType {
  /// A section's name.
  static const TextStyle section = ZarType.heading;

  /// A column header.
  static const TextStyle columnHead = ZarType.monoKey;

  /// A config key's dotted name.
  static const TextStyle keyName = TextStyle(
    fontFamily: ZarType.monoFamily,
    package: ZarType.fontPackage,
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w400,
    color: ZarColors.ink,
  );

  /// A value, aligned down a column.
  static const TextStyle value = TextStyle(
    fontFamily: ZarType.monoFamily,
    package: ZarType.fontPackage,
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w500,
    fontFeatures: [FontFeature.tabularFigures()],
    color: ZarColors.ink,
  );

  /// A value that has been superseded — the "before" side of a diff.
  static final TextStyle valueWas = value.copyWith(
    color: ZarColors.inkFaint,
    decoration: TextDecoration.lineThrough,
    decorationColor: ZarColors.inkFaint,
  );

  /// Supporting text under a row.
  static const TextStyle note = ZarType.caption;

  /// The label inside a chip.
  static const TextStyle chip = TextStyle(
    fontFamily: ZarType.monoFamily,
    package: ZarType.fontPackage,
    fontSize: ZarType.minimumSize,
    height: 1.1,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.4,
    color: ZarColors.inkMuted,
  );

  /// Every style this file adds, so a test can hold the set to the same floor
  /// `ekipa_ui` holds its own scale to.
  static List<TextStyle> get all => [
    section,
    columnHead,
    keyName,
    value,
    valueWas,
    note,
    chip,
  ];
}
