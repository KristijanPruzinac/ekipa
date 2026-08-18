import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_core/matching.dart';

/// Everything the CLI can be told, parsed from `argv`.
///
/// **Hand-rolled rather than `package:args`.** SC-2 asks for a written
/// justification per dependency, and "we parse eight flags in one binary that
/// never ships" does not survive being written down. The parser below is
/// forty lines and its failure mode is a thrown [FormatException] with the
/// offending argument in it, which is the whole feature set required.
final class Options {
  /// Records parsed options.
  const Options({
    required this.weeks,
    required this.people,
    required this.seed,
    required this.overrides,
    required this.asJson,
    required this.compare,
  });

  /// Parses [arguments], or throws [FormatException] naming the bad one.
  factory Options.parse(List<String> arguments) {
    var weeks = 12;
    var people = 120;
    var seed = 1;
    var asJson = false;
    var compare = false;
    final overrides = <String, Object?>{};
    final declared = {for (final key in MatchingKeys.all) key.name: key};

    for (var i = 0; i < arguments.length; i++) {
      final argument = arguments[i];
      if (argument == '--json') {
        asJson = true;
      } else if (argument == '--compare') {
        compare = true;
      } else if (argument.startsWith('--weeks=')) {
        weeks = _int(argument);
      } else if (argument.startsWith('--people=')) {
        people = _int(argument);
      } else if (argument.startsWith('--seed=')) {
        seed = _int(argument);
      } else if (argument == '--set') {
        if (i + 1 >= arguments.length) {
          throw const FormatException('--set needs a key=value');
        }
        _override(arguments[++i], declared, overrides);
      } else if (argument.startsWith('--set=')) {
        _override(argument.substring('--set='.length), declared, overrides);
      } else {
        throw FormatException('unknown argument: $argument');
      }
    }

    return Options(
      weeks: weeks,
      people: people,
      seed: seed,
      overrides: overrides,
      asJson: asJson,
      compare: compare,
    );
  }

  /// How many weeks to simulate.
  final int weeks;

  /// How many agents exist in week zero.
  final int people;

  /// The run seed.
  final int seed;

  /// Matching config overrides, by key name.
  final Map<String, Object?> overrides;

  /// Whether to print JSON instead of the table.
  final bool asJson;

  /// Whether to also run the defaults and print the delta.
  ///
  /// The point of the harness in one flag: a config change is only interesting
  /// next to the run it changed, and a reader comparing two tables by eye will
  /// miss a three-point move in newcomer wait time every time.
  final bool compare;

  /// The usage text, kept beside the parser so they cannot drift.
  static const usage = '''
usage: dart run simulator [options]

  --weeks=N          weeks to simulate (default 12)
  --people=N         starting population (default 120)
  --seed=N           run seed (default 1)
  --set key=value    override one matching config key; repeatable
  --json             print the metric table as JSON
  --compare          also run with declared defaults and print the delta
  --help             this text

config keys:
''';

  /// The matching configuration these options describe.
  MatchConfig get config => MatchConfig.from(
    ConfigSnapshot(
      versionId: ConfigVersionId(
        overrides.isEmpty ? 'defaults' : 'sim-override',
      ),
      values: overrides,
    ),
  );

  /// The configuration with nothing overridden, for `--compare`.
  MatchConfig get baseline => MatchConfig.from(ConfigSnapshot.defaults());

  static void _override(
    String pair,
    Map<String, ConfigKey<Object?>> declared,
    Map<String, Object?> into,
  ) {
    final split = pair.indexOf('=');
    if (split <= 0) throw FormatException('expected key=value, got: $pair');
    final name = pair.substring(0, split);
    final raw = pair.substring(split + 1);
    final key = declared[name];
    // Rejecting an unknown key rather than storing it is the point. A typo in a
    // key name would otherwise be absorbed silently by the default, and the run
    // would report that the change did nothing — which is true, and useless.
    if (key == null) throw FormatException('unknown config key: $name');
    final parsed = num.tryParse(raw) ?? raw;
    if (!key.accepts(parsed)) {
      throw FormatException('value $raw is not valid for $name');
    }
    into[name] = parsed;
  }

  static int _int(String argument) {
    final value = int.tryParse(argument.split('=').last);
    if (value == null || value < 0) {
      throw FormatException('expected a non-negative integer: $argument');
    }
    return value;
  }
}
