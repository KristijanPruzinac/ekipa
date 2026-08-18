import 'dart:io';

import 'package:lint/sql_rules.dart';
import 'package:test/test.dart';

/// Scans one synthetic migration and returns the ids that fired.
List<String> idsFor(String sql) => scanMigration(
  'supabase/migrations/9999_test.sql',
  sql,
).map((v) => v.id).toList();

/// The repository's `supabase/migrations`, wherever the suite is run from.
Directory _migrationsDirectory() {
  var here = Directory.current.absolute;
  for (var depth = 0; depth < 6; depth++) {
    final candidate = Directory('${here.path}/supabase/migrations');
    if (candidate.existsSync()) return candidate;
    final up = here.parent;
    if (up.path == here.path) break;
    here = up;
  }
  throw StateError(
    'supabase/migrations not found above ${Directory.current.path}',
  );
}

/// A well-formed table, used as the baseline the negative cases mutate.
const _goodTable = '''
create table public.thing (
  id uuid primary key
);
alter table public.thing enable row level security;
revoke all on table public.thing from anon, authenticated;
''';

/// A well-formed function, likewise.
const _goodFunction = r'''
create or replace function public.mine()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select p.id from public.people p where p.auth_user_id = auth.uid()
$$;
revoke all on function public.mine() from public, anon;
grant execute on function public.mine() to authenticated;
''';

void main() {
  group('the splitter survives the constructs migrations actually contain', () {
    test('a dollar-quoted body does not end a statement at its semicolons', () {
      final statements = splitStatements(_goodFunction);
      expect(statements, hasLength(3));
      expect(statements.first.code, contains('security definer'));
      expect(statements[1].code, startsWith('revoke all on function'));
    });

    test('a semicolon inside a string literal is not a terminator', () {
      final statements = splitStatements(
        "insert into t (a) values ('one; two');\n",
      );
      expect(statements, hasLength(1));
    });

    test('a trailing comment belongs to the statement it follows', () {
      final statements = splitStatements(
        'create policy p on t for select using (true);  -- catalogue: why\n'
        'select 1;\n',
      );
      expect(statements.first.text, contains('-- catalogue:'));
      expect(statements[1].text, isNot(contains('catalogue')));
    });

    test('line numbers survive a multi-line body', () {
      final statements = splitStatements('select 1;\n\n\nselect 2;\n');
      expect(statements[1].line, 4);
    });
  });

  group('every rule fires on the thing it forbids', () {
    // Each case is the mistake as it would actually be made: not sabotage, but
    // the line somebody writes at the end of a long migration.

    test('DP-1 — a table created without RLS', () {
      expect(
        idsFor('create table public.thing (id uuid primary key);'),
        contains('DP-1'),
      );
    });

    test('DP-1 — but not when RLS is enabled in the same file', () {
      expect(idsFor(_goodTable), isNot(contains('DP-1')));
    });

    test('DP-2 — a permissive policy with no stated reason', () {
      expect(
        idsFor(
          '$_goodTable'
          'create policy thing_read on public.thing\n'
          '  for select to authenticated using (true);\n',
        ),
        contains('DP-2'),
      );
    });

    test('DP-2 — but not when the catalogue marker says why', () {
      expect(
        idsFor(
          '$_goodTable'
          'create policy thing_read on public.thing\n'
          '  for select to authenticated using (true);'
          '  -- catalogue: options\n',
        ),
        isNot(contains('DP-2')),
      );
    });

    test('DP-5 — a security definer function with a mutable search_path', () {
      expect(
        idsFor(r'''
create function public.mine() returns uuid language sql security definer
as $$ select auth.uid() $$;
revoke all on function public.mine() from public, anon;
grant execute on function public.mine() to authenticated;
'''),
        contains('DP-5'),
      );
    });

    test('DP-5-CALLER — a definer function that never looks at the caller', () {
      expect(
        idsFor(r'''
create function public.everyone() returns setof public.people
language sql security definer set search_path = public
as $$ select * from public.people $$;
revoke all on function public.everyone() from public, anon;
grant execute on function public.everyone() to authenticated;
'''),
        contains('DP-5-CALLER'),
      );
    });

    test('DP-5-REVOKE — a function left with its default PUBLIC grant', () {
      expect(
        idsFor(r'''
create function public.mine() returns uuid language sql security definer
set search_path = public as $$ select auth.uid() $$;
grant execute on function public.mine() to authenticated;
'''),
        contains('DP-5-REVOKE'),
      );
    });

    test('DP-5-GRANT — a function nobody says who may call', () {
      expect(
        idsFor(r'''
create function public.mine() returns uuid language sql security definer
set search_path = public as $$ select auth.uid() $$;
revoke all on function public.mine() from public, anon;
'''),
        contains('DP-5-GRANT'),
      );
    });

    test('DP-6 — revoking from PUBLIC alone, the v1 mistake', () {
      expect(
        idsFor(
          '$_goodFunction'
          'revoke execute on function public.mine() from public;\n',
        ),
        contains('DP-6'),
      );
    });

    test('DP-6 — but not when anon is named as well', () {
      expect(idsFor(_goodFunction), isNot(contains('DP-6')));
    });

    test('EVIDENCE — dropping a trust table', () {
      expect(idsFor('drop table public.infractions;'), contains('EVIDENCE'));
    });

    test('EVIDENCE — or quietly shortening one', () {
      expect(
        idsFor('alter table public.sanctions drop column evidence;'),
        contains('EVIDENCE'),
      );
    });

    test('a clean migration fires nothing at all', () {
      expect(idsFor('$_goodTable$_goodFunction'), isEmpty);
    });
  });

  group('the migrations in this repository', () {
    // The rules above are proven to fire. This is the other half: they are
    // proven to be satisfied by the schema as it stands, so a green suite means
    // something about the real database rather than about the test fixtures.
    test('all pass the lint', () {
      // Found by walking up rather than assumed relative to the CWD. CI runs
      // this suite from tools/lint, and a test that quietly skipped there would
      // be a check nobody has ever watched pass.
      final directory = _migrationsDirectory();
      final violations = <SqlViolation>[];
      for (final file in directory.listSync().whereType<File>()) {
        if (!file.path.toLowerCase().endsWith('.sql')) continue;
        violations.addAll(
          scanMigration(
            file.path.replaceAll(r'\', '/'),
            file.readAsStringSync(),
          ),
        );
      }
      expect(violations.map((v) => v.toString()).join('\n'), isEmpty);
    });
  });
}
