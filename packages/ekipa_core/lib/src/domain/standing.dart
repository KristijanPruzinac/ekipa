import 'package:meta/meta.dart';

/// What the trust system currently permits a person to do.
///
/// **Intention.** Ordered from least to most restrictive, and the order is
/// load-bearing: seed eligibility is *"good standing only"*, and expressing
/// that as `tier == good` rather than as a list of excluded tiers means a tier
/// added later is excluded by default. A new sanction that accidentally grants
/// a privilege is the failure this ordering prevents — and it is not
/// hypothetical, it is the trap 03_MATCHMAKER.md §④ describes in full.
enum StandingTier {
  /// Nothing outstanding. The only tier that may seed a group.
  good,

  /// Elevated accumulator, no active response yet. Invisible.
  watched,

  /// Fewer hangouts per period. Invisible, because a throttle a person can feel
  /// but not see is exactly as effective and does not become a status.
  throttled,

  /// Preferentially matched with others in the same band. Invisible.
  segregated,

  /// Time-limited removal. **Visible, with a reason and an end date** — a
  /// suspension a person cannot see is a suspension they cannot appeal, and
  /// GDPR Art. 22 requires a route to human intervention.
  suspended,

  /// Permanent. Visible.
  banned;

  /// Whether a person in this tier may be matched at all.
  bool get mayBeMatched =>
      this != StandingTier.suspended && this != StandingTier.banned;

  /// Whether a person in this tier may be the seed a group is built around.
  ///
  /// **Only `good`.** This is the fix for the trap in 03_MATCHMAKER.md §④: a
  /// throttled person is, by construction, among the longest-waiting people in
  /// the city, so a naive "seed on whoever has waited longest" hands them the
  /// first group of every run and first pick of everyone's evening. The
  /// sanction inverts into a privilege, and it does so *silently* — the logs
  /// still show fewer hangouts permitted, while each permitted hangout is the
  /// best one available.
  ///
  /// Stated honestly, the sanction reads: *fewer evenings, and never the
  /// evening built around you.*
  bool get maySeed => this == StandingTier.good;

  /// Whether the person can see that this is their tier.
  bool get isVisibleToSubject =>
      this == StandingTier.suspended || this == StandingTier.banned;
}

/// The respect signal, smoothed and gated.
///
/// **Intention.** Respect ratings are sparse and noisy early — three ratings
/// carry almost no information, because almost everybody presses yes. Two
/// mechanisms handle that, and they do different jobs:
///
/// * **the Beta prior** pulls a small sample toward "respectful", so nobody
///     is condemned by a bad evening;
/// * **the evidence gate** refuses to use the number at all below
///     [usableAfter] ratings, so nobody is *boosted* by a small clean sample
///     either.
///
/// The prior alone would not be enough. It would still produce an ordering, and
/// an ordering invites ranking — which is the one use of this signal that is
/// forbidden (03_MATCHMAKER.md §6). One bit from three strangers cannot support
/// a ranking; it can support removing a genuinely disruptive tail, and that is
/// all it is asked to do.
@immutable
final class RespectSignal {
  /// Records [yes] and [no] respect answers about one person.
  const RespectSignal({
    required this.yes,
    required this.no,
    this.priorWeight = 12,
    this.priorMean = 0.97,
    this.usableAfter = 12,
  });

  /// A person nobody has rated yet.
  const RespectSignal.none()
    : yes = 0,
      no = 0,
      priorWeight = 12,
      priorMean = 0.97,
      usableAfter = 12;

  /// How many people answered yes.
  final int yes;

  /// How many answered no.
  final int no;

  /// `α₀ + β₀`, the strength of the prior in imaginary ratings. Config (D5).
  final double priorWeight;

  /// The prior's mean respect rate — "almost everyone is respectful". Config.
  final double priorMean;

  /// Real ratings required before the posterior may be used for anything.
  final int usableAfter;

  /// Actual observations.
  int get total => yes + no;

  /// Whether there is enough evidence to act on.
  bool get isUsable => total >= usableAfter;

  /// The posterior probability that this person is respectful.
  ///
  /// Always computable; only [isUsable] says whether it means anything. It is
  /// exposed below the gate so the console can show *why* somebody is being
  /// treated as neutral, rather than showing nothing and inviting the question.
  double get posterior {
    final alpha0 = priorWeight * priorMean;
    final beta0 = priorWeight - alpha0;
    return (yes + alpha0) / (total + alpha0 + beta0);
  }

  /// Whether the person falls below [floor].
  ///
  /// Below the evidence gate the answer is always `false`: never penalised for
  /// having little history, and never boosted for it either.
  bool isBelow(double floor) => isUsable && posterior < floor;

  @override
  String toString() =>
      'RespectSignal($yes/$total, '
      'posterior=${posterior.toStringAsFixed(3)}, '
      'usable=$isUsable)';
}

/// Everything the matcher is allowed to know about a person's trust state.
///
/// Deliberately narrow. The matcher gets a tier, a respect signal and a quota —
/// not the accumulator scores, not the infractions, not the reports. It cannot
/// rank people by trustworthiness because it is not given a number to rank them
/// by, and that is a stronger guarantee than a rule saying it must not.
@immutable
final class Standing {
  /// Records a person's trust state.
  const Standing({
    required this.tier,
    this.respect = const RespectSignal.none(),
    this.remainingQuota,
  });

  /// A person with nothing against them.
  static const good = Standing(tier: StandingTier.good);

  /// What the trust system permits.
  final StandingTier tier;

  /// The smoothed, gated respect signal.
  final RespectSignal respect;

  /// Hangouts still permitted this period under a throttle, or `null` when
  /// unthrottled. Zero means the quota is exhausted and the person is not
  /// placeable this run.
  final int? remainingQuota;

  /// Whether this person may be placed in a group at all.
  bool get mayBeMatched => tier.mayBeMatched && (remainingQuota ?? 1) > 0;

  /// Whether this person may be the seed a group is built around.
  bool get maySeed => tier.maySeed && mayBeMatched;

  @override
  String toString() =>
      'Standing(${tier.name}'
      '${remainingQuota == null ? '' : ', quota=$remainingQuota'})';
}
