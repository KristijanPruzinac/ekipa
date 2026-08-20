import 'package:ekipa_core/src/foundation/result.dart';
import 'package:meta/meta.dart';

/// Why an address was refused.
enum AddressProblem {
  /// No `@`, two `@`, empty either side.
  malformed,

  /// The domain is not on the allow-list.
  notAcademic,

  /// Longer than the column, or than any real address.
  tooLong,

  /// Characters that have no business in a local part.
  illegalCharacter,
}

/// An academic address, reduced to the one string we hash.
///
/// **Intention — this is the entire ban-evasion boundary, and it is one
/// function.** `09_OPEN_QUESTIONS.md` C-1 says it plainly: without
/// normalisation the `.edu.hr` code is not an identity at all, because
/// `ime.prezime+1@`, `+2@`, `+3@` are three free accounts and every ban is a
/// thirty-second inconvenience. Everything else in the trust system — the
/// accumulators, the ladder, the report weighting — is built on the assumption
/// that one human is one row, and this function is the only thing making that
/// true.
///
/// So it gets property tests and a database uniqueness constraint, not a code
/// review.
///
/// **What it does, and why each step is there:**
///
/// * **Lower-case both parts.** The domain is case-insensitive by RFC; the
///   local part is technically not, but no Croatian university issues
///   `Ime.Prezime@` and `ime.prezime@` to two different people, and treating
///   them as one costs nothing and closes an obvious hole.
/// * **Strip `+tag`.** The whole point. Every mail system that supports it
///   delivers `a+anything@` to `a@`.
/// * **Strip dots in the local part.** Gmail-style dot-blindness is *not*
///   universal, so this one is a genuine trade: it can merge two real people at
///   a provider that distinguishes them. It is applied because the failure it
///   prevents (unlimited free accounts from one mailbox) is systematic and the
///   failure it causes (two students with dot-identical addresses at the same
///   university) is rare, detectable, and appealable by a human. **Stated
///   openly because it is the one debatable line in this file.**
/// * **Nothing else.** No unicode folding, no homoglyph mapping, no
///   punycode games. Each of those is a source of false merges, and a false
///   merge locks a real person out of the product with no way back.
///
/// **The allow-list is config, not a constant** (D5): adding FERIT, PFOS or
/// FOOZOS is a console edit, not a deploy.
@immutable
final class AcademicAddress {
  const AcademicAddress._(this.canonical, this.domain);

  /// The normalised address. This, and only this, is what gets hashed.
  final String canonical;

  /// The institution's domain, kept so a city or cohort can be inferred later.
  final String domain;

  /// The longest address any of this actually needs to accept.
  static const int maxLength = 254;

  static final RegExp _legalLocal = RegExp(r"^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+$");

  /// Normalises [raw] against [allowedDomains].
  ///
  /// [allowedDomains] arrives from config and is matched by suffix, so
  /// `edu.hr` admits `ferit.hr`'s subdomains without listing each one, while an
  /// exact entry like `ferit.hr` admits only that.
  static Result<AcademicAddress, AddressProblem> parse(
    String raw, {
    required Set<String> allowedDomains,
  }) {
    final trimmed = raw.trim();
    if (trimmed.length > maxLength) return const Err(AddressProblem.tooLong);

    final at = trimmed.lastIndexOf('@');
    if (at <= 0 || at == trimmed.length - 1) {
      return const Err(AddressProblem.malformed);
    }
    if (trimmed.indexOf('@') != at) return const Err(AddressProblem.malformed);

    var local = trimmed.substring(0, at).toLowerCase();
    final domain = trimmed.substring(at + 1).toLowerCase();

    if (!_legalLocal.hasMatch(local)) {
      return const Err(AddressProblem.illegalCharacter);
    }
    if (domain.contains('..') ||
        domain.startsWith('.') ||
        domain.endsWith('.') ||
        !domain.contains('.')) {
      return const Err(AddressProblem.malformed);
    }

    final allowed = allowedDomains.any(
      (entry) => domain == entry || domain.endsWith('.$entry'),
    );
    if (!allowed) return const Err(AddressProblem.notAcademic);

    // Order matters: strip the tag first, then the dots. The other way round
    // turns `a.b+c.d@` into `abcd@` rather than `ab@`, so two addresses that
    // deliver to different mailboxes would collide.
    final plus = local.indexOf('+');
    if (plus >= 0) local = local.substring(0, plus);
    local = local.replaceAll('.', '');

    if (local.isEmpty) return const Err(AddressProblem.malformed);

    return Ok(AcademicAddress._('$local@$domain', domain));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AcademicAddress && other.canonical == canonical);

  @override
  int get hashCode => Object.hash(AcademicAddress, canonical);

  /// **Never prints the address.** An identifier that appears in a log line is
  /// an identifier in a log aggregator, and rule 5 of `11_SECURITY.md §8`
  /// forbids exactly this. The domain is safe and is often what you actually
  /// wanted to see.
  @override
  String toString() => 'AcademicAddress(@$domain)';
}
