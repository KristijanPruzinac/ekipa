/// Reads the current instant.
///
/// **Intention.** Every interesting behaviour in this product is driven by a
/// deadline that fires with no user present — confirmation windows, backfill
/// cut-off, arrival grace, rating due, sanction expiry. A system driven by
/// deadlines and reading `DateTime.now()` directly is untestable: the simulator
/// cannot run twelve weeks in a second, and DST bugs are unreproducible.
///
/// So `ekipa_core` never calls `DateTime.now()`. The dependency lint in
/// `tools/lint` fails the build if it does — see SC-6 in
/// `docs/v3/11_SECURITY.md`. Discipline degrades under deadline; lints do not.
///
/// **Rejected — a global mutable `currentClock`.** One line to write and it
/// reintroduces defect S1 from the legacy audit: a global with no injection
/// point, which is what forced `git commit 6ec65d9` ("Reset the router between
/// widget tests") in the v2 code. Tests would then share mutable time and
/// order-dependence would come back.
abstract interface class Clock {
  /// The current instant, always in UTC.
  ///
  /// Instants are stored and compared in UTC without exception; *rules* are
  /// expressed in a city's local timezone, because "16:00" and "the morning of"
  /// are local human concepts. Mixing the two is how DST bugs are born, so this
  /// interface refuses to offer a local-time accessor at all.
  DateTime nowUtc();
}
