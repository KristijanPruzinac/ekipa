/// The boundary between the database's JSON and the matcher's values.
///
/// **Intention — this is the only place in the worker that knows both.** The
/// matcher takes domain types and nothing else; `worker_snapshot` returns one
/// jsonb. Keeping the translation in one file means a column added to the
/// snapshot has exactly one place to be read, and that place is testable
/// without a database: `readSnapshot` takes a `Map`, so a unit test hands it a
/// literal and gets a `MatchSnapshot`.
///
/// **Everything here is total.** A missing field falls back to something
/// honest rather than throwing, because a nightly job that dies on one
/// unexpected null has cancelled a city's evening over a typo. The exception is
/// an unparseable id, which is not recoverable and would silently produce a
/// group of strangers to each other and to the database.
library;

import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_core/matching.dart';

/// Rebuilds the matcher's input from `worker_snapshot`.
MatchSnapshot readSnapshot(Map<String, Object?> json) {
  final people = <Person>[];
  for (final entry in _list(json['people'])) {
    final person = _map(entry);
    people.add(
      Person(
        id: PersonId(person['id']! as String),
        gender: Gender(person['gender']! as String),
        cityId: CityId(person['city']! as String),
        homeAnchor: GeoPoint(
          latitude: _double(person['lat']),
          longitude: _double(person['lon']),
        ),
        // **Zero, and nothing reads it.** The radius stopped being a property
        // of a person when the "how far will you go" question was deleted: it
        // is a property of the city now (`geo.max_travel_m`), applied by
        // `worker_snapshot` when it works out which clusters are reachable. By
        // the time the matcher sees a person, that question is already
        // answered as a set — `MustReachSomewhere` and `MustShareACluster` both
        // read `reachableClusters` and neither reads this field.
        //
        // It survives on `Person` because removing a field from a value type
        // that four packages construct is a change worth making on purpose
        // rather than in passing. Sending a real number here would be worse
        // than sending zero: it would look like the matcher used it.
        maxTravelMetres: 0,
        reachableClusters: {
          for (final cluster in _list(person['clusters']))
            ClusterId(cluster! as String),
        },
        standing: _standing(person),
        completedHangouts: _int(person['completed']),
        weeksWaiting: _int(person['weeks_waiting']),
        activities: {
          for (final activity in _list(person['activities']))
            activity! as String,
        },
        equipment: {
          for (final item in _list(person['equipment'])) item! as String,
        },
      ),
    );
  }

  final slots = [
    for (final entry in _list(json['slots']).map(_map))
      Slot(
        id: SlotId(entry['id']! as String),
        cityId: CityId(entry['city']! as String),
        startsAt: DateTime.parse(entry['starts_at']! as String).toUtc(),
        endsAt: DateTime.parse(entry['ends_at']! as String).toUtc(),
      ),
  ];

  final availability = <SlotId, Set<PersonId>>{
    for (final entry in _map(json['availability']).entries)
      SlotId(entry.key): {
        for (final person in _list(entry.value)) PersonId(person! as String),
      },
  };

  final edges = [
    for (final entry in _list(json['edges']).map(_map))
      Edge(
        pair: PairKey(
          PersonId(entry['a']! as String),
          PersonId(entry['b']! as String),
        ),
        weight: _double(entry['weight']),
        meetCount: _int(entry['meet_count'], fallback: 1),
        lastMetAt: DateTime.parse(entry['last_met_at']! as String).toUtc(),
      ),
  ];

  final exclusions = [
    for (final entry in _list(json['exclusions']).map(_map))
      Exclusion(
        pair: PairKey(
          PersonId(entry['a']! as String),
          PersonId(entry['b']! as String),
        ),
        reason: _reason(entry['reason'] as String?),
      ),
  ];

  final history = [
    for (final entry in _list(json['history']).map(_map))
      PastHangout(
        members: {
          for (final member in _list(entry['members']))
            PersonId(member! as String),
        },
        endedAt: DateTime.parse(entry['ended_at']! as String).toUtc(),
      ),
  ];

  final placed = <PersonId, Set<SlotId>>{
    for (final entry in _map(json['already_placed']).entries)
      PersonId(entry.key): {
        for (final slot in _list(entry.value)) SlotId(slot! as String),
      },
  };

  return MatchSnapshot(
    cityId: CityId(json['city']! as String),
    takenAt: DateTime.parse(json['taken_at']! as String).toUtc(),
    people: people,
    slots: slots,
    availability: availability,
    edges: edges,
    exclusions: exclusions,
    history: history,
    alreadyPlaced: placed,
  );
}

/// Turns a plan into the argument `worker_commit_plan` takes.
///
/// **Every deadline is computed here and sent as an absolute instant.** The
/// database does not derive them, because `0003` requires all seven written at
/// creation from the config version in force — that is what stops a mid-day
/// config change moving a deadline somebody is already inside. Doing the
/// arithmetic in one place, against one resolved snapshot, is what makes that
/// claim true rather than approximately true.
Map<String, Object?> writePlan(
  MatchPlan plan, {
  required ConfigSnapshot config,
  required MatchSnapshot snapshot,
  required String kind,
}) {
  final slots = {for (final slot in snapshot.slots) slot.id: slot};
  return {
    'city': plan.city.value,
    'kind': kind,
    'seed': plan.seed,
    'snapshot_hash': plan.snapshotHash,
    'config_version': plan.configVersion.value == 'defaults'
        ? null
        : plan.configVersion.value,
    'stats': plan.stats.toJson(),
    'groups': [
      for (final hangout in plan.hangouts)
        _group(
          hangout,
          config: config,
          slot: slots[hangout.slot],
          snapshot: snapshot,
        ),
    ],
  };
}

Map<String, Object?> _group(
  PlannedHangout hangout, {
  required ConfigSnapshot config,
  required Slot? slot,
  required MatchSnapshot snapshot,
}) {
  final startsAt = slot?.startsAt ?? DateTime.now().toUtc();
  final endsAt = slot?.endsAt ?? startsAt.add(const Duration(minutes: 90));
  final opens = startsAt.subtract(config.get(LifecycleKeys.confirmOpensBefore));
  final deadline = opens.add(config.get(LifecycleKeys.confirmWindow));

  return {
    'slot': hangout.slot.value,
    // The activity is chosen from what the group can actually do. Cards need
    // two people carrying a deck; the conversation deck needs nothing, which is
    // why it is the fallback rather than a preference.
    'activity': _activityFor(hangout, snapshot),
    'composition_rule': 'NO_LONE_GENDER',
    'seed_person': hangout.seed.value,
    'is_dating': false,
    'confirm_opens_at': opens.toIso8601String(),
    'confirm_deadline_at': deadline.toIso8601String(),
    'backfill_until': deadline
        .add(config.get(LifecycleKeys.backfillWindow))
        .toIso8601String(),
    'reveal_at': startsAt
        .subtract(config.get(LifecycleKeys.revealBefore))
        .toIso8601String(),
    'arrival_grace_until': startsAt
        .add(config.get(LifecycleKeys.arrivalGrace))
        .toIso8601String(),
    'late_report_until': startsAt
        .add(config.get(LifecycleKeys.lateReportWindow))
        .toIso8601String(),
    'rating_due_at': endsAt
        .add(config.get(LifecycleKeys.ratingDueAfter))
        .toIso8601String(),
    'ring_mix': hangout.ringMix,
    'rejected_alternates': [
      for (final rejected in hangout.rejectedAlternates) rejected.toJson(),
    ],
    'members': [
      for (final member in hangout.members)
        {
          'person': member.person.value,
          'role': member.role.storageCode,
          'ring_intended': member.ringIntended?.storageCode,
          'ring_realised': member.ringRealised?.storageCode,
          'via': member.via?.value,
        },
    ],
  };
}

/// The activity template id for a group.
///
/// **Conversation is the default and cards are the exception**, not the other
/// way round. The deck of questions needs nothing carried, works with any three
/// or four people in any weather, and cannot fail to be available. Cards need
/// two people who own a deck, and a group that cannot field two carriers must
/// never be told it is playing cards (`06_ACTIVITIES.md §2`) — being handed an
/// activity you cannot do is worse than being handed a dull one.
///
/// **Two carriers, not one.** One is a single point of failure with a face: if
/// that person forgets, three people are sitting at a table waiting for an
/// evening that cannot start, and everybody knows whose fault it is. The
/// requirement is read from [CardsActivity] rather than written here, so the
/// number lives beside the activity that needs it.
String _activityFor(PlannedHangout hangout, MatchSnapshot snapshot) {
  const cards = CardsActivity();
  final needed = cards.requirements.equipment;
  if (needed == null) return cards.id;

  final people = hangout.memberIds.map(snapshot.person).nonNulls.toList();
  final carriers = people.where((p) => p.equipment.contains(needed)).length;

  return carriers >= cards.requirements.minCarriers &&
          people.length >= cards.requirements.minPeople
      ? cards.id
      : const ConversationDeck().id;
}

// ── Reading ──────────────────────────────────────────────────────────────────

Standing _standing(Map<String, Object?> person) {
  final tier = switch (person['tier'] as String? ?? 'good') {
    'watched' => StandingTier.watched,
    'throttled' => StandingTier.throttled,
    'segregated' => StandingTier.segregated,
    'suspended' => StandingTier.suspended,
    'banned' => StandingTier.banned,
    _ => StandingTier.good,
  };
  return Standing(
    tier: tier,
    respect: RespectSignal(
      yes: _int(person['respect_yes']),
      no: _int(person['respect_no']),
    ),
    // `null` means no quota, which is not the same as a quota of zero and must
    // not be treated as it: zero is the rating gate holding somebody out, and
    // null is an ordinary person with nothing against them.
    remainingQuota: person['remaining_quota'] == null
        ? null
        : _int(person['remaining_quota']),
  );
}

ExclusionReason _reason(String? code) => switch (code) {
  'block' => ExclusionReason.block,
  'report_upheld' => ExclusionReason.reportUpheld,
  _ => ExclusionReason.ratherNot,
};

List<Object?> _list(Object? value) => value is List ? value : const <Object?>[];

Map<String, Object?> _map(Object? value) => switch (value) {
  final Map<String, Object?> map => map,
  final Map<Object?, Object?> map => {
    for (final entry in map.entries) '${entry.key}': entry.value,
  },
  _ => const <String, Object?>{},
};

int _int(Object? value, {int fallback = 0}) => switch (value) {
  final int n => n,
  final num n => n.round(),
  final String s => int.tryParse(s) ?? fallback,
  _ => fallback,
};

double _double(Object? value, {double fallback = 0}) => switch (value) {
  final double n => n,
  final num n => n.toDouble(),
  final String s => double.tryParse(s) ?? fallback,
  _ => fallback,
};
