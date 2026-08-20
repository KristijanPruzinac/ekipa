import 'package:ekipa_core/ekipa_core.dart';
import 'package:ekipa_core/matching.dart';

/// Every configuration key the console may edit, assembled here.
///
/// **Intention — why this list is built at the composition root and not
/// declared once inside `ekipa_core`.**
///
/// A static `ConfigCatalogue.all` in the core package would have to import
/// `MatchingKeys`, and `MatchingKeys` lives behind `package:ekipa_core/
/// matching.dart` precisely so that the mobile binary never carries the ring
/// shares (directive D9, enforced by `MOBILE-NO-MATCHING` in `tools/lint`). One
/// convenience constant would defeat the boundary that three lint rules exist
/// to hold. So each *binary* names the groups it is entitled to see, and the
/// console is the only one entitled to see all of them.
///
/// This is also why the console may import `matching.dart` at all while the app
/// may not: tuning ring shares is the console's job, and `12_CONSOLE.md` §6
/// asks for exactly that screen. The lint scopes the ban to `apps/mobile` and
/// `packages/ekipa_ui` for that reason.
///
/// Adding a group here is the whole of "make a new key editable". Forgetting to
/// is not silent: `ConfigDraft.validate` refuses an edit to a key no catalogue
/// declares, so an undeclared key is refused by the console before it can
/// become a row nothing reads.
ConfigCatalogue buildConsoleCatalogue() => ConfigCatalogue([
  MatchingKeys.group,
  ScheduleKeys.group,
]);

/// The layers the console publishes to, for the cities it knows about.
///
/// **Intention.** `ConfigDraft.validate` checks each cross-key invariant once
/// per target, not once globally, because a rule can hold everywhere and break
/// in one city — a city override that pushes `min_group_size` above
/// `max_group_size` is valid at the global layer and nonsense in Osijek. The
/// console therefore has to tell the validator which resolutions actually
/// exist, and that set is "everywhere, plus each real city".
List<ConfigTarget> targetsFor(Iterable<CityId> cities) => [
  const ConfigTarget.everywhere(),
  for (final city in cities) ConfigTarget(cityId: city),
];
