import 'package:ekipa_core/ekipa_core.dart';
import 'package:test/test.dart';

void main() {
  const ana = PersonId('ana');
  const bruno = PersonId('bruno');
  const cvita = PersonId('cvita');

  group('symmetry is structural, not maintained', () {
    // The database enforces this with `check (a_id < b_id)`. This is the same
    // rule in Dart, so a lookup cannot miss a row by asking in the wrong order.
    //
    // It is not tidiness. If the order of the key could carry a direction, then
    // invariant 4 — the direction of an edge is not stored and cannot be
    // derived — becomes a convention rather than a fact.

    test('a pair is the same pair whichever way it is built', () {
      expect(PairKey(ana, bruno), PairKey(bruno, ana));
    });

    test('and hashes the same, so a map lookup cannot miss', () {
      final seen = {PairKey(bruno, ana): 'recorded'};
      expect(seen[PairKey(ana, bruno)], 'recorded');
    });

    test('the low end is always the lexicographically smaller id', () {
      expect(PairKey(bruno, ana).low, ana);
      expect(PairKey(ana, bruno).high, bruno);
    });

    test('different pairs are different', () {
      expect(PairKey(ana, bruno), isNot(PairKey(ana, cvita)));
    });
  });

  group('asking about a pair', () {
    test('it knows who is in it', () {
      final pair = PairKey(ana, bruno);
      expect(pair.contains(ana), isTrue);
      expect(pair.contains(cvita), isFalse);
    });

    test('it can name the other one', () {
      final pair = PairKey(ana, bruno);
      expect(pair.otherThan(ana), bruno);
      expect(pair.otherThan(bruno), ana);
    });
  });

  group('an edge needs both sides', () {
    test('only a positive answer can contribute one', () {
      // A one-sided "I enjoyed them" creates nothing, and the reason is privacy
      // rather than manners: if one-sided liking could pull someone back, being
      // re-matched would leak that they liked you — and *not* being re-matched
      // would leak the opposite.
      expect(Enjoyment.reallyEnjoyed.isPositive, isTrue);
      expect(Enjoyment.enjoyed.isPositive, isTrue);
      expect(Enjoyment.noPreference.isPositive, isFalse);
      expect(Enjoyment.ratherNot.isPositive, isFalse);
    });

    test('a strong yes weighs more than a mild one', () {
      expect(
        Enjoyment.reallyEnjoyed.edgeWeight,
        greaterThan(Enjoyment.enjoyed.edgeWeight),
      );
    });

    test('neutral and negative both contribute nothing', () {
      expect(Enjoyment.noPreference.edgeWeight, 0);
      expect(Enjoyment.ratherNot.edgeWeight, 0);
    });
  });

  group('an exclusion is permanent and reasoned', () {
    test('two exclusions over the same pair are the same exclusion', () {
      expect(
        Exclusion(pair: PairKey(ana, bruno), reason: ExclusionReason.block),
        Exclusion(pair: PairKey(bruno, ana), reason: ExclusionReason.block),
      );
    });

    test('the reason is part of the record but never shown', () {
      // Recorded so the trust system can distinguish a quiet rather_not from an
      // upheld report; never surfaced, because a visible exclusion tells its
      // subject that somebody answered.
      final exclusion = Exclusion(
        pair: PairKey(ana, bruno),
        reason: ExclusionReason.reportUpheld,
      );
      expect(exclusion.reason, ExclusionReason.reportUpheld);
    });
  });

  group('the lifecycle says what may be disclosed', () {
    test('names appear only from the reveal onward', () {
      for (final state in HangoutState.values) {
        final expected = const {
          HangoutState.revealed,
          HangoutState.live,
          HangoutState.rating,
          HangoutState.closed,
        }.contains(state);
        expect(
          state.namesMayBeShown,
          expected,
          reason: '${state.name} disagrees with the reveal gate',
        );
      }
    });

    test('a terminal state has stopped moving', () {
      expect(HangoutState.closed.isTerminal, isTrue);
      expect(HangoutState.cancelled.isTerminal, isTrue);
      expect(HangoutState.abandoned.isTerminal, isTrue);
      expect(HangoutState.confirming.isTerminal, isFalse);
    });

    test('silence is an answer, and it is not attendance', () {
      // Modelling it as null would make "no answer yet" and "no answer, ever"
      // the same value, and only one of them is an infraction.
      expect(Confirmation.yes.isAttending, isTrue);
      expect(Confirmation.no.isAttending, isFalse);
      expect(Confirmation.silent.isAttending, isFalse);
      expect(Confirmation.values, hasLength(3));
    });
  });

  group('the respect signal is gated before it is used', () {
    test('a small clean sample is neutral, not excellent', () {
      // Almost everybody presses yes, so three yeses carry no information. The
      // gate stops the signal being used as a boost, which is the one use of it
      // that is forbidden.
      const sparse = RespectSignal(yes: 3, no: 0);
      expect(sparse.isUsable, isFalse);
      expect(sparse.isBelow(0.85), isFalse);
    });

    test('a small bad sample is also neutral', () {
      const sparse = RespectSignal(yes: 0, no: 2);
      expect(sparse.isUsable, isFalse);
      expect(
        sparse.isBelow(0.85),
        isFalse,
        reason: 'nobody is condemned by two answers',
      );
    });

    test('above the gate, a bad record shows', () {
      const evidenced = RespectSignal(yes: 8, no: 12);
      expect(evidenced.isUsable, isTrue);
      expect(evidenced.isBelow(0.85), isTrue);
    });

    test('the prior pulls a clean record toward respectful', () {
      const clean = RespectSignal(yes: 20, no: 0);
      expect(clean.posterior, greaterThan(0.95));
      expect(clean.posterior, lessThan(1));
    });

    test('somebody nobody has rated sits at the prior mean', () {
      expect(const RespectSignal.none().posterior, closeTo(0.97, 1e-9));
    });
  });
}
