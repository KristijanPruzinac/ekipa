import 'package:ekipa_core/src/foundation/config.dart';
import 'package:ekipa_core/src/foundation/ids.dart';
import 'package:meta/meta.dart';

/// The layers a configuration value can be attached to, in ascending
/// specificity.
///
/// **Intention.** `01_ARCHITECTURE.md` §5: *Osijek can run three weekdays while
/// a new city runs one, without a code path.* Scoping is the mechanism that
/// makes a second city a data operation (P5) rather than a release, and the
/// only way it can do that is if every layer already exists on the first day —
/// a `city` scope added later means every value written before it was global,
/// and nobody can say which of them was global *on purpose*.
///
/// The names and order match the `scope_kind` check constraint in
/// `supabase/migrations/0005_v3_config_and_runs.sql` exactly. If they drift,
/// the database will accept a scope this code cannot resolve, and the value
/// will be silently invisible.
///
/// **Rejected — a numeric priority column.** It lets two layers claim the same
/// priority, which makes resolution depend on row order, which makes a match
/// run depend on when a row happened to be inserted.
enum ConfigScopeKind {
  /// Everything, everywhere. The layer every key has a value at, by default.
  global,

  /// One country, by ISO-3166-1 alpha-2 code.
  country,

  /// One city.
  city,

  /// One named cohort — an experiment arm (`12_CONSOLE.md` §4).
  cohort,
}

/// One layer a value is attached to: a kind, and which one.
@immutable
final class ConfigScope {
  /// The layer under everything.
  const ConfigScope.global() : kind = ConfigScopeKind.global, ref = '';

  /// One country, by ISO-3166-1 alpha-2 code (`HR`).
  const ConfigScope.country(String code)
    : kind = ConfigScopeKind.country,
      ref = code;

  /// One cohort — an experiment arm, by name.
  const ConfigScope.cohort(String name)
    : kind = ConfigScopeKind.cohort,
      ref = name;

  /// One city.
  ConfigScope.city(CityId id) : kind = ConfigScopeKind.city, ref = id.value;

  /// Which layer.
  final ConfigScopeKind kind;

  /// Which member of that layer. Empty for [ConfigScopeKind.global], and the
  /// database stores `''` rather than `null` so the primary key stays total.
  final String ref;

  /// How specific this scope is. Higher wins.
  int get specificity => kind.index;

  /// Whether this scope is shaped legally: global carries no reference, and
  /// every other layer must name one.
  ///
  /// A `city` scope with an empty reference is the dangerous shape — it looks
  /// targeted in the console and behaves as a second global layer that
  /// out-ranks the real one.
  bool get isWellFormed =>
      kind == ConfigScopeKind.global ? ref.isEmpty : ref.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConfigScope && other.kind == kind && other.ref == ref);

  @override
  int get hashCode => Object.hash(kind, ref);

  @override
  String toString() =>
      kind == ConfigScopeKind.global ? 'global' : '${kind.name}:$ref';
}

/// One row of `config_values`.
@immutable
final class ConfigValueRow {
  /// Describes one stored value.
  const ConfigValueRow({
    required this.key,
    required this.scope,
    required this.value,
  });

  /// The dotted key name. A `String` rather than a [ConfigKey] because the
  /// database can hold a name no key declares — that is exactly the typo the
  /// console has to be able to show.
  final String key;

  /// Which layer it is attached to.
  final ConfigScope scope;

  /// The stored JSON value.
  final Object? value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConfigValueRow &&
          other.key == key &&
          other.scope == scope &&
          other.value == value);

  @override
  int get hashCode => Object.hash(key, scope, value);

  @override
  String toString() => 'ConfigValueRow($key@$scope = $value)';
}

/// Who a resolution is being performed *for*.
@immutable
final class ConfigTarget {
  /// A target in a country and city, optionally inside a cohort.
  const ConfigTarget({this.countryCode, this.cityId, this.cohort});

  /// The target that admits only global values — what the mill uses before it
  /// knows which city it is about to run.
  const ConfigTarget.everywhere()
    : countryCode = null,
      cityId = null,
      cohort = null;

  /// Which country, if the caller is in one.
  final String? countryCode;

  /// Which city, if the caller is in one.
  final CityId? cityId;

  /// Which cohort, if the caller is in one.
  ///
  /// One cohort, not a set. Two cohorts are two values at the same specificity
  /// for the same key, and picking between them needs a rule nobody has written
  /// yet. The experiments framework is P5; inventing its tie-break here would
  /// mean shipping a rule with no argument behind it.
  final String? cohort;

  /// Whether a value attached to [scope] applies to this target.
  bool admits(ConfigScope scope) => switch (scope.kind) {
    ConfigScopeKind.global => true,
    ConfigScopeKind.country => scope.ref == countryCode,
    ConfigScopeKind.city => scope.ref == cityId?.value,
    ConfigScopeKind.cohort => scope.ref == cohort,
  };

  @override
  String toString() =>
      'ConfigTarget(country: $countryCode, city: ${cityId?.value}, '
      'cohort: $cohort)';
}

/// A flattened configuration, plus which layer each value came from.
@immutable
final class ConfigResolution {
  const ConfigResolution._(this.snapshot, this._origins);

  /// The flattened values, ready to be handed to a run.
  final ConfigSnapshot snapshot;

  final Map<String, ConfigScope> _origins;

  /// Which layer supplied the value for [keyName], or `null` if no layer did
  /// and the key's default is in force.
  ///
  /// The console shows this beside every row. Without it, "why is this 3?" has
  /// three possible answers — a city override, a global value, or the code's
  /// default — and no way to tell them apart.
  ConfigScope? originOf(String keyName) => _origins[keyName];

  /// Every key this resolution supplies an explicit value for.
  Iterable<String> get explicitKeys => _origins.keys;
}

/// Flattens scoped rows into one snapshot for one target.
///
/// **Intention.** Most specific layer wins, and nothing else is consulted. The
/// resolution is a pure function of (rows, target), so two runs of the mill
/// against the same version cannot disagree about what a value is — which is
/// the precondition for `snapshot_hash` meaning anything.
///
/// **Rejected — merging layers value-by-value** (a city supplying half a key's
/// fields while global supplies the rest). It reads as flexible and it means no
/// single row anywhere in the database is the answer to "what is this value",
/// which is the state the console exists to prevent.
abstract final class ConfigResolver {
  /// Resolves [rows] for [target].
  ///
  /// Rows the target does not admit are dropped; among the admitted ones, the
  /// most specific scope wins per key. A tie is impossible by construction —
  /// `config_values` is keyed on `(version_id, key, scope_kind, scope_ref)`, so
  /// one layer can hold at most one value for one key — and if one ever appears
  /// it is a defect in the store, not a preference to resolve here.
  static ConfigResolution resolve({
    required ConfigVersionId versionId,
    required Iterable<ConfigValueRow> rows,
    required ConfigTarget target,
  }) {
    final values = <String, Object?>{};
    final origins = <String, ConfigScope>{};

    for (final row in rows) {
      if (!target.admits(row.scope)) continue;
      final incumbent = origins[row.key];
      if (incumbent != null && incumbent.specificity >= row.scope.specificity) {
        continue;
      }
      values[row.key] = row.value;
      origins[row.key] = row.scope;
    }

    return ConfigResolution._(
      ConfigSnapshot(versionId: versionId, values: values),
      Map.unmodifiable(origins),
    );
  }
}
