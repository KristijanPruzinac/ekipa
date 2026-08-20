// Dependency-rule lint. Control SC-6 in docs/v3/11_SECURITY.md.
//
// This binary is IO only: it walks the tree and hands each file to the pure
// scanner in lib/rules.dart, which is where the rules live and where they are
// tested. Keeping the rules pure is the same move the architecture asks of the
// product code, applied to the tool that enforces it.
//
// Run: dart run tools/lint/bin/dependency_lint.dart Exit 0 clean, 1 on any
// violation.

import 'dart:io';

import 'package:lint/rules.dart';

void main(List<String> args) {
  final root = Directory.current;
  final rootPath = root.path.replaceAll(r'\', '/');

  final files =
      root
          .listSync(recursive: true, followLinks: false)
          .whereType<File>()
          .where((f) => f.path.endsWith('.dart'))
          .map((f) => (file: f, rel: _relative(f.path, rootPath)))
          .where((e) => !isIgnored(e.rel))
          .toList()
        ..sort((a, b) => a.rel.compareTo(b.rel));

  final violations = <Violation>[];
  for (final entry in files) {
    violations.addAll(scanFile(entry.rel, entry.file.readAsLinesSync()));
  }

  if (violations.isEmpty) {
    stdout.writeln(
      'dependency lint: ${files.length} files, ${rules.length} rules, clean.',
    );
    return;
  }

  stderr
    ..writeln('dependency lint: ${violations.length} violation(s)\n')
    ..writeln(violations.join('\n'));
  exitCode = 1;
}

String _relative(String path, String rootPath) {
  final normalised = path.replaceAll(r'\', '/');
  if (!normalised.startsWith(rootPath)) return normalised;
  final cut = normalised.substring(rootPath.length);
  return cut.startsWith('/') ? cut.substring(1) : cut;
}
