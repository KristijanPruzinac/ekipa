import 'package:console/src/state/providers.dart';
import 'package:ekipa_core/ekipa_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_gateway.dart';

/// The properties `main.dart` relies on and never states.
///
/// **Intention.** The composition root binds exactly two ports and nothing
/// else. Both of those bindings are load-bearing in a way that is invisible
/// when they work: a default that quietly reached the network would turn every
/// widget test into an integration test against a live project, and a default
/// clock would make three "is this in the past" rules untestable. These tests
/// hold the two ports to failing loudly.
void main() {
  group('the ports refuse to default', () {
    test('the gateway throws rather than reaching a real client', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Riverpod wraps whatever a provider threw, so the assertion is on the
      // message rather than the type. The message is the part that matters: it
      // names the fix, and it is what a developer sees when a screen reaches
      // for a port nobody bound.
      expect(
        () => container.read(gatewayProvider),
        throwsA(
          predicate<Object>(
            (error) => '$error'.contains('gatewayProvider must be overridden'),
          ),
        ),
      );
    });

    test('the clock throws rather than reading the wall clock', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(
        () => container.read(clockProvider),
        throwsA(
          predicate<Object>(
            (error) => '$error'.contains('clockProvider must be overridden'),
          ),
        ),
      );
    });
  });

  group('the role ladder matches the database', () {
    // `atLeast` mirrors `admin_at_least` in migration 0009, including its
    // ordering. It is a second copy of a rule, which is normally the thing to
    // avoid — it exists only to grey out a button, and the server re-checks
    // every write regardless. This test is what keeps the copy honest.
    test('an owner is at least anything below them', () {
      expect(atLeast('owner', 'viewer'), isTrue);
      expect(atLeast('owner', 'operator'), isTrue);
      expect(atLeast('owner', 'owner'), isTrue);
    });

    test('a viewer is not an operator', () {
      expect(atLeast('viewer', 'operator'), isFalse);
      expect(atLeast('viewer', 'owner'), isFalse);
      expect(atLeast('viewer', 'viewer'), isTrue);
    });

    test('no role is not a role', () {
      // The answer for an operator who has not completed a second factor. It
      // must not accidentally satisfy the bottom of the ladder.
      expect(atLeast(null, 'viewer'), isFalse);
      expect(atLeast(null, 'operator'), isFalse);
    });

    test('a role this build does not know grants nothing', () {
      // A role added to the database and not yet to this build. Failing closed
      // is the only safe reading: the alternative is a name nobody recognises
      // being treated as the highest thing it resembles.
      expect(atLeast('superuser', 'viewer'), isFalse);
    });
  });

  group('what the console can ask for', () {
    // The port is the complete, readable list of what a console session can
    // do, and nothing in it returns a person, a rating, a report or a
    // standing. That is a property of the interface rather than of a test —
    // the compiler is what enforces it, because the fake below could not
    // implement a method the port does not declare, and a screen cannot call
    // one that is not there.
    test('the fake answers every declared method', () async {
      // If the port grows a method, this fails to compile before it fails
      // here — which is the point. The call log then proves nothing was
      // answered from a cache or skipped.
      final gateway = FakeConsoleGateway();
      await gateway.role();
      await gateway.configVersions();
      await gateway.configValues(
        const ConfigVersionId('00000000-0000-4000-8000-000000000000'),
      );
      await gateway.cities();
      await gateway.slots(
        cityId: const CityId('00000000-0000-4000-8000-000000000000'),
        from: DateTime.utc(2026, 10, 20),
        to: DateTime.utc(2026, 11, 3),
      );
      await gateway.inFlight();
      await gateway.audit();

      expect(gateway.calls, hasLength(7));
    });
  });
}
