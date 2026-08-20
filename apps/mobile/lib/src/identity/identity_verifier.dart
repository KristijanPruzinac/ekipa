/// How somebody proves they are a person, once.
///
/// **Intention — the app must not know which method is in use.** `.edu.hr`
/// email codes are what `09_OPEN_QUESTIONS.md` C-1 says ships, and `AAI@EduHr`
/// is what replaces it if SRCE ever answers. Both are one adapter behind this
/// port, and the sign-in screen is written against the port, so the swap costs
/// an adapter and nothing else.
///
/// **Why [IdentityVerifier.begin] returns a step, not a challenge.** A method
/// that needs a code and a method that does not are different shapes, and a
/// port that always returned a challenge would force the code-less adapter to
/// invent one and the screen to skip past it. Returning a sealed step means the
/// screen asks "what next" instead of assuming, which is the difference between
/// adding a method and rewriting a flow.
library;

import 'package:ekipa_core/ekipa_core.dart';
import 'package:flutter/foundation.dart';

/// What the verifier wants next.
sealed class VerificationStep {
  const VerificationStep();
}

/// Send a code, then come back with it.
final class CodeRequired extends VerificationStep {
  /// Describes an outstanding challenge.
  const CodeRequired({required this.challengeId, required this.sentTo});

  /// Opaque handle the adapter uses to find the challenge again.
  final String challengeId;

  /// What the person should look at — an address, a number — so the screen can
  /// say where the code went without knowing what kind of thing it is.
  final String sentTo;
}

/// Nothing else is needed; this person is verified.
final class Verified extends VerificationStep {
  /// Describes a completed verification.
  const Verified(this.identity);

  /// Who they turned out to be.
  final VerifiedIdentity identity;
}

/// The three things a verification is allowed to hand back.
///
/// **Intention.** Not an email, not a student number, not a document. The
/// subject is normalised and hashed by the *worker*, and what reaches the app
/// is a first name, a last initial and a token that binds the session. Anything
/// more would put the thing we promised not to store on the device that is
/// hardest to defend.
@immutable
final class VerifiedIdentity {
  /// Describes a verified person.
  const VerifiedIdentity({
    required this.firstName,
    required this.lastInitial,
    required this.sessionToken,
  });

  /// Their given name, as they typed it.
  final String firstName;

  /// One character. Never the surname — `02_DOMAIN.md` §6.
  final String lastInitial;

  /// What the session is bound to. Opaque here.
  final String sessionToken;
}

/// Proves a person is a person.
abstract interface class IdentityVerifier {
  /// A sentence for the sign-in screen, so it does not hard-code one method.
  ///
  /// The screen renders this rather than composing "Enter your student email",
  /// which would be a claim about the adapter that the screen cannot check.
  String get prompt;

  /// What the person types to identify themselves.
  String get subjectLabel;

  /// Placeholder text for the field.
  ///
  /// Part of the port rather than the screen for the same reason as [prompt]:
  /// "ime.prezime@ferit.hr" is a claim about which method is running, and a
  /// screen that hard-coded it would be wrong the day the method changed.
  String get subjectHint;

  /// Starts verification for [subject].
  Future<Result<VerificationStep, String>> begin(String subject);

  /// Finishes a [CodeRequired] step.
  Future<Result<VerifiedIdentity, String>> complete({
    required String challengeId,
    required String code,
  });
}
