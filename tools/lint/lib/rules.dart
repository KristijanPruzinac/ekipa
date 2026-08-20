/// The dependency-rule table and the pure scanner over it. Control SC-6 in
/// `docs/v3/11_SECURITY.md`.
///
/// The architecture in `01_ARCHITECTURE.md` §4 is only real if a machine
/// enforces it. Discipline degrades under deadline; lints do not.
///
/// The scan is a pure function over `(path, lines)` so that every rule can be
/// proven to fire in `test/rules_test.dart`. A lint nobody has watched fail is
/// indistinguishable from a lint that passes everything, and it will be
/// discovered to have been broken on the day it was needed.
library;

/// One forbidden pattern within one part of the tree.
final class Rule {
  /// Declares a rule.
  const Rule({
    required this.id,
    required this.scope,
    required this.pattern,
    required this.forbids,
    required this.why,
    this.exempt = const [],
  });

  /// Stable identifier, quoted in CI output and in `CONTRIBUTING.md`.
  final String id;

  /// Path prefix this rule applies to, using forward slashes. Empty means
  /// everywhere.
  final String scope;

  /// What is not allowed to appear.
  final RegExp pattern;

  /// One line naming the forbidden thing.
  final String forbids;

  /// Why, in terms of the failure it prevents. This is what the person who
  /// trips the rule reads at 2am, and it decides whether they fix the cause or
  /// add an ignore comment.
  final String why;

  /// Path prefixes inside [scope] where the rule does not apply.
  final List<String> exempt;
}

/// A single rule breach at a single line.
final class Violation {
  /// Records a breach.
  const Violation({
    required this.rule,
    required this.path,
    required this.line,
    required this.source,
  });

  /// The rule that fired.
  final Rule rule;

  /// Repository-relative path, forward slashes.
  final String path;

  /// One-based line number.
  final int line;

  /// The offending source line, trimmed.
  final String source;

  @override
  String toString() =>
      '  $path:$line  [${rule.id}]\n'
      '    $source\n'
      '    forbids: ${rule.forbids}\n'
      '    why: ${rule.why}\n';
}

const _core = 'packages/ekipa_core/lib';
const _mobile = 'apps/mobile/lib';
const _console = 'apps/console/lib';
const _ui = 'packages/ekipa_ui/lib';

/// Every rule enforced by CI.
final List<Rule> rules = [
  // ── D1: the quarantine is mechanical ──────────────────────────────────────
  Rule(
    id: 'NO-LEGACY-IMPORT',
    scope: '',
    pattern: RegExp(r'''(import|export)\s+['"][^'"]*legacy/'''),
    forbids: 'importing quarantined v1/v2 source',
    why:
        'Directive D1. legacy/ is deleted at P2 exit, so anything importing '
        'it stops compiling that day. If something in there is genuinely '
        'needed, rewrite it in the new structure.',
    exempt: ['legacy/'],
  ),

  // ── D2/D3: ekipa_core stays pure ─────────────────────────────────────────
  Rule(
    id: 'CORE-NO-FLUTTER',
    scope: _core,
    pattern: RegExp(r'''import\s+['"]package:flutter/'''),
    forbids: 'importing Flutter into the pure core',
    why:
        'ekipa_core is compiled by the worker and the simulator, neither of '
        'which has a Flutter SDK. A Flutter import breaks the build for two of '
        'its four consumers and ends the shared-algorithm property (D3).',
  ),
  Rule(
    id: 'CORE-NO-IO',
    scope: _core,
    pattern: RegExp(r'''import\s+['"]dart:(io|html|js|ffi|isolate)'''),
    forbids: 'importing an IO library into the pure core',
    why:
        'The domain must run inside a test with no filesystem, no network and '
        'no platform. Every side effect it needs is a port, implemented in '
        'ekipa_data.',
  ),
  Rule(
    id: 'CORE-NO-BACKEND',
    scope: _core,
    pattern: RegExp(
      r'''import\s+['"]package:(supabase|postgres|firebase|http)''',
    ),
    forbids: 'importing a backend client into the pure core',
    why:
        'Legacy defect S4: domain types that parse database rows cannot be '
        'tested or reused without a schema, which blocks D3 outright.',
  ),
  Rule(
    id: 'CORE-NO-WALL-CLOCK',
    scope: _core,
    pattern: RegExp(r'DateTime\.now\s*\('),
    forbids: 'reading the wall clock in the pure core',
    why:
        'Seven deadlines per hangout fire with no user present. Reading '
        'DateTime.now() makes them untestable and DST bugs unreproducible. '
        'Inject a Clock; the only real one is SystemClock in ekipa_data.',
  ),
  Rule(
    id: 'CORE-NO-UNSEEDED-RANDOM',
    scope: _core,
    pattern: RegExp(r'\bRandom\s*\(\s*\)'),
    forbids: 'constructing an unseeded Random in the pure core',
    why:
        'Same snapshot plus same seed must produce a byte-identical plan, or a '
        'match run cannot be replayed and no golden test of the matcher means '
        'anything. Use RandomSource.',
  ),
  Rule(
    id: 'CORE-NO-PRINT',
    scope: _core,
    pattern: RegExp(r'(?<![\w.$])print\s*\('),
    forbids: 'printing from the pure core',
    why:
        'Rule 5 of 11_SECURITY.md §8: never log names, hashes, anchors, '
        'ratings or standing. The core handles all five, and a print in a '
        'library reaches whatever log its host is wired to.',
  ),

  // ── D9: the matchmaker is unreachable from a user's device ───────────────
  Rule(
    id: 'MOBILE-NO-MATCHING',
    scope: _mobile,
    pattern: RegExp(r'''import\s+['"]package:ekipa_core/matching\.dart'''),
    forbids: 'importing the matcher into the mobile app',
    why:
        'Directive D9. A user who can read the matcher can infer, from their '
        'own match history, how other people rated them — which breaks the '
        'asymmetry invariant, the load-bearing privacy promise in the product. '
        'It is also an anti-gaming control.',
  ),
  Rule(
    id: 'MOBILE-NO-SERVICE-ROLE',
    scope: _mobile,
    pattern: RegExp('service_?[rR]ole|SUPABASE_SERVICE'),
    forbids: 'referencing the service-role credential in a user build',
    why:
        'The service-role key exists in exactly one place: the worker. In a '
        'Flutter binary it is extractable, and it bypasses every RLS policy — '
        'which is the entire privacy model.',
  ),
  Rule(
    id: 'CONSOLE-NO-SERVICE-ROLE',
    scope: _console,
    pattern: RegExp('service_?[rR]ole|SUPABASE_SERVICE'),
    forbids: 'referencing the service-role credential in the console',
    why:
        'AC-4: no service-role key in the browser. Every console action is an '
        'audited RPC that re-checks the role server-side.',
  ),

  // ── The design system takes value objects, never infrastructure ──────────
  Rule(
    id: 'UI-NO-DATA',
    scope: _ui,
    pattern: RegExp(
      r'''import\s+['"]package:(ekipa_data|supabase|postgres|firebase|http)''',
    ),
    forbids: 'importing infrastructure into the design system',
    why:
        'ekipa_ui depends on ekipa_core for value objects so that PersonName '
        'can refuse a raw String. That is the whole of the allowance. A '
        'primitive that can reach a backend client is a primitive that will '
        'eventually fetch something, and then no screen can be rendered in a '
        'widget test without a network.',
  ),
  Rule(
    id: 'UI-NO-MATCHING',
    scope: _ui,
    pattern: RegExp(r'''import\s+['"]package:ekipa_core/matching\.dart'''),
    forbids: 'importing the matcher into the design system',
    why:
        'Directive D9, by the back door: ekipa_ui is compiled into the mobile '
        'binary, so a matching import here defeats MOBILE-NO-MATCHING without '
        'tripping it.',
  ),

  // ── D8 / C-3: platform differences stay countable ────────────────────────
  Rule(
    id: 'PLATFORM-BRANCH-CONFINED',
    scope: _mobile,
    pattern: RegExp(r'Platform\.(isAndroid|isIOS|isMacOS|isWindows|isLinux)'),
    forbids: 'branching on the platform outside apps/mobile/lib/platform/',
    why:
        'iOS is deferred, not abandoned. The mitigation for "Android-only '
        'assumptions get baked in silently" is structural: every platform '
        'difference lives behind one interface in one folder, and is therefore '
        'countable on the day iOS resumes.',
    exempt: ['apps/mobile/lib/platform/'],
  ),
];

/// Files the scanner never inspects.
bool isIgnored(String relativePath) =>
    relativePath.contains('/.dart_tool/') ||
    relativePath.startsWith('.dart_tool/') ||
    relativePath.contains('/build/') ||
    relativePath.startsWith('build/') ||
    relativePath.endsWith('.g.dart') ||
    relativePath.endsWith('.freezed.dart') ||
    relativePath.endsWith('.mocks.dart') ||
    // The rule table necessarily contains every string it forbids.
    relativePath.startsWith('tools/lint/');

/// Applies every applicable rule to one file's [lines].
///
/// Comment lines are skipped so that documenting a rule — as this repository
/// does constantly — never trips it.
List<Violation> scanFile(
  String relativePath,
  List<String> lines, {
  List<Rule>? using,
}) {
  final applied = using ?? rules;
  final found = <Violation>[];

  for (var index = 0; index < lines.length; index++) {
    final line = lines[index];
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('//')) continue;

    for (final rule in applied) {
      if (rule.scope.isNotEmpty && !relativePath.startsWith(rule.scope)) {
        continue;
      }
      if (rule.exempt.any(relativePath.startsWith)) continue;
      if (!rule.pattern.hasMatch(line)) continue;
      found.add(
        Violation(
          rule: rule,
          path: relativePath,
          line: index + 1,
          source: line.trim(),
        ),
      );
    }
  }
  return found;
}
