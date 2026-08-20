import 'dart:ui';

/// The Zar palette.
///
/// Locked 2026-08-18 after four proof rounds (`00_BIBLE.md` amendment log). The
/// register comes from `docs/reference/` — dark base, warm accent — not from a
/// metaphor, which is what the three rejected proofs were built on.
///
/// **Two registers, used deliberately.** The system speaks in slate and ink;
/// the *people and places* in a hangout are the only things allowed to be warm.
/// That is the whole colour argument: when sand or ember appears, something
/// human is on screen. A palette where the accent is everywhere says nothing.
///
/// Single dark register, no light theme. *Rejected — a paired light theme:* the
/// product is evening-shaped, every screen that matters is read at dusk or in a
/// bar, and a second theme doubles the surface every contrast guarantee has to
/// hold across. The cost is real and named: someone reading in bright sun gets
/// a dark screen. Revisit if it is ever reported; do not pre-build it.
///
/// Every pairing used for text is asserted in `test/tokens/contrast_test.dart`
/// against WCAG AA. Legibility is a product requirement here, not a preference
/// — twice reported as physically uncomfortable during the proof rounds — so it
/// is a machine check, not a review note.
abstract final class ZarColors {
  // ── Ground and surfaces ────────────────────────────────────────────────────

  /// The app's ground. Deep slate rather than black: black makes ember scream,
  /// which is precisely the failure that killed proof 03.
  static const Color ground = Color(0xFF131719);

  /// A card or panel sitting on [ground].
  static const Color surface = Color(0xFF1A2023);

  /// A sheet or a dialog — the layer above [surface].
  static const Color surfaceRaised = Color(0xFF222A2E);

  /// Separator lines. Never carries text.
  static const Color hairline = Color(0xFF2C353A);

  /// Scrim behind a modal sheet, over a map or a photograph.
  static const Color scrim = Color(0xCC0B0E0F);

  // ── Ink ────────────────────────────────────────────────────────────────────

  /// Primary text on [ground] or [surface].
  static const Color ink = Color(0xFFECF1F2);

  /// Secondary text: labels, supporting lines.
  static const Color inkMuted = Color(0xFF9BAAB0);

  /// Tertiary text and disabled states. Still passes AA — a disabled control
  /// that cannot be read is a control nobody can decide about.
  ///
  /// Lightened from `#7C8C93` after `test/tokens/legibility_test.dart` failed
  /// it at 4.19:1 on [surfaceRaised]. Worth recording rather than silently
  /// fixing: the value was chosen by eye against [ground] and it looked fine
  /// there, which is exactly why the check is a test and not a review note.
  static const Color inkFaint = Color(0xFF86959C);

  // ── Ember: the accent ──────────────────────────────────────────────────────

  /// The accent. Primary actions, and the one live thing on a screen.
  static const Color ember = Color(0xFFFF6B3F);

  /// Ember pressed, and ember used as a large flat fill behind ink.
  static const Color emberQuiet = Color(0xFFC2502D);

  /// Text and icons on top of an [ember] fill.
  static const Color emberInk = Color(0xFF1A0E08);

  /// Ember at rest behind something — a tint, never a text ground.
  static const Color emberWash = Color(0x1FFF6B3F);

  // ── Sand: the human register ───────────────────────────────────────────────

  /// Reserved for the names of people and venues. See `ZarType.personName`.
  static const Color sand = Color(0xFFE9DCC6);

  /// Sand's supporting line — a venue's street, a person's arrival time.
  static const Color sandMuted = Color(0xFFB9AE9C);

  // ── State ──────────────────────────────────────────────────────────────────

  /// Confirmed, arrived, done.
  static const Color mint = Color(0xFF63D3A2);

  /// Waiting on someone, or a deadline approaching.
  static const Color amber = Color(0xFFE9B44C);

  /// Cancelled, declined, wrong. Deliberately not a pure red: nothing in this
  /// product is an emergency, and a screen that shouts at someone who just got
  /// cancelled on is the wrong screen.
  static const Color rose = Color(0xFFE5715F);

  /// Focus ring. Distinct from every state colour so keyboard focus is never
  /// confused with a status.
  static const Color focus = Color(0xFF8FD4FF);
}
