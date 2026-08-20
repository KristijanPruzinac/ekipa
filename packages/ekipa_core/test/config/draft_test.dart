import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_core/matching.dart';
import 'package:test/test.dart';

const _osijek = CityId('osijek');
final _now = DateTime.utc(2026, 8, 18, 12);
final _tomorrow = DateTime.utc(2026, 8, 19, 12);

final _catalogue = ConfigCatalogue([MatchingKeys.group, ScheduleKeys.group]);

ConfigValueRow _row(String key, Object? value, {ConfigScope? scope}) =>
    ConfigValueRow(
      key: key,
      scope: scope ?? const ConfigScope.global(),
      value: value,
    );

ConfigDraft _draft({
  List<ConfigValueRow> base = const [],
  List<ConfigEdit> edits = const [],
  String note = 'why this exists',
  DateTime? effectiveFrom,
}) => ConfigDraft(
  baseVersionId: const ConfigVersionId('v1'),
  baseRows: base,
  note: note,
  effectiveFrom: effectiveFrom ?? _tomorrow,
  edits: edits,
);

List<ConfigProblem> _problems(ConfigDraft draft) => draft
    .validate(
      catalogue: _catalogue,
      now: _now,
      targets: const [ConfigTarget.everywhere()],
    )
    .errorOrNull!;

Set<ConfigProblemCode> _codes(ConfigDraft draft) =>
    _problems(draft).map((problem) => problem.code).toSet();

void main() {
  group('the catalogue', () {
    test('a key declared twice fails at assembly, not at a read site', () {
      final duplicate = ConfigKey.integer(
        MatchingKeys.cooldownMeetups.name,
        defaultValue: 99,
        description: 'a second opinion about the same key',
      );

      expect(
        () => ConfigCatalogue([
          MatchingKeys.group,
          ConfigGroup(
            name: 'Rogue',
            description: 'a group that redeclares a key',
            keys: [duplicate],
          ),
        ]),
        throwsArgumentError,
      );
    });

    test('every declared key is findable by name', () {
      for (final key in [...MatchingKeys.all, ...ScheduleKeys.all]) {
        expect(
          _catalogue.keyNamed(key.name),
          same(key),
          reason: '${key.name} is declared but not reachable',
        );
      }
      expect(_catalogue.keyNamed('matching.cooldown_meetupz'), isNull);
    });

    test('the composition rules are the safety-critical ones', () {
      expect(
        _catalogue.safetyCritical.map((key) => key.name).toSet(),
        {
          MatchingKeys.minGroupSize.name,
          MatchingKeys.maxGroupSize.name,
          MatchingKeys.maxKnownPairFraction.name,
        },
      );
    });
  });

  group('the diff', () {
    test('names what changed, and nothing else', () {
      final draft = _draft(
        base: [_row(MatchingKeys.cooldownDays.name, 21)],
        edits: [
          ConfigEdit(
            key: MatchingKeys.cooldownDays.name,
            scope: const ConfigScope.global(),
            value: 14,
          ),
        ],
      );

      final changes = draft.changes(_catalogue);
      expect(changes, hasLength(1));
      expect(changes.single.kind, ConfigChangeKind.changed);
      expect(changes.single.before, 21);
      expect(changes.single.after, 14);
    });

    test('writing the value that is already there is not a change', () {
      // The diff is what the operator reads before publishing. A line saying
      // "21 -> 21" trains them to skim it.
      final draft = _draft(
        base: [_row(MatchingKeys.cooldownDays.name, 21)],
        edits: [
          ConfigEdit(
            key: MatchingKeys.cooldownDays.name,
            scope: const ConfigScope.global(),
            value: 21,
          ),
        ],
      );

      expect(draft.changes(_catalogue), isEmpty);
    });

    test('a first value at a layer is an addition, not a change', () {
      final draft = _draft(
        edits: [
          ConfigEdit(
            key: MatchingKeys.cooldownDays.name,
            scope: ConfigScope.city(_osijek),
            value: 14,
          ),
        ],
      );

      final change = draft.changes(_catalogue).single;
      expect(change.kind, ConfigChangeKind.added);
      expect(change.before, isNull);
    });

    test('a null value clears the override at that layer', () {
      final draft = _draft(
        base: [
          _row(MatchingKeys.cooldownDays.name, 21),
          _row(
            MatchingKeys.cooldownDays.name,
            14,
            scope: ConfigScope.city(_osijek),
          ),
        ],
        edits: [
          ConfigEdit(
            key: MatchingKeys.cooldownDays.name,
            scope: ConfigScope.city(_osijek),
          ),
        ],
      );

      expect(draft.changes(_catalogue).single.kind, ConfigChangeKind.cleared);
      expect(draft.rows, hasLength(1));
      expect(draft.rows.single.scope, const ConfigScope.global());
    });

    test('the last edit to a coordinate is the one published', () {
      final draft = _draft(
        edits: [
          ConfigEdit(
            key: MatchingKeys.cooldownDays.name,
            scope: const ConfigScope.global(),
            value: 14,
          ),
          ConfigEdit(
            key: MatchingKeys.cooldownDays.name,
            scope: const ConfigScope.global(),
            value: 10,
          ),
        ],
      );

      expect(draft.rows.single.value, 10);
      expect(draft.changes(_catalogue), hasLength(1));
    });

    test('a change to a composition rule demands a typed confirmation', () {
      final draft = _draft(
        edits: [
          ConfigEdit(
            key: MatchingKeys.maxGroupSize.name,
            scope: const ConfigScope.global(),
            value: 4,
          ),
          ConfigEdit(
            key: MatchingKeys.minGroupSize.name,
            scope: const ConfigScope.global(),
            value: 3,
          ),
        ],
      );

      final publishable = draft
          .validate(
            catalogue: _catalogue,
            now: _now,
            targets: const [ConfigTarget.everywhere()],
          )
          .valueOrNull!;
      expect(publishable.requiresConfirmation, isTrue);
    });

    test('a change to an ordinary key does not', () {
      final draft = _draft(
        edits: [
          ConfigEdit(
            key: MatchingKeys.cooldownDays.name,
            scope: const ConfigScope.global(),
            value: 14,
          ),
        ],
      );

      final publishable = draft
          .validate(
            catalogue: _catalogue,
            now: _now,
            targets: const [ConfigTarget.everywhere()],
          )
          .valueOrNull!;
      expect(publishable.requiresConfirmation, isFalse);
    });
  });

  group('validation refuses', () {
    test('a key name nothing declares', () {
      final problems = _problems(
        _draft(
          edits: [
            const ConfigEdit(
              key: 'matching.cooldown_meetupz',
              scope: ConfigScope.global(),
              value: 1,
            ),
          ],
        ),
      );

      expect(problems.single.code, ConfigProblemCode.unknownKey);
      expect(problems.single.key, 'matching.cooldown_meetupz');
    });

    test('a value the key cannot hold', () {
      // Without this the row is stored, the runtime falls back to the default,
      // and the version looks applied while changing nothing.
      expect(
        _codes(
          _draft(
            edits: [
              ConfigEdit(
                key: MatchingKeys.cooldownDays.name,
                scope: const ConfigScope.global(),
                value: 'soon',
              ),
            ],
          ),
        ),
        contains(ConfigProblemCode.unparseableValue),
      );
    });

    test('a city scope with no city', () {
      expect(
        _codes(
          _draft(
            edits: [
              ConfigEdit(
                key: MatchingKeys.cooldownDays.name,
                scope: const ConfigScope.cohort(''),
                value: 14,
              ),
            ],
          ),
        ),
        contains(ConfigProblemCode.malformedScope),
      );
    });

    test('an effective-from in the past', () {
      expect(
        _codes(
          _draft(
            effectiveFrom: _now.subtract(const Duration(hours: 3)),
            edits: [
              ConfigEdit(
                key: MatchingKeys.cooldownDays.name,
                scope: const ConfigScope.global(),
                value: 14,
              ),
            ],
          ),
        ),
        contains(ConfigProblemCode.retroactive),
      );
    });

    test('effective-from exactly now is fine', () {
      final draft = _draft(
        effectiveFrom: _now,
        edits: [
          ConfigEdit(
            key: MatchingKeys.cooldownDays.name,
            scope: const ConfigScope.global(),
            value: 14,
          ),
        ],
      );

      expect(
        draft
            .validate(
              catalogue: _catalogue,
              now: _now,
              targets: const [ConfigTarget.everywhere()],
            )
            .isOk,
        isTrue,
      );
    });

    test('a version with no note', () {
      expect(
        _codes(
          _draft(
            note: '   ',
            edits: [
              ConfigEdit(
                key: MatchingKeys.cooldownDays.name,
                scope: const ConfigScope.global(),
                value: 14,
              ),
            ],
          ),
        ),
        contains(ConfigProblemCode.emptyNote),
      );
    });

    test('a draft that changes nothing', () {
      expect(_codes(_draft()), contains(ConfigProblemCode.nothingChanged));
    });

    test('every problem at once, not the first one', () {
      // An operator who has to fix one thing per round trip stops reading.
      final codes = _codes(
        _draft(
          note: '',
          effectiveFrom: _now.subtract(const Duration(days: 1)),
          edits: [
            const ConfigEdit(
              key: 'matching.nonsense',
              scope: ConfigScope.global(),
              value: 1,
            ),
          ],
        ),
      );

      expect(
        codes,
        containsAll([
          ConfigProblemCode.emptyNote,
          ConfigProblemCode.retroactive,
          ConfigProblemCode.unknownKey,
        ]),
      );
    });
  });

  group('cross-key invariants', () {
    test('ring shares that sum above one are refused', () {
      final problems = _problems(
        _draft(
          edits: [
            ConfigEdit(
              key: MatchingKeys.ringShareEnjoyed.name,
              scope: const ConfigScope.global(),
              value: 0.6,
            ),
            ConfigEdit(
              key: MatchingKeys.ringShareLeaf.name,
              scope: const ConfigScope.global(),
              value: 0.6,
            ),
          ],
        ),
      );

      expect(
        problems.map((problem) => problem.code),
        contains(ConfigProblemCode.invariantBroken),
      );
      expect(
        problems.map((problem) => problem.detail).join(),
        contains('stranger'),
      );
    });

    test('an inverted group size range is refused', () {
      expect(
        _codes(
          _draft(
            edits: [
              ConfigEdit(
                key: MatchingKeys.minGroupSize.name,
                scope: const ConfigScope.global(),
                value: 5,
              ),
            ],
          ),
        ),
        contains(ConfigProblemCode.invariantBroken),
      );
    });

    test('a minimum group of two is refused', () {
      expect(
        _codes(
          _draft(
            edits: [
              ConfigEdit(
                key: MatchingKeys.minGroupSize.name,
                scope: const ConfigScope.global(),
                value: 2,
              ),
            ],
          ),
        ),
        contains(ConfigProblemCode.invariantBroken),
      );
    });

    test('an invariant that holds globally but breaks for one city', () {
      // The reason targets are passed in. A city override is invisible to a
      // global-only check, and the city is exactly where a hand-tuned value
      // ends up.
      final draft = _draft(
        base: [_row(MatchingKeys.ringShareEnjoyed.name, 0.25)],
        edits: [
          ConfigEdit(
            key: MatchingKeys.ringShareLeaf.name,
            scope: ConfigScope.city(_osijek),
            value: 0.9,
          ),
        ],
      );

      expect(
        draft
            .validate(
              catalogue: _catalogue,
              now: _now,
              targets: const [ConfigTarget.everywhere()],
            )
            .isOk,
        isTrue,
        reason: 'the global layer is still consistent',
      );
      expect(
        draft
            .validate(
              catalogue: _catalogue,
              now: _now,
              targets: const [ConfigTarget(cityId: _osijek)],
            )
            .isErr,
        isTrue,
        reason: 'Osijek now draws 1.15 of a dyad',
      );
    });
  });

  group('a publishable draft', () {
    test('carries the whole value set, not the delta', () {
      // Reading a version back must never mean replaying a chain of versions.
      final draft = _draft(
        base: [
          _row(MatchingKeys.cooldownDays.name, 21),
          _row(MatchingKeys.starveCapWeeks.name, 4),
        ],
        edits: [
          ConfigEdit(
            key: MatchingKeys.cooldownDays.name,
            scope: const ConfigScope.global(),
            value: 14,
          ),
        ],
      );

      final publishable = draft
          .validate(
            catalogue: _catalogue,
            now: _now,
            targets: const [ConfigTarget.everywhere()],
          )
          .valueOrNull!;

      expect(publishable.rows, hasLength(2));
      expect(publishable.changes, hasLength(1));
      expect(publishable.note, 'why this exists');
    });
  });
}
