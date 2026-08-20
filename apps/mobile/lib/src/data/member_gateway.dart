import 'package:ekipa_core/ekipa_core.dart';
import 'package:mobile/src/data/records.dart';

/// Everything the app may ask the server, and nothing else.
///
/// **Intention — the whole client surface, on one page.** `11_SECURITY.md §3`
/// makes the client a hostile display surface: every method here has a matching
/// `security definer` RPC that re-checks membership, phase and time window,
/// because a screen that hides a button has hidden nothing. Keeping the surface
/// in one interface means a new capability is a visible act — you cannot add
/// one by writing a query in a widget.
///
/// **What is deliberately absent, and why each absence is load-bearing:**
///
/// * **No method reads another person.** Not a profile, not a history, not a
///   count. The only people the app ever sees are members of its own hangouts,
///   after the reveal, through [hangouts].
/// * **No method reads a rating** — given or received, own or others', raw or
///   aggregate (invariant 3).
/// * **No method reads standing, a trust score, or a respect rate**
///   (invariant 7). [sanction] returns the consequence, never the number.
/// * **No method reads anybody's anchor but the caller's own.**
/// * **No method touches the matchmaker.** Not to trigger it, not to query it,
///   not to ask why a group was built (D9). There is no `whyThisGroup()` and
///   there never will be — it would leak the graph, and through the graph, how
///   people rated each other.
/// * **No `setCity`, `setGender`, or `setName`.** A person who could change
///   city on the morning of a run could relocate into a denser market; a person
///   who could change gender could defeat the composition invariant. Both are
///   set once, at signup, and changed by a human through appeal.
abstract interface class MemberGateway {
  // ── Who is asking ──────────────────────────────────────────────────────────

  /// Where this person stands.
  Future<MemberState> state();

  /// The active sanction, if there is one.
  Future<SanctionNotice?> sanction();

  /// The caller's own row.
  Future<MemberProfile?> profile();

  // ── Catalogues ─────────────────────────────────────────────────────────────

  /// The gender registry (D6).
  Future<List<GenderOption>> genders();

  /// Cities open to signup.
  Future<List<CityBrief>> cities();

  // ── Signup ─────────────────────────────────────────────────────────────────

  /// Creates the person row.
  ///
  /// **One call, not four.** Onboarding collects a name from the verifier, a
  /// gender and an anchor, and sends them together. Four writes means four ways
  /// to end up with half a member — and a row with a name and no gender is a
  /// person the matcher silently never places, which looks like nothing being
  /// wrong from the inside.
  ///
  /// The city is **not** a parameter. It is derived server-side from the
  /// anchor, because `people.city_id` is not client-settable by design.
  Future<void> createProfile({
    required String firstName,
    required String lastInitial,
    required String genderCode,
    required double anchorLatitude,
    required double anchorLongitude,
    List<String> equipment,
  });

  // ── The week ───────────────────────────────────────────────────────────────

  /// The slots this person can still answer.
  Future<List<SlotOption>> slots();

  /// Replaces this person's availability with [slotIds].
  ///
  /// **The whole set, never a delta.** Two half-applied deltas leave a person
  /// available for evenings matching neither what they saw nor what they meant,
  /// and the matcher runs against whatever is there.
  Future<void> setAvailability(Set<SlotId> slotIds);

  /// Copies last week's answers forward.
  Future<void> repeatLastWeek();

  // ── The hangouts ───────────────────────────────────────────────────────────

  /// Every hangout this person is in that has not closed, soonest first.
  Future<List<Hangout>> hangouts();

  /// Answers the morning-of question.
  ///
  /// Returns the hangout as it stands *after* the answer, because the answer
  /// can change the phase — the third yes locks the group, in the same
  /// transaction that counted it.
  Future<Hangout> confirm({required String hangoutId, required bool coming});

  /// Taps "I'm here".
  Future<Hangout> markArrived(String hangoutId);

  /// Says whether another member is present.
  ///
  /// **Everyone taps for themselves and about each other** — the transcript is
  /// explicit that this is a duty and that one tap per group is not enough.
  /// The server combines them (`02_DOMAIN.md §4`): present means they tapped
  /// *and* nobody contradicted it, or a majority attests it.
  Future<Hangout> attest({
    required String hangoutId,
    required String memberId,
    required bool present,
  });

  /// The activity's cards, once every member has arrived.
  ///
  /// Deterministic per hangout, so every phone shows the same card in the same
  /// order with no real-time synchronisation and no server round-trip
  /// (`06_ACTIVITIES.md §1`).
  Future<List<ActivityCard>> activityCards(String hangoutId);

  /// Confirms or withdraws a promise to bring equipment.
  ///
  /// A `no` before reveal is free and swaps the activity; a carrier who
  /// confirms and does not bring gets a low infraction (`06_ACTIVITIES.md §2`).
  Future<void> setBringing({required String hangoutId, required bool bringing});

  // ── After ──────────────────────────────────────────────────────────────────

  /// Submits every rating for a hangout at once.
  ///
  /// All of them together, because a partial set is indistinguishable from a
  /// missing one and the rating gate would then block somebody who tried.
  Future<void> submitRatings({
    required String hangoutId,
    required List<RatingAnswer> answers,
    required VenueVerdict venue,
  });

  /// Reports a member.
  ///
  /// A separate, heavier action than a rating, and invisible to its subject —
  /// including the count (invariant 6). The first report costs the subject
  /// almost nothing and protects the reporter completely: they never meet
  /// again (`04_TRUST.md §4.3`, rung R0).
  Future<void> report({
    required String hangoutId,
    required String memberId,
    required String category,
    String? note,
  });

  /// Says the meeting point was wrong — closed, gone, unfindable.
  ///
  /// One tap on the reveal screen. Demotes the venue immediately and, past a
  /// threshold, deactivates it pending re-ingestion. Automatic, no queue (D11).
  Future<void> reportVenue({required String hangoutId, required String reason});
}

/// What the server said no to.
///
/// **The message is the server's, not ours.** A client that composed its own
/// explanation would eventually explain a refusal it did not understand — and
/// the refusals that matter here ("you have ratings outstanding", "that
/// confirmation window has closed") are exactly the ones a person needs to be
/// told accurately.
final class MemberFailure implements Exception {
  /// A failure carrying the server's [code] and [message].
  const MemberFailure(this.code, this.message);

  /// The SQLSTATE or an application code.
  final String code;

  /// What to show.
  final String message;

  /// Whether this was a refusal rather than a fault. `42501` is Postgres'
  /// insufficient privilege — the shape a policy refusal arrives in.
  bool get isRefusal => code == '42501';

  @override
  String toString() => 'MemberFailure($code): $message';
}
