import 'package:lint/rules.dart';
import 'package:test/test.dart';

/// Scans one synthetic file and returns the ids of the rules that fired.
List<String> idsFor(String path, String source) =>
    scanFile(path, source.split('\n')).map((v) => v.rule.id).toList();

void main() {
  group('every rule fires on the thing it forbids', () {
    // A lint nobody has watched fail is indistinguishable from a lint that
    // passes everything. Each case below is the violation as it would actually
    // be written by someone in a hurry.

    test('CORE-NO-FLUTTER', () {
      expect(
        idsFor(
          'packages/ekipa_core/lib/src/x.dart',
          "import 'package:flutter/material.dart';",
        ),
        contains('CORE-NO-FLUTTER'),
      );
    });

    test('CORE-NO-IO', () {
      expect(
        idsFor('packages/ekipa_core/lib/src/x.dart', "import 'dart:io';"),
        contains('CORE-NO-IO'),
      );
    });

    test('CORE-NO-BACKEND', () {
      expect(
        idsFor(
          'packages/ekipa_core/lib/src/x.dart',
          "import 'package:supabase/supabase.dart';",
        ),
        contains('CORE-NO-BACKEND'),
      );
    });

    test('CORE-NO-WALL-CLOCK', () {
      expect(
        idsFor(
          'packages/ekipa_core/lib/src/x.dart',
          'final now = DateTime.now();',
        ),
        contains('CORE-NO-WALL-CLOCK'),
      );
    });

    test('CORE-NO-UNSEEDED-RANDOM', () {
      expect(
        idsFor(
          'packages/ekipa_core/lib/src/x.dart',
          'final rng = Random();',
        ),
        contains('CORE-NO-UNSEEDED-RANDOM'),
      );
    });

    test('CORE-NO-PRINT', () {
      expect(
        idsFor('packages/ekipa_core/lib/src/x.dart', "print('hello');"),
        contains('CORE-NO-PRINT'),
      );
    });

    test('MOBILE-NO-MATCHING', () {
      expect(
        idsFor(
          'apps/mobile/lib/features/hangout/view.dart',
          "import 'package:ekipa_core/matching.dart';",
        ),
        contains('MOBILE-NO-MATCHING'),
      );
    });

    test('MOBILE-NO-SERVICE-ROLE', () {
      expect(
        idsFor(
          'apps/mobile/lib/main.dart',
          "const key = String.fromEnvironment('SUPABASE_SERVICE_KEY');",
        ),
        contains('MOBILE-NO-SERVICE-ROLE'),
      );
    });

    test('CONSOLE-NO-SERVICE-ROLE', () {
      expect(
        idsFor('apps/console/lib/main.dart', 'final c = serviceRole;'),
        contains('CONSOLE-NO-SERVICE-ROLE'),
      );
    });

    test('PLATFORM-BRANCH-CONFINED', () {
      expect(
        idsFor(
          'apps/mobile/lib/features/push/setup.dart',
          'if (Platform.isAndroid) {',
        ),
        contains('PLATFORM-BRANCH-CONFINED'),
      );
    });

    test('UI-NO-DATA', () {
      expect(
        idsFor(
          'packages/ekipa_ui/lib/src/primitives/person_name.dart',
          "import 'package:ekipa_data/ekipa_data.dart';",
        ),
        contains('UI-NO-DATA'),
      );
    });

    test('UI-NO-MATCHING', () {
      expect(
        idsFor(
          'packages/ekipa_ui/lib/src/primitives/group_card.dart',
          "import 'package:ekipa_core/matching.dart';",
        ),
        contains('UI-NO-MATCHING'),
      );
    });

    test('NO-LEGACY-IMPORT', () {
      expect(
        idsFor(
          'packages/ekipa_data/lib/x.dart',
          "import '../../legacy/v2/lib/models/models.dart';",
        ),
        contains('NO-LEGACY-IMPORT'),
      );
    });

    test('the table has no rule without a test', () {
      // Guards the case this whole group exists to prevent: a rule added later,
      // never exercised, quietly wrong in its regex, and trusted anyway.
      const tested = {
        'NO-LEGACY-IMPORT',
        'CORE-NO-FLUTTER',
        'CORE-NO-IO',
        'CORE-NO-BACKEND',
        'CORE-NO-WALL-CLOCK',
        'CORE-NO-UNSEEDED-RANDOM',
        'CORE-NO-PRINT',
        'MOBILE-NO-MATCHING',
        'MOBILE-NO-SERVICE-ROLE',
        'CONSOLE-NO-SERVICE-ROLE',
        'UI-NO-DATA',
        'UI-NO-MATCHING',
        'PLATFORM-BRANCH-CONFINED',
      };
      expect(rules.map((r) => r.id).toSet(), tested);
    });
  });

  group('scope and exemptions', () {
    test('core rules do not apply outside the core', () {
      expect(
        idsFor(
          'packages/ekipa_data/lib/src/system_clock.dart',
          'DateTime.now().toUtc();',
        ),
        isEmpty,
      );
    });

    test('the worker may import the matcher', () {
      expect(
        idsFor(
          'services/mill/bin/mill.dart',
          "import 'package:ekipa_core/matching.dart';",
        ),
        isEmpty,
      );
    });

    test('the simulator may import the matcher', () {
      expect(
        idsFor(
          'tools/simulator/bin/simulate.dart',
          "import 'package:ekipa_core/matching.dart';",
        ),
        isEmpty,
      );
    });

    test('platform branching is allowed inside the platform folder', () {
      expect(
        idsFor(
          'apps/mobile/lib/platform/push_tokens.dart',
          'if (Platform.isAndroid) {',
        ),
        isEmpty,
      );
    });

    test('legacy source may import itself', () {
      expect(
        idsFor(
          'legacy/v2/lib/router.dart',
          "import 'package:ekipa/legacy/thing.dart';",
        ),
        isEmpty,
      );
    });

    test('the design system may import core value objects', () {
      // The one dependency ekipa_ui is allowed, and the reason PersonName can
      // refuse a raw String.
      expect(
        idsFor(
          'packages/ekipa_ui/lib/src/primitives/person_name.dart',
          "import 'package:ekipa_core/ekipa_core.dart';",
        ),
        isEmpty,
      );
    });

    test('the app may import the safe core entry point', () {
      expect(
        idsFor(
          'apps/mobile/lib/main.dart',
          "import 'package:ekipa_core/ekipa_core.dart';",
        ),
        isEmpty,
      );
    });
  });

  group('false positives', () {
    test('a comment describing a forbidden thing does not trip a rule', () {
      // This repository documents its rules constantly. If prose tripped them,
      // the first fix anyone reached for would be to delete the explanation.
      expect(
        idsFor(
          'packages/ekipa_core/lib/src/clock.dart',
          '// Never call DateTime.now() here; inject a Clock instead.',
        ),
        isEmpty,
      );
    });

    test('a doc comment describing a forbidden import does not trip', () {
      expect(
        idsFor(
          'apps/mobile/lib/main.dart',
          "/// Never import 'package:ekipa_core/matching.dart' from here.",
        ),
        isEmpty,
      );
    });

    test('a seeded Random is allowed', () {
      expect(
        idsFor(
          'packages/ekipa_core/lib/src/random_source.dart',
          'final r = Random(seed);',
        ),
        isEmpty,
      );
    });

    test('debugPrint-style suffixes do not trip the print rule', () {
      expect(
        idsFor(
          'packages/ekipa_core/lib/src/x.dart',
          'buffer.sprint(value);',
        ),
        isEmpty,
      );
    });

    test(
      'a variable named for a person does not trip the service-role rule',
      () {
        expect(
          idsFor('apps/mobile/lib/x.dart', 'final serviceLevel = 3;'),
          isEmpty,
        );
      },
    );
  });

  group('reporting', () {
    test('a violation names the file, the line and the reason', () {
      final found = scanFile(
        'packages/ekipa_core/lib/src/x.dart',
        ['// header', "import 'dart:io';"],
      );
      expect(found, hasLength(1));
      expect(found.single.line, 2);
      expect(found.single.path, 'packages/ekipa_core/lib/src/x.dart');
      expect(found.single.toString(), contains('CORE-NO-IO'));
      expect(found.single.toString(), contains('why:'));
    });

    test('every rule carries a why that explains the failure it prevents', () {
      for (final rule in rules) {
        expect(rule.why.length, greaterThan(40), reason: rule.id);
        expect(rule.forbids, isNotEmpty, reason: rule.id);
      }
    });

    test('generated and build output are never scanned', () {
      expect(isIgnored('apps/mobile/lib/thing.g.dart'), isTrue);
      expect(isIgnored('build/whatever.dart'), isTrue);
      expect(isIgnored('packages/ekipa_core/.dart_tool/x.dart'), isTrue);
      expect(isIgnored('packages/ekipa_core/lib/src/real.dart'), isFalse);
    });
  });
}
