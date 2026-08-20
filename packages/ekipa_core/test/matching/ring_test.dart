import 'package:ekipa_core/matching.dart';
import 'package:test/test.dart';

void main() {
  group('rings widen outward and never inward', () {
    test('R1 falls to R2, R2 to R3, and R3 nowhere', () {
      // A stranger draw silently becoming a friend draw is the direction that
      // builds closed cliques. Falling outward costs one person one evening of
      // familiarity and increases exposure, which is the failure we can afford.
      expect(Ring.r1Enjoyed.widened, Ring.r2Leaf);
      expect(Ring.r2Leaf.widened, Ring.r3Stranger);
      expect(Ring.r3Stranger.widened, isNull);
    });

    test('the storage codes match the database enum', () {
      expect(Ring.r1Enjoyed.storageCode, 'r1_enjoyed');
      expect(Ring.r2Leaf.storageCode, 'r2_leaf');
      expect(Ring.r3Stranger.storageCode, 'r3_stranger');
    });
  });

  group('a slot role says why somebody is in the group', () {
    test('the storage codes match the database enum', () {
      expect(SlotRole.seed.storageCode, 'seed');
      expect(SlotRole.partner.storageCode, 'partner');
      expect(SlotRole.backfill.storageCode, 'backfill');
    });
  });
}
