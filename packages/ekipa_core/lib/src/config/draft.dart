import 'package:ekipa_core/src/config/catalogue.dart';
import 'package:ekipa_core/src/config/scope.dart';
import 'package:ekipa_core/src/foundation/ids.dart';
import 'package:ekipa_core/src/foundation/result.dart';
import 'package:meta/meta.dart';

/// One intended write to one key at one layer.
@immutable
final class ConfigEdit {
  /// Sets [key] at [scope] to [value].
  ///
  /// A `null` [value] means *clear this override* — remove the row and let the
  /// next layer down answer. No declared key type accepts `null` as a value
  /// (`ConfigKey.read` treats it as absent), so the meaning cannot collide with
  /// a legitimate stored value.
  const ConfigEdit({required this.key, required this.scope, this.value});

  /// The dotted key name.
  final String key;

  /// Which layer to write it at.
  final ConfigScope scope;

  /// The new value, or `null` to remove the override.
  final Object? value;

  @override
  String toString() => 'ConfigEdit($key@$scope = $value)';
}

/// What one edit did, once resolved against the base version.
enum ConfigChangeKind {
  /// No value existed at this layer; one does now.
  added,

  /// A value existed at this layer and is different now.
  changed,

  /// A value existed at this layer and no longer does.
  cleared,
}

/// One line of the console's diff view.
@immutable
final class ConfigChange {
  /// Describes one change.
  const ConfigChange({
    required this.key,
    required this.scope,
    required this.kind,
    required this.before,
    required this.after,
    required this.safetyCritical,
  });

  /// The dotted key name.
  final String key;

  /// The layer written at.
  final ConfigScope scope;

  /// Which of the three things happened.
  final ConfigChangeKind kind;

  /// The value at this layer in the base version, or `null` if there was none.
  final Object? before;

  /// The value at this layer after the edit, or `null` if it was cleared.
  final Object? after;

  /// Whether this key is marked safety-critical (AC-6).
  final bool safetyCritical;

  @override
  String toString() => '${kind.name} $key@$scope: $before -> $after';
}

/// Why a draft cannot be published.
enum ConfigProblemCode {
  /// A key name nothing declares. Almost always a typo, and the failure without
  /// this check is silent: the row is stored, nothing reads it, and the value
  /// the operator thinks they set is the code's default forever.
  unknownKey,

  /// A value the key's type cannot interpret. The runtime would fall back to
  /// the default, so the version would appear to have been applied and would
  /// change nothing.
  unparseableValue,

  /// A scope shaped illegally — a global with a reference, or a city without
  /// one. A `city` scope with an empty reference reads as targeted in the
  /// console and behaves as a second global layer that outranks the real one.
  malformedScope,

  /// The version would take effect in the past.
  ///
  /// This is the bug versioning exists to prevent, stated in
  /// `0005_v3_config_and_runs.sql`: shorten the confirmation window at 11:00
  /// while forty people hold a 09:00 confirmation, backdate it, and you have
  /// penalised people under a rule that did not exist when they were asked.
  retroactive,

  /// A version with no note. In six months the note is the only thing that can
  /// answer "why is this 3", and nobody writes it retrospectively.
  emptyNote,

  /// A consistency rule between keys no longer holds.
  invariantBroken,

  /// The draft changes nothing. An empty version still appears in every
  /// historical join and still has to be explained by whoever reads it later.
  nothingChanged,
}

/// One reason a draft was refused.
@immutable
final class ConfigProblem {
  /// Describes a problem.
  const ConfigProblem({
    required this.code,
    required this.detail,
    this.key,
    this.scope,
  });

  /// Which rule was broken.
  final ConfigProblemCode code;

  /// A sentence for the operator, naming what to change.
  final String detail;

  /// The key involved, where one is.
  final String? key;

  /// The layer involved, where one is.
  final ConfigScope? scope;

  @override
  String toString() => '${code.name}: $detail';
}

/// A draft that has passed validation and may be sent to the publish RPC.
///
/// **Intention.** A distinct type, not a flag on the draft. The console has one
/// function that writes a version, and it takes this; a draft nobody validated
/// cannot be handed to it by mistake. The server re-checks everything anyway
/// (nothing the client displays is a permission, `11_SECURITY.md` §2) — this
/// stops the *console* from being the thing that produced a bad version.
@immutable
final class PublishableConfig {
  const PublishableConfig._({
    required this.rows,
    required this.note,
    required this.effectiveFrom,
    required this.changes,
  });

  /// The complete value set the new version should hold.
  ///
  /// A whole set rather than a delta: a version is a full picture of the rules
  /// at a moment, so reading one back never means replaying a chain.
  final List<ConfigValueRow> rows;

  /// Why this version exists.
  final String note;

  /// When it starts to apply.
  final DateTime effectiveFrom;

  /// What changed against the base version.
  final List<ConfigChange> changes;

  /// Whether publishing requires the operator to type a reason (AC-6).
  bool get requiresConfirmation =>
      changes.any((change) => change.safetyCritical);
}

/// An unpublished set of edits on top of a published version.
///
/// **Intention.** `12_CONSOLE.md` §3.7 asks for a versioned editor with a diff,
/// an effective-from timestamp, a note and a blast radius. All four are
/// properties of the *change*, not of the editor, so they live in a value
/// object that a test can hold — the console screen then has no logic in it
/// worth testing separately.
@immutable
final class ConfigDraft {
  /// Describes a draft.
  const ConfigDraft({
    required this.baseVersionId,
    required this.baseRows,
    required this.note,
    required this.effectiveFrom,
    required this.edits,
  });

  /// The published version this is edited from.
  final ConfigVersionId baseVersionId;

  /// Every value the base version holds, at every layer.
  final List<ConfigValueRow> baseRows;

  /// Why this version is being made.
  final String note;

  /// When it should start applying.
  final DateTime effectiveFrom;

  /// The intended writes.
  final List<ConfigEdit> edits;

  /// The value set this draft would publish.
  ///
  /// Later edits to the same `(key, scope)` supersede earlier ones, so an
  /// operator who changes their mind twice publishes what is on the screen and
  /// not a history of their typing.
  List<ConfigValueRow> get rows {
    final byCoordinate = <(String, ConfigScope), Object?>{
      for (final row in baseRows) (row.key, row.scope): row.value,
    };
    for (final edit in edits) {
      if (edit.value == null) {
        byCoordinate.remove((edit.key, edit.scope));
      } else {
        byCoordinate[(edit.key, edit.scope)] = edit.value;
      }
    }
    return [
      for (final entry in byCoordinate.entries)
        ConfigValueRow(
          key: entry.key.$1,
          scope: entry.key.$2,
          value: entry.value,
        ),
    ];
  }

  /// The diff against the base version, one line per `(key, scope)` that moved.
  ///
  /// An edit that writes the value already stored produces no line: the console
  /// shows what changed, and a diff full of unchanged rows is a diff nobody
  /// reads carefully.
  List<ConfigChange> changes(ConfigCatalogue catalogue) {
    final before = <(String, ConfigScope), Object?>{
      for (final row in baseRows) (row.key, row.scope): row.value,
    };
    final seen = <(String, ConfigScope)>{};
    final changes = <ConfigChange>[];

    for (final edit in edits) {
      final coordinate = (edit.key, edit.scope);
      if (!seen.add(coordinate)) continue;

      final had = before.containsKey(coordinate);
      final was = before[coordinate];
      if (edit.value == null && !had) continue;
      if (edit.value == was && had) continue;

      changes.add(
        ConfigChange(
          key: edit.key,
          scope: edit.scope,
          kind: switch ((had, edit.value)) {
            (false, _) => ConfigChangeKind.added,
            (true, null) => ConfigChangeKind.cleared,
            (true, _) => ConfigChangeKind.changed,
          },
          before: was,
          after: edit.value,
          safetyCritical: catalogue.keyNamed(edit.key)?.safetyCritical ?? false,
        ),
      );
    }

    return changes;
  }

  /// Checks everything that can be checked without the database.
  ///
  /// Every problem is collected rather than the first one returned: an operator
  /// who has to fix one thing per round trip stops reading the messages.
  ///
  /// [targets] are the audiences the invariants are evaluated for — typically
  /// the global target plus one per active city, since a rule can hold globally
  /// and break for the one city that overrides half of it. Passed in rather
  /// than derived from the rows, because "which cities are live" is a fact
  /// about the world and this is a pure function.
  Result<PublishableConfig, List<ConfigProblem>> validate({
    required ConfigCatalogue catalogue,
    required DateTime now,
    required List<ConfigTarget> targets,
  }) {
    final problems = <ConfigProblem>[];

    if (note.trim().isEmpty) {
      problems.add(
        const ConfigProblem(
          code: ConfigProblemCode.emptyNote,
          detail: 'A version needs a note saying why it exists.',
        ),
      );
    }

    if (effectiveFrom.isBefore(now)) {
      problems.add(
        ConfigProblem(
          code: ConfigProblemCode.retroactive,
          detail:
              'Effective from ${effectiveFrom.toIso8601String()}, which is in '
              'the past. A backdated rule penalises people under a rule that '
              'did not exist when they were asked.',
        ),
      );
    }

    for (final edit in edits) {
      if (!edit.scope.isWellFormed) {
        problems.add(
          ConfigProblem(
            code: ConfigProblemCode.malformedScope,
            detail: 'Scope ${edit.scope} is not addressable.',
            key: edit.key,
            scope: edit.scope,
          ),
        );
      }

      final key = catalogue.keyNamed(edit.key);
      if (key == null) {
        problems.add(
          ConfigProblem(
            code: ConfigProblemCode.unknownKey,
            detail:
                'No key named "${edit.key}" is declared. '
                'Nothing would read it.',
            key: edit.key,
            scope: edit.scope,
          ),
        );
        continue;
      }

      if (!key.accepts(edit.value)) {
        problems.add(
          ConfigProblem(
            code: ConfigProblemCode.unparseableValue,
            detail:
                '"${edit.value}" is not a value ${edit.key} can hold; the '
                'runtime would silently fall back to ${key.defaultValue}.',
            key: edit.key,
            scope: edit.scope,
          ),
        );
      }
    }

    final changes = this.changes(catalogue);
    if (changes.isEmpty) {
      problems.add(
        const ConfigProblem(
          code: ConfigProblemCode.nothingChanged,
          detail: 'This draft is identical to the version it is based on.',
        ),
      );
    }

    final rows = this.rows;
    for (final target in targets) {
      final resolution = ConfigResolver.resolve(
        versionId: baseVersionId,
        rows: rows,
        target: target,
      );
      for (final invariant in catalogue.invariants) {
        if (!invariant.holds(resolution.snapshot)) {
          problems.add(
            ConfigProblem(
              code: ConfigProblemCode.invariantBroken,
              detail: '${invariant.name} for $target: ${invariant.explanation}',
            ),
          );
        }
      }
    }

    if (problems.isNotEmpty) return Err(problems);

    return Ok(
      PublishableConfig._(
        rows: List.unmodifiable(rows),
        note: note.trim(),
        effectiveFrom: effectiveFrom,
        changes: List.unmodifiable(changes),
      ),
    );
  }
}
