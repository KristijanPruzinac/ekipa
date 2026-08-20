import 'package:ekipa_ui/src/tokens/colors.dart';
import 'package:flutter/painting.dart';

/// The type scale.
///
/// Three families, three jobs, and the jobs do not overlap:
///
/// * **Archivo** is the system voice. Everything the app says about itself. *
/// **Instrument Serif** is reserved for **the names of people and venues** and
/// nothing else. It is the typographic half of the two-register argument in
/// [ZarColors]: when the serif appears, a human being is on screen. * **DM
/// Mono** carries times, counts and codes, where digits have to line up and be
/// read at a glance while walking.
///
/// **The floor is 14.5.** Nothing in this file is smaller, and
/// `test/tokens/type_scale_test.dart` fails the build if a style is added below
/// it. This is not a preference: two proof rounds were rejected for physical
/// eye discomfort, so the constraint is machine-checked like any other
/// invariant.
///
/// *Rejected — a fourth "display" face with personality:* proof 03 put
/// character in a decorative face and it was the thing that hurt to read.
/// Character here lives in the palette and the spacing, and the type stays out
/// of the way.
abstract final class ZarType {
  /// The family every word the app says in its own voice is set in.
  static const String systemFamily = 'Archivo';

  /// The family used **only** for the names of people and venues.
  static const String nameFamily = 'Instrument Serif';

  /// The family used for times, counts and codes.
  static const String monoFamily = 'DM Mono';

  /// Where the bundled faces live, so a consumer app does not have to know.
  static const String fontPackage = 'ekipa_ui';

  /// The smallest size any style in this system is permitted to use.
  static const double minimumSize = 14.5;

  /// The family name Flutter actually resolves for a packaged face.
  ///
  /// `TextStyle(fontFamily: 'Archivo', package: 'ekipa_ui')` folds the package
  /// into the family as `packages/ekipa_ui/Archivo` before anything can read it
  /// back, so anywhere a family name is compared or handed to `ThemeData` it
  /// has to be this form. Named rather than spelled out at each call site,
  /// because a hand-written prefix that drifts fails silently — the face just
  /// falls back and the screen looks subtly wrong with nothing to point at.
  static String packaged(String family) => 'packages/$fontPackage/$family';

  // ── System voice ───────────────────────────────────────────────────────────

  /// The one big statement on a screen. One per screen, or none.
  static const TextStyle title = TextStyle(
    fontFamily: systemFamily,
    package: fontPackage,
    fontSize: 30,
    height: 1.14,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    color: ZarColors.ink,
  );

  /// A section within a screen.
  static const TextStyle heading = TextStyle(
    fontFamily: systemFamily,
    package: fontPackage,
    fontSize: 22,
    height: 1.27,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: ZarColors.ink,
  );

  /// Running text. The size most of the product is read at.
  static const TextStyle body = TextStyle(
    fontFamily: systemFamily,
    package: fontPackage,
    fontSize: 17,
    height: 1.47,
    fontWeight: FontWeight.w400,
    color: ZarColors.ink,
  );

  /// Running text carrying the weight of a decision.
  static const TextStyle bodyStrong = TextStyle(
    fontFamily: systemFamily,
    package: fontPackage,
    fontSize: 17,
    height: 1.47,
    fontWeight: FontWeight.w500,
    color: ZarColors.ink,
  );

  /// A button's word, or a field's label.
  ///
  /// The same size as [body] and separated from it by weight, not by a point.
  /// It was 16 until `type_scale_test.dart` pointed out that 16 and 17 are not
  /// a hierarchy — they are an accident nobody can see and everybody has to
  /// maintain. A button's word is also a sentence someone is deciding on, so
  /// reading size is the right size for it.
  static const TextStyle label = TextStyle(
    fontFamily: systemFamily,
    package: fontPackage,
    fontSize: 17,
    height: 1.24,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    color: ZarColors.ink,
  );

  /// The supporting line under something. The floor of the scale.
  static const TextStyle caption = TextStyle(
    fontFamily: systemFamily,
    package: fontPackage,
    fontSize: minimumSize,
    height: 1.34,
    fontWeight: FontWeight.w400,
    color: ZarColors.inkMuted,
  );

  // ── The reserved register: people and places ───────────────────────────────

  /// A person's or a venue's name, at the size a name is normally read.
  static const TextStyle personName = TextStyle(
    fontFamily: nameFamily,
    package: fontPackage,
    fontSize: 24,
    height: 1.2,
    fontWeight: FontWeight.w400,
    color: ZarColors.sand,
  );

  /// A person's or a venue's name as the subject of the whole screen.
  static const TextStyle personNameHero = TextStyle(
    fontFamily: nameFamily,
    package: fontPackage,
    fontSize: 40,
    height: 1.1,
    fontWeight: FontWeight.w400,
    color: ZarColors.sand,
  );

  // ── Times, counts, codes ───────────────────────────────────────────────────

  /// A time or a count, read at a glance.
  static const TextStyle mono = TextStyle(
    fontFamily: monoFamily,
    package: fontPackage,
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w400,
    fontFeatures: [FontFeature.tabularFigures()],
    color: ZarColors.ink,
  );

  /// The small all-caps key above a fact. Letter-spaced because capitals set
  /// tight are the other thing that is hard to read.
  static const TextStyle monoKey = TextStyle(
    fontFamily: monoFamily,
    package: fontPackage,
    fontSize: minimumSize,
    height: 1.2,
    fontWeight: FontWeight.w500,
    letterSpacing: 1.1,
    fontFeatures: [FontFeature.tabularFigures()],
    color: ZarColors.inkMuted,
  );

  /// Every style in the scale, so tests can hold the whole set to one rule.
  static const List<TextStyle> all = [
    title,
    heading,
    body,
    bodyStrong,
    label,
    caption,
    personName,
    personNameHero,
    mono,
    monoKey,
  ];
}
