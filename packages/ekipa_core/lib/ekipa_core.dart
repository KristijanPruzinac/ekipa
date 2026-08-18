/// Pure domain, policies and value objects shared by every ekipa runtime.
///
/// **This library deliberately does not export the matcher.** The matching
/// algorithms live behind `package:ekipa_core/matching.dart`, a separate entry
/// point that the mobile app must never import — directive D9, control SC-6 in
/// `docs/v3/11_SECURITY.md`, enforced by `tools/lint`.
///
/// The reason is not secrecy for its own sake: a user who can read the matcher
/// can infer, from their own match history, information about how other people
/// rated them. That breaks the asymmetry invariant, which is the single
/// load-bearing privacy promise in the product.
library;

export 'src/foundation/clock.dart';
export 'src/foundation/config.dart';
export 'src/foundation/display_name.dart';
export 'src/foundation/ids.dart';
export 'src/foundation/random_source.dart';
export 'src/foundation/result.dart';
