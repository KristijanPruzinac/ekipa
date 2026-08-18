import 'package:flutter/animation.dart';

/// The motion vocabulary.
///
/// Carried forward deliberately from the v1 kit — `LEGACY_AUDIT.md` §4 names it
/// as the one part of the old app that reads as designed rather than assembled:
/// fade-through, pressable scale, staggered appear.
///
/// The rule from `docs/reference/README.md` is **motion as atmosphere, not
/// spectacle**. Everything here is short, and nothing bounces. *Rejected —
/// spring physics and overshoot:* it reads as playful, and this product's
/// moments are a confirmation, an arrival and a rating, none of which are
/// playful.
///
/// **Every animation in the app must be able to not happen.** Someone who has
/// asked their phone to reduce motion has usually asked for a medical reason,
/// so [scale] returns [Duration.zero] under that setting and animated
/// primitives jump to their end state rather than easing to it.
abstract final class ZarMotion {
  /// A press, a toggle, a colour change under the finger.
  static const Duration quick = Duration(milliseconds: 120);

  /// The default. A card appearing, a sheet settling.
  static const Duration base = Duration(milliseconds: 240);

  /// A screen transition, or a reveal.
  static const Duration slow = Duration(milliseconds: 420);

  /// Atmosphere — something that breathes rather than moves.
  static const Duration ambient = Duration(milliseconds: 900);

  /// The gap between successive items in a staggered entrance.
  static const Duration stagger = Duration(milliseconds: 55);

  /// Things arriving. Decelerating, so the end is calm.
  static const Curve entering = Curves.easeOutCubic;

  /// Things leaving. Accelerating, so they get out of the way.
  static const Curve leaving = Curves.easeInCubic;

  /// The emphasised arrival, for the one thing on a screen that matters.
  static const Curve emphasised = Curves.easeOutQuint;

  /// A value changing in place.
  static const Curve standard = Curves.easeInOut;

  /// [duration], or nothing at all when the platform asks for reduced motion.
  ///
  /// Callers pass the value of `MediaQuery.disableAnimationsOf(context)`.
  static Duration scale(Duration duration, {required bool reduceMotion}) =>
      reduceMotion ? Duration.zero : duration;
}
