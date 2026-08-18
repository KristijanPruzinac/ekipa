/// The ekipa design system.
///
/// Direction **Zar**, locked 2026-08-18 after four proof rounds: deep slate
/// ground, ember accent, and one serif reserved for the names of people and
/// places. The register comes from the four reference apps in `docs/reference/`
/// — dark base, warm accent, one decision per screen, motion as atmosphere, and
/// no numbers about people — not from a metaphor, which is what the three
/// rejected proofs were built on.
///
/// **Two constraints here are machine-checked, not stylistic.** Nothing renders
/// below 14.5 logical pixels, and every text pairing meets WCAG AA on its own
/// ground; both are asserted in `test/tokens/`. Legibility was twice reported
/// as physically uncomfortable during the proof rounds, which makes it a
/// product requirement, and product requirements get tests.
///
/// The package holds tokens, six primitives and the motion vocabulary. It holds
/// no feature code, no rules, and no infrastructure. It does depend on
/// `ekipa_core` — for value objects only, so that `PersonName` can refuse to
/// accept a raw string. That dependency points inward and is enforced by
/// `tools/lint` (`UI-NO-DATA`, `UI-NO-MATCHING`).
library;

export 'src/primitives/appear.dart' show Appear, staggered;
export 'src/primitives/ekipa_button.dart' show EkipaButton, EkipaButtonTone;
export 'src/primitives/ekipa_card.dart' show EkipaCard, EkipaCardTone;
export 'src/primitives/ekipa_screen.dart' show EkipaScreen;
export 'src/primitives/fact_strip.dart' show Fact, FactStrip;
export 'src/primitives/person_name.dart' show PersonName, VenueName;
export 'src/theme/ekipa_theme.dart' show EkipaTheme;
export 'src/tokens/colors.dart' show ZarColors;
export 'src/tokens/motion.dart' show ZarMotion;
export 'src/tokens/spacing.dart' show ZarLayout, ZarRadius, ZarSpace;
export 'src/tokens/typography.dart' show ZarType;
