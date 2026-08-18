// Migration lint. Controls DP-1, DP-2, DP-5, DP-6 and rule 10 in
// docs/v3/11_SECURITY.md.
//
// IO only: it reads supabase/migrations/*.sql in order and hands each file to
// the pure scanner in lib/sql_rules.dart, which is where the rules live and
// where they are tested.
//
// Run: dart run tools/lint/bin/migration_lint.dart
// Exit 0 clean, 1 on any violation.

import 'dart:io';

import 'package:lint/sql_rules.dart';

const _migrations = 'supabase/migrations';

void main(List<String> args) {
  final directory = Directory(args.isEmpty ? _migrations : args.first);
  if (!directory.existsSync()) {
    stderr.writeln('migration lint: no such directory: ${directory.path}');
    exitCode = 1;
    return;
  }

  final files =
      directory
          .listSync()
          .whereType<File>()
          .where((f) => f.path.toLowerCase().endsWith('.sql'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  final violations = <SqlViolation>[];
  for (final file in files) {
    final relative = file.path.replaceAll(r'\', '/');
    violations.addAll(scanMigration(relative, file.readAsStringSync()));
  }

  if (violations.isEmpty) {
    stdout.writeln('migration lint: ${files.length} migrations, clean.');
    return;
  }

  stderr
    ..writeln('migration lint: ${violations.length} violation(s)\n')
    ..writeln(violations.join('\n'));
  exitCode = 1;
}
