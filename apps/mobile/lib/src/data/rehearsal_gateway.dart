import 'package:ekipa_core/ekipa_core.dart';
import 'package:mobile/src/data/member_gateway.dart';
import 'package:mobile/src/data/records.dart';

/// Which part of the loop to rehearse.
///
/// The hangout lifecycle spends most of its time in states nobody can reach on
/// demand — you cannot be in `CONFIRMING` on a Tuesday afternoon just because
/// you want to look at the screen. So the phase is an input.
enum Rehearsal {
  /// Verified, nothing filled in.
  fresh,

  /// Active, no hangout yet.
  waiting,

  /// A hangout exists; the morning-of question has not been asked.
  proposed,

  /// The morning-of question, unanswered.
  confirming,

  /// Everyone said yes; the place is not out yet.
  locked,

  /// Somebody dropped out and the repair is running.
  backfilling,

  /// Place, sigil and names are out.
  revealed,

  /// It is happening. Nobody has tapped arrived.
  arriving,

  /// Everyone is there; the activity is running.
  playing,

  /// It is over; the ratings are due.
  rating,

  /// Suspended.
  suspended,
}

/// An in-memory server, for building and looking at screens.
///
/// **Intention — every screen in this app can be reached, in every state, with
/// no network and no database.** That is not a convenience. The states that
/// matter most here are the ones that are hardest to reach in real life: the
/// morning-of confirmation, the repair pass, the fifteen minutes when one
/// person has not shown up. A build where those can only be seen by waiting for
/// a Thursday is a build where they are designed once and never looked at
/// again.
///
/// **What it is not.** It is not a fake of the server's *rules*. It answers
/// plausibly; it does not enforce a phase machine, a deadline, or a privacy
/// invariant, and nothing in the app may come to depend on it doing so. Every
/// one of those lives in Postgres, and the app's job is to render the answer.
///
/// **It does not run the matchmaker, and it cannot.** `apps/mobile` may never
/// import `package:ekipa_core/matching.dart` (D9, SC-6, enforced by
/// `tools/lint`). So the hangouts below are *fabricated*, not matched — which
/// is exactly right: a client that could produce a plausible group is a client
/// that knows how groups are produced.
final class RehearsalGateway implements MemberGateway {
  /// Creates a rehearsal server at [_clock], in [_stage].
  RehearsalGateway(this._clock, [this._stage = Rehearsal.waiting]);

  final Clock _clock;
  final Rehearsal _stage;

  static const CityId _osijek = CityId('c0000000-0000-4000-8000-000000000001');

  MemberProfile? _profile;
  Set<SlotId> _chosen = {};
  final Map<String, bool> _confirmed = {};
  final Set<String> _arrived = {};
  final Set<String> _rated = {};
  List<SlotOption>? _week;

  // ── Who is asking ──────────────────────────────────────────────────────────

  @override
  Future<MemberState> state() async => switch (_stage) {
    Rehearsal.fresh =>
      _profile == null ? MemberState.incomplete : MemberState.active,
    Rehearsal.suspended => MemberState.suspended,
    _ => MemberState.active,
  };

  @override
  Future<SanctionNotice?> sanction() async => _stage != Rehearsal.suspended
      ? null
      : SanctionNotice(
          reason:
              'You did not answer the confirmation for two hangouts in a row. '
              'Three people waited for an answer that never came, and one of '
              'those evenings was cancelled because of it.\n\n'
              'Saying no is nearly free — it costs almost nothing and it lets '
              'us find somebody else. Silence is what this is for.',
          until: _clock.nowUtc().add(const Duration(days: 5)),
          appealable: true,
        );

  @override
  Future<MemberProfile?> profile() async =>
      _profile ??
      (_stage == Rehearsal.fresh
          ? null
          : MemberProfile(
              id: const PersonId('p0000000-0000-4000-8000-000000000001'),
              name: DisplayName.create(
                firstName: 'Ana',
                lastInitial: 'K',
              ).valueOrNull!,
              gender: 'woman',
              cityId: _osijek,
              cityName: 'Osijek',
              hasAnchor: true,
              anchor: const GeoPoint(latitude: 45.5585, longitude: 18.6890),
              completedHangouts: switch (_stage) {
                Rehearsal.waiting => 2,
                Rehearsal.rating => 5,
                _ => 3,
              },
              datingUnlocked: _stage == Rehearsal.rating,
              equipment: const ['deck_of_cards'],
            ));

  // ── Catalogues ─────────────────────────────────────────────────────────────

  @override
  Future<List<GenderOption>> genders() async => const [
    GenderOption(code: 'woman', label: 'Woman'),
    GenderOption(code: 'man', label: 'Man'),
    GenderOption(code: 'other', label: 'Something else'),
  ];

  @override
  Future<List<CityBrief>> cities() async => const [
    CityBrief(
      id: _osijek,
      name: 'Osijek',
      centre: GeoPoint(latitude: 45.5550, longitude: 18.6955),
    ),
  ];

  // ── Signup ─────────────────────────────────────────────────────────────────

  @override
  Future<void> createProfile({
    required String firstName,
    required String lastInitial,
    required String genderCode,
    required double anchorLatitude,
    required double anchorLongitude,
    List<String> equipment = const [],
  }) async {
    final name = DisplayName.create(
      firstName: firstName,
      lastInitial: lastInitial,
    );
    if (name case Err(:final error)) {
      throw MemberFailure('22023', switch (error) {
        DisplayNameError.emptyFirstName => 'A first name is required.',
        DisplayNameError.invalidLastInitial =>
          'The last initial is exactly one letter.',
      });
    }
    _profile = MemberProfile(
      id: const PersonId('p0000000-0000-4000-8000-000000000001'),
      name: name.valueOrNull!,
      gender: genderCode,
      cityId: _osijek,
      cityName: 'Osijek',
      hasAnchor: true,
      anchor: GeoPoint(latitude: anchorLatitude, longitude: anchorLongitude),
      completedHangouts: 0,
      datingUnlocked: false,
      equipment: equipment,
    );
  }

  // ── The week ───────────────────────────────────────────────────────────────

  @override
  Future<List<SlotOption>> slots() async {
    // Built from the real schedule rather than three hand-written rows, so the
    // calendar is designed against what a month actually looks like — nine
    // slots a week, not three.
    final week = _week ??= _materialise();

    // Somebody who has a hangout tonight said yes to evenings at some point,
    // and a rehearsal that starts everyone at zero draws the home screen as it
    // looks for nobody: one card and a page of nothing under it. Seeding the
    // next few is not decoration — it is the difference between reviewing the
    // screen a person sees and reviewing an empty state that only exists for
    // the first ten minutes of an account.
    if (_chosen.isEmpty && _stage != Rehearsal.fresh) {
      _chosen = {for (final slot in week.take(7)) slot.id};
    }

    return [
      for (final slot in week)
        SlotOption(
          id: slot.id,
          startsAt: slot.startsAt,
          localDate: slot.localDate,
          localWeekday: slot.localWeekday,
          localTime: slot.localTime,
          chosen: _chosen.contains(slot.id),
          density: slot.density,
        ),
    ];
  }

  List<SlotOption> _materialise() {
    final schedule = SlotSchedule.fromSnapshot(ConfigSnapshot.defaults());
    if (schedule case Err()) return const [];
    final now = _clock.nowUtc();
    final local = schedule.valueOrNull!.materialise(from: now, weeks: 6);
    return [
      for (final slot in local)
        SlotOption(
          id: SlotId(
            's${slot.sqlDate}-${slot.startsAt}'
                .padRight(36, '0')
                .substring(
                  0,
                  36,
                ),
          ),
          startsAt: DateTime.utc(
            slot.year,
            slot.month,
            slot.day,
            slot.startsAt.hour - 2,
            slot.startsAt.minute,
          ),
          localDate: slot.sqlDate,
          localWeekday: slot.weekday,
          localTime: '${slot.startsAt}',
          chosen: false,
          // A coarse bucket, as `05_PLACES.md §7` requires. Friday evenings and
          // the 17:30 slot are the busy ones, which is also what the simulator
          // produced.
          density: switch ((slot.weekday, slot.startsAt.hour)) {
            (5, 17) => 0.95,
            (5, _) => 0.7,
            (6, 17) => 0.8,
            (_, 17) => 0.6,
            (_, 19) => 0.45,
            _ => 0.3,
          },
        ),
    ];
  }

  @override
  Future<void> setAvailability(Set<SlotId> slotIds) async {
    _chosen = {...slotIds};
  }

  @override
  Future<void> repeatLastWeek() async {
    final week = _week ??= _materialise();
    _chosen = {
      for (final slot in week.take(9))
        if (slot.localWeekday != 6) slot.id,
    };
  }

  // ── The hangouts ───────────────────────────────────────────────────────────

  @override
  Future<List<Hangout>> hangouts() async {
    final phase = switch (_stage) {
      Rehearsal.fresh || Rehearsal.waiting || Rehearsal.suspended => null,
      Rehearsal.proposed => HangoutPhase.proposed,
      Rehearsal.confirming => HangoutPhase.confirming,
      Rehearsal.locked => HangoutPhase.locked,
      Rehearsal.backfilling => HangoutPhase.backfilling,
      Rehearsal.revealed => HangoutPhase.revealed,
      Rehearsal.arriving || Rehearsal.playing => HangoutPhase.live,
      Rehearsal.rating => HangoutPhase.rating,
    };
    if (phase == null) return const [];
    return [_build(phase)];
  }

  static const String _id = 'h0000000-0000-4000-8000-000000000001';

  Hangout _build(HangoutPhase phase) {
    final now = _clock.nowUtc();
    final start = switch (phase) {
      HangoutPhase.proposed => now.add(const Duration(days: 2, hours: 6)),
      HangoutPhase.confirming ||
      HangoutPhase.backfilling => now.add(const Duration(hours: 8)),
      HangoutPhase.locked => now.add(const Duration(hours: 6)),
      HangoutPhase.revealed => now.add(const Duration(minutes: 48)),
      HangoutPhase.live => now.subtract(const Duration(minutes: 6)),
      _ => now.subtract(const Duration(hours: 2)),
    };
    final revealed =
        phase.index >= HangoutPhase.revealed.index &&
        phase != HangoutPhase.cancelled;

    return Hangout(
      id: _id,
      phase: phase,
      startsAt: start,
      endsAt: start.add(const Duration(minutes: 90)),
      localDay: _day(start),
      localTime: '17:30',
      memberCount: phase == HangoutPhase.backfilling ? 3 : 4,
      activity: _activity,
      members: revealed ? _members() : const [],
      meetingPoint:
          phase.index >= HangoutPhase.locked.index &&
              phase != HangoutPhase.backfilling
          ? _meetingPoint
          : null,
      sigil: revealed ? _sigil : null,
      yourConfirmation: _confirmed[_id],
      confirmDeadline:
          phase == HangoutPhase.confirming || phase == HangoutPhase.backfilling
          ? DateTime.utc(now.year, now.month, now.day, 10)
          : null,
      revealAt: start.subtract(const Duration(minutes: 60)),
      youArrived: _arrived.contains(_id) || _stage == Rehearsal.playing,
      ratingsDueAt: phase == HangoutPhase.rating
          ? start.add(const Duration(hours: 24))
          : null,
    );
  }

  static const ActivityBrief _activity = ActivityBrief(
    id: 'CONVERSATION_DECK',
    name: 'Questions',
    summary:
        'A deck of questions that get slowly more personal. One card at a '
        'time, everyone answers in turn. Anyone can pass on any card.',
    howItEnds:
        'When the last card is done, that is the end. Say “that was the deck '
        '— good to meet you” and go.',
  );

  static const MeetingPoint _meetingPoint = MeetingPoint(
    name: 'Kavana Waldinger',
    street: 'Županijska 8',
    location: GeoPoint(latitude: 45.5602, longitude: 18.6788),
    standingSpot:
        'Outside, at the tables on the left as you face the door. If it is '
        'raining, just inside, first room on the right.',
    chips: ['outdoor seating', 'step-free', 'open until 23:00'],
    walkMinutes: 11,
  );

  static const SigilMark _sigil = SigilMark(
    symbol: 'key',
    colour: 'orange',
    label: 'narančasti ključ',
  );

  List<Member> _members() {
    final playing = _stage == Rehearsal.playing;
    return [
      Member(
        id: 'm1',
        name: DisplayName.create(
          firstName: 'Ana',
          lastInitial: 'K',
        ).valueOrNull!,
        isYou: true,
        arrived: _arrived.contains(_id) || playing,
        attestedPresent: playing,
      ),
      Member(
        id: 'm2',
        name: DisplayName.create(
          firstName: 'Bruno',
          lastInitial: 'M',
        ).valueOrNull!,
        isYou: false,
        arrived: playing,
        attestedPresent: playing,
      ),
      Member(
        id: 'm3',
        name: DisplayName.create(
          firstName: 'Cvita',
          lastInitial: 'P',
        ).valueOrNull!,
        isYou: false,
        arrived: true,
        attestedPresent: true,
      ),
      Member(
        id: 'm4',
        name: DisplayName.create(
          firstName: 'Dario',
          lastInitial: 'S',
        ).valueOrNull!,
        isYou: false,
        arrived: playing,
        attestedPresent: playing,
      ),
    ];
  }

  @override
  Future<Hangout> confirm({
    required String hangoutId,
    required bool coming,
  }) async {
    _confirmed[hangoutId] = coming;
    return _build(coming ? HangoutPhase.locked : HangoutPhase.cancelled);
  }

  @override
  Future<Hangout> markArrived(String hangoutId) async {
    _arrived.add(hangoutId);
    return _build(HangoutPhase.live);
  }

  @override
  Future<Hangout> attest({
    required String hangoutId,
    required String memberId,
    required bool present,
  }) async => _build(HangoutPhase.live);

  @override
  Future<List<ActivityCard>> activityCards(String hangoutId) async {
    const template = ConversationDeck();
    final steps = template.session(
      SeededRandomSource.fromString(hangoutId),
      people: 4,
    );
    return [
      for (final (index, step) in steps.indexed)
        ActivityCard(
          index: index,
          total: steps.length,
          text: step.text,
          note: step.note,
        ),
    ];
  }

  @override
  Future<void> setBringing({
    required String hangoutId,
    required bool bringing,
  }) async {}

  // ── After ──────────────────────────────────────────────────────────────────

  @override
  Future<void> submitRatings({
    required String hangoutId,
    required List<RatingAnswer> answers,
    required VenueVerdict venue,
  }) async {
    _rated.add(hangoutId);
  }

  @override
  Future<void> report({
    required String hangoutId,
    required String memberId,
    required String category,
    String? note,
  }) async {}

  @override
  Future<void> reportVenue({
    required String hangoutId,
    required String reason,
  }) async {}

  static const List<String> _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  String _day(DateTime instant) =>
      '${_weekdays[instant.weekday - 1]} ${instant.day} '
      '${_months[instant.month - 1]}';
}
