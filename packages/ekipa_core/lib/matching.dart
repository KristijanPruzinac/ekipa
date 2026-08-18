/// The matchmaker: partition, eligibility, seed selection, the ring draw,
/// completion, validation and emission.
///
/// **Import boundary.** Only `services/mill`, `tools/simulator`, `apps/console`
/// and this package's own tests may import this library. `apps/mobile` may not,
/// and `tools/lint` fails the build if it does.
///
/// Populated in chunk 6. It exists now, empty, so the boundary is established
/// and tested before there is anything worth hiding behind it — a rule added
/// after the code it governs is a rule that gets an exception on day one.
library;

/// Marks this library as present so the import-boundary lint has a real target
/// to test against before the matcher itself is written.
const String matchingLibraryMarker = 'ekipa_core/matching';
