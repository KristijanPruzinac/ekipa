import 'dart:convert';
import 'dart:io';

import 'package:ekipa_core/matching.dart';
import 'package:simulator/simulator.dart';

/// Entry point for the simulator.
///
/// **The thinnest layer in the tool.** Everything it does is parse, run and
/// print; the run is a pure function of the options and the report is a pure
/// function of the run, so the interesting parts are all under test and this
/// file is the only place a `print` is allowed to appear.
void main(List<String> arguments) {
  if (arguments.contains('--help') || arguments.contains('-h')) {
    stdout
      ..write(Options.usage)
      ..writeln(_keyList());
    return;
  }

  final Options options;
  try {
    options = Options.parse(arguments);
  } on FormatException catch (error) {
    stderr
      ..writeln(error.message)
      ..writeln()
      ..write(Options.usage)
      ..writeln(_keyList());
    exitCode = 64; // EX_USAGE
    return;
  }

  final report = _run(options, options.config);

  if (options.asJson) {
    stdout.writeln(
      const JsonEncoder.withIndent('  ').convert({
        'run': report.toJson(),
        if (options.compare)
          'baseline': _run(options, options.baseline).toJson(),
      }),
    );
    return;
  }

  stdout.write(Report.render(report));
  if (options.compare) {
    // The baseline runs on the same seed and therefore the same founders and
    // the same arrivals. Two runs on different populations would differ for
    // reasons that have nothing to do with the config, which is the mistake
    // this flag exists to make impossible to commit by accident.
    stdout
      ..writeln()
      ..writeln(Report.delta(_run(options, options.baseline), report));
  }
}

SimulationReport _run(Options options, MatchConfig config) => Simulation(
  config: config,
  seed: options.seed,
  startingPeople: options.people,
  weeks: options.weeks,
).run();

String _keyList() => [
  for (final key in MatchingKeys.all)
    '  ${key.name.padRight(38)} ${key.defaultValue}',
].join('\n');
