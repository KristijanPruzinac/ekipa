/// The matchmaker: partition, eligibility, seed selection, the ring draw,
/// completion, validation and emission.
///
/// **Import boundary.** Only `services/mill`, `tools/simulator`, `apps/console`
/// and this package's own tests may import this library. `apps/mobile` may not,
/// and `tools/lint` fails the build if it does.
library;

export 'src/matching/eligibility.dart';
export 'src/matching/matching_config.dart';
export 'src/matching/ring.dart';
export 'src/matching/seed_policy.dart';
export 'src/matching/snapshot.dart';
