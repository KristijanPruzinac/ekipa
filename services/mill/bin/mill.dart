/// Entry point for the worker.
///
/// Zone 2 in the trust model (`docs/v3/11_SECURITY.md` §3): no inbound port, no
/// URL, no listener. It is invoked by a scheduler, does its work, and exits —
/// which is why a pull-based GitHub Actions cron satisfies D9 more completely
/// than an authenticated HTTP endpoint would. There is nothing to attack that
/// is not already the database.
///
/// ```text
/// dart run mill:mill sweep          every few minutes
/// dart run mill:mill match          once a day, per active city
/// dart run mill:mill match --city <uuid> --seed 42 --dry-run
/// ```
///
/// **The exit code is the interface.** `0` means the job did what it was asked;
/// anything else means the scheduler should say so. A worker that swallowed its
/// failures and exited zero would make a cron job that has been broken for a
/// fortnight indistinguishable from one that has nothing to do — which is the
/// exact failure mode a system with no operator on duty cannot have (D11).
///
/// **Nothing here prints a name, an identity hash, an anchor, a rating, a
/// report, or a standing** (`11_SECURITY.md §8` rule 5). The reports below
/// carry counts and city ids, and that is on purpose: this output goes to a CI
/// log in a public repository.
library;

import 'dart:io';

import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_data/ekipa_data.dart';
import 'package:mill/src/jobs.dart';
import 'package:mill/src/postgrest.dart';

Future<void> main(List<String> args) async {
  final job = args.isEmpty ? 'help' : args.first;
  final flags = _flags(args.skip(1));

  if (job == 'help' || flags.containsKey('help')) {
    stdout.writeln(_usage);
    return;
  }

  final Postgrest db;
  try {
    db = Postgrest.fromEnvironment();
  } on MissingCredential catch (missing) {
    // Refuse to start rather than fail on the first call. A worker that
    // discovers it has no credentials halfway through a match run has already
    // written a stack trace into a log; one that refuses has told the
    // scheduler something it can act on.
    stderr.writeln('mill: $missing');
    exitCode = 78; // EX_CONFIG
    return;
  }

  // The defaults, until the worker reads a published version. `ConfigSnapshot`
  // falls every key back to its declared default, so a city with no config
  // rows runs on the numbers in `LifecycleKeys` and `TrustKeys` rather than on
  // nothing — and the version id recorded against the run says `defaults`,
  // which is the honest answer.
  final config = ConfigSnapshot.defaults();
  final mill = Mill(db, const SystemClock());

  try {
    switch (job) {
      case 'sweep':
        stdout.writeln(await mill.sweep(config: config));
      case 'match':
        final city = flags['city'];
        if (city == null) {
          stderr.writeln('mill: match needs --city <uuid>');
          exitCode = 64; // EX_USAGE
          return;
        }
        stdout.writeln(
          await mill.matchCity(
            CityId(city),
            config: config,
            seed: int.tryParse(flags['seed'] ?? ''),
          ),
        );
      default:
        stderr.writeln('mill: no job called "$job"');
        stderr.writeln(_usage);
        exitCode = 64;
    }
  } on PostgrestFailure catch (failure) {
    // The body carries the Postgres error and its code, which is diagnostic.
    // The key is in a header, and headers are never in this message.
    stderr.writeln('mill: $failure');
    exitCode = failure.isRefusal ? 77 : 70; // EX_NOPERM / EX_SOFTWARE
  } finally {
    db.close();
  }
}

Map<String, String> _flags(Iterable<String> args) {
  final flags = <String, String>{};
  String? pending;
  for (final arg in args) {
    if (arg.startsWith('--')) {
      if (pending != null) flags[pending] = '';
      pending = arg.substring(2);
    } else if (pending != null) {
      flags[pending] = arg;
      pending = null;
    }
  }
  if (pending != null) flags[pending] = '';
  return flags;
}

const String _usage = '''
mill — the ekipa worker

  sweep                     advance every hangout the clock says is due
  match --city <uuid>       form groups for one city
        [--seed <int>]      override the derived seed, for a replay

Environment:
  SUPABASE_URL              the project's base URL
  SUPABASE_SERVICE_ROLE_KEY the worker's key. One place only, never a build.
''';
