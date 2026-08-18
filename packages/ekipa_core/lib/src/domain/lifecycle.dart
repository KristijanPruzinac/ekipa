/// Where a hangout is in its life.
///
/// **Intention.** The states are the ones a *person* can be in a different
/// relationship to — not the ones a developer found convenient. `PROPOSED` and
/// `PLANNED` differ only in whether anybody has been told, and that difference
/// is the whole reason the matcher can run, be inspected, and be discarded
/// before it has cost anyone an expectation.
///
/// **Rejected — a boolean pair (`confirmed`, `cancelled`).** Two booleans make
/// four states, of which three are reachable and one is nonsense, and nothing
/// stops a write producing the nonsense one. An enum makes the illegal state
/// unrepresentable and makes the transition table something you can read.
enum HangoutState {
  /// The matcher emitted it; nobody has been told. Discardable at no cost.
  planned,

  /// Members know a hangout exists for their slot. No names, no place.
  proposed,

  /// Morning-of. Each member answers yes or no, and silence is a third answer.
  confirming,

  /// Someone declined; the repair pass is running.
  backfilling,

  /// Enough confirmations. It is happening.
  locked,

  /// Meeting point, sigil and names are visible. T−60m.
  revealed,

  /// Arrival taps, the grace window, late reports.
  live,

  /// Mandatory ratings are open.
  rating,

  /// Edges formed, infractions written, metrics final.
  closed,

  /// The system called it off — before anyone left home, always.
  cancelled,

  /// Nobody arrived.
  abandoned;

  /// Whether names and the meeting point may be disclosed in this state.
  ///
  /// The clock check lives beside this on the server (`hangout_reveal`); this
  /// is the state half of the same gate, in the one place both the worker and
  /// the console can read it.
  bool get namesMayBeShown => switch (this) {
    HangoutState.revealed ||
    HangoutState.live ||
    HangoutState.rating ||
    HangoutState.closed => true,
    _ => false,
  };

  /// Whether the hangout has stopped moving.
  bool get isTerminal => switch (this) {
    HangoutState.closed ||
    HangoutState.cancelled ||
    HangoutState.abandoned => true,
    _ => false,
  };
}

/// A member's answer to the morning-of confirmation.
///
/// **Silence is a third answer, not a missing one.** It is treated as worse
/// than a decline, because the scarce resource is time to repair and silence
/// destroys it (04_TRUST.md §3.1). Modelling it as `null` would make that
/// impossible to say: "no answer yet" and "no answer, ever" would be the same
/// value, and only one of them is an infraction.
enum Confirmation {
  /// Coming.
  yes,

  /// Not coming, said in time for the group to be repaired.
  no,

  /// Never answered. The expensive one.
  silent;

  /// Whether this answer keeps the member in the group.
  bool get isAttending => this == Confirmation.yes;
}

/// How enjoyable another member was, asked of everyone after every hangout.
///
/// Four values rather than a five-star scale, deliberately: a star rating asks
/// people to be precise about something they are not precise about, and the
/// only decisions taken from this are *form an edge* and *never again*, which
/// need exactly the two ends.
enum Enjoyment {
  /// Strong positive. Forms an edge if it is mutual.
  reallyEnjoyed,

  /// Positive. Forms an edge if it is mutual.
  enjoyed,

  /// Neutral. The honest default, and it must be cheap to give.
  noPreference,

  /// A permanent, symmetric, invisible exclusion.
  ratherNot;

  /// Whether this answer can contribute to a mutual edge.
  ///
  /// An edge needs **both** sides positive (02_DOMAIN.md). A one-sided "I
  /// enjoyed them" creates nothing, and that is load-bearing for privacy rather
  /// than for manners: if one-sided liking could pull someone back, being
  /// re-matched would leak that they liked you — and *not* being re-matched
  /// would leak the opposite.
  bool get isPositive =>
      this == Enjoyment.reallyEnjoyed || this == Enjoyment.enjoyed;

  /// The weight this answer contributes to an edge, before decay.
  double get edgeWeight => switch (this) {
    Enjoyment.reallyEnjoyed => 1,
    Enjoyment.enjoyed => 0.6,
    Enjoyment.noPreference => 0,
    Enjoyment.ratherNot => 0,
  };
}
