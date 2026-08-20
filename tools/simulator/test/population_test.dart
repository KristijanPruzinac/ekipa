import 'package:ekipa_core/ekipa_core.dart';
import 'package:simulator/simulator.dart';
import 'package:test/test.dart';

void main() {
  const city = SimCity();
  const population = Population(city: city, behaviour: Behaviour());

  group('the city has geography that actually bites', () {
    test('somebody at a district centre cannot reach every district', () {
      // If everyone could reach everything, `noSharedCluster` would never fire
      // and the group-wide cluster check — the one failure a pairwise rule
      // cannot see — would be untested by the whole harness.
      final centre = city.districts.first.$2;
      expect(city.reachableFrom(centre, 4000).length, lessThan(4));
    });

    test('nobody is stranded with nowhere to go', () {
      // An agent who reaches nothing is filtered every week forever. That is a
      // real product state and a useless simulation state: churn with extra
      // steps, and it would quietly drag the match rate down for a reason that
      // has nothing to do with matching.
      const faraway = GeoPoint(latitude: 40, longitude: 10);
      expect(city.reachableFrom(faraway, 100).length, 1);
    });

    test('a week is nine slots on three evenings', () {
      final slots = city.slotsOfWeek(0, DateTime.utc(2026, 9, 7));
      expect(slots, hasLength(9));
      expect(city.slotsPerWeek, 9);
      expect(slots.map((slot) => slot.id.value).toSet(), hasLength(9));
    });

    test('the two early slots of an evening do not overlap', () {
      // 16:00-17:30 and 17:30-19:00 are back to back. If `overlaps` treated
      // them as clashing, half the city's supply would vanish and the match
      // rate would look like a matching problem.
      final slots = city.slotsOfWeek(0, DateTime.utc(2026, 9, 7));
      expect(slots[0].overlaps(slots[1]), isFalse);
      expect(slots[1].overlaps(slots[2]), isFalse);
    });

    test('later weeks are later', () {
      final monday = DateTime.utc(2026, 9, 7);
      final first = city.slotsOfWeek(0, monday).first.startsAt;
      final second = city.slotsOfWeek(1, monday).first.startsAt;
      expect(second.difference(first), const Duration(days: 7));
    });
  });

  group('sampling', () {
    test('every trait lands inside its range', () {
      final agents = population.sample(200, 0, 0, SeededRandomSource(7));
      for (final agent in agents) {
        expect(agent.availability, inInclusiveRange(0, 1));
        expect(agent.reliability, inInclusiveRange(0, 1));
        expect(agent.warmth, inInclusiveRange(0, 1));
        expect(agent.openness, inInclusiveRange(0, 1));
        expect(agent.patienceWeeks, greaterThanOrEqualTo(1));
        expect(agent.reachableClusters, isNotEmpty);
      }
    });

    test('ids are unique and continue from where the last batch stopped', () {
      final first = population.sample(10, 0, 0, SeededRandomSource(1));
      final second = population.sample(10, 1, 10, SeededRandomSource(1));
      final ids = {
        for (final agent in [...first, ...second]) agent.id,
      };
      expect(ids, hasLength(20));
    });

    test('the gender mix is respected, third value included', () {
      final agents = population.sample(600, 0, 0, SeededRandomSource(3));
      final counts = <String, int>{};
      for (final agent in agents) {
        counts[agent.gender.code] = (counts[agent.gender.code] ?? 0) + 1;
      }
      expect(counts['woman'], greaterThan(200));
      expect(counts['man'], greaterThan(200));
      // 4% of 600 is 24. The assertion is only that a third gender exists at
      // all: the composition rule is "nobody is the only one of their gender"
      // and it has to be exercised by a population that has three.
      expect(counts['other'], greaterThan(0));
    });

    test('the same seed samples the same city', () {
      final a = population.sample(50, 0, 0, SeededRandomSource(11));
      final b = population.sample(50, 0, 0, SeededRandomSource(11));
      expect(
        [for (final agent in a) '${agent.id.value}:${agent.warmth}'],
        [for (final agent in b) '${agent.id.value}:${agent.warmth}'],
      );
    });

    test('a different seed samples a different city', () {
      final a = population.sample(50, 0, 0, SeededRandomSource(11));
      final b = population.sample(50, 0, 0, SeededRandomSource(12));
      expect(
        [for (final agent in a) agent.warmth],
        isNot([for (final agent in b) agent.warmth]),
      );
    });

    test('a narrowed model narrows the population it produces', () {
      const uniform = Population(
        city: city,
        behaviour: Behaviour(warmthMean: 0.5, warmthSpread: 0),
      );
      final agents = uniform.sample(30, 0, 0, SeededRandomSource(5));
      expect(agents.every((agent) => agent.warmth == 0.5), isTrue);
    });
  });

  group('an agent as the matcher sees them', () {
    test('carries no latent trait across the boundary', () {
      // The matcher must not be able to read warmth even by accident: the
      // whole claim of the harness is that it is testing the real algorithm on
      // the information the real algorithm has.
      final agent = population.sample(1, 0, 0, SeededRandomSource(2)).single;
      final person = agent.asPerson(city.id);
      expect(person.toString(), isNot(contains('${agent.warmth}')));
      expect(person.standing, Standing.good);
      expect(person.id, agent.id);
    });
  });
}
