import 'package:ekipa_core/ekipa_core.dart';
import 'package:test/test.dart';

import '../support/world.dart';

void main() {
  group('the tiers are ordered from least to most restrictive', () {
    // The order is load-bearing. Seed eligibility is expressed as
    // `tier == good` rather than as a list of excluded tiers, so a tier added
    // later is excluded by default. A new sanction that accidentally *grants*
    // a privilege is the failure this prevents, and it is not hypothetical —
    // it is the trap 03_MATCHMAKER.md §④ describes in full.

    test('good is first', () {
      expect(StandingTier.values.first, StandingTier.good);
    });

    test('exactly one tier may seed', () {
      final seeders = StandingTier.values.where((t) => t.maySeed).toList();
      expect(seeders, [StandingTier.good]);
    });

    test('the two removals are the only tiers that cannot be matched', () {
      final blocked = StandingTier.values
          .where((t) => !t.mayBeMatched)
          .toList();
      expect(blocked, [StandingTier.suspended, StandingTier.banned]);
    });

    test('everything a person can feel, they can see', () {
      // R0 to R2 are invisible by design: a pair exclusion, a dating removal
      // and a silent throttle cost a falsely-accused person almost nothing,
      // and are therefore never appealed. A suspension is different — one a
      // person cannot see is one they cannot appeal, and GDPR Art. 22 requires
      // a route to human intervention.
      final visible = StandingTier.values
          .where((t) => t.isVisibleToSubject)
          .toList();
      expect(visible, [StandingTier.suspended, StandingTier.banned]);
      for (final tier in visible) {
        expect(tier.mayBeMatched, isFalse);
      }
    });
  });

  group('the quota is separate from the tier', () {
    test('an unthrottled person has no quota to spend', () {
      expect(Standing.good.remainingQuota, isNull);
      expect(Standing.good.mayBeMatched, isTrue);
    });

    test('a spent quota blocks placement without changing the tier', () {
      // The distinction matters for the console: "throttled, out of turns this
      // week" and "suspended" look the same to the matcher and are entirely
      // different things to explain to a person.
      const spent = Standing(
        tier: StandingTier.throttled,
        remainingQuota: 0,
      );
      expect(spent.tier, StandingTier.throttled);
      expect(spent.mayBeMatched, isFalse);
      expect(spent.maySeed, isFalse);
    });

    test('a quota left unspent still permits a seat', () {
      const left = Standing(tier: StandingTier.throttled, remainingQuota: 2);
      expect(left.mayBeMatched, isTrue);
      expect(left.maySeed, isFalse);
    });

    test('a quota cannot rescue a suspension', () {
      const suspended = Standing(
        tier: StandingTier.suspended,
        remainingQuota: 9,
      );
      expect(suspended.mayBeMatched, isFalse);
    });

    test('it renders the quota only when there is one', () {
      expect(Standing.good.toString(), 'Standing(good)');
      expect(
        const Standing(
          tier: StandingTier.throttled,
          remainingQuota: 1,
        ).toString(),
        'Standing(throttled, quota=1)',
      );
    });
  });

  group('the respect posterior is inspectable below the gate', () {
    test('it reports a number even when it refuses to act on one', () {
      // Exposed deliberately: the console has to be able to say *why* somebody
      // is being treated as neutral, rather than showing nothing and inviting
      // the question.
      const sparse = RespectSignal(yes: 1, no: 2);
      expect(sparse.isUsable, isFalse);
      expect(sparse.posterior, greaterThan(0));
      expect(sparse.total, 3);
    });

    test('a heavier prior pulls harder', () {
      const light = RespectSignal(yes: 6, no: 6, priorWeight: 2);
      const heavy = RespectSignal(yes: 6, no: 6, priorWeight: 40);
      expect(heavy.posterior, greaterThan(light.posterior));
    });

    test('the gate is config, so the number is not a literal', () {
      const strict = RespectSignal(yes: 10, no: 2, usableAfter: 30);
      const lenient = RespectSignal(yes: 10, no: 2, usableAfter: 6);
      expect(strict.isUsable, isFalse);
      expect(lenient.isUsable, isTrue);
    });

    test('it renders without naming anybody', () {
      expect(
        const RespectSignal(yes: 9, no: 3).toString(),
        contains('9/12'),
      );
    });
  });

  group('a person carries only what a matching decision may turn on', () {
    test('shared clusters are the geographic question, not distance', () {
      final ana = aPerson('ana', clusters: {centre, north});
      final bruno = aPerson('bruno', gender: man, clusters: {north, south});
      expect(ana.sharesClusterWith(bruno), isTrue);
      expect(ana.sharedClustersWith(bruno), {north});
    });

    test('no overlap means no shared cluster', () {
      final ana = aPerson('ana', clusters: {centre});
      final bruno = aPerson('bruno', gender: man, clusters: {south});
      expect(ana.sharesClusterWith(bruno), isFalse);
      expect(ana.sharedClustersWith(bruno), isEmpty);
    });

    test('a person is their id, so a set deduplicates by id', () {
      expect({aPerson('ana'), aPerson('ana', weeksWaiting: 9)}, hasLength(1));
    });

    test('a newcomer is somebody with no completed hangout', () {
      expect(aPerson('new', completedHangouts: 0).isNewcomer, isTrue);
      expect(aPerson('old', completedHangouts: 1).isNewcomer, isFalse);
    });
  });
}
