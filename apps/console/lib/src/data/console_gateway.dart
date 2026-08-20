import 'package:console/src/data/records.dart';
import 'package:ekipa_core/ekipa_core.dart';

/// Everything the console can ask the server to do.
///
/// **Intention — why a port and not a Supabase client in the screens.** Two
/// reasons, and the second is the one that matters.
///
/// The first is testability: every screen below can be driven by a fake, so the
/// widget tests need no network and no project. That is ordinary.
///
/// The second is that this interface is the complete, readable list of what a
/// console session can do. `AC-4` says the browser holds no service-role key
/// and reaches the database only through audited functions that re-check the
/// caller; that is a claim about a *surface*, and a surface scattered across
/// twelve widgets is a claim nobody can check. Here it is eleven methods on one
/// page. If a thirteenth thing becomes possible, it becomes possible *here*,
/// where a reviewer will see it.
///
/// Note what is absent and cannot be added by accident: there is no method that
/// reads a person, a rating, a report or an identity. The console has no view
/// over them, so the port has no door to them.
abstract interface class ConsoleGateway {
  /// The caller's console role, or `null` if they have none.
  ///
  /// `null` is the answer for an ordinary member, for an anonymous caller, and
  /// — the case this exists for — for an operator who has not completed a
  /// second factor. The database decides this, not the app.
  Future<String?> role();

  /// The most recent config versions, newest effective-from first.
  Future<List<ConfigVersionRecord>> configVersions({int limit});

  /// Every value a version carries, at every layer.
  Future<List<ConfigValueRow>> configValues(ConfigVersionId versionId);

  /// Writes a new, **unpublished** version and returns its id.
  ///
  /// [reason] is separate from the draft's note on purpose: the note says what
  /// the version is, the reason says why it was made, and the audit trail keeps
  /// the second one.
  Future<ConfigVersionId> publishConfig(
    PublishableConfig draft, {
    required String reason,
  });

  /// Makes a written version live.
  Future<void> markPublished(
    ConfigVersionId versionId, {
    required String reason,
  });

  /// Every city, including the inactive ones.
  Future<List<CityRecord>> cities();

  /// Slots for a city between two local dates, inclusive.
  Future<List<SlotRecord>> slots({
    required CityId cityId,
    required DateTime from,
    required DateTime to,
  });

  /// Materialises [slots] for a city, and returns how many were new.
  ///
  /// Takes local dates and times rather than instants. The conversion to UTC
  /// happens in Postgres against the city's own IANA zone, because that is
  /// where the tz database lives; see the header of migration 0009.
  Future<int> generateSlots({
    required CityId cityId,
    required List<LocalSlot> slots,
    required String generatedBy,
    required String reason,
  });

  /// What a rule change could still reach.
  Future<List<InFlightObject>> inFlight();

  /// The audit trail, newest first.
  Future<List<AuditRecord>> audit({int limit});
}

/// Raised when the server refuses, or cannot be reached.
///
/// **Intention.** One exception type with a message the screen prints verbatim.
/// The alternative — a per-case enum the UI switches on to compose a sentence —
/// puts a second, quieter copy of the server's rules in the client, and the two
/// drift. The console's job when refused is to say what it was told and stop.
final class ConsoleFailure implements Exception {
  /// Describes a failure.
  const ConsoleFailure(this.message, {this.code});

  /// What to show the operator.
  final String message;

  /// The SQLSTATE, where the server gave one.
  ///
  /// `42501` is "you may not", `22023` is "that is not a valid thing to ask".
  /// Kept because the two deserve different words on screen, and because a
  /// `42501` after a working session usually means a token expired rather than
  /// that a permission changed.
  final String? code;

  /// Whether the server refused on permission grounds.
  bool get isRefusal => code == '42501';

  @override
  String toString() => 'ConsoleFailure(${code ?? '-'}): $message';
}

/// Turns a [ConfigScope] into the two columns `config_values` stores, and back.
///
/// **Intention.** Exactly one place in the console knows that `city` scope
/// travels as `('city', '<uuid>')`. The check constraint, the resolver and the
/// publish RPC all agree on that encoding, and the way to keep a fourth party
/// agreeing is to give it no opinion of its own.
abstract final class ConfigScopeCodec {
  /// The `scope_kind` column.
  static String kindOf(ConfigScope scope) => scope.kind.name;

  /// The `scope_ref` column.
  static String refOf(ConfigScope scope) => scope.ref;

  /// Rebuilds a scope from its two columns.
  ///
  /// Returns `null` for an encoding this build does not know. A row the console
  /// cannot interpret is skipped rather than guessed at: guessing would place
  /// a value at the wrong layer, and the layer is what decides which city it
  /// applies to.
  static ConfigScope? decode(String kind, String ref) => switch (kind) {
    'global' => const ConfigScope.global(),
    'country' => ConfigScope.country(ref),
    'city' => ConfigScope.city(CityId(ref)),
    'cohort' => ConfigScope.cohort(ref),
    _ => null,
  };
}
