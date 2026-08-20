import 'package:ekipa_core/src/config/catalogue.dart';
import 'package:ekipa_core/src/foundation/config.dart';

/// What each way of letting people down is worth, and what a good evening buys.
///
/// **Intention — two accumulators that never sum** (`04_TRUST.md §2). A flake
/// and a creep need different responses, and adding them together mislabels
/// both: a person who has missed three confirmations is not one third of a
/// person who followed somebody home. So every weight below belongs to exactly
/// one of `reliability` or `conduct`, and the ladders are walked separately.
///
/// **The weights are stored as applied, not recomputed.** An infraction row
/// copies the number that was in force when it happened
/// (`0004_v3_trust.sql`). Recomputing later from current config would silently
/// rewrite history every time a threshold moved, and somebody would be
/// suspended for a pattern that was never against the rules while they were
/// doing it.
///
/// **The ordering of the reliability weights is the product's whole incentive
/// argument, in numbers.** Silence costs more than a decline — six times more
/// by default — because the scarce resource is *time to repair*, and a decline
/// arrives while it is still actionable. The app says so on the confirmation
/// screen in plain words, because an incentive nobody knows about is not an
/// incentive, it is a trap people learn about from the sanction.
abstract final class TrustKeys {
  // ── Reliability (04_TRUST.md §3.1) ─────────────────────────────────────────

  /// Declining in good time.
  ///
  /// Deliberately near zero. "Saying no is nearly free" is a sentence the
  /// product prints, and a number that made it expensive would make the
  /// sentence false.
  static final ConfigKey<double> declineWeight = ConfigKey.decimal(
    'trust.weight_confirm_decline',
    defaultValue: 0.25,
    description:
        'Cost of declining inside the window. Nearly free on purpose: an '
        'early no is cooperative, and the screen promises as much.',
  );

  /// Declining after the window has closed.
  static final ConfigKey<double> lateDeclineWeight = ConfigKey.decimal(
    'trust.weight_confirm_decline_late',
    defaultValue: 1,
    description:
        'Cost of declining after the deadline. Still far better than silence, '
        'because it at least ends the uncertainty.',
  );

  /// Never answering at all.
  static final ConfigKey<double> silenceWeight = ConfigKey.decimal(
    'trust.weight_confirm_silent',
    defaultValue: 1.5,
    description:
        'Cost of not answering. Higher than a decline because it destroys the '
        'repair window: by the time silence tells us anything, it is too late '
        'to fix.',
    safetyCritical: true,
  );

  /// Confirming and not turning up.
  static final ConfigKey<double> noShowWeight = ConfigKey.decimal(
    'trust.weight_no_show',
    defaultValue: 3,
    description:
        'Cost of saying yes and not arriving. The most expensive reliability '
        'failure: three people went somewhere for it.',
    safetyCritical: true,
  );

  /// Arriving after the grace window.
  static final ConfigKey<double> lateArrivalWeight = ConfigKey.decimal(
    'trust.weight_late_arrival',
    defaultValue: 0.5,
    description:
        'Cost of arriving after the grace window. Small: people are late for '
        'ordinary reasons and the arrival screen says so.',
  );

  /// Not rating within the window.
  ///
  /// Low, because the rating gate already does the work — an unrated hangout
  /// keeps a person out of the next run, which is felt immediately and costs
  /// nothing permanent.
  static final ConfigKey<double> missedRatingWeight = ConfigKey.decimal(
    'trust.weight_rating_missed',
    defaultValue: 0.5,
    description:
        'Cost of never rating. Kept low because the gate already holds the '
        'person out of the next run, which is the real consequence.',
  );

  /// Promising equipment and not bringing it.
  static final ConfigKey<double> equipmentWeight = ConfigKey.decimal(
    'trust.weight_equipment_missing',
    defaultValue: 0.5,
    description:
        'Cost of confirming you would bring the cards and not bringing them. '
        'Withdrawing before the reveal is free, and that is the point.',
  );

  /// How long a reliability infraction keeps counting.
  static final ConfigKey<int> reliabilityWindowDays = ConfigKey.integer(
    'trust.reliability_window_days',
    defaultValue: 120,
    description:
        'How far back the reliability accumulator looks. A person who was '
        'unreliable a term ago and reliable since is reliable.',
  );

  // ── The edge a good evening leaves behind (03_MATCHMAKER.md §③) ────────────

  /// Weight of a mutual "really enjoyed".
  static final ConfigKey<double> edgeStrong = ConfigKey.decimal(
    'trust.edge_weight_strong',
    defaultValue: 1,
    description:
        'Edge weight when both people said they really enjoyed it. Only ever '
        'written for a *mutual* answer — a one-sided like creates nothing.',
  );

  /// Weight of a mutual "enjoyed", or one of each.
  static final ConfigKey<double> edgeWarm = ConfigKey.decimal(
    'trust.edge_weight_warm',
    defaultValue: 0.6,
    description:
        'Edge weight when both enjoyed it without either saying "really". The '
        'ordinary good evening, which is most of them.',
  );

  /// Minimum arrivals before the evening counts as having happened.
  ///
  /// Below this, nothing is written: no edges, no completed count, no
  /// no-shows held against the people who did turn up. Two people who were
  /// stood up should not carry a record of it.
  static final ConfigKey<int> minArrivalsToCount = ConfigKey.integer(
    'trust.min_arrivals_to_count',
    defaultValue: 2,
    description:
        'How many people must arrive before the hangout counts at all. Below '
        'it the evening is abandoned and nobody who turned up is charged for '
        'the people who did not.',
    safetyCritical: true,
  );

  /// Every key in this group.
  static final List<ConfigKey<Object?>> all = [
    declineWeight,
    lateDeclineWeight,
    silenceWeight,
    noShowWeight,
    lateArrivalWeight,
    missedRatingWeight,
    equipmentWeight,
    reliabilityWindowDays,
    edgeStrong,
    edgeWarm,
    minArrivalsToCount,
  ];

  /// The group, for the console's editor.
  static final ConfigGroup group = ConfigGroup(
    name: 'Trust',
    description:
        'What each way of letting people down is worth, and what a good '
        'evening leaves behind.',
    keys: all,
    invariants: [
      ConfigInvariant(
        name: 'silence costs more than a decline',
        explanation:
            'The whole incentive is to convert silence into information. A '
            'version where the cheap answer is to say nothing inverts the '
            'product.',
        holds: (snapshot) =>
            snapshot.get(silenceWeight) > snapshot.get(declineWeight),
      ),
      ConfigInvariant(
        name: 'a no-show costs more than any answer',
        explanation:
            'Three people went somewhere. Nothing that happens at a keyboard '
            'may cost more than that.',
        holds: (snapshot) =>
            snapshot.get(noShowWeight) > snapshot.get(silenceWeight) &&
            snapshot.get(noShowWeight) > snapshot.get(lateDeclineWeight),
      ),
      ConfigInvariant(
        name: 'a strong edge outweighs a warm one',
        explanation:
            'Otherwise "really enjoyed" is worth less than "enjoyed", and the '
            'ring draw prefers the weaker signal.',
        holds: (snapshot) =>
            snapshot.get(edgeStrong) > snapshot.get(edgeWarm),
      ),
      ConfigInvariant(
        name: 'an evening needs at least two people to have happened',
        explanation:
            'One person alone at a table is not a hangout, and writing it up '
            'as one would charge the absent for something nobody attended.',
        holds: (snapshot) => snapshot.get(minArrivalsToCount) >= 2,
      ),
    ],
  );
}
