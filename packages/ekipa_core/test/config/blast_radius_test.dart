import 'package:ekipa_core/ekipa_core.dart';
import 'package:test/test.dart';

final _publishAt = DateTime.utc(2026, 8, 19, 9);

InFlightObject _hangout(
  String id, {
  required DateTime decidesAt,
  ConfigVersionId? pinned,
}) => InFlightObject(
  id: id,
  kind: 'hangout',
  decidesAt: decidesAt,
  pinnedVersion: pinned,
);

void main() {
  group('estimating', () {
    test('a pinned hangout is untouched however late it decides', () {
      final radius = BlastRadius.estimate(
        inFlight: [
          _hangout(
            'h1',
            decidesAt: _publishAt.add(const Duration(days: 2)),
            pinned: const ConfigVersionId('v1'),
          ),
        ],
        effectiveFrom: _publishAt,
      );

      expect(radius.pinned, hasLength(1));
      expect(radius.isEmpty, isTrue);
    });

    test('an unpinned hangout deciding after the change is exposed', () {
      final radius = BlastRadius.estimate(
        inFlight: [
          _hangout('h1', decidesAt: _publishAt.add(const Duration(hours: 1))),
        ],
        effectiveFrom: _publishAt,
      );

      expect(radius.exposed.single.id, 'h1');
      expect(radius.isEmpty, isFalse);
    });

    test('an unpinned hangout that has already decided is settled', () {
      final radius = BlastRadius.estimate(
        inFlight: [
          _hangout(
            'h1',
            decidesAt: _publishAt.subtract(const Duration(minutes: 1)),
          ),
        ],
        effectiveFrom: _publishAt,
      );

      expect(radius.settled, hasLength(1));
      expect(radius.isEmpty, isTrue);
    });

    test('a decision exactly at the effective moment is exposed', () {
      // The boundary belongs to the new rules: a version effective at 09:00
      // governs the 09:00 sweep, or "effective from" means something the
      // sweeper does not agree with.
      final radius = BlastRadius.estimate(
        inFlight: [_hangout('h1', decidesAt: _publishAt)],
        effectiveFrom: _publishAt,
      );

      expect(radius.exposed, hasLength(1));
    });

    test('every object lands in exactly one bucket', () {
      final objects = [
        _hangout(
          'pinned',
          decidesAt: _publishAt.add(const Duration(days: 1)),
          pinned: const ConfigVersionId('v1'),
        ),
        _hangout('exposed', decidesAt: _publishAt.add(const Duration(days: 1))),
        _hangout(
          'settled',
          decidesAt: _publishAt.subtract(const Duration(days: 1)),
        ),
      ];
      final radius = BlastRadius.estimate(
        inFlight: objects,
        effectiveFrom: _publishAt,
      );

      expect(
        radius.pinned.length + radius.exposed.length + radius.settled.length,
        objects.length,
      );
    });
  });

  group('describing', () {
    test('an empty system says so instead of reporting a clean zero', () {
      // "0 hangouts affected" reads identically whether nothing is exposed or
      // nothing exists, and only one of those is reassuring.
      final radius = BlastRadius.estimate(
        inFlight: const [],
        effectiveFrom: _publishAt,
      );

      expect(radius.describe(), 'Nothing is in flight.');
    });

    test('a safe change counts what protected it', () {
      final radius = BlastRadius.estimate(
        inFlight: [
          _hangout(
            'h1',
            decidesAt: _publishAt.add(const Duration(days: 1)),
            pinned: const ConfigVersionId('v1'),
          ),
        ],
        effectiveFrom: _publishAt,
      );

      expect(radius.describe(), contains('1 pinned'));
      expect(radius.describe(), contains('none exposed'));
    });

    test('an unsafe change leads with the number that matters', () {
      final radius = BlastRadius.estimate(
        inFlight: [
          _hangout('h1', decidesAt: _publishAt.add(const Duration(hours: 2))),
          _hangout('h2', decidesAt: _publishAt.add(const Duration(hours: 3))),
        ],
        effectiveFrom: _publishAt,
      );

      expect(radius.describe(), startsWith('2 in flight'));
    });
  });
}
