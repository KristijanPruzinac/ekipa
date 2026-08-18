import 'package:ekipa_core/src/foundation/config.dart';
import 'package:meta/meta.dart';

/// A named set of keys that belong together on one console screen.
@immutable
final class ConfigGroup {
  /// Describes a group.
  const ConfigGroup({
    required this.name,
    required this.description,
    required this.keys,
    this.invariants = const [],
  });

  /// The heading the console renders — `Matching`, `Schedule`, `Trust`.
  final String name;

  /// One sentence saying what this group of keys decides.
  final String description;

  /// The keys, in the order they should be shown.
  final List<ConfigKey<Object?>> keys;

  /// Consistency rules that hold *between* the keys in this group.
  ///
  /// **Intention.** A key can validate itself — the type does that. What no key
  /// can see is that `ring_share_enjoyed` and `ring_share_leaf` now sum above
  /// one, or that `min_group_size` has passed `max_group_size`. Those live with
  /// the group that owns the keys rather than in the validator, because the
  /// validator must not know what a ring is: `ekipa_core`'s config layer is
  /// imported by the mobile app, and the matcher is not (D9).
  final List<ConfigInvariant> invariants;
}

/// One consistency rule over a resolved snapshot.
@immutable
final class ConfigInvariant {
  /// Describes a rule.
  const ConfigInvariant({
    required this.name,
    required this.explanation,
    required this.holds,
  });

  /// A short identifier, shown against the failure in the console.
  final String name;

  /// What goes wrong if it does not hold. Written for the person about to
  /// press publish, not for a log.
  final String explanation;

  /// Whether the rule holds for a resolved snapshot.
  final bool Function(ConfigSnapshot snapshot) holds;
}

/// Every key the running system declares, assembled by a composition root.
///
/// **Intention.** The console lists keys, descriptions and defaults, and the
/// validator needs to know which names exist so a typo is a refusal instead of
/// a value silently absorbed by a default. Both need one list.
///
/// **Rejected — a static `all` constant in `ekipa_core`.** It would have to
/// import `MatchingKeys`, which lives behind `package:ekipa_core/matching.dart`
/// precisely so the mobile app cannot reach it (D9, SC-6). A static registry
/// would drag the ring shares into every user's binary to satisfy a screen only
/// the operator sees. Assembling at the composition root costs one line in each
/// runtime's `main` and keeps the boundary where the lint can check it.
final class ConfigCatalogue {
  /// Assembles a catalogue from [groups].
  ///
  /// Throws [ArgumentError] if two groups declare the same key name. That is a
  /// programmer error with a silent failure mode — two descriptions and two
  /// defaults for one name, one of which wins by list order — so it fails at
  /// startup rather than at whichever read site loses.
  ConfigCatalogue(List<ConfigGroup> groups)
    : groups = List.unmodifiable(groups),
      _byName = _index(groups);

  static Map<String, ConfigKey<Object?>> _index(List<ConfigGroup> groups) {
    final byName = <String, ConfigKey<Object?>>{};
    for (final group in groups) {
      for (final key in group.keys) {
        if (byName.containsKey(key.name)) {
          throw ArgumentError.value(
            key.name,
            'groups',
            'declared twice; a key has exactly one default and one description',
          );
        }
        byName[key.name] = key;
      }
    }
    return Map.unmodifiable(byName);
  }

  /// The groups, in console order.
  final List<ConfigGroup> groups;

  final Map<String, ConfigKey<Object?>> _byName;

  /// Every declared key.
  Iterable<ConfigKey<Object?>> get keys => _byName.values;

  /// Every rule that holds between keys, across all groups.
  Iterable<ConfigInvariant> get invariants =>
      groups.expand((group) => group.invariants);

  /// The key called [name], or `null` if nothing declares it.
  ConfigKey<Object?>? keyNamed(String name) => _byName[name];

  /// The keys a change to which requires a typed confirmation (AC-6).
  Iterable<ConfigKey<Object?>> get safetyCritical =>
      _byName.values.where((key) => key.safetyCritical);
}
