import 'package:ekipa_core/src/domain/pair.dart';
import 'package:ekipa_core/src/domain/person.dart';
import 'package:ekipa_core/src/domain/slot.dart';
import 'package:ekipa_core/src/foundation/ids.dart';
import 'package:meta/meta.dart';

/// One completed hangout, as far as cooldown and saturation are concerned.
///
/// Not the hangout row — just the two facts a matching decision needs about a
/// past evening: who was there, and when.
@immutable
final class PastHangout {
  /// Records a past hangout.
  const PastHangout({required this.members, required this.endedAt});

  /// Who attended.
  final Set<PersonId> members;

  /// When it ended.
  final DateTime endedAt;

  /// Every pair that met at this hangout.
  Iterable<PairKey> get pairs {
    final people = members.toList();
    return [
      for (var i = 0; i < people.length; i++)
        for (var j = i + 1; j < people.length; j++)
          PairKey(people[i], people[j]),
    ];
  }
}

/// The immutable input to one match run.
///
/// **Intention.** `MatchPlan run(MatchSnapshot, MatchConfig, Seed)` is a
/// value-in / value-out transform, which is what lets the same function run in
/// the worker, in a unit test, in the simulator over a synthetic city, and in
/// the console as a dry-run against live data. That is directive D3 made
/// literal, and it means the scariest code in the system has the cheapest
/// possible test loop.
///
/// **Rejected — handing the matcher a database connection.** It would be
/// shorter to write and it would end the property above: a matcher that reads
/// cannot be dry-run, cannot be simulated, and cannot be replayed to answer
/// "why was I put in that group?" months later.
///
/// The snapshot also carries a [snapshotHash], which is what makes
/// reproducibility *checkable* rather than merely claimed.
@immutable
final class MatchSnapshot {
  /// Builds a snapshot. Every collection is copied and made unmodifiable, so a
  /// caller cannot mutate the input of a run that is already under way.
  MatchSnapshot({
    required this.cityId,
    required this.takenAt,
    required Iterable<Person> people,
    required Iterable<Slot> slots,
    required Map<SlotId, Set<PersonId>> availability,
    Iterable<Edge> edges = const [],
    Iterable<Exclusion> exclusions = const [],
    Iterable<PastHangout> history = const [],
    Map<PersonId, Set<SlotId>> alreadyPlaced = const {},
  }) : _people = Map.unmodifiable({for (final p in people) p.id: p}),
       slots = List.unmodifiable(slots),
       _availability = Map.unmodifiable({
         for (final entry in availability.entries)
           entry.key: Set<PersonId>.unmodifiable(entry.value),
       }),
       _edges = Map.unmodifiable({for (final e in edges) e.pair: e}),
       _exclusions = Set.unmodifiable({for (final e in exclusions) e.pair}),
       history = List.unmodifiable(history),
       _alreadyPlaced = Map.unmodifiable({
         for (final entry in alreadyPlaced.entries)
           entry.key: Set<SlotId>.unmodifiable(entry.value),
       });

  /// The city this run is for. Partitioning is per (city, slot).
  final CityId cityId;

  /// When the snapshot was taken. **The matcher's only notion of "now"** — it
  /// never reads a clock, so a run over yesterday's snapshot produces
  /// yesterday's plan rather than a subtly different one.
  final DateTime takenAt;

  final Map<PersonId, Person> _people;

  /// Slots in scope, in whatever order the caller supplied. The pipeline
  /// reorders them by scarcity.
  final List<Slot> slots;

  final Map<SlotId, Set<PersonId>> _availability;
  final Map<PairKey, Edge> _edges;
  final Set<PairKey> _exclusions;

  /// Completed hangouts relevant to cooldown.
  final List<PastHangout> history;

  final Map<PersonId, Set<SlotId>> _alreadyPlaced;

  /// Everyone in scope.
  Iterable<Person> get people => _people.values;

  /// How many people are in scope.
  int get populationSize => _people.length;

  /// Looks up a person, or `null` if they are not in this snapshot.
  Person? person(PersonId id) => _people[id];

  /// Who marked themselves available for [slot].
  Set<PersonId> availableFor(SlotId slot) =>
      _availability[slot] ?? const <PersonId>{};

  /// The mutual edge between two people, or `null`.
  Edge? edgeBetween(PersonId a, PersonId b) =>
      a == b ? null : _edges[PairKey(a, b)];

  /// Every edge, for building the ring sets.
  Iterable<Edge> get edges => _edges.values;

  /// Whether these two must never be matched.
  ///
  /// Symmetric by construction: the key is ordered, so there is no "either
  /// direction" to remember to check.
  bool isExcluded(PersonId a, PersonId b) =>
      a != b && _exclusions.contains(PairKey(a, b));

  /// Slots this person has already been placed into, in this run or a previous
  /// one for the same week.
  Set<SlotId> placedSlotsOf(PersonId person) =>
      _alreadyPlaced[person] ?? const <SlotId>{};

  /// How many hangouts have completed since this pair last met.
  ///
  /// One of the two cooldown clocks. `null` when they have never met, which is
  /// not the same as "a very long time ago" and must not be treated as it — a
  /// pair who have never met has no cooldown to satisfy.
  int? interveningHangoutsSince(PersonId a, PersonId b) {
    var lastIndex = -1;
    for (var i = 0; i < history.length; i++) {
      if (history[i].members.contains(a) && history[i].members.contains(b)) {
        lastIndex = i;
      }
    }
    if (lastIndex == -1) return null;

    // Hangouts either of them attended since. Counting *their* intervening
    // hangouts rather than the city's is deliberate: the rule is about how much
    // has happened to these two, and a busy city would otherwise clear a
    // cooldown for a pair who did nothing in the meantime.
    var count = 0;
    for (var i = lastIndex + 1; i < history.length; i++) {
      if (history[i].members.contains(a) || history[i].members.contains(b)) {
        count++;
      }
    }
    return count;
  }

  /// A stable digest of everything a run depends on.
  ///
  /// **Intention.** Recorded on the `match_run` row beside the seed. Together
  /// they make the claim *"the same snapshot and seed produce a byte-identical
  /// plan"* something you can check rather than something the documentation
  /// asserts. Without it, a replay that disagrees leaves you unable to tell
  /// whether the algorithm changed or the input did.
  ///
  /// FNV-1a over a canonical rendering, for the same reason
  /// `SeededRandomSource` uses it: `String.hashCode` is not stable across
  /// platforms or releases, so a digest built on it would differ between CI and
  /// a laptop and would fail *silently*.
  String get snapshotHash {
    final parts = <String>[
      cityId.value,
      takenAt.toUtc().toIso8601String(),
      for (final id in _people.keys.map((k) => k.value).toList()..sort()) id,
      for (final slot in slots.map((s) => s.id.value).toList()..sort()) slot,
      for (final entry
          in _availability.entries.toList()
            ..sort((a, b) => a.key.value.compareTo(b.key.value)))
        _availabilityPart(entry.key, entry.value),
      for (final pair
          in _edges.keys.map((k) => '${k.low.value}~${k.high.value}').toList()
            ..sort())
        pair,
      for (final pair
          in _exclusions.map((k) => '${k.low.value}!${k.high.value}').toList()
            ..sort())
        pair,
    ];

    var hash = 0x811c9dc5;
    for (final unit in parts.join('|').codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(8, '0');
  }

  static String _availabilityPart(SlotId slot, Set<PersonId> people) {
    final ids = people.map((p) => p.value).toList()..sort();
    return '${slot.value}:${ids.join(",")}';
  }

  @override
  String toString() =>
      'MatchSnapshot(${cityId.value}, '
      '${_people.length} people, ${slots.length} slots, '
      'hash=$snapshotHash)';
}
