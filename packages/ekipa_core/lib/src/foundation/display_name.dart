import 'package:ekipa_core/src/foundation/result.dart';
import 'package:meta/meta.dart';

/// Why a [DisplayName] could not be constructed.
enum DisplayNameError {
  /// The first name was empty or whitespace only.
  emptyFirstName,

  /// The last initial was not exactly one character.
  invalidLastInitial,
}

/// The only name format this product ever renders: `Marko ····n`.
///
/// First name, a dot mask, and the **final letter of the surname** — enough to
/// disambiguate two Markos in one group without publishing a surname to a
/// stranger. Surnames in full are not stored at all (`docs/v3/02_DOMAIN.md`
/// §6).
///
/// **Intention.** The masking rule exists in exactly one place. A format
/// applied ad hoc at each call site is a format that will be right on five
/// screens and wrong on the sixth, and the sixth is the leak.
///
/// **Rejected — masking in the presentation layer.** It would put a privacy
/// rule in the widget tree, where the server cannot enforce it and where rule 6
/// of `docs/v3/11_SECURITY.md` §8 says it must never live.
@immutable
final class DisplayName {
  const DisplayName._(this.firstName, this.lastInitial);

  /// Validates and constructs a display name.
  static Result<DisplayName, DisplayNameError> create({
    required String firstName,
    required String lastInitial,
  }) {
    final trimmedFirst = firstName.trim();
    if (trimmedFirst.isEmpty) {
      return const Err(DisplayNameError.emptyFirstName);
    }
    final trimmedInitial = lastInitial.trim();
    if (trimmedInitial.runes.length != 1) {
      return const Err(DisplayNameError.invalidLastInitial);
    }
    return Ok(DisplayName._(trimmedFirst, trimmedInitial));
  }

  /// The person's first name, as they gave it.
  final String firstName;

  /// The final letter of their surname.
  final String lastInitial;

  /// How many mask characters sit between the two parts.
  ///
  /// Fixed rather than proportional to the real surname length: a mask that
  /// grew with the name would leak the surname's length, which narrows a guess
  /// in a city the size of Osijek far more than it looks.
  static const int maskLength = 4;

  /// The rendered form, e.g. `Marko ····n`.
  String get masked => '$firstName ${'·' * maskLength}$lastInitial';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DisplayName &&
          other.firstName == firstName &&
          other.lastInitial == lastInitial);

  @override
  int get hashCode => Object.hash(firstName, lastInitial);

  @override
  String toString() => masked;
}
