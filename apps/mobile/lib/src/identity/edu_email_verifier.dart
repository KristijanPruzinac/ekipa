/// A one-time code to a Croatian academic address.
///
/// **Intention — what ships while AAI is being arranged.**
/// `09_OPEN_QUESTIONS.md` C-1: a six-digit code to an address on an
/// allow-listed academic domain. It proves student status, gives a stable
/// subject, and can be built in days.
///
/// **The load-bearing part is not the code, it is the normalisation.** Without
/// it this is not an identity at all — `ime.prezime+1@`, `+2@`, `+3@` are three
/// free accounts and every ban is a thirty-second inconvenience. That function
/// is [AcademicAddress], in `ekipa_core`, with property tests and a database
/// uniqueness constraint behind it.
///
/// **What this class does not do:** send the code, hash the address, or decide
/// whether the code was right. All three happen on the worker, which holds the
/// identity pepper and the mail credentials. This adapter normalises early —
/// so a typo is caught before an email is sent — and then asks the server.
/// **The client's normalisation is a courtesy, never a control.** The server
/// normalises again on the value it received, because a patched client can send
/// anything (`11_SECURITY.md §2`).
///
/// *Rejected — phone/SMS as the primary anchor:* stronger against sybils, but
/// it costs money per signup, it is trivially rentable, and it drops the
/// "students only" property that makes the launch population coherent.
/// *Rejected — social login:* free, frictionless, and worth nothing here, since
/// a new Google account takes two minutes.
library;

import 'package:ekipa_core/ekipa_core.dart';
import 'package:mobile/src/identity/identity_verifier.dart';

/// Starts and finishes an email-code verification, server-side.
///
/// A port of its own rather than a method on the gateway: verification happens
/// *before* there is a member, so it cannot sit behind an interface whose every
/// other method assumes one.
abstract interface class VerificationService {
  /// Asks the server to send a code to [canonicalAddress].
  Future<Result<CodeRequired, String>> sendCode(String canonicalAddress);

  /// Asks the server to check [code] against [challengeId].
  Future<Result<VerifiedIdentity, String>> checkCode({
    required String challengeId,
    required String code,
  });
}

/// The interim verifier.
final class EduEmailVerifier implements IdentityVerifier {
  /// Creates a verifier that talks to [_service].
  const EduEmailVerifier(this._service, {this.allowedDomains = defaultDomains});

  final VerificationService _service;

  /// Which domains count as academic.
  ///
  /// **Config, not a constant** (D5). Adding an institution has to be a console
  /// edit, not a deploy — the list below is the seed value, and the resolved
  /// config wins wherever one is available. Suffix-matched, so `edu.hr` admits
  /// every subdomain beneath it while an exact entry admits only itself.
  final Set<String> allowedDomains;

  /// The starting allow-list: the national academic suffix plus the Osijek
  /// institutions the pilot is aimed at.
  static const Set<String> defaultDomains = {
    'edu.hr',
    'ferit.hr',
    'unios.hr',
    'foozos.hr',
    'pfos.hr',
    'mefos.hr',
    'pravos.hr',
    'efos.hr',
  };

  @override
  String get prompt =>
      'Your university address. We send a six-digit code and never see your '
      'password. The address is turned into a one-way code and thrown away — '
      'it is not stored, and it is not how anybody finds you.';

  @override
  String get subjectLabel => 'University email';

  @override
  String get subjectHint => 'ime.prezime@ferit.hr';

  @override
  Future<Result<VerificationStep, String>> begin(String subject) async {
    final address = AcademicAddress.parse(
      subject,
      allowedDomains: allowedDomains,
    );

    if (address case Err(:final error)) {
      return Err(switch (error) {
        AddressProblem.malformed => 'That does not look like an email address.',
        AddressProblem.notAcademic =>
          'That is not a Croatian university address. ekipa is students only '
              'for now — it is what keeps the group coherent.',
        AddressProblem.tooLong => 'That address is too long to be real.',
        AddressProblem.illegalCharacter =>
          'There is a character in there an address cannot have.',
      });
    }

    final sent = await _service.sendCode(address.valueOrNull!.canonical);
    return switch (sent) {
      Ok(:final value) => Ok(value),
      Err(:final error) => Err(error),
    };
  }

  @override
  Future<Result<VerifiedIdentity, String>> complete({
    required String challengeId,
    required String code,
  }) {
    final digits = code.trim();
    if (digits.length != 6 || int.tryParse(digits) == null) {
      return Future.value(const Err('The code is six digits.'));
    }
    return _service.checkCode(challengeId: challengeId, code: digits);
  }
}
