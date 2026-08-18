/// The synthetic-population harness over the real matchmaker.
///
/// **Pulled forward from P4 to P0 deliberately.** Every ring ratio in
/// `docs/v3/03_MATCHMAKER.md` §3 is a guess, and every one of them is
/// unverifiable until a friend graph exists — which is roughly two months after
/// launch. This is the only way to test the most important algorithm in the app
/// before it runs on people.
///
/// **What it can tell us:** whether the ratios starve newcomers, whether the
/// graph closes into cliques, whether cooldown deadlocks a small city, and
/// which of those a config change makes worse. Those failures are structural,
/// so a plausible population is enough to see them.
///
/// **What it cannot tell us:** whether anybody enjoys the hangouts. Nothing
/// simulated can, and the day there is outcome data this harness stops being a
/// tuning tool and becomes a regression harness.
library;

export 'src/agent.dart';
export 'src/behaviour.dart';
export 'src/city.dart';
export 'src/metrics.dart';
export 'src/options.dart';
export 'src/population.dart';
export 'src/report.dart';
export 'src/simulation.dart';
