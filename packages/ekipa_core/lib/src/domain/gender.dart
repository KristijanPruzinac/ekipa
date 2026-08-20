import 'package:meta/meta.dart';

/// A gender, carried as a registry code rather than as a closed enum.
///
/// **Intention.** Directive D6, and one specific consequence of it: the
/// composition rule is *"no person is ever the only one of their gender in a
/// group"*, and that rule **never names a value**. It is a policy over whatever
/// the `genders` table happens to contain, which is what lets a third or fourth
/// value exist without a special case anywhere in the matcher
/// (09_OPEN_QUESTIONS.md C-4).
///
/// **Rejected — `enum Gender { woman, man, other }`.** Every `switch` over it
/// becomes a place that must be edited to add a value, and the compiler helps
/// you find those places only in Dart — not in the database, not in the
/// console, not in the two years of rows already written. The registry keeps
/// the set of values in one place that all four runtimes read.
///
/// **Rejected — a bare `String`.** `person.gender == 'Woman'` compiles, is
/// wrong, and fails silently: the person simply never satisfies the composition
/// rule and quietly stops being matched. That is the worst failure shape this
/// product has, because nothing looks broken.
@immutable
final class Gender {
  /// Wraps a registry [code], as stored in `genders.code`.
  const Gender(this.code);

  /// The registry code. Opaque to every rule in the system.
  final String code;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || (other is Gender && other.code == code);

  @override
  int get hashCode => Object.hash(Gender, code);

  @override
  String toString() => 'Gender($code)';
}

/// Counts of each gender in a group.
///
/// Exists as a named type rather than a bare `Map` because the one question
/// asked of it — *is anybody alone?* — is the composition invariant, and a
/// helper on a map is a helper somebody reimplements slightly differently in
/// the backfill path.
@immutable
final class GenderMix {
  /// Counts genders across [genders].
  factory GenderMix(Iterable<Gender> genders) {
    final counts = <Gender, int>{};
    for (final gender in genders) {
      counts[gender] = (counts[gender] ?? 0) + 1;
    }
    return GenderMix._(Map.unmodifiable(counts));
  }

  const GenderMix._(this._counts);

  final Map<Gender, int> _counts;

  /// How many people carry [gender].
  int countOf(Gender gender) => _counts[gender] ?? 0;

  /// Every gender present, with its count.
  Map<Gender, int> get counts => _counts;

  /// Total people counted.
  int get size => _counts.values.fold(0, (sum, n) => sum + n);

  /// Whether at least one person is the only one of their gender.
  ///
  /// This is invariant 1 of 03_MATCHMAKER.md §⑥, and it holds **at every group
  /// size** — which is what makes it survive the 3-person backfill case that a
  /// "2+2 or 4-same" rule could not express.
  ///
  /// A group of one is the degenerate case and is *not* a violation: the rule
  /// is about being outnumbered alone in a room, and there is no room.
  bool get hasLoneGender =>
      size > 1 && _counts.values.any((count) => count == 1);

  /// The genders that appear exactly once. Named so a rejection can say which.
  List<Gender> get loneGenders => [
    if (size > 1)
      for (final entry in _counts.entries)
        if (entry.value == 1) entry.key,
  ];

  @override
  String toString() {
    final parts =
        _counts.entries.map((e) => '${e.key.code}:${e.value}').toList()..sort();
    return 'GenderMix(${parts.join(' ')})';
  }
}
