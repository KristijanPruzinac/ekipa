import 'package:ekipa_core/src/domain/gender.dart';
import 'package:ekipa_core/src/domain/geo.dart';
import 'package:ekipa_core/src/domain/standing.dart';
import 'package:ekipa_core/src/foundation/ids.dart';
import 'package:meta/meta.dart';

/// A person, as the matcher sees them.
///
/// **Intention.** This is a *view*, not the row. It carries the seven things a
/// matching decision can legitimately turn on and nothing else — no name, no
/// identity hash, no device, no ratings, no report history. The matcher cannot
/// leak what it was never given, and the list of fields here is a list anyone
/// can check against the promise in 02_DOMAIN.md §6.
///
/// **Rejected — passing the database row.** It is one import away and it is
/// how a first name ends up in a diagnostic string that gets logged. Legacy
/// defect S4: domain types that carry database shape cannot be tested without
/// a schema, and cannot be trusted without reading the schema.
@immutable
final class Person {
  /// Describes a person for matching purposes.
  const Person({
    required this.id,
    required this.gender,
    required this.cityId,
    required this.homeAnchor,
    required this.maxTravelMetres,
    required this.reachableClusters,
    required this.standing,
    required this.completedHangouts,
    required this.weeksWaiting,
    this.activities = const {},
    this.equipment = const {},
  });

  /// Internal surrogate. Never shown to anyone.
  final PersonId id;

  /// Registry code. The composition rule never names a value (D6).
  final Gender gender;

  /// Where they are matched.
  final CityId cityId;

  /// Snapped to a ~500 m grid before it was ever written. Matching input only,
  /// never displayed to anyone, never logged.
  final GeoPoint homeAnchor;

  /// How far they are willing to travel. The *default* comes from config; this
  /// is what they chose.
  final int maxTravelMetres;

  /// Venue clusters within [maxTravelMetres] of [homeAnchor].
  ///
  /// Precomputed rather than derived per pair, because the pairwise check runs
  /// O(n²) times per slot and a haversine per pair is the difference between a
  /// run that finishes and one that does not. It is also the right *unit*: the
  /// geographic question is "could we both get to the same place", and a place
  /// is a cluster (05_PLACES.md §4).
  final Set<ClusterId> reachableClusters;

  /// What the trust system permits. Deliberately narrow — see [Standing].
  final Standing standing;

  /// How many hangouts they have completed. Drives the newcomer multiplier.
  final int completedHangouts;

  /// Weeks since they were last matched, capped by the caller at `starve_cap`.
  ///
  /// **Why capped.** Uncapped, someone unmatchable for a *structural* reason —
  /// no reachable cluster, a gender-ratio dead end — accrues unbounded
  /// priority, permanently outranks everyone, and still never gets matched. The
  /// cap keeps that person visible on the console's unmatched report instead of
  /// buried inside a weight.
  final int weeksWaiting;

  /// Activity templates they said yes to.
  final Set<String> activities;

  /// Equipment codes they can bring. A cards hangout with nobody carrying cards
  /// is a failure the matcher can prevent, so this is matching input.
  final Set<String> equipment;

  /// Whether this is their first hangout.
  bool get isNewcomer => completedHangouts == 0;

  /// Whether [other] shares at least one reachable cluster.
  ///
  /// The geographic hard constraint, stated as the question it actually asks:
  /// not "how far apart do these two live" but "is there anywhere they could
  /// both get to".
  bool sharesClusterWith(Person other) =>
      reachableClusters.any(other.reachableClusters.contains);

  /// Clusters both could reach.
  Set<ClusterId> sharedClustersWith(Person other) =>
      reachableClusters.intersection(other.reachableClusters);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Person && other.id == id);

  @override
  int get hashCode => Object.hash(Person, id);

  /// Deliberately minimal — an id and a tier, never an anchor or a name.
  @override
  String toString() => 'Person(${id.value}, ${standing.tier.name})';
}
