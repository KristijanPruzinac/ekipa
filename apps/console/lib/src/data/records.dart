/// The shapes the console's RPCs hand back.
///
/// **Intention.** These are not domain types and they deliberately do not try
/// to be. `ekipa_core` owns what a config version *means*; these own what the
/// nine functions in migration 0009 *return*. Keeping them apart means a change
/// to a `returns table (...)` clause breaks compilation here — in one file that
/// names the RPC it came from — instead of quietly reshaping a domain object
/// that four screens depend on.
///
/// Nothing here carries a name, an identity hash, an anchor, a rating or a
/// report. That is not an accident of what the console needs today: rule 5 in
/// `CONTRIBUTING.md` forbids those reaching a log or a screen, and the way to
/// keep a rule like that is to have no field to put them in.
library;

import 'package:ekipa_core/ekipa_core.dart';
import 'package:flutter/foundation.dart';

/// One row of `console_config_versions`.
@immutable
final class ConfigVersionRecord {
  /// Describes a stored version.
  const ConfigVersionRecord({
    required this.id,
    required this.createdAt,
    required this.effectiveFrom,
    required this.note,
    required this.published,
    required this.valueCount,
  });

  /// The version's id.
  final ConfigVersionId id;

  /// When somebody wrote it.
  final DateTime createdAt;

  /// When it starts applying.
  final DateTime effectiveFrom;

  /// Why it exists, in the operator's own words.
  final String note;

  /// Whether it is live, or still a draft nobody has released.
  final bool published;

  /// How many values it carries, across every layer.
  final int valueCount;

  /// Whether this version's rules are the ones in force at [now].
  ///
  /// A published version with a future [effectiveFrom] is *scheduled*, not
  /// live, and the difference is the whole point of the table. A screen that
  /// showed only "published" would say a change had landed while every hangout
  /// in flight was still being decided by the previous one.
  bool isLiveAt(DateTime now) => published && !effectiveFrom.isAfter(now);
}

/// One row of `console_cities`.
@immutable
final class CityRecord {
  /// Describes a city.
  const CityRecord({
    required this.id,
    required this.name,
    required this.countryCode,
    required this.timezone,
    required this.active,
    required this.slotCount,
  });

  /// The city's id.
  final CityId id;

  /// Its name. A place, not a person — but the console still sets it in the
  /// system face, because `ZarType.personName` means *somebody is on screen*
  /// and nobody is.
  final String name;

  /// ISO 3166-1 alpha-2.
  final String countryCode;

  /// The IANA zone the slot generator converts against — `Europe/Zagreb`, not
  /// an offset. An offset is wrong twice a year.
  final String timezone;

  /// Whether it is open to members. A city is inactive precisely while it is
  /// being set up, which is why the console reads it and the app does not.
  final bool active;

  /// Slots still ahead of now.
  final int slotCount;
}

/// One row of `console_slots`.
@immutable
final class SlotRecord {
  /// Describes a materialised slot.
  const SlotRecord({
    required this.id,
    required this.startsAt,
    required this.endsAt,
    required this.localDate,
    required this.localWeekday,
    required this.localTime,
    required this.generatedBy,
    required this.available,
  });

  /// The slot's id.
  final SlotId id;

  /// The instant it begins, in UTC.
  final DateTime startsAt;

  /// The instant it ends, in UTC.
  final DateTime endsAt;

  /// The calendar date in the city, as `yyyy-mm-dd`.
  ///
  /// Stored beside [startsAt] rather than derived from it, because deriving it
  /// needs the city's zone and every reader would have to fetch that first.
  final String localDate;

  /// ISO weekday, 1 = Monday.
  final int localWeekday;

  /// The wall-clock start in the city, as `HH:mm`.
  final String localTime;

  /// The schedule signature that produced it, so a row can be traced to the
  /// rule that made it.
  final String? generatedBy;

  /// How many people said they are free for it.
  ///
  /// A count, never a list. The console has no view over who is available, and
  /// this field is where that would leak if it were going to.
  final int available;
}

/// One row of `console_audit`.
@immutable
final class AuditRecord {
  /// Describes an audited action.
  const AuditRecord({
    required this.id,
    required this.actor,
    required this.action,
    required this.target,
    required this.reason,
    required this.occurredAt,
  });

  /// Monotonic row id.
  final int id;

  /// The operator's auth id.
  final String actor;

  /// A dotted action name, e.g. `config.publish`.
  final String action;

  /// What was acted on — a version id, a city id.
  final String? target;

  /// Why, typed by the operator at the time.
  final String reason;

  /// When.
  final DateTime occurredAt;

  /// The operator as the console is allowed to name them.
  ///
  /// **Intention.** `12_CONSOLE.md` §2 says analytical surfaces show `P-7F3A`
  /// and never a name, and the trail is the surface most likely to be read by
  /// somebody checking up on a colleague. A stable short label is enough to
  /// answer "was this the same person twice", which is the only question the
  /// screen needs to support, and not enough to answer "who".
  ///
  /// Derived from the id rather than stored, so there is no second column that
  /// could drift out of step with it — and no column an operator could set.
  String get actorLabel {
    final compact = actor.replaceAll('-', '').toUpperCase();
    return compact.length >= 4 ? 'OP-${compact.substring(0, 4)}' : 'OP-????';
  }
}
