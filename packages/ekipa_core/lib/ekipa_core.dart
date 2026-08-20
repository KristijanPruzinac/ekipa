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

export 'src/activities/activity.dart';
export 'src/activities/cards_activity.dart';
export 'src/activities/conversation_deck.dart';
export 'src/config/blast_radius.dart';
export 'src/config/catalogue.dart';
export 'src/config/draft.dart';
export 'src/config/schedule.dart';
export 'src/config/scope.dart';
export 'src/domain/basemap.dart';
export 'src/domain/gender.dart';
export 'src/domain/geo.dart';
export 'src/domain/lifecycle.dart';
export 'src/domain/pair.dart';
export 'src/domain/person.dart';
export 'src/domain/slot.dart';
export 'src/domain/standing.dart';
export 'src/foundation/clock.dart';
export 'src/foundation/config.dart';
export 'src/foundation/display_name.dart';
export 'src/foundation/ids.dart';
export 'src/foundation/random_source.dart';
export 'src/foundation/result.dart';
export 'src/identity/academic_address.dart';
