import 'package:ekipa_core/ekipa_core.dart';

/// The real [Clock], reading wall-clock time.
///
/// It lives here and not in `ekipa_core` for one reason: this is the single
/// line in the system that calls `DateTime.now()`, and the dependency lint
/// forbids that call inside the pure package. Keeping the only impure
/// implementation on the infrastructure side of the boundary is what makes the
/// ban mechanically checkable rather than a convention.
final class SystemClock implements Clock {
  /// Creates the production clock.
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}
