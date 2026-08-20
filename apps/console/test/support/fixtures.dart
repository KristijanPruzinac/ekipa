/// The rows this suite pretends the server returned.
///
/// **Intention — the fixtures are dated, not relative.** Every one of them sits
/// at a fixed instant around `testNow`, so "this version is scheduled, not
/// live" is a property of the data rather than of when the test happened to
/// run. A suite whose fixtures say `now.add(...)` passes at 23:59 and fails at
/// 00:01 twice a year, which is the exact class of bug the console exists to
/// make visible.
library;

import 'package:console/src/data/records.dart';
import 'package:ekipa_core/ekipa_core.dart';

/// The version whose rules are the ones in force at `testNow`.
final ConfigVersionRecord liveVersion = ConfigVersionRecord(
  id: const ConfigVersionId('11111111-2222-4333-8444-555555555555'),
  createdAt: DateTime.utc(2026, 9, 28, 11),
  effectiveFrom: DateTime.utc(2026, 10),
  note: 'Opening Osijek on three evenings.',
  published: true,
  valueCount: 4,
);

/// Published, but starting after `testNow` — the state a console that only
/// showed "published" would misreport as live.
final ConfigVersionRecord scheduledVersion = ConfigVersionRecord(
  id: const ConfigVersionId('99999999-8888-4777-8666-555555555555'),
  createdAt: DateTime.utc(2026, 10, 18, 9),
  effectiveFrom: DateTime.utc(2026, 11),
  note: 'Groups of four from November.',
  published: true,
  valueCount: 5,
);

/// Written, never released.
final ConfigVersionRecord unpublishedVersion = ConfigVersionRecord(
  id: const ConfigVersionId('aaaaaaaa-bbbb-4ccc-8ddd-eeeeeeeeeeee'),
  createdAt: DateTime.utc(2026, 10, 19, 15),
  effectiveFrom: DateTime.utc(2026, 12),
  note: 'Draft nobody released.',
  published: false,
  valueCount: 5,
);

/// Osijek.
const CityRecord osijek = CityRecord(
  id: CityId('c0000000-0000-4000-8000-000000000001'),
  name: 'Osijek',
  countryCode: 'HR',
  timezone: 'Europe/Zagreb',
  active: true,
  slotCount: 18,
);

/// A city that is being set up and is not open to anybody yet.
const CityRecord zagreb = CityRecord(
  id: CityId('c0000000-0000-4000-8000-000000000002'),
  name: 'Zagreb',
  countryCode: 'HR',
  timezone: 'Europe/Zagreb',
  active: false,
  slotCount: 0,
);

/// A global value, and a city value shadowing it.
///
/// `matching.max_group_size` is set twice on purpose: the whole point of the
/// scope ladder is that the more specific layer wins, and the whole point of
/// the chip beside the value is that the operator can see which one did.
final List<ConfigValueRow> layeredValues = [
  const ConfigValueRow(
    key: 'matching.min_group_size',
    scope: ConfigScope.global(),
    value: 3,
  ),
  const ConfigValueRow(
    key: 'matching.max_group_size',
    scope: ConfigScope.global(),
    value: 4,
  ),
  ConfigValueRow(
    key: 'matching.max_group_size',
    scope: ConfigScope.city(osijek.id),
    value: 3,
  ),
  const ConfigValueRow(
    key: 'schedule.weekdays',
    scope: ConfigScope.global(),
    value: '4,5,6',
  ),
];

/// Two slots at the same wall-clock time, an hour apart in UTC.
///
/// The last Sunday of October 2026 is the 25th, so 17:30 in Osijek is 15:30Z on
/// the 23rd and 16:30Z on the 30th. This pair is the fixture the schedule
/// screen's two clock columns exist for.
final List<SlotRecord> dstSlots = [
  SlotRecord(
    id: const SlotId('50000000-0000-4000-8000-000000000001'),
    startsAt: DateTime.utc(2026, 10, 23, 15, 30),
    endsAt: DateTime.utc(2026, 10, 23, 17),
    localDate: '2026-10-23',
    localWeekday: 5,
    localTime: '17:30',
    generatedBy: 'schedule:4,5,6@16:00,17:30,19:00/90m',
    available: 11,
  ),
  SlotRecord(
    id: const SlotId('50000000-0000-4000-8000-000000000002'),
    startsAt: DateTime.utc(2026, 10, 30, 16, 30),
    endsAt: DateTime.utc(2026, 10, 30, 18),
    localDate: '2026-10-30',
    localWeekday: 5,
    localTime: '17:30',
    generatedBy: 'schedule:4,5,6@16:00,17:30,19:00/90m',
    available: 7,
  ),
];

/// Two audited actions by the same operator, and one by another.
final List<AuditRecord> auditRows = [
  AuditRecord(
    id: 3,
    actor: '7f3a91c2-0000-4000-8000-000000000001',
    action: 'config.publish',
    target: '11111111-2222-4333-8444-555555555555',
    reason: 'Three evenings was too few for the number of people waiting.',
    occurredAt: DateTime.utc(2026, 10, 19, 14, 2),
  ),
  AuditRecord(
    id: 2,
    actor: '7f3a91c2-0000-4000-8000-000000000001',
    action: 'slots.generate',
    target: 'c0000000-0000-4000-8000-000000000001',
    reason: 'Horizon had run down to four days.',
    occurredAt: DateTime.utc(2026, 10, 18, 8, 40),
  ),
  AuditRecord(
    id: 1,
    actor: 'b21d0000-0000-4000-8000-000000000009',
    action: 'config.publish',
    target: null,
    reason: 'First version.',
    occurredAt: DateTime.utc(2026, 10, 1, 6),
  ),
];

/// One hangout pinned to the live version, one not yet pinned.
final List<InFlightObject> inFlightObjects = [
  InFlightObject(
    id: 'h1',
    kind: 'hangout',
    decidesAt: DateTime.utc(2026, 10, 22, 15),
    pinnedVersion: liveVersion.id,
  ),
  InFlightObject(
    id: 'h2',
    kind: 'match_run',
    decidesAt: DateTime.utc(2026, 10, 23, 12),
  ),
];
