import 'package:ekipa_core/ekipa_core.dart';

/// A synthetic person: the [Person] the matcher is allowed to see, plus the
/// latent traits that decide what they do afterwards.
///
/// **The split is the point.** Everything above [asPerson] is input to the
/// matcher; everything below it is hidden from it, exactly as the real thing is
/// hidden — nobody submits a `warmth` score, and the matcher never learns one.
/// The simulator's job is to let those hidden traits produce ratings, the
/// ratings produce edges, and the edges feed back into the next run, so we can
/// watch what twelve weeks of that loop does to the metrics in
/// `docs/v3/03_MATCHMAKER.md` §8.
///
/// **Rejected — giving agents a utility function and letting them choose.** It
/// would be a better model of a marketplace and a worse model of this product:
/// nobody picks their group here, and an agent that optimises would be
/// answering a question (can users game it?) that D9 answers structurally by
/// making the matcher unreachable.
final class Agent {
  /// Builds an agent. Traits are sampled by `Population`, never hand-set except
  /// in tests that are about one trait.
  Agent({
    required this.id,
    required this.gender,
    required this.homeAnchor,
    required this.reachableClusters,
    required this.availability,
    required this.reliability,
    required this.warmth,
    required this.openness,
    required this.patienceWeeks,
    required this.joinedWeek,
  });

  /// Their id. Stable for the whole simulation.
  final PersonId id;

  /// Their gender, sampled from the configured mix.
  final Gender gender;

  /// Where they live. Only ever used to derive [reachableClusters].
  final GeoPoint homeAnchor;

  /// Which clusters they can get to.
  final Set<ClusterId> reachableClusters;

  /// Probability of marking any one slot available in a week.
  ///
  /// Sampled per agent rather than shared, because a population where everyone
  /// is available half the time and a population split between the eager and
  /// the occasional produce very different match rates from the same average.
  final double availability;

  /// Probability of confirming and turning up once matched.
  final double reliability;

  /// How much **other people** enjoy them, in `[0, 1]`.
  ///
  /// Never visible to the matcher, never visible to them. It is the latent this
  /// whole harness exists to make consequential: warmth builds edges, edges
  /// build R1 and R2, and R1 and R2 are what the ring ratios are made of.
  final double warmth;

  /// How readily **they** enjoy other people, in `[0, 1]`.
  ///
  /// Separate from [warmth] on purpose. Collapsing them into one "niceness"
  /// axis would make every edge mutual by construction and hide the case the
  /// product actually has to survive: one-sided liking, which forms nothing.
  final double openness;

  /// Consecutive unmatched weeks tolerated before they leave.
  final int patienceWeeks;

  /// The week they joined, counted from zero.
  final int joinedWeek;

  /// Hangouts they have completed.
  int completedHangouts = 0;

  /// Consecutive weeks they wanted a hangout and did not get one.
  int weeksWaiting = 0;

  /// The week they left, or `null` while they are still here.
  int? leftWeek;

  /// The week of their first completed hangout, or `null` if it never came.
  int? firstHangoutWeek;

  /// Everyone they have actually met, for the repeat-saturation metric.
  final Set<PersonId> met = {};

  /// Whether they are still in the city.
  bool get isActive => leftWeek == null;

  /// The view of them the matcher is given.
  ///
  /// Standing is always [Standing.good]: the trust ladder in
  /// `docs/v3/04_TRUST.md` is not implemented yet, and inventing a local
  /// version of it here would be a second implementation of a rule that must
  /// have exactly one (D3). The sanction-rate row of §8 is therefore absent
  /// from the report rather than approximated in it.
  Person asPerson(CityId city) => Person(
    id: id,
    gender: gender,
    cityId: city,
    homeAnchor: homeAnchor,
    maxTravelMetres: 4000,
    reachableClusters: reachableClusters,
    standing: Standing.good,
    completedHangouts: completedHangouts,
    weeksWaiting: weeksWaiting,
    activities: const {'CONVERSATION_DECK'},
  );

  @override
  String toString() => 'Agent(${id.value}, ${completedHangouts}h)';
}
