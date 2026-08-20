/// The declared defaults must satisfy the declared invariants.
///
/// **Intention — an invariant nobody runs is a comment.** Each of these was
/// written because violating it produces a specific unkindness: a person told
/// where to go while still being asked whether they are coming, a cancellation
/// that lands after somebody left home, a version in which the cheapest answer
/// is to say nothing. The console refuses to publish a version that breaks one.
///
/// That leaves one gap the console cannot cover: the **defaults**, which are
/// what a city runs on before anybody has published anything at all. Nothing
/// validates those, because nothing publishes them. This does.
library;

import 'package:ekipa_core/ekipa_core.dart';
import 'package:test/test.dart';

void main() {
  final defaults = ConfigSnapshot.defaults();

  for (final group in [LifecycleKeys.group, TrustKeys.group]) {
    group_(group, defaults);
  }

  test('every key name is unique across the groups the console loads', () {
    // A duplicate name is not a compile error and not a runtime error: the
    // second declaration wins, silently, and one of the two descriptions is a
    // lie about what the key does. `ConfigCatalogue` throws on it, so building
    // one is the assertion.
    expect(
      () => ConfigCatalogue([LifecycleKeys.group, TrustKeys.group]),
      returnsNormally,
    );
  });

  test('every key resolves to its default from an empty snapshot', () {
    // A key whose `read` cannot handle a missing value would throw the first
    // time a fresh city ran, which is the worst possible moment to find out.
    for (final key in [...LifecycleKeys.all, ...TrustKeys.all]) {
      expect(
        () => defaults.get(key),
        returnsNormally,
        reason: '${key.name} cannot fall back to its own default',
      );
    }
  });
}

void group_(ConfigGroup group, ConfigSnapshot defaults) {
  for (final invariant in group.invariants) {
    test('${group.name}: ${invariant.name}', () {
      expect(
        invariant.holds(defaults),
        isTrue,
        reason: invariant.explanation,
      );
    });
  }
}
