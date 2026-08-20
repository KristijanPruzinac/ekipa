/// The interim verifier: a name, and nothing checked.
///
/// **Intention — this is a placeholder, and it says so on the screen.** It
/// exists so the rest of P1 — onboarding, the availability picker, the session
/// state machine — can be built and looked at before the `.edu.hr` code path
/// is written. It verifies nothing, and a build carrying it must never reach a
/// real person.
///
/// **Why it is a full adapter rather than an `if` in the sign-in screen.** The
/// screen has to handle a two-step method whether or not today's method is one,
/// and the cheapest way to be sure it does is to make today's method arrive
/// through the same door. When the `.edu.hr` verifier lands, the only file that
/// changes is the one line in `main.dart` that binds the port.
///
/// **What it deliberately does not do:** normalise. The real verifier's
/// normalisation — lowercase, strip `+tag`, compare against the existing hash
/// set — is the single function ban-evasion resistance rests on
/// (`09_OPEN_QUESTIONS.md` C-1), and a half-version of it here would be a
/// second implementation to keep in step. There is no normalisation because
/// there is no identity.
library;

import 'package:ekipa_core/ekipa_core.dart';
import 'package:mobile/src/identity/identity_verifier.dart';

/// Accepts any name, verifies nothing.
final class NameOnlyVerifier implements IdentityVerifier {
  /// Creates the placeholder verifier.
  const NameOnlyVerifier();

  @override
  String get prompt =>
      'Verification is not switched on yet. Type a name and you are in.';

  @override
  String get subjectLabel => 'Your name';

  @override
  String get subjectHint => 'Ana Kovač';

  /// Splits [subject] into a given name and one initial.
  ///
  /// Rejects a single word, because a last initial is not optional: it is half
  /// of how one Ana is told from another, and the alternative — a blank
  /// initial — makes two people look like one person on the reveal screen.
  @override
  Future<Result<VerificationStep, String>> begin(String subject) async {
    final parts = subject
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.length < 2) {
      return const Err('Both names, please — Ana Kovač.');
    }
    final first = parts.first;
    if (first.length > 40) {
      return const Err('That first name is longer than the database allows.');
    }

    return Ok(
      Verified(
        VerifiedIdentity(
          firstName: first,
          lastInitial: parts.last.substring(0, 1).toUpperCase(),
          sessionToken: 'placeholder',
        ),
      ),
    );
  }

  /// Never reached: [begin] always returns [Verified].
  @override
  Future<Result<VerifiedIdentity, String>> complete({
    required String challengeId,
    required String code,
  }) async => const Err('This verifier does not send codes.');
}
