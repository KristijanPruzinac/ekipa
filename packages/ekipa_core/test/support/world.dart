import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_core/matching.dart';

/// A tiny city, built by hand, for the matching tests.
///
/// **Intention.** Every test below is about one rule, and a fixture that
/// requires nine lines of setup per test is a fixture that makes people write
/// one big test instead of nine small ones. The builder defaults everything to
/// "nothing wrong with this person" so each test states only the fact it is
/// about, and the assertion reads as the rule it is checking.
///
/// It lives in `test/support/` rather than in `lib/testing.dart` on purpose:
/// `testing.dart` ships to consumers and holds the *fakes for ports* that all
/// four runtimes must share. This is scaffolding for one package's own tests,
/// and shipping it would invite a consumer to build a production snapshot out
/// of test defaults.
const woman = Gender('woman');
const man = Gender('man');
const other = Gender('other');

/// The city every fixture person lives in.
const testCity = CityId('city-test');

/// Clusters, named so a test can say what it means by "reachable".
const centre = ClusterId('cluster-centre');
const north = ClusterId('cluster-north');
const south = ClusterId('cluster-south');

/// A fixed instant, so nothing in a test depends on when it runs.
final testNow = DateTime.utc(2026, 8, 20, 12);

/// A slot three days out.
final testSlot = Slot(
  id: const SlotId('slot-1'),
  cityId: testCity,
  startsAt: testNow.add(const Duration(days: 3)),
  endsAt: testNow.add(const Duration(days: 3, minutes: 90)),
);

/// A second slot, later the same evening, that does not overlap the first.
final laterSlot = Slot(
  id: const SlotId('slot-2'),
  cityId: testCity,
  startsAt: testNow.add(const Duration(days: 3, hours: 2)),
  endsAt: testNow.add(const Duration(days: 3, hours: 3, minutes: 30)),
);

/// A slot that overlaps [testSlot] by half an hour.
final overlappingSlot = Slot(
  id: const SlotId('slot-overlap'),
  cityId: testCity,
  startsAt: testNow.add(const Duration(days: 3, minutes: 60)),
  endsAt: testNow.add(const Duration(days: 3, minutes: 150)),
);

/// Builds a person with nothing wrong with them.
Person aPerson(
  String id, {
  Gender gender = woman,
  CityId? city,
  Set<ClusterId>? clusters,
  Standing standing = Standing.good,
  int completedHangouts = 3,
  int weeksWaiting = 0,
  int maxTravelMetres = 3000,
  Set<String> activities = const {'CONVERSATION_DECK'},
  Set<String> equipment = const {},
}) => Person(
  id: PersonId(id),
  gender: gender,
  cityId: city ?? testCity,
  homeAnchor: const GeoPoint(latitude: 45.555, longitude: 18.6955),
  maxTravelMetres: maxTravelMetres,
  reachableClusters: clusters ?? {centre},
  standing: standing,
  completedHangouts: completedHangouts,
  weeksWaiting: weeksWaiting,
  activities: activities,
  equipment: equipment,
);

/// Builds a snapshot in which everyone named is available for [testSlot].
MatchSnapshot aSnapshot(
  List<Person> people, {
  List<Slot>? slots,
  Map<SlotId, Set<PersonId>>? availability,
  List<Edge> edges = const [],
  List<Exclusion> exclusions = const [],
  List<PastHangout> history = const [],
  Map<PersonId, Set<SlotId>> alreadyPlaced = const {},
  DateTime? takenAt,
}) => MatchSnapshot(
  cityId: testCity,
  takenAt: takenAt ?? testNow,
  people: people,
  slots: slots ?? [testSlot],
  availability:
      availability ??
      {
        for (final slot in slots ?? [testSlot])
          slot.id: {for (final person in people) person.id},
      },
  edges: edges,
  exclusions: exclusions,
  history: history,
  alreadyPlaced: alreadyPlaced,
);

/// The default configuration, resolved from declared defaults.
MatchConfig defaultConfig() => MatchConfig.from(ConfigSnapshot.defaults());

/// A configuration with [overrides] applied over the defaults.
MatchConfig configWith(Map<String, Object?> overrides) => MatchConfig.from(
  ConfigSnapshot(
    versionId: const ConfigVersionId('test'),
    values: overrides,
  ),
);

/// A mutual edge between two people, last met [daysAgo].
Edge anEdge(
  String a,
  String b, {
  double weight = 0.8,
  int meetCount = 1,
  int daysAgo = 60,
}) => Edge(
  pair: PairKey(PersonId(a), PersonId(b)),
  weight: weight,
  meetCount: meetCount,
  lastMetAt: testNow.subtract(Duration(days: daysAgo)),
);

/// An exclusion between two people.
Exclusion anExclusion(
  String a,
  String b, {
  ExclusionReason reason = ExclusionReason.ratherNot,
}) => Exclusion(pair: PairKey(PersonId(a), PersonId(b)), reason: reason);

/// A past hangout that ended [daysAgo].
PastHangout aPastHangout(List<String> ids, {int daysAgo = 7}) => PastHangout(
  members: {for (final id in ids) PersonId(id)},
  endedAt: testNow.subtract(Duration(days: daysAgo)),
);
