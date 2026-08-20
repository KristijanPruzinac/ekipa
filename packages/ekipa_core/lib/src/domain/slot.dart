import 'package:ekipa_core/src/foundation/ids.dart';
import 'package:meta/meta.dart';

/// One 90-minute window in one city on one date.
///
/// **Intention.** Slots are *materialised* per week per city rather than
/// computed from a recurrence rule, so daylight-saving time is resolved once,
/// at generation, and never recomputed ambiguously. "17:30 on the last Sunday
/// in October" is two different instants depending on which library you ask,
/// and the difference is an hour of four people waiting.
///
/// The instants are UTC; the *rules* are expressed in the city's local
/// timezone, because "16:00" and "the morning of" are local human concepts.
@immutable
final class Slot {
  /// Describes a slot.
  const Slot({
    required this.id,
    required this.cityId,
    required this.startsAt,
    required this.endsAt,
  });

  /// Identifies the slot.
  final SlotId id;

  /// Which city it belongs to. A person has no use for another city's slots.
  final CityId cityId;

  /// When it begins, in UTC.
  final DateTime startsAt;

  /// When it ends, in UTC.
  final DateTime endsAt;

  /// How long it runs.
  Duration get duration => endsAt.difference(startsAt);

  /// Whether this slot's window intersects [other]'s.
  ///
  /// Used by eligibility: a person already placed in an overlapping slot cannot
  /// be placed here, however available they claimed to be. Two groups holding
  /// the same person at 17:30 means at least one group waits for somebody who
  /// is not coming — the single outcome the product cannot survive at launch.
  bool overlaps(Slot other) =>
      startsAt.isBefore(other.endsAt) && other.startsAt.isBefore(endsAt);

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Slot && other.id == id);

  @override
  int get hashCode => Object.hash(Slot, id);

  @override
  String toString() => 'Slot(${id.value}, ${startsAt.toIso8601String()})';
}
