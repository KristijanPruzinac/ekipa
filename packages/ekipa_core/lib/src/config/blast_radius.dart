import 'package:ekipa_core/src/foundation/ids.dart';
import 'package:meta/meta.dart';

/// Something already in motion that a config change could reach.
///
/// A hangout, or a match run that has started. Deliberately opaque: the blast
/// radius does not need to know what a hangout is, only when its next rule is
/// applied and whether it already carries a version.
@immutable
final class InFlightObject {
  /// Describes one live object.
  const InFlightObject({
    required this.id,
    required this.kind,
    required this.decidesAt,
    this.pinnedVersion,
  });

  /// Its identifier, for the console's list.
  final String id;

  /// What it is — `hangout`, `match_run`. A string, because the blast radius
  /// gains nothing from an enum it would have to be taught about every time a
  /// new kind of durable object appears.
  final String kind;

  /// When a rule is next applied to it: the confirmation deadline, the reveal,
  /// the moment the sweeper looks at it again.
  final DateTime decidesAt;

  /// The version it was created under, if it carries one.
  ///
  /// A pinned object is untouchable by definition:
  /// `hangouts.config_version_id` exists so an evening plays out under the
  /// rules it started with.
  final ConfigVersionId? pinnedVersion;
}

/// What publishing a version would and would not touch.
///
/// **Intention.** `12_CONSOLE.md` §3.7: *which in-flight hangouts, if any, a
/// change would touch — the answer should usually be "none"*. The value of the
/// screen is not the "none"; it is that the number is computed rather than
/// assumed. Pinning is a claim the schema makes, and this is the thing that
/// checks the claim against the rows actually in flight before a change lands.
///
/// **Rejected — showing only the exposed count.** "0 hangouts affected" reads
/// the same whether nothing is exposed or nothing is in flight at all. Shown
/// beside "14 pinned", it says something.
@immutable
final class BlastRadius {
  const BlastRadius._({
    required this.pinned,
    required this.exposed,
    required this.settled,
  });

  /// Estimates what [effectiveFrom] would reach across [inFlight].
  ///
  /// An object is **exposed** when it carries no version and its next decision
  /// falls at or after the moment the new rules start. Everything else is
  /// either pinned to the version it began under, or already past the point
  /// where a rule would be applied to it.
  factory BlastRadius.estimate({
    required Iterable<InFlightObject> inFlight,
    required DateTime effectiveFrom,
  }) {
    final pinned = <InFlightObject>[];
    final exposed = <InFlightObject>[];
    final settled = <InFlightObject>[];

    for (final object in inFlight) {
      if (object.pinnedVersion != null) {
        pinned.add(object);
      } else if (object.decidesAt.isBefore(effectiveFrom)) {
        settled.add(object);
      } else {
        exposed.add(object);
      }
    }

    return BlastRadius._(
      pinned: List.unmodifiable(pinned),
      exposed: List.unmodifiable(exposed),
      settled: List.unmodifiable(settled),
    );
  }

  /// Objects carrying their own version. Untouched, and counted so the zero
  /// below can be read as a fact rather than as an empty table.
  final List<InFlightObject> pinned;

  /// Objects a change would reach. This is the number the confirmation step is
  /// about.
  final List<InFlightObject> exposed;

  /// Objects whose remaining decisions all fall before the change applies.
  final List<InFlightObject> settled;

  /// Whether publishing reaches nothing already in motion.
  bool get isEmpty => exposed.isEmpty;

  /// A sentence for the console, saying what it found rather than reassuring.
  String describe() {
    if (pinned.isEmpty && exposed.isEmpty && settled.isEmpty) {
      return 'Nothing is in flight.';
    }
    if (exposed.isEmpty) {
      return '${pinned.length} pinned, ${settled.length} already decided, '
          'none exposed.';
    }
    return '${exposed.length} in flight would be decided under the new rules '
        '(${pinned.length} pinned, ${settled.length} already decided).';
  }
}
