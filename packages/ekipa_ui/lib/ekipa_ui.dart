/// The ekipa design system.
///
/// Direction **Zar** (proof 04, agreed 2026-08-18): deep slate ground, ember
/// accent, and one serif reserved for the names of people and places. The four
/// reference apps in `docs/reference/` decided the register — dark base, warm
/// accent, one decision per screen, motion as atmosphere, and no numbers about
/// people.
///
/// Two constraints are hard requirements rather than preferences, both learned
/// from review: **nothing below 14.5sp**, and **no script or decorative face
/// anywhere**. Legibility is a product requirement here, not a nicety.
///
/// Tokens and the six primitives land in chunk 4. This library exists now so
/// the package boundary is fixed before any screen imports styling from
/// elsewhere.
library;
