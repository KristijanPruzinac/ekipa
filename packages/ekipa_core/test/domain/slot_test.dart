import 'package:ekipa_core/ekipa_core.dart';
import 'package:test/test.dart';

Slot slotAt(String id, DateTime start, {Duration length = _ninety}) => Slot(
  id: SlotId(id),
  cityId: const CityId('osijek'),
  startsAt: start,
  endsAt: start.add(length),
);

const _ninety = Duration(minutes: 90);
final _thursday = DateTime.utc(2026, 8, 20, 15, 30);

void main() {
  group('overlap is the rule the double-booking filter is built on', () {
    // Two groups holding the same person at 17:30 means at least one group
    // waits for somebody who is not coming — the single outcome the product
    // cannot survive at launch. This predicate is a rule, not a utility.

    test('a slot overlaps itself', () {
      final slot = slotAt('a', _thursday);
      expect(slot.overlaps(slot), isTrue);
    });

    test('two slots half an hour apart overlap', () {
      expect(
        slotAt('a', _thursday).overlaps(
          slotAt('b', _thursday.add(const Duration(minutes: 30))),
        ),
        isTrue,
      );
    });

    test('and it is symmetric, so the filter cannot ask the wrong way', () {
      final early = slotAt('a', _thursday);
      final late = slotAt('b', _thursday.add(const Duration(minutes: 30)));
      expect(early.overlaps(late), late.overlaps(early));
    });

    test('back-to-back slots do not overlap', () {
      // 16:00–17:30 and 17:30–19:00 are the product's real adjacent slots. If
      // touching counted as overlapping, nobody could be available for two
      // consecutive windows, which is most of the week's supply.
      expect(
        slotAt('a', _thursday).overlaps(slotAt('b', _thursday.add(_ninety))),
        isFalse,
      );
    });

    test('slots on different evenings do not overlap', () {
      expect(
        slotAt('a', _thursday).overlaps(
          slotAt('b', _thursday.add(const Duration(days: 1))),
        ),
        isFalse,
      );
    });

    test('a long slot swallowing a short one overlaps', () {
      final long = slotAt('long', _thursday, length: const Duration(hours: 4));
      final short = slotAt('short', _thursday.add(const Duration(hours: 1)));
      expect(long.overlaps(short), isTrue);
      expect(short.overlaps(long), isTrue);
    });
  });

  group('identity', () {
    test('a slot is its id, so a set of slots deduplicates by id', () {
      final same = {
        slotAt('a', _thursday),
        slotAt('a', _thursday.add(const Duration(hours: 5))),
      };
      expect(same, hasLength(1));
    });

    test('different ids are different slots', () {
      expect(slotAt('a', _thursday), isNot(slotAt('b', _thursday)));
    });

    test('the window is ninety minutes', () {
      expect(slotAt('a', _thursday).duration, _ninety);
    });

    test('it renders as an id and an instant', () {
      expect(
        slotAt('a', _thursday).toString(),
        'Slot(a, 2026-08-20T15:30:00.000Z)',
      );
    });
  });
}
