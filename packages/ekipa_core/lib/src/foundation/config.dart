import 'package:ekipa_core/src/foundation/ids.dart';

/// A typed, named configuration key with a default.
///
/// **Intention.** Directive D5: *no behavioural constant is a literal in code.*
/// If a product person could reasonably want it different next month, it is a
/// config key. Typing the key rather than the read site means a mistyped value
/// in the database fails at one place with the key's name attached, instead of
/// producing a plausible-looking wrong number deep inside the matcher.
///
/// **Rejected — env vars / `--dart-define`.** A deploy per change, no audit
/// trail, no per-city override, and the app and the worker can silently
/// disagree about what a value is.
final class ConfigKey<T> {
  const ConfigKey._(
    this.name,
    this.defaultValue,
    this._parse,
    this.description,
  );

  /// An integer key, e.g. `matching.starve_cap_weeks`.
  static ConfigKey<int> integer(
    String name, {
    required int defaultValue,
    required String description,
  }) => ConfigKey<int>._(name, defaultValue, _parseInt, description);

  /// A fractional key, e.g. `matching.ring_a_enjoyed`.
  static ConfigKey<double> decimal(
    String name, {
    required double defaultValue,
    required String description,
  }) => ConfigKey<double>._(name, defaultValue, _parseDouble, description);

  /// A boolean flag, e.g. `dating.enabled`.
  static ConfigKey<bool> boolean(
    String name, {
    required bool defaultValue,
    required String description,
  }) => ConfigKey<bool>._(name, defaultValue, _parseBool, description);

  /// A string key, e.g. `identity.provider`.
  static ConfigKey<String> text(
    String name, {
    required String defaultValue,
    required String description,
  }) => ConfigKey<String>._(name, defaultValue, _parseString, description);

  /// A duration key. Stored as whole seconds, because a JSON number is the only
  /// representation both Postgres and Dart agree on without a parser.
  static ConfigKey<Duration> duration(
    String name, {
    required Duration defaultValue,
    required String description,
  }) => ConfigKey<Duration>._(name, defaultValue, _parseDuration, description);

  /// The dotted key name as stored in `config_values`.
  final String name;

  /// The value used when no version supplies one.
  final T defaultValue;

  /// What this key controls. Rendered in the console's config editor, so it is
  /// documentation with a reader rather than a comment nobody opens.
  final String description;

  final T? Function(Object? raw) _parse;

  /// Interprets [raw], falling back to [defaultValue] when absent or
  /// unparseable.
  ///
  /// Falling back rather than throwing is deliberate: a single malformed row
  /// must not take the nightly match run down. The fallback is observable — see
  /// [ConfigSnapshot.malformedKeys] — so it degrades loudly rather than
  /// silently.
  T read(Object? raw) {
    if (raw == null) return defaultValue;
    return _parse(raw) ?? defaultValue;
  }

  /// Whether [raw] is a value this key can interpret.
  bool accepts(Object? raw) => raw == null || _parse(raw) != null;

  static int? _parseInt(Object? raw) => switch (raw) {
    final int v => v,
    final double v when v == v.roundToDouble() => v.toInt(),
    final String v => int.tryParse(v),
    _ => null,
  };

  static double? _parseDouble(Object? raw) => switch (raw) {
    final num v => v.toDouble(),
    final String v => double.tryParse(v),
    _ => null,
  };

  static bool? _parseBool(Object? raw) => switch (raw) {
    final bool v => v,
    'true' => true,
    'false' => false,
    _ => null,
  };

  static String? _parseString(Object? raw) => raw is String ? raw : null;

  static Duration? _parseDuration(Object? raw) {
    final seconds = _parseInt(raw);
    return seconds == null ? null : Duration(seconds: seconds);
  }

  @override
  String toString() => 'ConfigKey($name)';
}

/// One immutable resolution of configuration, taken once at the start of a run.
///
/// **Intention.** Directive D5, and the failure it prevents is specific:
/// shorten the confirmation window at 11:00 while forty people hold a 09:00
/// confirmation, and without versioning you have just penalised people under a
/// rule that did not exist when they were asked. That is the most
/// trust-destroying class of bug this product can have, and it is invisible
/// without this type.
///
/// A run resolves one snapshot and passes it down as a parameter. **Nothing
/// reads configuration from a global** — that was defect S1 in the legacy
/// audit.
final class ConfigSnapshot {
  /// Builds a snapshot from raw key/value pairs as stored in `config_values`.
  ConfigSnapshot({
    required this.versionId,
    required Map<String, Object?> values,
  }) : _values = Map.unmodifiable(values);

  /// A snapshot in which every key falls back to its declared default.
  ///
  /// For tests and for the very first run, before any version exists.
  ConfigSnapshot.defaults({ConfigVersionId? versionId})
    : versionId = versionId ?? const ConfigVersionId('defaults'),
      _values = const {};

  /// The version these values came from. Recorded on every `match_run`, every
  /// `sanction` and every `hangout`, so a historical decision can be re-read
  /// under the rules that actually applied to it.
  final ConfigVersionId versionId;

  final Map<String, Object?> _values;

  /// Reads [key], falling back to its default when unset or malformed.
  T get<T>(ConfigKey<T> key) => key.read(_values[key.name]);

  /// Whether this version supplies an explicit value for [key].
  bool hasExplicitValue<T>(ConfigKey<T> key) => _values.containsKey(key.name);

  /// The names of keys whose stored value could not be interpreted, given
  /// [declared]. Surfaced on the console so a typo is visible rather than
  /// silently absorbed by a default.
  List<String> malformedKeys(Iterable<ConfigKey<Object?>> declared) => [
    for (final key in declared)
      if (_values.containsKey(key.name) && !key.accepts(_values[key.name]))
        key.name,
  ];

  @override
  String toString() =>
      'ConfigSnapshot(${versionId.value}, ${_values.length} explicit)';
}
