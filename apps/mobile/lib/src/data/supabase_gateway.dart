/// The [MemberGateway] backed by the real project.
///
/// **Intention — everything private is an `rpc` call.** There is no
/// `.from('people').select()` in this file and there cannot be one that works:
/// `people`, `hangouts`, `ratings` and `infractions` are closed to
/// `authenticated` by policy, so a table read of any of them is refused by
/// Postgres rather than by review. Migrations `0006`, `0011` and `0014` define
/// the whole callable surface, and this class is the adapter for that shape.
///
/// **Two reads are direct, and both are catalogues.** `genders` and `cities`
/// are reference data every client needs and nobody owns, and `0001` wrote
/// `genders_read` and `cities_read` for exactly this. Wrapping them in
/// pass-through RPCs would add a function whose only body is the `select` the
/// policy already constrains.
///
/// **`sanctions` is not one of them, and the reason is instructive.** It has a
/// policy that would have let this class read it, and reading it would have
/// been wrong anyway: the row holds a `reason_code` and a `ladder_step`, and
/// the screen needs a sentence and an appeal button. Turning one into the
/// other is a trust decision, so it lives in `my_sanction` (`0015`), where the
/// server can also refuse on it.
///
/// **Nothing here decides anything.** `dating_unlocked` is read, not computed;
/// `names_visible` is read, not compared against a clock; a hangout's phase is
/// the server's word for it. `11_SECURITY.md` rule 6 says a privacy or trust
/// decision may never live in the client, and the only way to keep that true is
/// for the client to have no rule to get wrong. Where this file does compute
/// something — the walk chips, the local day, the activity cards — it is
/// presentation over data the server already released.
///
/// **The one credential it holds is the session the person signed in with.**
/// The service-role key is not read here, not passed in, and not present in any
/// build this file compiles into.
library;

// **`hide Enjoyment` is load-bearing, not tidying.** `ekipa_core` exports an
// `Enjoyment` that the matcher reads to weight an edge; `records.dart` defines
// one that is the four buttons on the rating screen. They share a name, they do
// not share a type, and the one this file must serialise is the screen's.
// Importing both unhidden makes every mention ambiguous, and resolving it by
// picking whichever happened to win would eventually send the matcher's
// spelling to a column expecting the screen's.
import 'package:ekipa_core/ekipa_core.dart' hide Enjoyment;
import 'package:mobile/src/data/member_gateway.dart';
import 'package:mobile/src/data/records.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Talks to the hosted project on behalf of one signed-in person.
final class SupabaseGateway implements MemberGateway {
  /// Wraps a Supabase client.
  const SupabaseGateway(this._client);

  final SupabaseClient _client;

  // ── Transport ──────────────────────────────────────────────────────────────

  /// Calls [function], turning any refusal into a [MemberFailure].
  ///
  /// Every server error arrives here and leaves as one type, so no screen has
  /// to know the transport is PostgREST — and, more importantly, so no screen
  /// can accidentally treat a refusal as an empty result. A `42501` that came
  /// back as `[]` would render as "you have no hangouts" to somebody who has
  /// been suspended, which is a lie the app told itself.
  Future<T> _call<T>(
    String function,
    Map<String, Object?> params,
    T Function(Object? data) parse,
  ) async {
    try {
      return parse(await _client.rpc<Object?>(function, params: params));
    } on PostgrestException catch (error) {
      throw MemberFailure(error.code ?? 'unknown', error.message);
    } on AuthException catch (error) {
      throw MemberFailure(error.statusCode ?? 'auth', error.message);
    }
  }

  /// Reads a catalogue table straight, through its own policy.
  ///
  /// **Only for tables whose policy is the whole rule.** `genders_read` is
  /// `true` and `cities_read` is `active`; there is nothing for a client to get
  /// wrong, and nothing a `where` clause here could add that the policy has not
  /// already decided. Every table that holds a person — theirs or anybody
  /// else's — goes through an RPC instead, and is closed to this role anyway.
  Future<T> _read<T>(
    String table,
    T Function(List<Map<String, Object?>> rows) parse, {
    String? order,
    int? limit,
  }) async {
    try {
      // The builder narrows as it chains — `.order()` returns a transform
      // builder that cannot be assigned back over the filter builder it came
      // from — so the chain is built in one expression rather than accumulated
      // in a variable.
      final rows = await switch ((order, limit)) {
        (final String by, final int n) =>
          _client.from(table).select().order(by, ascending: true).limit(n),
        (final String by, null) =>
          _client.from(table).select().order(by, ascending: true),
        (null, final int n) => _client.from(table).select().limit(n),
        _ => _client.from(table).select(),
      };
      return parse(_rows(rows));
    } on PostgrestException catch (error) {
      throw MemberFailure(error.code ?? 'unknown', error.message);
    }
  }

  /// A person's name, or a legible placeholder.
  ///
  /// [DisplayName] refuses an empty first name or a multi-character initial,
  /// and it is right to: the masked form is a privacy guarantee and a malformed
  /// one could unmask. But a single corrupt row must not take the screen down
  /// with it, so the failure renders as a name-shaped absence rather than
  /// throwing on a list somebody is halfway through reading.
  static DisplayName _name(Object? first, Object? initial) =>
      DisplayName.create(
        firstName: first is String ? first : '',
        lastInitial: initial is String ? initial : '',
      ).valueOrNull ??
      _unknown;

  static final DisplayName _unknown = DisplayName.create(
    firstName: 'Someone',
    lastInitial: '?',
  ).valueOrNull!;

  /// The storage code for an [Enjoyment].
  ///
  /// Written out rather than derived from `.name`, because Dart's `.name` is
  /// `reallyEnjoyed` and the Postgres enum's label is `really_enjoyed`. A
  /// mechanical conversion would work today and break silently the first time
  /// somebody adds a value whose two spellings do not correspond — and the
  /// breakage would be an invalid cast at rating time, on the one screen a
  /// person is required to finish.
  static String _enjoyment(Enjoyment value) => switch (value) {
    Enjoyment.reallyEnjoyed => 'really_enjoyed',
    Enjoyment.enjoyed => 'enjoyed',
    Enjoyment.noPreference => 'no_preference',
    Enjoyment.ratherNot => 'rather_not',
  };

  /// A PostGIS `geography` as PostgREST hands it back: GeoJSON, `[lon, lat]`.
  ///
  /// The order is the trap. GeoJSON is longitude first and every other
  /// coordinate in this codebase is latitude first, so reading it positionally
  /// without saying so is how a city ends up in the Indian Ocean.
  static GeoPoint _point(Object? raw) {
    if (raw is Map && raw['coordinates'] is List) {
      final pair = raw['coordinates']! as List<Object?>;
      if (pair.length >= 2) {
        return GeoPoint(
          latitude: _double(pair[1]),
          longitude: _double(pair[0]),
        );
      }
    }
    return const GeoPoint(latitude: 0, longitude: 0);
  }

  /// The rows of a `returns table (...)` result.
  static List<Map<String, Object?>> _rows(Object? data) => switch (data) {
    final List<Object?> list => [
      for (final row in list)
        if (row is Map) Map<String, Object?>.from(row),
    ],
    _ => const [],
  };

  /// The single row of a `returns table (...)` that returns at most one.
  static Map<String, Object?>? _row(Object? data) {
    final rows = _rows(data);
    return rows.isEmpty ? null : rows.first;
  }

  static DateTime? _at(Object? raw) =>
      raw is String ? DateTime.parse(raw).toUtc() : null;

  static DateTime _atOr(Object? raw, DateTime fallback) => _at(raw) ?? fallback;

  static int _int(Object? raw) => switch (raw) {
    final int value => value,
    final num value => value.round(),
    final String value => int.tryParse(value) ?? 0,
    _ => 0,
  };

  static double _double(Object? raw) => switch (raw) {
    final double value => value,
    final num value => value.toDouble(),
    final String value => double.tryParse(value) ?? 0,
    _ => 0,
  };

  static List<String> _strings(Object? raw) => switch (raw) {
    final List<Object?> list => [
      for (final item in list)
        if (item != null) '$item',
    ],
    _ => const [],
  };

  // ── Who is asking ──────────────────────────────────────────────────────────

  @override
  Future<MemberState> state() => _call('my_state', const {}, (data) {
    // The server answers in one word and the client does not second-guess it.
    // Deriving this from, say, "has a sanction row" would put the suspension
    // rule in two places, and the copy of it here would be the one that drifts.
    return switch (data) {
      'active' => MemberState.active,
      'suspended' => MemberState.suspended,
      'banned' => MemberState.banned,
      _ => MemberState.incomplete,
    };
  });

  @override
  Future<SanctionNotice?> sanction() => _call('my_sanction', const {}, (data) {
    // No row means either nothing against this person, or a sanction the
    // automation is deliberately not announcing yet. The app cannot tell those
    // apart, which is the intended outcome rather than a gap: an app that could
    // would be a way of finding out you are being watched.
    final row = _row(data);
    if (row == null) return null;
    return SanctionNotice(
      // The server's own sentence. It is the one string here a person will
      // read twice and remember, and a client-side rewrite would eventually
      // explain a sanction the client did not understand.
      reason: (row['reason'] as String?) ?? '',
      until: _at(row['until']),
      // Decided in SQL, because the appeal endpoint refuses on the same rule.
      // A button the server will turn away is worse than no button.
      appealable: (row['appealable'] as bool?) ?? false,
    );
  });

  @override
  Future<MemberProfile?> profile() => _call('my_profile', const {}, (data) {
    final row = _row(data);
    if (row == null) return null;
    return MemberProfile(
      id: PersonId(row['person_id']! as String),
      name: _name(row['first_name'], row['last_initial']),
      gender: (row['gender_code'] as String?) ?? '',
      cityId: CityId(row['city_id']! as String),
      cityName: (row['city_name'] as String?) ?? '',
      hasAnchor: (row['has_anchor'] as bool?) ?? false,
      anchor: row['anchor_lat'] == null
          ? null
          : GeoPoint(
              latitude: _double(row['anchor_lat']),
              longitude: _double(row['anchor_lon']),
            ),
      completedHangouts: _int(row['completed_hangouts']),
      // Read, never computed. `0014` decides this in SQL precisely so that a
      // patched client showing the dating tab still meets a server that
      // refuses (rule 6).
      datingUnlocked: (row['dating_unlocked'] as bool?) ?? false,
      equipment: _strings(row['equipment']),
    );
  });

  // ── Catalogues ─────────────────────────────────────────────────────────────

  @override
  Future<List<GenderOption>> genders() => _read(
    'genders',
    (rows) => [
      for (final row in rows)
        GenderOption(
          code: row['code']! as String,
          // A registry, not an enum (D6): adding an option is a row, and this
          // client renders whatever the row says without knowing the list.
          label: (row['label_en'] as String?) ?? row['code']! as String,
        ),
    ],
    order: 'sort_order',
  );

  @override
  Future<List<CityBrief>> cities() => _read(
    'cities',
    (rows) => [
      for (final row in rows)
        CityBrief(
          id: CityId(row['id']! as String),
          name: (row['name'] as String?) ?? '',
          // The centroid is a `geography` and PostgREST hands it back as
          // GeoJSON. It is the city's own centre, not anybody's anchor — the
          // only geography in this product that is safe to read in bulk.
          centre: _point(row['centroid']),
        ),
    ],
    // `cities_read`'s qual is `active`, so a city that has a map but has not
    // opened is simply not here. The signup screen therefore cannot offer one,
    // and would be refused by `create_profile` if it did.
    order: 'name',
  );

  // ── Signup ─────────────────────────────────────────────────────────────────

  @override
  Future<void> createProfile({
    required String firstName,
    required String lastInitial,
    required String genderCode,
    required double anchorLatitude,
    required double anchorLongitude,
    List<String> equipment = const [],
  }) => _call('create_profile', {
    'p_first_name': firstName,
    'p_last_initial': lastInitial,
    'p_gender_code': genderCode,
    // Sent at full precision and snapped by the server to a ~500 m grid before
    // it is stored. Snapping here instead would be a privacy guarantee made by
    // the party it protects against — and the exact anchor would still have
    // been on the wire (`05_PLACES.md §2`).
    'p_latitude': anchorLatitude,
    'p_longitude': anchorLongitude,
    'p_equipment': equipment,
    // No city. `people.city_id` is derived from the anchor, because a
    // client-settable city is a way to relocate into a denser market on the
    // morning of a run.
  }, (_) {});

  // ── The week ───────────────────────────────────────────────────────────────

  @override
  Future<List<SlotOption>> slots() => _call('my_slots', const {}, (data) {
    return [
      for (final row in _rows(data))
        SlotOption(
          id: SlotId(row['slot_id']! as String),
          startsAt: _atOr(row['starts_at'], DateTime.now().toUtc()),
          localDate: (row['local_date'] as String?) ?? '',
          localWeekday: _int(row['local_weekday']),
          // A Postgres `time` arrives as `17:30:00`. The seconds are always
          // zero — slots are on the half hour — and a screen that prints them
          // looks like a stopwatch rather than a plan.
          localTime: _hhmm(row['local_time']),
          chosen: (row['chosen'] as bool?) ?? false,
          // A coarse bucket, chosen server-side out of five. Never a headcount:
          // a count is gameable and it publishes how thin the network is.
          density: _double(row['density']),
        ),
    ];
  });

  @override
  Future<void> setAvailability(Set<SlotId> slotIds) => _call(
    'set_availability',
    {
      'p_slot_ids': [for (final id in slotIds) id.value],
    },
    (_) {},
  );

  @override
  Future<void> repeatLastWeek() => _call('repeat_last_week', const {}, (_) {});

  // ── The hangouts ───────────────────────────────────────────────────────────

  @override
  Future<List<Hangout>> hangouts() async {
    final rows = await _call('my_hangouts', const {}, _rows);
    return [
      for (final row in rows)
        // The reveal is a second call, and only for the hangouts that have
        // actually revealed. Folding it into `my_hangouts` would mean the list
        // endpoint returned names — and then the privacy boundary would depend
        // on a `where` clause in a query somebody could later widen, instead of
        // on a separate function with its own time check (invariant 2).
        await _hangout(
          row,
          reveal: (row['names_visible'] as bool?) ?? false
              ? await _call(
                  'hangout_reveal',
                  {'p_hangout_id': row['hangout_id']},
                  _rows,
                )
              : const [],
        ),
    ];
  }

  @override
  Future<Hangout> confirm({
    required String hangoutId,
    required bool coming,
  }) async {
    await _call('confirm_hangout', {
      'p_hangout_id': hangoutId,
      'p_coming': coming,
    }, (_) {});
    return _reread(hangoutId);
  }

  @override
  Future<Hangout> markArrived(String hangoutId) async {
    await _call('mark_arrived', {
      'p_hangout_id': hangoutId,
      // **Always true, and the server does not believe it.** `p_near` is the
      // phone's own claim to be at the venue, and a claim a client makes about
      // itself is worth nothing against somebody who edited the client. What
      // settles attendance is the peers' attestations (`02_DOMAIN.md §4`);
      // this flag only lets the automation notice a person whose own taps
      // never once agree with their group's.
      'p_near': true,
    }, (_) {});
    return _reread(hangoutId);
  }

  @override
  Future<Hangout> attest({
    required String hangoutId,
    required String memberId,
    required bool present,
  }) async {
    await _call('attest_member', {
      'p_hangout_id': hangoutId,
      'p_member_id': memberId,
      'p_present': present,
    }, (_) {});
    return _reread(hangoutId);
  }

  @override
  Future<List<ActivityCard>> activityCards(String hangoutId) async {
    // **Computed on the phone, from the hangout's own id.** The cards are a
    // pure function of the template and a seed, so every member's phone
    // produces the same sequence with no round-trip and no real-time
    // synchronisation — which is the point: the evening cannot stall because
    // somebody's signal went (`06_ACTIVITIES.md §1`).
    final list = await hangouts();
    final hangout = list.where((h) => h.id == hangoutId).firstOrNull;
    final template =
        ActivityRegistry.find(hangout?.activity.id ?? '') ??
        const ConversationDeck();
    final steps = template.session(
      SeededRandomSource.fromString(hangoutId),
      people: hangout?.memberCount ?? 4,
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
  }) => _call('set_bringing', {
    'p_hangout_id': hangoutId,
    'p_bringing': bringing,
  }, (_) {});

  // ── After ──────────────────────────────────────────────────────────────────

  @override
  Future<void> submitRatings({
    required String hangoutId,
    required List<RatingAnswer> answers,
    required VenueVerdict venue,
  }) => _call('submit_ratings', {
    'p_hangout_id': hangoutId,
    // All of them in one array, because the server counts them against the
    // membership and refuses a partial set. A partial set is indistinguishable
    // from a missing one, and the rating gate would then hold out somebody who
    // did try.
    'p_answers': [
      for (final answer in answers)
        {
          'subject': answer.subjectId,
          'enjoyment': _enjoyment(answer.enjoyment),
          'respect': answer.respectful,
          // Sent so the server can discard a set that was tapped through
          // faster than it can be read. It is an anti-abuse signal, not a
          // measurement of anybody.
          'dwell_ms': answer.dwellMs,
        },
    ],
    'p_easy_to_find': venue.easyToFind,
    'p_good_to_meet': venue.goodToMeet,
  }, (_) {});

  @override
  Future<void> report({
    required String hangoutId,
    required String memberId,
    required String category,
    String? note,
  }) => _call('report_member', {
    'p_hangout_id': hangoutId,
    'p_member_id': memberId,
    // A category from a fixed list, never free text: free text may not reach
    // the matcher, a notification body, or a display name (rule 11). The note
    // is stored for the automation's own record and is never rendered to
    // anybody but the reporter.
    'p_category': category,
    'p_note': note,
  }, (_) {});

  @override
  Future<void> reportVenue({
    required String hangoutId,
    required String reason,
  }) => _call('report_venue', {
    'p_hangout_id': hangoutId,
    'p_reason': reason,
  }, (_) {});

  // ── Assembly ───────────────────────────────────────────────────────────────

  /// Re-reads one hangout after a write that can have changed its phase.
  ///
  /// The third yes locks the group in the same transaction that counted it, so
  /// the answer to "what did my tap do" is a fresh read rather than an
  /// optimistic guess. Guessing would show a person `confirming` for the
  /// half-second before the truth arrived, which is exactly the moment they are
  /// staring at the screen.
  Future<Hangout> _reread(String hangoutId) async {
    final list = await hangouts();
    final found = list.where((h) => h.id == hangoutId).firstOrNull;
    if (found == null) {
      throw const MemberFailure('42501', 'That hangout is no longer yours.');
    }
    return found;
  }

  Future<Hangout> _hangout(
    Map<String, Object?> row, {
    required List<Map<String, Object?>> reveal,
  }) async {
    final startsAt = _atOr(row['starts_at'], DateTime.now().toUtc());
    final endsAt = _atOr(
      row['ends_at'],
      startsAt.add(const Duration(minutes: 90)),
    );
    final template =
        ActivityRegistry.find((row['activity_id'] as String?) ?? '') ??
        const ConversationDeck();
    final venue = reveal.firstOrNull;

    return Hangout(
      id: row['hangout_id']! as String,
      phase: _phase(row['state']),
      startsAt: startsAt,
      endsAt: endsAt,
      localDay: _day(startsAt),
      localTime: _time(startsAt),
      memberCount: _int(row['member_count']),
      activity: ActivityBrief(
        id: template.id,
        // The label is the server's, so a copy change is a config change
        // rather than a release. The rest is the template's, because a client
        // that does not know an activity cannot render its brief anyway.
        name: (row['activity_label'] as String?) ?? template.name,
        summary: template.brief,
        howItEnds: template.exitScript,
        equipment: template.requirements.equipment,
        needsCarriers: template.requirements.minCarriers,
      ),
      members: [
        for (final person in reveal)
          Member(
            id: person['person_id']! as String,
            name: _name(person['first_name'], person['last_initial']),
            isYou: (person['is_me'] as bool?) ?? false,
            arrived: (person['arrived'] as bool?) ?? false,
            attestedPresent: (person['arrived'] as bool?) ?? false,
          ),
      ],
      meetingPoint: venue == null || venue['venue_name'] == null
          ? null
          : MeetingPoint(
              name: venue['venue_name']! as String,
              street: (venue['venue_street'] as String?) ?? '',
              location: GeoPoint(
                latitude: _double(venue['venue_lat']),
                longitude: _double(venue['venue_lon']),
              ),
              standingSpot: (venue['standing_spot'] as String?) ?? '',
              chips: _chips(venue),
              // The caller's own walk, from the caller's own anchor. It is the
              // only place a person's anchor becomes something visible, and it
              // is visible only to them, only about a venue.
              walkMinutes: venue['walk_minutes'] == null
                  ? null
                  : _int(venue['walk_minutes']),
            ),
      sigil: venue == null || venue['sigil_symbol'] == null
          ? null
          : SigilMark(
              symbol: venue['sigil_symbol']! as String,
              colour: (venue['sigil_colour'] as String?) ?? '',
              // Declined by the server, because Croatian will not survive
              // being assembled from parts in a client.
              label: (venue['sigil_label'] as String?) ?? '',
            ),
      // `silent` and "not asked yet" both arrive here as null, and the screen
      // treats them alike — because from the person's side they are alike:
      // they have not answered. The *server* distinguishes them sharply (a
      // silence past the deadline is an infraction; an unopened window is
      // not), and that is where the distinction belongs.
      yourConfirmation: switch (row['my_confirmation']) {
        'yes' => true,
        'no' => false,
        _ => null,
      },
      confirmDeadline: _at(row['confirm_deadline_at']),
      revealAt: _at(row['reveal_at']),
      youArrived: (row['i_arrived'] as bool?) ?? false,
      ratingsDueAt: _at(row['rating_due_at']),
      cancelledBecause: row['cancel_reason'] as String?,
    );
  }

  /// The server's state name, mapped to the smaller set a client may see.
  ///
  /// `PLANNED` has no case and falls through to [HangoutPhase.proposed], but it
  /// cannot arrive: `my_hangouts` excludes it, because a hangout nobody has
  /// been told about is not yet a hangout.
  static HangoutPhase _phase(Object? raw) => switch (raw) {
    'PROPOSED' => HangoutPhase.proposed,
    'CONFIRMING' => HangoutPhase.confirming,
    'LOCKED' => HangoutPhase.locked,
    'BACKFILLING' => HangoutPhase.backfilling,
    'REVEALED' => HangoutPhase.revealed,
    'LIVE' => HangoutPhase.live,
    'RATING' => HangoutPhase.rating,
    'CLOSED' => HangoutPhase.closed,
    'CANCELLED' => HangoutPhase.cancelled,
    // **`ABANDONED` reads as closed, not cancelled.** It is the state for an
    // evening that reached the venue and did not happen, because too few
    // people arrived. `cancelled` says "it will not happen", which is a
    // promise made before anybody leaves home; saying it afterwards would be
    // untrue about the one thing this person definitely knows, since they
    // were there.
    'ABANDONED' => HangoutPhase.closed,
    _ => HangoutPhase.proposed,
  };

  /// The short facts under a venue's name.
  ///
  /// Only what OSM actually recorded. `wheelchair=limited` is not step-free and
  /// does not become a chip — a person told there is no step, who then meets
  /// one, has been failed worse than a person told nothing.
  static List<String> _chips(Map<String, Object?> venue) => [
    if (venue['outdoor'] == true) 'outdoor seating',
    if (venue['step_free'] == true) 'step-free',
    if (venue['opening_hours'] case final String hours when hours.isNotEmpty)
      hours,
  ];

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

  /// `Thursday 23 October`, in the phone's own zone.
  ///
  /// The phone's zone rather than the city's, deliberately: every slot is in
  /// one city and a person reading this is either in it or travelling to it.
  /// Rendering a city-local string for somebody currently in another zone would
  /// be right about the evening and wrong about their watch.
  static String _day(DateTime utc) {
    final local = utc.toLocal();
    return '${_weekdays[local.weekday - 1]} ${local.day} '
        '${_months[local.month - 1]}';
  }

  /// `17:30:00` or `17:30` from Postgres, as `17:30`.
  static String _hhmm(Object? raw) {
    final text = raw is String ? raw : '';
    final parts = text.split(':');
    return parts.length >= 2 ? '${parts[0]}:${parts[1]}' : text;
  }

  static String _time(DateTime utc) {
    final local = utc.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
