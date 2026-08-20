/// What the server tells the app, and nothing more.
///
/// **Intention — these types are the privacy contract, written down.** Every
/// field here is a field the server has decided this person may see. There is
/// no `Person` with a standing on it, no rating anywhere, no other member's
/// anchor, no `via_person_id`, no ring, no score. If a screen wants something,
/// it has to appear here first, which means somebody has to decide it is
/// allowed — the same reasoning that keeps `hangout_reveal` a `security
/// definer` function instead of a view.
///
/// Two absences are worth naming because they look like omissions and are not:
///
/// * **Nothing carries a rating, in either direction.** Invariant 3
/// (`02_DOMAIN.md §6`) is that nobody can ever learn how anyone rated them —
/// not the value, not the existence, not an aggregate that leaks it. A field
/// here would be the leak.
/// * **Nothing carries standing or trust score.** Invariant 7. A person sees
/// the *sanction* — what they cannot do, and until when — never the number
/// behind it.
library;

import 'package:ekipa_core/ekipa_core.dart';
import 'package:flutter/foundation.dart';

/// Where a person stands with the app.
enum MemberState {
  /// Verified, but the profile is not finished.
  incomplete,

  /// Ordinary.
  active,

  /// Temporarily out, with a reason and an end date.
  suspended,

  /// Out.
  banned,
}

/// The hangout lifecycle, as the app is allowed to see it.
///
/// The server's machine has more states than this (`02_DOMAIN.md §3`), and the
/// difference is deliberate: `PLANNED` never reaches a client, because a
/// hangout nobody has been told about is not a hangout yet.
enum HangoutPhase {
  /// It exists; the morning-of question has not been asked.
  proposed,

  /// Answer yes or no.
  confirming,

  /// Everyone said yes. Waiting for the reveal.
  locked,

  /// Somebody dropped out and the repair is running. Deliberately shown: a
  /// group that has gone quiet is worse than a group that says it is repairing.
  backfilling,

  /// Place, sigil and names are out.
  revealed,

  /// It is happening.
  live,

  /// It is over and the ratings are due.
  rating,

  /// Done.
  closed,

  /// It will not happen. Everyone was told before they left home.
  cancelled,
}

/// One person in a hangout, as far as another member may know them.
@immutable
final class Member {
  /// Describes a member.
  const Member({
    required this.id,
    required this.name,
    required this.isYou,
    this.arrived = false,
    this.attestedPresent = false,
    this.bringingEquipment,
  });

  /// Stable within this hangout. Never a global person id — see
  /// `hangout_reveal`, which hands out per-hangout handles so two hangouts
  /// cannot be joined up by a client to learn that the same person was in both.
  final String id;

  /// First name and last initial. The only name that exists.
  final DisplayName name;

  /// Whether this row is the viewer.
  final bool isYou;

  /// Whether they have tapped "I'm here".
  final bool arrived;

  /// Whether the group's taps agree that they are here (`02_DOMAIN.md §4`).
  final bool attestedPresent;

  /// What they said they would bring, when the activity needs equipment.
  final String? bringingEquipment;
}

/// Where the group meets.
@immutable
final class MeetingPoint {
  /// Describes a meeting point.
  const MeetingPoint({
    required this.name,
    required this.street,
    required this.location,
    required this.standingSpot,
    this.chips = const [],
    this.walkMinutes,
    this.openNow = true,
  });

  /// The venue's name. Rendered in the serif — it is a place, and places get
  /// the human register.
  final String name;

  /// One line of address. Enough to type into any other map app.
  final String street;

  /// Where it is.
  final GeoPoint location;

  /// The exact spot to stand, in one sentence.
  ///
  /// **This is the most valuable string on the reveal screen.** "Outside, at
  /// the tables facing the cathedral" converts a café with three entrances into
  /// one place. `06_ACTIVITIES.md §4` calls it the first-arriver job and puts
  /// it on the platform rather than in an activity, because every activity
  /// needs it.
  final String standingSpot;

  /// Short facts: `outdoor`, `step-free`, `quiet`.
  final List<String> chips;

  /// How long the viewer's own walk is. Theirs alone — computed from their own
  /// anchor, never shown for anybody else.
  final int? walkMinutes;

  /// Whether it is open at the slot time, for venues that have hours.
  final bool openNow;
}

/// The group's mark.
@immutable
final class SigilMark {
  /// Describes a sigil.
  const SigilMark({
    required this.symbol,
    required this.colour,
    required this.label,
  });

  /// Catalogue code, e.g. `circle`.
  final String symbol;

  /// Catalogue code, e.g. `red`.
  final String colour;

  /// The sayable name, declined by the server (`0007_v3_sigils.sql`).
  final String label;
}

/// A hangout, in whatever detail this phase permits.
///
/// **The shape/identity split is enforced here by nullability.** Before
/// `revealed`, `members` is empty and `meetingPoint` and `sigil` are null — not
/// because the app hides them, but because `hangout_reveal` refuses to return
/// them (invariant 2). A client patched to render them would render nulls.
@immutable
final class Hangout {
  /// Describes a hangout.
  const Hangout({
    required this.id,
    required this.phase,
    required this.startsAt,
    required this.endsAt,
    required this.localDay,
    required this.localTime,
    required this.memberCount,
    required this.activity,
    this.members = const [],
    this.meetingPoint,
    this.sigil,
    this.yourConfirmation,
    this.confirmDeadline,
    this.revealAt,
    this.youArrived = false,
    this.ratingsDueAt,
    this.cancelledBecause,
  });

  /// The hangout's id.
  final String id;

  /// Where it is in its life.
  final HangoutPhase phase;

  /// When it starts, in UTC.
  final DateTime startsAt;

  /// When it ends, in UTC.
  final DateTime endsAt;

  /// A rendered local day, e.g. `Thursday 23 October`. Rendered by the server
  /// so the city's timezone decides, not the phone's.
  final String localDay;

  /// A rendered local start time, e.g. `17:30`.
  final String localTime;

  /// How many people. Available before names are (invariant 2).
  final int memberCount;

  /// Which activity template.
  final ActivityBrief activity;

  /// The others, once revealed.
  final List<Member> members;

  /// Where, once locked.
  final MeetingPoint? meetingPoint;

  /// The mark, once locked.
  final SigilMark? sigil;

  /// The viewer's own answer, once they have given one.
  final bool? yourConfirmation;

  /// When the answer stops being useful.
  final DateTime? confirmDeadline;

  /// When the place and names arrive.
  final DateTime? revealAt;

  /// Whether the viewer has tapped arrived.
  final bool youArrived;

  /// When the ratings are due.
  final DateTime? ratingsDueAt;

  /// Why it will not happen, in a sentence the server wrote.
  ///
  /// **Never "two people declined".** Invariant 5: a decline is invisible, and
  /// a cancellation reason that counts declines is a decline made visible with
  /// extra steps.
  final String? cancelledBecause;
}

/// What an activity is, on the screens that describe it.
@immutable
final class ActivityBrief {
  /// Describes an activity.
  const ActivityBrief({
    required this.id,
    required this.name,
    required this.summary,
    required this.howItEnds,
    this.equipment,
    this.needsCarriers = 0,
  });

  /// Registry id, e.g. `CONVERSATION_DECK`.
  final String id;

  /// What to call it.
  final String name;

  /// What happens, in a sentence.
  final String summary;

  /// **How it ends.** `06_ACTIVITIES.md §1`: every activity must supply an exit
  /// script, because the most expensive ambiguity in a social meeting is *"is
  /// it over?"*. It is stated up front, at confirmation, not discovered at the
  /// end.
  final String howItEnds;

  /// What somebody has to bring, if anything.
  final String? equipment;

  /// How many people must bring it.
  final int needsCarriers;
}

/// One card in an activity session.
@immutable
final class ActivityCard {
  /// Describes a card.
  const ActivityCard({
    required this.index,
    required this.total,
    required this.text,
    required this.note,
  });

  /// Zero-based position.
  final int index;

  /// How many cards there are. Shown, because an unknown remaining count is its
  /// own small anxiety.
  final int total;

  /// The question or instruction.
  final String text;

  /// A line under it — what set it belongs to, or how to play it.
  final String note;
}

/// Registry entry for a gender (D6).
@immutable
final class GenderOption {
  /// Describes a gender option.
  const GenderOption({required this.code, required this.label});

  /// Registry code. The composition rule never names one of these.
  final String code;

  /// What to show.
  final String label;
}

/// A city open to signup.
@immutable
final class CityBrief {
  /// Describes a city.
  const CityBrief({required this.id, required this.name, required this.centre});

  /// The city's id.
  final CityId id;

  /// Its name.
  final String name;

  /// Where to open the anchor map.
  final GeoPoint centre;
}

/// One slot a person can answer.
@immutable
final class SlotOption {
  /// Describes a slot.
  const SlotOption({
    required this.id,
    required this.startsAt,
    required this.localDate,
    required this.localWeekday,
    required this.localTime,
    required this.chosen,
    this.density = 0,
  });

  /// The slot's id.
  final SlotId id;

  /// When it starts, in UTC.
  final DateTime startsAt;

  /// `yyyy-mm-dd` in the city.
  final String localDate;

  /// ISO weekday, 1 = Monday.
  final int localWeekday;

  /// Local start, e.g. `17:30`.
  final String localTime;

  /// Whether the person has said yes.
  final bool chosen;

  /// How likely a hangout is here, `0…1`, as a coarse bucket.
  ///
  /// `05_PLACES.md §7` is explicit that this is never a raw count: a count is
  /// gameable and it publishes how thin the network is.
  final double density;

  /// A copy with [chosen] flipped.
  SlotOption toggled() => SlotOption(
    id: id,
    startsAt: startsAt,
    localDate: localDate,
    localWeekday: localWeekday,
    localTime: localTime,
    chosen: !chosen,
    density: density,
  );
}

/// The viewer's own row.
@immutable
final class MemberProfile {
  /// Describes a profile.
  const MemberProfile({
    required this.id,
    required this.name,
    required this.gender,
    required this.cityId,
    required this.cityName,
    required this.hasAnchor,
    required this.completedHangouts,
    required this.datingUnlocked,
    this.anchor,
    this.equipment = const [],
  });

  /// The person's id.
  final PersonId id;

  /// Their name, masked for display.
  final DisplayName name;

  /// Registry code.
  final String gender;

  /// Which city.
  final CityId cityId;

  /// Its name.
  final String cityName;

  /// Whether they gave us a starting point.
  final bool hasAnchor;

  /// Their own anchor, snapped. Only ever their own.
  final GeoPoint? anchor;

  /// How many hangouts they have completed. Used for the dating unlock, and it
  /// is the *only* count about a person the app ever sees — a deliberate
  /// exception to "no numbers about people", because it is the one number that
  /// is about what they did rather than about what anyone thought of them.
  final int completedHangouts;

  /// Whether the dating tab is available (`07_DATING.md §4`).
  final bool datingUnlocked;

  /// What they can bring: `deck_of_cards`.
  final List<String> equipment;
}

/// An active sanction, in the person's own words rather than the system's.
@immutable
final class SanctionNotice {
  /// Describes a sanction.
  const SanctionNotice({
    required this.reason,
    required this.until,
    required this.appealable,
  });

  /// Why, written by the server. Never a score, never a threshold.
  final String reason;

  /// When it lifts. `null` means it does not.
  final DateTime? until;

  /// Whether an appeal is open.
  ///
  /// Always true for anything automatic: GDPR Art. 22 constrains automated
  /// decisions with significant effects, and `01_ARCHITECTURE.md §11` requires
  /// a human-reachable path for exactly this reason.
  final bool appealable;
}

/// How much somebody enjoyed a person's company.
///
/// The four levels are the transcript's, in its order. `enjoyed` and
/// `reallyEnjoyed` weigh **identically** for friend matching — see
/// `02_DOMAIN.md §5` for why that is what buys a clean dating signal.
enum Enjoyment {
  /// Feeds friend matching *and* is the dating signal.
  reallyEnjoyed,

  /// Feeds friend matching.
  enjoyed,

  /// Nothing is recorded.
  noPreference,

  /// A permanent exclusion for the pair, in both directions.
  ratherNot,
}

/// One person's answers about one other person.
@immutable
final class RatingAnswer {
  /// Describes an answer.
  const RatingAnswer({
    required this.subjectId,
    required this.enjoyment,
    required this.respectful,
    required this.dwellMs,
  });

  /// Who it is about, by their per-hangout handle.
  final String subjectId;

  /// How it went.
  final Enjoyment enjoyment;

  /// Whether they were respectful.
  final bool respectful;

  /// How long the rater spent on this person.
  ///
  /// Sent so the server can enforce the two-second floor and detect
  /// straight-lining (`04_TRUST.md §8`). **The client does not enforce it** —
  /// it renders the delay, the server decides. A dwell check in the app is a
  /// check a patched app skips.
  final int dwellMs;
}

/// How the meeting point worked out.
///
/// Two questions, both from `05_PLACES.md §3`. They are what makes the venue
/// catalogue self-improving (D11) — and they are data nobody else has, because
/// no star rating anywhere measures "four strangers converging at 17:30".
@immutable
final class VenueVerdict {
  /// Describes venue feedback.
  const VenueVerdict({required this.easyToFind, required this.goodToMeet});

  /// Could people find it.
  final bool easyToFind;

  /// Did it feel like a good place to meet.
  final bool goodToMeet;
}
