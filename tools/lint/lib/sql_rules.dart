/// The migration lint. Controls DP-1, DP-2, DP-5 and DP-6 in
/// `docs/v3/11_SECURITY.md`, plus rule 10 of its §8.
///
/// The rules here are the four that were learned expensively rather than the
/// four that are easiest to check. Every one of them describes a mistake that
/// is **silent**: a table without RLS serves rows and looks fine, a
/// `revoke … from public` reports success and changes nothing, a
/// `security definer` function with a mutable `search_path` works perfectly
/// until somebody creates a schema. None of these fail a test that was not
/// written to look for them, which is exactly why they are here and not in a
/// review checklist.
///
/// Like `rules.dart`, this is a pure function over `(path, source)` so that
/// every rule can be proven to fire in `test/sql_rules_test.dart`.
library;

/// One breach of one migration rule.
final class SqlViolation {
  /// Records a breach.
  const SqlViolation({
    required this.id,
    required this.path,
    required this.line,
    required this.subject,
    required this.forbids,
    required this.why,
  });

  /// Stable identifier, quoted in CI output.
  final String id;

  /// Repository-relative path, forward slashes.
  final String path;

  /// One-based line of the statement that tripped the rule.
  final int line;

  /// What the statement was about — a table name, a function name.
  final String subject;

  /// One line naming the forbidden thing.
  final String forbids;

  /// Why, in terms of the failure it prevents.
  final String why;

  @override
  String toString() =>
      '  $path:$line  [$id]  $subject\n'
      '    forbids: $forbids\n'
      '    why: $why\n';
}

/// One top-level SQL statement, with the comments that belong to it.
final class Statement {
  /// Records a statement.
  const Statement({required this.text, required this.line});

  /// The statement source, comments included, `;` excluded.
  final String text;

  /// One-based line the statement starts on.
  final int line;

  /// The statement with comments removed and whitespace collapsed, which is
  /// what every rule matches against.
  String get code {
    final stripped = text
        .replaceAll(RegExp(r'--[^\n]*'), ' ')
        .replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), ' ');
    return stripped.replaceAll(RegExp(r'\s+'), ' ').trim().toLowerCase();
  }
}

/// Splits [source] into top-level statements.
///
/// Written by hand rather than with a regex because of one construct: the
/// dollar-quoted function body. `$$ … ; … $$` contains semicolons that are not
/// statement terminators, and every rule below would mis-attribute them —
/// which would make the lint wrong in precisely the files that matter most.
List<Statement> splitStatements(String source) {
  final statements = <Statement>[];
  final buffer = StringBuffer();
  var line = 1;
  var startLine = 1;
  var index = 0;

  void flush() {
    final text = buffer.toString();
    if (text.trim().isNotEmpty) {
      statements.add(Statement(text: text, line: startLine));
    }
    buffer.clear();
    startLine = line;
  }

  while (index < source.length) {
    final char = source[index];

    // A line comment runs to the newline and is kept, because `-- catalogue:`
    // is load-bearing evidence for DP-2.
    if (char == '-' && index + 1 < source.length && source[index + 1] == '-') {
      final end = source.indexOf('\n', index);
      final stop = end == -1 ? source.length : end;
      buffer.write(source.substring(index, stop));
      index = stop;
      continue;
    }

    if (char == "'") {
      final end = _endOfSingleQuoted(source, index);
      buffer.write(source.substring(index, end));
      line += _newlinesIn(source.substring(index, end));
      index = end;
      continue;
    }

    if (char == r'$') {
      final tag = _dollarTagAt(source, index);
      if (tag != null) {
        final close = source.indexOf(tag, index + tag.length);
        final end = close == -1 ? source.length : close + tag.length;
        buffer.write(source.substring(index, end));
        line += _newlinesIn(source.substring(index, end));
        index = end;
        continue;
      }
    }

    if (char == ';') {
      // A trailing comment on the same line belongs to the statement it
      // follows, not to the next one. `using (true);  -- catalogue: …` is the
      // shape the migrations actually use, and DP-2 reads that marker.
      var probe = index + 1;
      while (probe < source.length &&
          (source[probe] == ' ' || source[probe] == '\t')) {
        probe++;
      }
      if (probe + 1 < source.length &&
          source[probe] == '-' &&
          source[probe + 1] == '-') {
        final end = source.indexOf('\n', probe);
        final stop = end == -1 ? source.length : end;
        buffer.write(' ${source.substring(probe, stop)}');
        index = stop;
      } else {
        index++;
      }
      flush();
      continue;
    }

    if (char == '\n') {
      line++;
      if (buffer.toString().trim().isEmpty) startLine = line;
    }
    buffer.write(char);
    index++;
  }
  flush();
  return statements;
}

int _newlinesIn(String text) => '\n'.allMatches(text).length;

int _endOfSingleQuoted(String source, int start) {
  var index = start + 1;
  while (index < source.length) {
    if (source[index] == "'") {
      if (index + 1 < source.length && source[index + 1] == "'") {
        index += 2;
        continue;
      }
      return index + 1;
    }
    index++;
  }
  return source.length;
}

/// The opening `$$` or `$tag$` at [start], if there is one.
///
/// **No `^` in the pattern.** `matchAsPrefix` already anchors at [start], and
/// an anchored `^` matches only at offset zero — so for eight migrations this
/// returned `null` for every body in the file, dollar quoting never engaged,
/// and each function was shredded into fragments by its own semicolons. Nothing
/// failed loudly: the fragments simply did not look like a `create table` or a
/// `revoke`, so every rule read garbage and found nothing in it. The lint's own
/// suite passed throughout, because its fixtures are single statements.
String? _dollarTagAt(String source, int start) {
  final match = RegExp(r'\$[A-Za-z_]*\$').matchAsPrefix(source, start);
  return match?.group(0);
}

// ─────────────────────────────────────────────────────────────────────────────
// Patterns, each anchored to the shape the codebase actually writes.

final _createTable = RegExp(r'^create table (?:if not exists )?(\S+)');
final _enableRls = RegExp(r'^alter table (\S+) enable row level security');
final _createPolicy = RegExp(r'^create policy (\S+) on (\S+)');
final _permissive = RegExp(r'using \( true \)|using \(true\)');
final _createFunction = RegExp(
  r'^create (?:or replace )?function ([a-z0-9_.]+)\s*\(',
);
final _revokeFunction = RegExp(
  r'^revoke [^;]*on function ([a-z0-9_.]+)\s*\([^)]*\) from ([^;]*)$',
);
final _grantFunction = RegExp(
  r'^grant execute on function ([a-z0-9_.]+)\s*\([^)]*\) to ',
);
final _revokeAnything = RegExp(r'^revoke .* from ([^;]*)$');
final _drops = RegExp(
  '^(?:drop table|truncate)(?: if exists)? ([a-z0-9_.]+)'
  '|^alter table ([a-z0-9_.]+) drop ',
);

/// Tables whose rows are evidence. Rule 10: nothing here is dropped, truncated
/// or shortened without an explicit instruction, because a sanction that cannot
/// be explained months later is a sanction that cannot be appealed.
const evidenceTables = <String>{
  'infractions',
  'sanctions',
  'reports',
  'ratings',
  'hangout_events',
  'person_events',
  'admin_audit',
};

String _bare(String qualified) => qualified.split('.').last;

/// Applies every migration rule to one file.
List<SqlViolation> scanMigration(String path, String source) {
  final statements = splitStatements(source);
  final found = <SqlViolation>[];

  final created = <String, int>{};
  final rlsEnabled = <String>{};
  final functionsDefined = <String, int>{};
  final functionsRevoked = <String>{};
  final functionsGranted = <String>{};

  for (final statement in statements) {
    final code = statement.code;

    final table = _createTable.firstMatch(code);
    if (table != null) created[_bare(table.group(1)!)] = statement.line;

    final rls = _enableRls.firstMatch(code);
    if (rls != null) rlsEnabled.add(_bare(rls.group(1)!));

    // ── DP-2 ────────────────────────────────────────────────────────────────
    final policy = _createPolicy.firstMatch(code);
    if (policy != null &&
        _permissive.hasMatch(code) &&
        !statement.text.contains('-- catalogue:')) {
      found.add(
        SqlViolation(
          id: 'DP-2',
          path: path,
          line: statement.line,
          subject: policy.group(1)!,
          forbids: 'a permissive using (true) policy with no stated reason',
          why:
              'Deny by default. The catalogue genuinely needs a few of these, '
              'so the rule is not "never" — it is "say which, and why, on the '
              'line". A permissive policy nobody had to justify is how a '
              'people table becomes world-readable.',
        ),
      );
    }

    // ── DP-5 / DP-6, gathered here and judged after the whole file ──────────
    final function = _createFunction.firstMatch(code);
    if (function != null) {
      final name = _bare(function.group(1)!);
      functionsDefined[name] = statement.line;

      // The DP-2 shape, reused: an exception is allowed, and it has to be
      // written where a reader looks. A function callable by no role at all is
      // a legitimate thing — an internal helper that only another `security
      // definer` function calls — and it is indistinguishable from a function
      // somebody forgot to grant unless it says which it is. The marker goes in
      // the comment above the function, with the reason.
      if (statement.text.contains('-- internal:')) {
        functionsGranted.add(name);
      }

      if (code.contains('security definer')) {
        if (!code.contains('set search_path')) {
          found.add(
            SqlViolation(
              id: 'DP-5',
              path: path,
              line: statement.line,
              subject: name,
              forbids: 'a security definer function with a mutable search_path',
              why:
                  'The function runs as its owner. Without a pinned '
                  'search_path, anyone who can create a schema on the search '
                  'path chooses which `people` table it reads.',
            ),
          );
        }
        if (!_looksLikeItChecksTheCaller(_callerCheckWindow(code))) {
          found.add(
            SqlViolation(
              id: 'DP-5-CALLER',
              path: path,
              line: statement.line,
              subject: name,
              forbids:
                  'a security definer function with no visible caller check',
              why:
                  'DP-5 wants the caller checked in the first statement, and '
                  'only the declare block and the first statement after '
                  '`begin` are searched. This is the one heuristic in the '
                  'file: it looks for the five ways this codebase asks who is '
                  'calling, and it is asking a human to look rather than '
                  'claiming to have checked.',
            ),
          );
        }
      }
    }

    final revoke = _revokeFunction.firstMatch(code);
    if (revoke != null) functionsRevoked.add(_bare(revoke.group(1)!));

    final grant = _grantFunction.firstMatch(code);
    if (grant != null) functionsGranted.add(_bare(grant.group(1)!));

    // ── DP-6 ────────────────────────────────────────────────────────────────
    final anyRevoke = _revokeAnything.firstMatch(code);
    if (anyRevoke != null) {
      final roles = anyRevoke
          .group(1)!
          .split(',')
          .map((role) => role.trim())
          .toSet();
      if (roles.contains('public') && !roles.contains('anon')) {
        found.add(
          SqlViolation(
            id: 'DP-6',
            path: path,
            line: statement.line,
            subject: anyRevoke.group(1)!.trim(),
            forbids: 'revoking from PUBLIC without naming anon',
            why:
                'The v1 lesson, and the most expensive one in this repository: '
                'Supabase writes grants to anon and authenticated as explicit '
                'per-role ACL entries, so revoking from PUBLIC succeeds, '
                'reports success, and changes nothing.',
          ),
        );
      }
    }

    // ── Rule 10 ─────────────────────────────────────────────────────────────
    final drop = _drops.firstMatch(code);
    if (drop != null) {
      final target = _bare(drop.group(1) ?? drop.group(2)!);
      if (evidenceTables.contains(target)) {
        found.add(
          SqlViolation(
            id: 'EVIDENCE',
            path: path,
            line: statement.line,
            subject: target,
            forbids: 'dropping or shortening a trust or audit table',
            why:
                'Rule 10 of 11_SECURITY.md §8. Infractions, sanctions, reports '
                'and event logs are evidence: they are what makes a sanction '
                'explainable to a human months later, and an appeal possible '
                'at all.',
          ),
        );
      }
    }
  }

  // ── DP-1, judged over the file rather than the statement ──────────────────
  for (final entry in created.entries) {
    if (rlsEnabled.contains(entry.key)) continue;
    found.add(
      SqlViolation(
        id: 'DP-1',
        path: path,
        line: entry.value,
        subject: entry.key,
        forbids: 'creating a table without enabling row level security',
        why:
            'RLS must be enabled in the same migration that creates the table. '
            'A gap between the two is a window in which the table is served in '
            'full to every client, and nothing about it looks wrong.',
      ),
    );
  }

  for (final entry in functionsDefined.entries) {
    if (!functionsRevoked.contains(entry.key)) {
      found.add(
        SqlViolation(
          id: 'DP-5-REVOKE',
          path: path,
          line: entry.value,
          subject: entry.key,
          forbids: 'defining a function without revoking the default grant',
          why:
              'A new function is executable by PUBLIC. Not revoking is not a '
              'missing hardening step — it is publishing the function.',
        ),
      );
    }
    if (!functionsGranted.contains(entry.key)) {
      found.add(
        SqlViolation(
          id: 'DP-5-GRANT',
          path: path,
          line: entry.value,
          subject: entry.key,
          forbids: 'defining a function with no explicit grant',
          why:
              'Every function is either callable by a named role or by nobody, '
              'and which one it is should be written down. Silence here means '
              'the answer is whatever the last revoke happened to leave. A '
              'function nobody may call says so with `-- internal:` and a '
              'reason on its revoke line.',
        ),
      );
    }
  }

  found.sort((a, b) => a.line.compareTo(b.line));
  return found;
}

/// The one heuristic in this file, and it is deliberately a small closed list.
///
/// Five markers, one per way the codebase asks "who is this": the raw session
/// user, the person behind it, membership of a hangout, the console's role
/// gate, and the worker's. A function that checks its caller some sixth way has
/// to add itself here, which is the point — the rule cannot tell a real check
/// from a plausible-looking one, so it asks a human to look at anything it does
/// not already recognise.
///
/// **`auth.role()` was added when `0012` arrived**, and it is worth saying why
/// that is a widening rather than a weakening. The worker's functions open with
/// `if auth.role() is distinct from 'service_role' then raise`, which is a
/// *stronger* check than the four above it: those ask which person is calling,
/// this one asks which realm the request came from at all. The lint flagged six
/// functions; four were this form and two genuinely had no check, and both of
/// those were fixed rather than exempted. That is the rule working — it asked a
/// human to look, and looking found something.
bool _looksLikeItChecksTheCaller(String code) =>
    code.contains('auth.uid()') ||
    code.contains('current_person_id()') ||
    code.contains('is_member(') ||
    code.contains('admin_role()') ||
    code.contains('admin_at_least(') ||
    code.contains('auth.role()');

/// The part of a function the caller check has to appear in.
///
/// **Intention.** "Checked in the first statement" is the rule; scanning the
/// whole body would pass a function that reads four tables and then asks who
/// the caller is, which is a function that has already done the work.
///
/// The window is the declare block plus the first statement after `begin`,
/// because plpgsql's idiom for this is
/// `declare v_person uuid := public.current_person_id();` and that *is* the
/// check. A `language sql` body has no `begin` and is one expression, so the
/// whole of it is its first statement.
String _callerCheckWindow(String code) {
  final open = RegExp(r'\$[A-Za-z_]*\$').firstMatch(code);
  if (open == null) return code;
  final body = code.substring(open.end);

  final begin = RegExp(r'(?:^|\s)begin(?:\s|\$)').firstMatch(body);
  if (begin == null) return body;

  final after = body.substring(begin.end);
  final semicolon = after.indexOf(';');
  return body.substring(0, begin.end) +
      (semicolon == -1 ? after : after.substring(0, semicolon + 1));
}
