/// Deterministic fakes for the ports declared in `package:ekipa_core`.
///
/// Shipped in the package rather than in each consumer's `test/` folder so that
/// the app, the console, the worker and the simulator all substitute *the same*
/// fake. Four subtly different fake clocks is four subtly different notions of
/// time, and the disagreement would surface as a flaky test nobody can
/// reproduce.
library;

export 'src/testing/fake_clock.dart';
export 'src/testing/scripted_random_source.dart';
