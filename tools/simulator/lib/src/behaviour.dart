/// Every number in the population model, in one place, each with the reason it
/// has the value it has.
///
/// **Intention.** These are guesses. They are guesses about people, which is
/// the one thing a simulation cannot check, so the honest response is not to
/// hide them but to corner them: one struct, one default per field, one
/// sentence saying where the number came from, and a CLI flag that moves any of
/// them. A reader who disagrees with the model can then disagree with a
/// specific number instead of with the whole harness.
///
/// **Rejected — scattering probabilities through the week loop as literals.**
/// It is how every simulation starts and it is why nobody trusts the second
/// one: the model becomes unstatable, so a surprising metric cannot be traced
/// to the assumption that produced it.
///
/// These are *not* `MatchConfig` keys and must never migrate there. D5 governs
/// behavioural constants the product enforces; these are assumptions about
/// people the product observes, and shipping them to a device would mean the
/// app carrying a table of how likely it thinks you are to cancel.
final class Behaviour {
  /// Builds a behaviour model. Every field defaults, so a test overrides one.
  const Behaviour({
    this.availabilityMean = 0.35,
    this.availabilitySpread = 0.25,
    this.reliabilityMean = 0.85,
    this.reliabilitySpread = 0.2,
    this.warmthMean = 0.55,
    this.warmthSpread = 0.3,
    this.opennessMean = 0.6,
    this.opennessSpread = 0.25,
    this.patienceMean = 4,
    this.patienceSpread = 3,
    this.enjoyFloor = 0.1,
    this.enjoyGain = 0.75,
    this.stronglyEnjoyedShare = 0.35,
    this.ratherNotRate = 0.03,
    this.churnAfterBadHangout = 0.08,
    this.arrivalsPerWeek = 6,
    this.genderMix = const {'woman': 0.48, 'man': 0.48, 'other': 0.04},
  });

  /// Mean of the per-agent probability of marking one slot available.
  ///
  /// 0.35 of nine weekly slots is roughly three, which is what somebody who
  /// wants to go out once a week but has a life would plausibly offer.
  final double availabilityMean;

  /// Half-width of the uniform band around [availabilityMean].
  final double availabilitySpread;

  /// Mean probability of confirming and turning up once matched.
  ///
  /// 0.85 is deliberately pessimistic. The interesting question is what the
  /// matcher does on the nights groups collapse, and a population that always
  /// shows up never asks it.
  final double reliabilityMean;

  /// Half-width of the band around [reliabilityMean].
  final double reliabilitySpread;

  /// Mean of the latent that decides how much others enjoy an agent.
  final double warmthMean;

  /// Half-width of the band around [warmthMean].
  ///
  /// Wide on purpose: a population with uniform warmth forms edges uniformly,
  /// and clique capture — the failure this harness exists to catch — needs some
  /// people to be much more re-drawable than others.
  final double warmthSpread;

  /// Mean of the latent that decides how readily an agent enjoys others.
  final double opennessMean;

  /// Half-width of the band around [opennessMean].
  final double opennessSpread;

  /// Mean number of consecutive unmatched weeks tolerated before leaving.
  final int patienceMean;

  /// Half-width of the band around [patienceMean].
  final int patienceSpread;

  /// Probability of enjoying somebody with zero warmth and zero openness.
  ///
  /// Not zero: people are polite, and a model where the least warm person in
  /// the city never once gets a positive rating overstates how cleanly the
  /// graph separates.
  final double enjoyFloor;

  /// How much warmth and openness together lift the probability of enjoyment.
  final double enjoyGain;

  /// Of positive answers, the share that are `reallyEnjoyed` rather than
  /// `enjoyed`. Only affects edge weight, which only affects redraw odds.
  final double stronglyEnjoyedShare;

  /// Probability that a *negative* answer is `ratherNot` — a permanent,
  /// symmetric exclusion — rather than `noPreference`.
  ///
  /// Small, and load-bearing at this size: exclusions accumulate and never
  /// expire, so an overstated rate here quietly strangles a small city and the
  /// match rate falls for a reason that is a modelling artefact.
  final double ratherNotRate;

  /// Probability of leaving after a hangout where they enjoyed nobody.
  final double churnAfterBadHangout;

  /// New arrivals per week.
  final int arrivalsPerWeek;

  /// The gender mix, as shares that should sum to one.
  ///
  /// A map rather than two numbers, because the composition rule is "nobody is
  /// the only one of their gender" and it has to survive a third value (D6).
  final Map<String, double> genderMix;

  /// A copy with some fields replaced, for the `--set` flag and for tests.
  Behaviour copyWith({
    double? availabilityMean,
    double? reliabilityMean,
    double? warmthMean,
    double? warmthSpread,
    double? ratherNotRate,
    double? churnAfterBadHangout,
    int? arrivalsPerWeek,
    Map<String, double>? genderMix,
  }) => Behaviour(
    availabilityMean: availabilityMean ?? this.availabilityMean,
    availabilitySpread: availabilitySpread,
    reliabilityMean: reliabilityMean ?? this.reliabilityMean,
    reliabilitySpread: reliabilitySpread,
    warmthMean: warmthMean ?? this.warmthMean,
    warmthSpread: warmthSpread ?? this.warmthSpread,
    opennessMean: opennessMean,
    opennessSpread: opennessSpread,
    patienceMean: patienceMean,
    patienceSpread: patienceSpread,
    enjoyFloor: enjoyFloor,
    enjoyGain: enjoyGain,
    stronglyEnjoyedShare: stronglyEnjoyedShare,
    ratherNotRate: ratherNotRate ?? this.ratherNotRate,
    churnAfterBadHangout: churnAfterBadHangout ?? this.churnAfterBadHangout,
    arrivalsPerWeek: arrivalsPerWeek ?? this.arrivalsPerWeek,
    genderMix: genderMix ?? this.genderMix,
  );
}
