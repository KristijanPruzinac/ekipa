import 'package:meta/meta.dart';

/// Base for every identifier in the domain.
///
/// **Intention.** Identifiers are the most-passed values in the system and the
/// easiest to transpose — a `hangoutId` handed to a parameter expecting a
/// `personId` is a bug that a `String`-typed API cannot catch and that a
/// reviewer reads straight past.
///
/// **Rejected — `extension type const PersonId(String value)`.** Zero-cost and
/// idiomatic Dart 3, and wrong here: extension types are erased at runtime, so
/// `PersonId('x') == SlotId('x')` is `true` and a `Map<PersonId, …>` will
/// happily return a slot's entry. Equality discriminated by [runtimeType] costs
/// one allocation per id and removes that entire class of bug.
///
/// **Rejected — `typedef PersonId = String`.** No safety at all; it documents
/// the intent while providing none of it.
@immutable
abstract base class EntityId {
  /// Wraps [value] as an identifier.
  const EntityId(this.value);

  /// The opaque underlying identifier. Never parsed, never given meaning.
  final String value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is EntityId &&
          other.runtimeType == runtimeType &&
          other.value == value);

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => '$runtimeType($value)';
}

/// Identifies a person. Internal surrogate, never shown to anyone.
final class PersonId extends EntityId {
  /// Wraps [value] as a person identifier.
  const PersonId(super.value);
}

/// Identifies one 90-minute window in one city on one date.
final class SlotId extends EntityId {
  /// Wraps [value] as a slot identifier.
  const SlotId(super.value);
}

/// Identifies one scheduled meeting of 3–4 people.
final class HangoutId extends EntityId {
  /// Wraps [value] as a hangout identifier.
  const HangoutId(super.value);
}

/// Identifies a city.
final class CityId extends EntityId {
  /// Wraps [value] as a city identifier.
  const CityId(super.value);
}

/// Identifies a vetted meeting point.
final class VenueId extends EntityId {
  /// Wraps [value] as a venue identifier.
  const VenueId(super.value);
}

/// Identifies a derived venue cluster — the matching unit.
final class ClusterId extends EntityId {
  /// Wraps [value] as a cluster identifier.
  const ClusterId(super.value);
}

/// Identifies one immutable configuration version.
final class ConfigVersionId extends EntityId {
  /// Wraps [value] as a config version identifier.
  const ConfigVersionId(super.value);
}

/// Identifies one execution of the matchmaker.
final class MatchRunId extends EntityId {
  /// Wraps [value] as a match run identifier.
  const MatchRunId(super.value);
}
