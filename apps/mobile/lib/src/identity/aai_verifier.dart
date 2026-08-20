/// AAI@EduHr, over OpenID Connect.
///
/// **What was wrong in the docs, and what is actually true.**
/// `09_OPEN_QUESTIONS.md` C-1 said the registration procedure "is not published
/// in a form I could verify" and told the user to email SRCE first. That was
/// wrong. The procedure is published, and the parts that matter to a Flutter
/// app are better than the doc assumed:
///
/// * **OIDC is supported**, alongside SAML, CAS and WS-FED. So this is an
/// ordinary authorization-code + PKCE flow and there is **no SAML broker** —
/// the Keycloak dependency C-1 assumed is simply not needed.
/// * **Registration is self-service** through the Resource Registry at
/// `registar.aaiedu.hr`: register the resource, pull the metadata, configure,
/// then request production status.
/// * **`AAI@EduHr Lab`** is a complete test federation — test SSO, test LDAP,
/// test accounts — usable for development before any production approval
/// exists. That is what this adapter points at first.
///
/// **The gate that is real:** the service provider must belong to a *partner
/// sustava* or a *matična ustanova*. An individual cannot register a production
/// SP. FERIT is a matična ustanova, so the route is its AAI coordinator and a
/// form, not a cold email to SRCE.
///
/// **Attributes, and what each one buys:**
///
/// * `hrEduPersonPersistentID` — **mandatory.** The identity anchor:
///   permanent, opaque and institution-issued, which is strictly better than
///   an email address and expensive to re-acquire. That expense is exactly
///   what makes a ban stick.
/// * `givenName`, `sn` — **mandatory.** The display name, without asking for
///   it.
/// * `hrEduPersonPrimaryAffiliation` — **mandatory.** Proves *student*, which
///   is the property that makes the launch population coherent.
/// * `hrEduPersonDateOfBirth` — **optional**, so the 18+ gate cannot rely on
///   it. It stays an attested date plus the affiliation, and
///   `09_OPEN_QUESTIONS.md` Q-AGE keeps its answer.
///
/// **What this file deliberately does not do.** It does not hash anything, it
/// does not decide whether an affiliation is acceptable, and it does not see
/// the persistent id. The app receives an authorization code, hands it to the
/// worker, and the worker — which holds the client secret and the identity
/// pepper — exchanges it, reads the attributes, applies the age and affiliation
/// rules, and returns a first name, a last initial and a session. A client that
/// could see `hrEduPersonPersistentID` is a client that could correlate people
/// across systems, and a client that held the token exchange would hold a
/// secret on the least defensible device in the system (`11_SECURITY.md §5`).
library;

import 'package:ekipa_core/ekipa_core.dart';
import 'package:mobile/src/identity/identity_verifier.dart';

/// Where an OIDC flow points.
///
/// Config rather than constants, because the Lab and production are the same
/// code with different endpoints — and "which federation is this build talking
/// to" must be answerable by looking, not by reading a build flag.
final class OidcEndpoints {
  /// Describes a federation.
  const OidcEndpoints({
    required this.discovery,
    required this.clientId,
    required this.redirectUri,
    this.label = 'AAI@EduHr',
  });

  /// The Lab federation, for development.
  ///
  /// The discovery document is the only URL worth hard-coding, because it is
  /// what everything else is read from — an adapter that hard-codes an
  /// authorization endpoint breaks silently when the federation moves it.
  static const OidcEndpoints lab = OidcEndpoints(
    discovery: 'https://fed-lab.aaiedu.hr/.well-known/openid-configuration',
    clientId: 'ekipa-lab',
    redirectUri: 'hr.ekipa.app://auth',
    label: 'AAI@EduHr Lab',
  );

  /// Where the provider publishes its configuration.
  final String discovery;

  /// The registered client. Public: a mobile app cannot hold a secret, which is
  /// why the flow is PKCE and the token exchange happens on the worker.
  final String clientId;

  /// The app's custom scheme.
  final String redirectUri;

  /// What to show a person about which federation this is.
  final String label;
}

/// Signs in through AAI@EduHr.
///
/// **Not yet wired to a browser.** The authorization-code redirect needs a
/// platform surface — a custom tab on Android, `ASWebAuthenticationSession` on
/// iOS — which belongs in `apps/mobile/lib/platform/` behind one interface
/// (C-3's rule: no platform branch outside that folder, enforced by lint). This
/// class exists now so the shape is fixed and the swap is a binding change:
/// everything the sign-in screen renders already comes from the port.
final class AaiEduHrVerifier implements IdentityVerifier {
  /// Creates a verifier against [endpoints].
  const AaiEduHrVerifier({this.endpoints = OidcEndpoints.lab});

  /// Which federation.
  final OidcEndpoints endpoints;

  @override
  String get prompt =>
      'Sign in with your university account. We never see your password, and '
      'we never learn your student number — only your first name, the first '
      'letter of your surname, and that you are a student.';

  @override
  String get subjectLabel => 'University account';

  @override
  String get subjectHint => 'Continue to ${endpoints.label}';

  @override
  Future<Result<VerificationStep, String>> begin(String subject) async =>
      const Err(
        'AAI sign-in is not switched on in this build yet. It needs the '
        'browser handoff, which lives in the platform layer.',
      );

  @override
  Future<Result<VerifiedIdentity, String>> complete({
    required String challengeId,
    required String code,
  }) async => const Err('AAI sign-in is not switched on in this build yet.');
}
