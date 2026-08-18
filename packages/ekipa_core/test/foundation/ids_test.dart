import 'package:ekipa_core/ekipa_core.dart';
import 'package:test/test.dart';

void main() {
  group('EntityId', () {
    test('identifiers of the same type and value are equal', () {
      expect(const PersonId('p1'), const PersonId('p1'));
      expect(const PersonId('p1').hashCode, const PersonId('p1').hashCode);
    });

    test('identifiers of the same type and different value differ', () {
      expect(const PersonId('p1'), isNot(const PersonId('p2')));
    });

    test('identifiers of different types never compare equal', () {
      // The bug this exists to prevent: a hangout id handed to a parameter
      // expecting a person id. Under `extension type` these assertions would
      // fail, because both erase to String at runtime.
      expect(const PersonId('x'), isNot(const SlotId('x')));
      expect(const HangoutId('x'), isNot(const VenueId('x')));
      expect(const CityId('x'), isNot(const ClusterId('x')));
    });

    test('a map keyed by one id type does not match another', () {
      final byPerson = <PersonId, String>{const PersonId('x'): 'Marta'};
      expect(byPerson[const PersonId('x')], 'Marta');
      expect(byPerson.containsKey(const PersonId('y')), isFalse);
    });

    test('hash codes differ across types for the same raw value', () {
      expect(
        const PersonId('x').hashCode,
        isNot(const SlotId('x').hashCode),
      );
    });

    test('toString names the type, so logs are readable', () {
      expect(const PersonId('abc').toString(), contains('PersonId'));
      expect(const PersonId('abc').toString(), contains('abc'));
    });
  });
}
