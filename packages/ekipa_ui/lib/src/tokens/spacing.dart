import 'package:flutter/painting.dart';

/// Spacing, radius and the one screen measurement everything is laid out
/// inside.
///
/// A four-point grid with named steps rather than raw numbers. *Rejected —
/// arbitrary padding per widget:* it is what the v1 kit did, and the result is
/// that no two screens share a rhythm and every restyle is a hunt through
/// literals (`LEGACY_AUDIT.md` S13).
abstract final class ZarSpace {
  /// Hairline gap — between a key and its value.
  static const double xxs = 4;

  /// Between tightly related lines.
  static const double xs = 8;

  /// Between elements inside one component.
  static const double sm = 12;

  /// The default gap. Between components in a column.
  static const double md = 16;

  /// Inside a card.
  static const double lg = 20;

  /// The screen's side margin, and the gap between unrelated blocks.
  static const double xl = 24;

  /// Between the last thing said and the decision being asked for.
  static const double xxl = 32;

  /// Around the single object on a screen that has only one.
  static const double huge = 48;

  /// The breathing room above a screen's title.
  static const double vast = 72;
}

/// Corner radii.
///
/// One family of curves. The scale is deliberately short — three values and a
/// pill — because a system with seven radii has none.
abstract final class ZarRadius {
  /// Chips and small tags.
  static const Radius sm = Radius.circular(10);

  /// Cards and fields.
  static const Radius md = Radius.circular(16);

  /// Sheets and the big surfaces that sit over a map.
  static const Radius lg = Radius.circular(28);

  /// Buttons and status pills.
  static const Radius pill = Radius.circular(999);

  /// [sm] on every corner.
  static const BorderRadius allSm = BorderRadius.all(sm);

  /// [md] on every corner.
  static const BorderRadius allMd = BorderRadius.all(md);

  /// [lg] on every corner.
  static const BorderRadius allLg = BorderRadius.all(lg);

  /// [pill] on every corner.
  static const BorderRadius allPill = BorderRadius.all(pill);

  /// [lg] on the top two corners — a sheet rising over a map, which is the
  /// Polarsteps frame `docs/reference/README.md` names as the reveal template.
  static const BorderRadius topLg = BorderRadius.only(
    topLeft: lg,
    topRight: lg,
  );
}

/// Layout constants that are properties of the product rather than of a screen.
abstract final class ZarLayout {
  /// Content never grows wider than this, whatever the device.
  ///
  /// Running text past roughly 70 characters loses the reader between lines,
  /// and a tablet or a foldable would otherwise stretch every paragraph to the
  /// glass.
  static const double maxContentWidth = 560;

  /// The minimum square a tappable thing occupies. Below this, people miss.
  static const double minTapTarget = 48;

  /// The height of a primary action.
  static const double controlHeight = 56;

  /// Thickness of a separator.
  static const double hairline = 1;
}
