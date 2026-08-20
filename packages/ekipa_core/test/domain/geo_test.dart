import 'package:ekipa_core/ekipa_core.dart';
import 'package:test/test.dart';

void main() {
  // Osijek's centre, and a point about 1.2 km east of it.
  const centre = GeoPoint(latitude: 45.5550, longitude: 18.6955);
  const eastward = GeoPoint(latitude: 45.5550, longitude: 18.7110);

  group('distance is good enough for the decision it informs', () {
    test('a point is no distance from itself', () {
      expect(centre.distanceTo(centre), 0);
    });

    test('roughly a kilometre reads as roughly a kilometre', () {
      // 0.0155° of longitude at this latitude is about 1.21 km. The tolerance
      // is wide on purpose: the question this answers is "is this person
      // twenty minutes from that café", and a geodesic library would be
      // precision the decision cannot use, paid for with a dependency (SC-2).
      expect(centre.distanceTo(eastward), closeTo(1210, 40));
    });

    test('distance is symmetric', () {
      expect(
        centre.distanceTo(eastward),
        closeTo(eastward.distanceTo(centre), 1e-6),
      );
    });
  });

  group('an anchor is snapped before it is ever stored', () {
    test('two nearby points collapse onto the same grid cell', () {
      // The product needs "roughly twenty minutes away". It does not need an
      // address, and holding one is a liability against the stalker (T2) that
      // buys nothing. Snapping happens before the write, so the precise point
      // never exists in the database to be leaked.
      const a = GeoPoint(latitude: 45.55501, longitude: 18.69551);
      const b = GeoPoint(latitude: 45.55519, longitude: 18.69572);
      expect(a.snappedTo(500), b.snappedTo(500));
    });

    test('the snapped point stays within the grid cell it came from', () {
      const point = GeoPoint(latitude: 45.5550, longitude: 18.6955);
      expect(point.distanceTo(point.snappedTo(500)), lessThan(400));
    });

    test('points a kilometre apart do not collapse together', () {
      expect(centre.snappedTo(500), isNot(eastward.snappedTo(500)));
    });

    test('snapping is idempotent', () {
      final once = centre.snappedTo(500);
      expect(once.snappedTo(500), once);
    });
  });

  group('the type that holds the most dangerous value is the least chatty', () {
    test('toString does not print coordinates', () {
      // A toString that printed them would put a home anchor into every stack
      // trace, every print somebody added while debugging, and every crash
      // report — rule 5 of 11_SECURITY.md §8, breached by accident.
      final rendered = centre.toString();
      expect(rendered, isNot(contains('45.5')));
      expect(rendered, isNot(contains('18.6')));
    });

    test('a person renders as an id and a tier, never an anchor', () {
      const person = Person(
        id: PersonId('ana'),
        gender: Gender('woman'),
        cityId: CityId('osijek'),
        homeAnchor: centre,
        maxTravelMetres: 3000,
        reachableClusters: {},
        standing: Standing.good,
        completedHangouts: 0,
        weeksWaiting: 0,
      );
      expect(person.toString(), 'Person(ana, good)');
    });
  });
}
