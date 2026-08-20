import 'package:ekipa_core/src/foundation/clock.dart';

/// A [Clock] that only moves when a test moves it.
///
/// **Intention.** Deadline behaviour is the spine of this product, and there
/// are seven deadlines per hangout. Testing them against real time would mean
/// either sleeping (slow, flaky) or not testing them (which is what the v1 code
/// did). With this, the simulator runs twelve weeks in a second and a DST
/// boundary is a one-line test rather than a bug report in October.
final class FakeClock implements Clock {
  /// Starts the clock at [start], which is normalised to UTC.
  FakeClock(DateTime start) : _now = start.toUtc();

  DateTime _now;

  @override
  DateTime nowUtc() => _now;

  /// Moves time forward by [delta].
  ///
  /// Rejects a negative [delta]: every consumer of this clock assumes time is
  /// monotonic, and a test that rewinds it is testing a situation that cannot
  /// occur in production while appearing to prove something about one that can.
  void advance(Duration delta) {
    if (delta.isNegative) {
      throw ArgumentError.value(delta, 'delta', 'time does not move backwards');
    }
    _now = _now.add(delta);
  }

  /// Jumps to [instant], normalised to UTC. Also refuses to move backwards.
  void setTo(DateTime instant) {
    final target = instant.toUtc();
    if (target.isBefore(_now)) {
      throw ArgumentError.value(
        instant,
        'instant',
        'time does not move backwards',
      );
    }
    _now = target;
  }

  @override
  String toString() => 'FakeClock(${_now.toIso8601String()})';
}
