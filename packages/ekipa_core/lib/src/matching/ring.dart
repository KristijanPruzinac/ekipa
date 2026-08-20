/// Which ring of the graph a partner was drawn from.
///
/// **Intention.** These three sets are the product's actual thesis. A dating
/// app draws from strangers forever; a friend-of-a-friend app draws from R1
/// forever and closes. Drawing from all three, in a ratio somebody can tune, is
/// the bet — and [Ring] exists so the bet can be *measured*, because the
/// primary metric is edge yield sliced by realised ring (03_MATCHMAKER.md §9).
///
/// **This type lives behind `package:ekipa_core/matching.dart` and not in the
/// shared domain**, even though it looks like plain vocabulary. Directive D9
/// says nothing about matching reaches a user's device, and "nothing" is
/// cheaper to enforce than "nothing important". The mobile app has no use for
/// it: a person is never told which ring they were drawn from, because that
/// sentence — *"you were matched with C because C is a friend of someone you
/// liked"* — is the friend graph, spoken out loud.
enum Ring {
  /// A direct mutual edge. Someone you enjoyed and who enjoyed you.
  ///
  /// Repeated exposure is the only known mechanism by which acquaintances
  /// become friends, so this ring has to exist. It is bounded by the cooldown,
  /// because *guaranteed* repetition would leak rating information.
  r1Enjoyed,

  /// The R1 sets of your R1 people, minus your own R1 and you.
  ///
  /// **The operating principle.** You discover your friends' friends, which is
  /// how a social circle actually grows and is the one move no dating-style app
  /// makes.
  r2Leaf,

  /// Everyone else eligible.
  ///
  /// Without this the graph closes: new people never enter, separate components
  /// never merge, and the product becomes a tool for the people who already
  /// know each other.
  r3Stranger;

  /// The value stored in `hangout_members.ring_intended` / `ring_realised`.
  String get storageCode => switch (this) {
    Ring.r1Enjoyed => 'r1_enjoyed',
    Ring.r2Leaf => 'r2_leaf',
    Ring.r3Stranger => 'r3_stranger',
  };

  /// The ring one step further out, or `null` at the outermost.
  ///
  /// **Fallback goes down, never up.** If the drawn ring has no member passing
  /// the hard constraints, the draw falls R1 → R2 → R3 and never the other way.
  /// A stranger draw silently becoming a friend draw is the direction that
  /// builds closed cliques; falling outward costs one person one evening of
  /// familiarity and increases exposure, which is the failure we can afford.
  Ring? get widened => switch (this) {
    Ring.r1Enjoyed => Ring.r2Leaf,
    Ring.r2Leaf => Ring.r3Stranger,
    Ring.r3Stranger => null,
  };
}

/// Why a person is in the group.
///
/// Recorded per member so a run can be read back. `seed` is not a status — it
/// is the person the draw ran *from*, and the console needs to know which one
/// that was to explain the rest of the group.
enum SlotRole {
  /// The person the group was built around.
  seed,

  /// Drawn by the ring draw, or placed as a leftover.
  partner,

  /// Added by the morning-of repair pass after a decline.
  backfill;

  /// The value stored in `hangout_members.slot_role`.
  String get storageCode => name;
}
