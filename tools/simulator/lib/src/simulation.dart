import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_core/matching.dart';
import 'package:simulator/src/agent.dart';
import 'package:simulator/src/behaviour.dart';
import 'package:simulator/src/city.dart';
import 'package:simulator/src/metrics.dart';
import 'package:simulator/src/population.dart';

/// Twelve weeks of a synthetic city, run through the real matchmaker.
///
/// **What this file is allowed to contain.** The behaviour of *people* — who
/// marks themselves available, who turns up, who enjoys whom, who leaves. It
/// contains no matching rule, no composition rule and no eligibility rule; it
/// calls [Matchmaker] and [Composition] for those. That boundary is the whole
/// value of the harness: a simulator carrying its own copy of the rules tells
/// you about the copy.
///
/// **Rejected — simulating the database round trip.** It would make the harness
/// slower than the thing it is meant to iterate on, and it would test the
/// worker rather than the matcher. Persistence is tested by pgTAP, which can
/// actually deny something.
///
/// **Determinism.** One seed reaches everything through forks named after what
/// they decide (`week:3` → `ratings`), so changing the rating model does not
/// reshuffle who turned up in week 2. Without that, every model change would
/// move every metric and no comparison between two configs would mean anything.
final class Simulation {
  /// Builds a simulation. Nothing here reads a clock or a file.
  Simulation({
    required this.config,
    required this.seed,
    this.city = const SimCity(),
    this.behaviour = const Behaviour(),
    this.startingPeople = 120,
    this.weeks = 12,
    this.matchmaker = const Matchmaker(),
    DateTime? firstMonday,
  }) : firstMonday = firstMonday ?? DateTime.utc(2026, 9, 7);

  /// The matching configuration under test. This is the knob the harness
  /// exists to turn.
  final MatchConfig config;

  /// The run seed.
  final int seed;

  /// The synthetic city.
  final SimCity city;

  /// The population model.
  final Behaviour behaviour;

  /// How many agents exist in week zero.
  final int startingPeople;

  /// How many weeks to run.
  final int weeks;

  /// The matcher. Injected so a test can substitute a stage, never so the
  /// simulator can supply its own matching logic.
  final Matchmaker matchmaker;

  /// The Monday week zero starts on.
  final DateTime firstMonday;

  static const _composition = Composition();

  /// Runs the simulation and returns the metric table.
  SimulationReport run() {
    final random = SeededRandomSource(seed);
    final population = Population(city: city, behaviour: behaviour);
    final agents = <PersonId, Agent>{};
    final edges = <PairKey, Edge>{};
    final exclusions = <PairKey, Exclusion>{};
    final history = <PastHangout>[];
    final hangoutsWithRepeat = <PersonId, int>{};
    var nextIndex = 0;

    void admit(List<Agent> arrivals) {
      for (final agent in arrivals) {
        agents[agent.id] = agent;
      }
      nextIndex += arrivals.length;
    }

    admit(
      population.sample(startingPeople, 0, nextIndex, random.fork('founders')),
    );

    final table = <WeekMetrics>[];
    for (var week = 0; week < weeks; week++) {
      final weekRandom = random.fork('week:$week');
      final arrivals = week == 0
          ? <Agent>[]
          : population.sample(
              behaviour.arrivalsPerWeek,
              week,
              nextIndex,
              weekRandom.fork('arrivals'),
            );
      admit(arrivals);

      final active = [
        for (final agent in agents.values)
          if (agent.isActive) agent,
      ];
      final slots = city.slotsOfWeek(week, firstMonday);
      final takenAt = firstMonday.add(Duration(days: week * 7));

      // ── who wants a hangout this week ────────────────────────────────────
      final availabilityRandom = weekRandom.fork('availability');
      final availability = {for (final slot in slots) slot.id: <PersonId>{}};
      final askedForSomething = <PersonId>{};
      for (final agent in active) {
        final rolls = availabilityRandom.fork(agent.id.value);
        for (final slot in slots) {
          if (rolls.nextDouble() < agent.availability) {
            availability[slot.id]!.add(agent.id);
            askedForSomething.add(agent.id);
          }
        }
      }

      final snapshot = MatchSnapshot(
        cityId: city.id,
        takenAt: takenAt,
        people: [for (final agent in active) agent.asPerson(city.id)],
        slots: slots,
        availability: availability,
        edges: edges.values,
        exclusions: exclusions.values,
        history: history,
      );

      final plan = matchmaker.run(
        snapshot,
        config,
        weekRandom.fork('match').nextInt(1 << 30),
      );

      // ── what the people then did about it ────────────────────────────────
      final confirmations = weekRandom.fork('confirmations');
      final ratings = weekRandom.fork('ratings');
      var held = 0;
      var cancelled = 0;
      var confirmedCount = 0;
      var attendedCount = 0;
      final cancelReasons = <String, int>{};
      var newEdges = 0;
      var newExclusions = 0;
      final matchedThisWeek = <PersonId>{};

      for (final hangout in plan.hangouts) {
        final invited = [for (final id in hangout.memberIds) agents[id]!];
        matchedThisWeek.addAll(hangout.memberIds);
        final rolls = confirmations.fork(hangout.localKey);
        final attending = [
          for (final agent in invited)
            if (rolls.nextDouble() < agent.reliability) agent,
        ];

        // The group has to survive its own no-shows. Asking [Composition] here
        // rather than counting heads is deliberate: a 2+2 that loses one woman
        // is a 1+2, and the product's answer to that is to cancel — a rule that
        // exists once, in the core, and is checked here by calling it.
        final verdict = _composition.verdict(
          [for (final agent in attending) agent.asPerson(city.id)],
          snapshot,
          config,
        );
        confirmedCount += attending.length;
        if (!verdict.isValid) {
          cancelled++;
          for (final failure in verdict.failures) {
            cancelReasons[failure.name] =
                (cancelReasons[failure.name] ?? 0) + 1;
          }
          continue;
        }

        held++;
        attendedCount += attending.length;
        final endedAt = slots
            .firstWhere((slot) => slot.id == hangout.slot)
            .endsAt;

        for (final agent in attending) {
          final others = {
            for (final other in attending)
              if (other.id != agent.id) other.id,
          };
          if (agent.met.intersection(others).isNotEmpty) {
            hangoutsWithRepeat[agent.id] =
                (hangoutsWithRepeat[agent.id] ?? 0) + 1;
          }
        }

        final answers = <PersonId, Map<PersonId, Enjoyment>>{};
        for (final rater in attending) {
          // One stream per rater, drawn from once per subject. Forking inside
          // the subject loop would hand every subject the same first roll from
          // this rater, and their answers would correlate for a reason that is
          // an artefact of the harness rather than a fact about people.
          final rolls = ratings.fork(
            '${hangout.localKey}:${rater.id.value}',
          );
          final of = <PersonId, Enjoyment>{};
          for (final subject in attending) {
            if (subject.id == rater.id) continue;
            of[subject.id] = _rate(rater, subject, rolls);
          }
          answers[rater.id] = of;
        }

        for (var i = 0; i < attending.length; i++) {
          for (var j = i + 1; j < attending.length; j++) {
            final a = attending[i];
            final b = attending[j];
            final key = PairKey(a.id, b.id);
            final fromA = answers[a.id]![b.id]!;
            final fromB = answers[b.id]![a.id]!;

            if (fromA == Enjoyment.ratherNot || fromB == Enjoyment.ratherNot) {
              // One side is enough, and it is permanent and symmetric. The
              // other person is never told, which is why the metric watches the
              // count: nobody will ever complain about this number rising.
              if (!exclusions.containsKey(key)) newExclusions++;
              exclusions[key] = Exclusion(
                pair: key,
                reason: ExclusionReason.ratherNot,
              );
              continue;
            }

            if (!fromA.isPositive || !fromB.isPositive) continue;
            final existing = edges[key];
            if (existing == null) newEdges++;
            edges[key] = Edge(
              pair: key,
              weight:
                  (((existing?.weight ?? 0) +
                              (fromA.edgeWeight + fromB.edgeWeight) / 2) *
                          0.8)
                      .clamp(0.0, 1.0),
              meetCount: (existing?.meetCount ?? 0) + 1,
              lastMetAt: endedAt,
            );
          }
        }

        history.add(
          PastHangout(
            members: {for (final agent in attending) agent.id},
            endedAt: endedAt,
          ),
        );

        for (final agent in attending) {
          agent
            ..completedHangouts += 1
            ..firstHangoutWeek ??= week
            ..met.addAll({
              for (final other in attending)
                if (other.id != agent.id) other.id,
            });
        }

        // Leaving after an evening they got nothing out of. Modelled on the
        // rater's own answers rather than on being liked, because nobody is
        // told whether they were liked — and a churn model that used the hidden
        // half would be predicting from information the product never emits.
        final churn = weekRandom.fork('churn:${hangout.localKey}');
        for (final agent in attending) {
          final enjoyedSomebody = answers[agent.id]!.values.any(
            (answer) => answer.isPositive,
          );
          if (!enjoyedSomebody &&
              churn.nextDouble() < behaviour.churnAfterBadHangout) {
            agent.leftWeek = week;
          }
        }
      }

      // ── the week's bookkeeping ───────────────────────────────────────────
      var departures = 0;
      for (final agent in active) {
        if (!agent.isActive) {
          departures++;
          continue;
        }
        if (matchedThisWeek.contains(agent.id)) {
          agent.weeksWaiting = 0;
        } else if (askedForSomething.contains(agent.id)) {
          agent.weeksWaiting += 1;
          if (agent.weeksWaiting > agent.patienceWeeks) {
            agent.leftWeek = week;
            departures++;
          }
        }
      }

      table.add(
        WeekMetrics(
          week: week,
          active: active.length,
          available: askedForSomething.length,
          planned: plan.hangouts.length,
          held: held,
          cancelled: cancelled,
          placed: matchedThisWeek.length,
          confirmed: confirmedCount,
          attended: attendedCount,
          cancelReasons: cancelReasons,
          newEdges: newEdges,
          newExclusions: newExclusions,
          departures: departures,
          arrivals: arrivals.length,
          filtered: plan.stats.funnel.toJson(),
          ringRealised: {
            for (final ring in Ring.values)
              ring.storageCode: plan.stats.ringLedger.realisedCount(ring),
          },
          unplaced: plan.stats.unplaced,
        ),
      );
    }

    return _report(
      seed,
      table,
      agents.values.toList(),
      edges,
      hangoutsWithRepeat,
    );
  }

  Enjoyment _rate(Agent rater, Agent subject, RandomSource random) {
    // Warmth is the subject's; openness is the rater's. Keeping them on
    // opposite sides is what produces one-sided liking, which forms no edge —
    // the asymmetry the product's privacy promise is built on.
    final chance = Stats.probability(
      behaviour.enjoyFloor +
          behaviour.enjoyGain * subject.warmth * (0.5 + 0.5 * rater.openness),
    );
    if (random.nextDouble() < chance) {
      return random.nextDouble() < behaviour.stronglyEnjoyedShare
          ? Enjoyment.reallyEnjoyed
          : Enjoyment.enjoyed;
    }
    return random.nextDouble() < behaviour.ratherNotRate
        ? Enjoyment.ratherNot
        : Enjoyment.noPreference;
  }

  SimulationReport _report(
    int runSeed,
    List<WeekMetrics> table,
    List<Agent> everybody,
    Map<PairKey, Edge> edges,
    Map<PersonId, int> hangoutsWithRepeat,
  ) {
    final waits = [
      for (final agent in everybody)
        if (agent.firstHangoutWeek != null)
          agent.firstHangoutWeek! - agent.joinedWeek,
    ];
    final neverMatched = everybody
        .where((agent) => agent.firstHangoutWeek == null)
        .length;
    final repeatShares = [
      for (final agent in everybody)
        if (agent.completedHangouts >= 2)
          (hangoutsWithRepeat[agent.id] ?? 0) / agent.completedHangouts,
    ];
    final totalHeld = table.fold<int>(0, (sum, week) => sum + week.held);

    return SimulationReport(
      seed: runSeed,
      weeks: table,
      timeToFirstHangout: (
        Stats.percentile(waits, 0.5),
        Stats.percentile(waits, 0.9),
      ),
      neverMatchedShare: everybody.isEmpty
          ? 0
          : neverMatched / everybody.length,
      repeatSaturation: Stats.mean(repeatShares),
      edgesPerHangout: totalHeld == 0 ? 0 : edges.length / totalHeld,
      closedTriadShare: Stats.closedTriadShare(edges.keys),
      hangoutGini: Stats.gini([
        for (final agent in everybody) agent.completedHangouts,
      ]),
      finalActive: everybody.where((agent) => agent.isActive).length,
      totalHeld: totalHeld,
      ringConfigured: {
        Ring.r1Enjoyed.storageCode: config.ringShareEnjoyed,
        Ring.r2Leaf.storageCode: config.ringShareLeaf,
        Ring.r3Stranger.storageCode: config.ringShareStranger,
      },
    );
  }
}
