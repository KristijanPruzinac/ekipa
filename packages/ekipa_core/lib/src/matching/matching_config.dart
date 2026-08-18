import 'package:ekipa_core/src/config/catalogue.dart';
import 'package:ekipa_core/src/foundation/config.dart';
import 'package:ekipa_core/src/foundation/ids.dart';

/// Every behavioural constant the matcher reads.
///
/// **Intention.** Directive D5, stated as strongly as it deserves: *no
/// behavioural constant is a literal in code.* If a product person could
/// reasonably want it different next month, it is a row in `config_values`.
/// Every default below is a **guess** — the simulator's job is to replace them
/// with numbers whose failure modes we have already seen (03_MATCHMAKER.md §8),
/// and a guess in a config row can be changed from a console while a guess in a
/// literal needs a release.
///
/// The keys are declared in one place so the console's config editor can list
/// them with their descriptions, and so [MatchingKeys.all] can be asserted
/// against what a version actually stores — a typo in a key name is otherwise
/// invisible, absorbed silently by a default.
abstract final class MatchingKeys {
  // ── The ring draw (03_MATCHMAKER.md §⑤) ──────────────────────────────────

  /// Share of dyads drawn from R1.
  static final ConfigKey<double> ringShareEnjoyed = ConfigKey.decimal(
    'matching.ring_share_enjoyed',
    defaultValue: 0.25,
    description:
        'Probability a dyad is drawn from R1 (someone you both enjoyed). '
        'Raising it deepens existing connections at the cost of new ones.',
  );

  /// Share of dyads drawn from R2.
  ///
  /// The largest share by default, because R2 is the product's thesis: you
  /// discover your friends' friends.
  static final ConfigKey<double> ringShareLeaf = ConfigKey.decimal(
    'matching.ring_share_leaf',
    defaultValue: 0.5,
    description:
        'Probability a dyad is drawn from R2 (a friend of someone you '
        'enjoyed). This is the mechanism the product is a bet on.',
  );

  // `C = 1 − A − B` is never configured directly, so the three shares can never
  // fail to sum. A setting that can be inconsistent will be.

  /// How hard a run corrects a ring that is running short.
  ///
  /// Zero disables deficit correction entirely, which is what makes the
  /// correction itself measurable: run half the nights with it off and the
  /// console can say what it bought.
  static final ConfigKey<double> ringDeficitGain = ConfigKey.decimal(
    'matching.ring_deficit_gain',
    defaultValue: 1,
    description:
        'How strongly later draws in a run are pushed toward a ring that '
        'fallbacks have starved. Zero turns the correction off.',
  );

  /// Half-life of an edge's weight.
  static final ConfigKey<Duration> edgeHalfLife = ConfigKey.duration(
    'matching.edge_half_life',
    defaultValue: const Duration(days: 120),
    description:
        'How long a mutual edge takes to lose half its weight. Says '
        '"this mattered, and it was a while ago" with one number.',
  );

  /// Multiplier applied to a two-hop path's strength.
  static final ConfigKey<double> bridgeDiscount = ConfigKey.decimal(
    'matching.bridge_discount',
    defaultValue: 0.6,
    description:
        'How much weaker a friend-of-a-friend is treated than a friend. '
        'Evidence about someone you have never met, from someone you liked.',
  );

  // ── Seed selection (03_MATCHMAKER.md §④) ─────────────────────────────────

  /// Extra sampling weight per week of waiting.
  static final ConfigKey<double> starveGain = ConfigKey.decimal(
    'matching.starve_gain',
    defaultValue: 1,
    description:
        'How much each week of waiting raises the chance of being a seed. '
        'Accrues in good standing only.',
  );

  /// Weeks after which waiting stops accruing credit.
  static final ConfigKey<int> starveCapWeeks = ConfigKey.integer(
    'matching.starve_cap_weeks',
    defaultValue: 4,
    description:
        'Ceiling on starvation credit. Uncapped, a structurally unmatchable '
        'person outranks everyone forever and still never gets matched.',
  );

  /// Sampling multiplier for a person with no completed hangouts.
  static final ConfigKey<double> newcomerMultiplier = ConfigKey.decimal(
    'matching.newcomer_multiplier',
    defaultValue: 3,
    description:
        'How strongly a first-time member is favoured as a seed. They are '
        'the biggest churn risk and clean by definition.',
  );

  // ── Cooldown (03_MATCHMAKER.md §5) ───────────────────────────────────────

  /// Hangouts a pair must sit out before meeting again.
  static final ConfigKey<int> cooldownMeetups = ConfigKey.integer(
    'matching.cooldown_meetups',
    defaultValue: 2,
    description:
        'Intervening hangouts before a pair may meet again. Also social '
        'cover: because even the best pairs sit out, "not matched again" '
        'carries no signal.',
  );

  /// Days a pair must wait before meeting again.
  static final ConfigKey<int> cooldownDays = ConfigKey.integer(
    'matching.cooldown_days',
    defaultValue: 21,
    description:
        'Days before a pair may meet again, whichever of the two cooldowns '
        'is longer.',
  );

  // ── Group shape (03_MATCHMAKER.md §⑥) ────────────────────────────────────

  /// Smallest group the matcher will emit.
  static final ConfigKey<int> minGroupSize = ConfigKey.integer(
    'matching.min_group_size',
    defaultValue: 3,
    description: 'Smallest group. Three is a conversation; two is a date.',
    safetyCritical: true,
  );

  /// Largest group the matcher will emit.
  static final ConfigKey<int> maxGroupSize = ConfigKey.integer(
    'matching.max_group_size',
    defaultValue: 4,
    description:
        'Largest group. Above four, one person stops talking and nobody '
        'notices.',
    safetyCritical: true,
  );

  /// Fraction of a group's pairs that may already have met.
  static final ConfigKey<double> maxKnownPairFraction = ConfigKey.decimal(
    'matching.max_known_pair_fraction',
    defaultValue: 0.5,
    description:
        'Ceiling on pairs in a group that have met before. A 2+2 gives two '
        'of six and holds by construction.',
    safetyCritical: true,
  );

  /// How many times a group is rebuilt before the slot gives up.
  ///
  /// Bounded because the alternative is a nightly job that can hang: a
  /// population whose gender ratio or cluster split makes a valid group
  /// impossible would otherwise retry forever, and nobody is awake to notice. A
  /// run that hits this ceiling reports it in `rebuild_attempts`, which is the
  /// signal that the constraints and the population disagree.
  static final ConfigKey<int> maxRebuildAttempts = ConfigKey.integer(
    'matching.max_rebuild_attempts',
    defaultValue: 8,
    description:
        'How many candidate groups a slot may build and discard before it '
        'gives up. A rising count means the constraints and the population '
        'disagree.',
  );

  // ── Respect (03_MATCHMAKER.md §6, 04_TRUST.md §4.1) ──────────────────────

  /// Real ratings needed before the respect posterior may be used.
  static final ConfigKey<int> minRespectRatings = ConfigKey.integer(
    'trust.min_respect_ratings',
    defaultValue: 12,
    description:
        'Ratings required before respect means anything. Almost everyone '
        'presses yes, so a small sample carries no information.',
  );

  /// Strength of the respect prior, in imaginary ratings.
  static final ConfigKey<double> respectPriorWeight = ConfigKey.decimal(
    'trust.respect_prior_weight',
    defaultValue: 12,
    description:
        'How many imaginary respectful ratings everyone starts with. Stops '
        'one bad evening from condemning anyone.',
  );

  /// Mean of the respect prior.
  static final ConfigKey<double> respectPriorMean = ConfigKey.decimal(
    'trust.respect_prior_mean',
    defaultValue: 0.97,
    description: 'The prior belief that almost everybody is respectful.',
  );

  /// Posterior below which friend matching is throttled.
  static final ConfigKey<double> respectFloorFriend = ConfigKey.decimal(
    'trust.respect_floor_friend',
    defaultValue: 0.85,
    description:
        'Below this, match frequency is throttled and the person is '
        'preferentially placed with others in the same band. Never a '
        'ranking boost in the other direction.',
  );

  /// Every key, for the console editor and for malformed-value reporting.
  static final List<ConfigKey<Object?>> all = [
    ringShareEnjoyed,
    ringShareLeaf,
    ringDeficitGain,
    edgeHalfLife,
    bridgeDiscount,
    starveGain,
    starveCapWeeks,
    newcomerMultiplier,
    cooldownMeetups,
    cooldownDays,
    minGroupSize,
    maxGroupSize,
    maxKnownPairFraction,
    maxRebuildAttempts,
    minRespectRatings,
    respectPriorWeight,
    respectPriorMean,
    respectFloorFriend,
  ];

  /// The console group, with the rules that hold *between* these keys.
  ///
  /// **Intention.** A key validates its own type; nothing validates that two
  /// keys still agree. `ring_share_enjoyed` and `ring_share_leaf` summing above
  /// one is the sharpest example: the draw keeps working, the derived stranger
  /// share clamps to zero, and the ratio the operator chose silently is not the
  /// ratio anybody is running. These live here rather than in the validator
  /// because the validator is in `ekipa_core` proper, which the mobile app
  /// imports and which must never learn what a ring is (D9).
  static final ConfigGroup group = ConfigGroup(
    name: 'Matching',
    description:
        'How groups are drawn, how often a pair may repeat, and how large a '
        'group gets.',
    keys: all,
    invariants: [
      ConfigInvariant(
        name: 'the ring shares leave room for strangers',
        explanation:
            'R1 and R2 together must not exceed one. Above one the stranger '
            'share clamps to zero and the draw runs a ratio nobody chose.',
        holds: (snapshot) =>
            snapshot.get(ringShareEnjoyed) + snapshot.get(ringShareLeaf) <= 1,
      ),
      ConfigInvariant(
        name: 'the ring shares are shares',
        explanation:
            'Neither R1 nor R2 may be negative. A negative share is not a '
            'smaller ring, it is an unreachable branch.',
        holds: (snapshot) =>
            snapshot.get(ringShareEnjoyed) >= 0 &&
            snapshot.get(ringShareLeaf) >= 0,
      ),
      ConfigInvariant(
        name: 'the group size range is non-empty',
        explanation:
            'The smallest group must not exceed the largest. With the range '
            'inverted the matcher builds nothing and the night reads as a '
            'population problem.',
        holds: (snapshot) =>
            snapshot.get(minGroupSize) <= snapshot.get(maxGroupSize),
      ),
      ConfigInvariant(
        name: 'the smallest group is still a group',
        explanation:
            'Three is a conversation; two is a date. A minimum of two turns '
            'the friend matcher into something the product has not asked '
            'anybody to consent to.',
        holds: (snapshot) => snapshot.get(minGroupSize) >= 3,
      ),
      ConfigInvariant(
        name: 'the known-pair ceiling is a fraction',
        explanation:
            'Outside 0–1 the ceiling either forbids every group or permits a '
            'group of people who have all already met.',
        holds: (snapshot) {
          final fraction = snapshot.get(maxKnownPairFraction);
          return fraction >= 0 && fraction <= 1;
        },
      ),
    ],
  );
}

/// One run's resolved matcher settings.
///
/// **Intention.** Read once, at the start of a run, and passed down as a
/// parameter. Nothing in the matcher reads configuration from a global — that
/// was defect S1 in the legacy audit, and it is what makes a run
/// unreproducible: the same snapshot and seed produce a different plan because
/// somebody edited a value halfway through.
final class MatchConfig {
  /// Resolves every key from [snapshot].
  MatchConfig.from(ConfigSnapshot snapshot)
    : versionId = snapshot.versionId,
      ringShareEnjoyed = snapshot.get(MatchingKeys.ringShareEnjoyed),
      ringShareLeaf = snapshot.get(MatchingKeys.ringShareLeaf),
      ringDeficitGain = snapshot.get(MatchingKeys.ringDeficitGain),
      edgeHalfLife = snapshot.get(MatchingKeys.edgeHalfLife),
      bridgeDiscount = snapshot.get(MatchingKeys.bridgeDiscount),
      starveGain = snapshot.get(MatchingKeys.starveGain),
      starveCapWeeks = snapshot.get(MatchingKeys.starveCapWeeks),
      newcomerMultiplier = snapshot.get(MatchingKeys.newcomerMultiplier),
      cooldownMeetups = snapshot.get(MatchingKeys.cooldownMeetups),
      cooldownDays = snapshot.get(MatchingKeys.cooldownDays),
      minGroupSize = snapshot.get(MatchingKeys.minGroupSize),
      maxGroupSize = snapshot.get(MatchingKeys.maxGroupSize),
      maxKnownPairFraction = snapshot.get(MatchingKeys.maxKnownPairFraction),
      maxRebuildAttempts = snapshot.get(MatchingKeys.maxRebuildAttempts),
      minRespectRatings = snapshot.get(MatchingKeys.minRespectRatings),
      respectPriorWeight = snapshot.get(MatchingKeys.respectPriorWeight),
      respectPriorMean = snapshot.get(MatchingKeys.respectPriorMean),
      respectFloorFriend = snapshot.get(MatchingKeys.respectFloorFriend);

  /// Which config version produced these values. Recorded on the run.
  final ConfigVersionId versionId;

  /// See [MatchingKeys.ringShareEnjoyed].
  final double ringShareEnjoyed;

  /// See [MatchingKeys.ringShareLeaf].
  final double ringShareLeaf;

  /// See [MatchingKeys.ringDeficitGain].
  final double ringDeficitGain;

  /// See [MatchingKeys.edgeHalfLife].
  final Duration edgeHalfLife;

  /// See [MatchingKeys.bridgeDiscount].
  final double bridgeDiscount;

  /// See [MatchingKeys.starveGain].
  final double starveGain;

  /// See [MatchingKeys.starveCapWeeks].
  final int starveCapWeeks;

  /// See [MatchingKeys.newcomerMultiplier].
  final double newcomerMultiplier;

  /// See [MatchingKeys.cooldownMeetups].
  final int cooldownMeetups;

  /// See [MatchingKeys.cooldownDays].
  final int cooldownDays;

  /// See [MatchingKeys.minGroupSize].
  final int minGroupSize;

  /// See [MatchingKeys.maxGroupSize].
  final int maxGroupSize;

  /// See [MatchingKeys.maxKnownPairFraction].
  final double maxKnownPairFraction;

  /// See [MatchingKeys.maxRebuildAttempts].
  final int maxRebuildAttempts;

  /// See [MatchingKeys.minRespectRatings].
  final int minRespectRatings;

  /// See [MatchingKeys.respectPriorWeight].
  final double respectPriorWeight;

  /// See [MatchingKeys.respectPriorMean].
  final double respectPriorMean;

  /// See [MatchingKeys.respectFloorFriend].
  final double respectFloorFriend;

  /// The stranger share, derived rather than configured.
  ///
  /// **Never a config key.** Three numbers that must sum to one, stored
  /// independently, are three numbers that will not sum to one — and the
  /// failure is silent, because the draw still works, just not in the ratio
  /// anybody chose. Deriving the third removes the possibility.
  ///
  /// Clamped at zero: a version that sets A + B above 1 is a mistake, and the
  /// honest response is to run with no strangers rather than to crash a nightly
  /// job over a bad row.
  double get ringShareStranger =>
      (1 - ringShareEnjoyed - ringShareLeaf).clamp(0, 1);

  /// Whether this configuration is the all-strangers control arm.
  ///
  /// `A = B = 0` is a control by construction (03_MATCHMAKER.md §9), which is
  /// why the permanent control arm needs no separate code path. If ring-drawn
  /// groups never beat it, the honest response is to leave it here — a config
  /// change, not a refactor. That retreat being cheap is the whole reason the
  /// design survives being wrong.
  bool get isAllStrangersControl => ringShareEnjoyed == 0 && ringShareLeaf == 0;
}
